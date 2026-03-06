"""Flow2API Host Agent - Web UI"""
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, Form
from fastapi.requests import Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

# Ensure scripts/ is importable regardless of cwd
BASE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE / 'scripts'))
from core import load_config, read_json  # noqa: E402

CFG_PATH = str(BASE / 'agent.toml')
app = FastAPI(title='Flow2API Host Agent')
templates = Jinja2Templates(directory=str(BASE / 'web' / 'templates'))


def _run_cmd(cmd: str) -> dict:
    """Run agent CLI command and return parsed JSON output."""
    result = subprocess.run(
        ['python3', str(BASE / 'scripts' / 'agent.py'), '--config', CFG_PATH, cmd],
        capture_output=True, text=True
    )
    try:
        return json.loads(result.stdout)
    except Exception:
        return {'error': result.stderr[:500] or 'no output'}


def _write_config(cfg: dict) -> None:
    """Serialize config dict back to TOML (simple key = value format)."""
    lines = []
    for k, v in cfg.items():
        if isinstance(v, bool):
            lines.append(f'{k} = {str(v).lower()}')
        elif isinstance(v, (int, float)):
            lines.append(f'{k} = {v}')
        else:
            escaped = str(v).replace('"', '\\"')
            lines.append(f'{k} = "{escaped}"')
    Path(CFG_PATH).write_text('\n'.join(lines) + '\n', encoding='utf-8')


@app.get('/', response_class=HTMLResponse)
def index(request: Request):
    cfg = load_config(CFG_PATH)
    state = read_json(cfg['state_file']) or {}
    status = _run_cmd('status')

    # Format last update time for display
    last_update_display = '—'
    if state.get('time'):
        try:
            last_update_display = datetime.fromtimestamp(state['time']).strftime('%Y-%m-%d %H:%M:%S')
        except Exception:
            pass

    return templates.TemplateResponse('index.html', {
        'request': request,
        'cfg': cfg,
        'state': state,
        'status': status,
        'last_update_display': last_update_display,
    })


@app.get('/api/status')
def api_status():
    return _run_cmd('status')


@app.post('/action/login')
def action_login():
    _run_cmd('login')
    return RedirectResponse('/', status_code=303)


@app.post('/action/run-once')
def action_run_once():
    result = _run_cmd('run-once')
    # Store result info in redirect for toast display (use query param)
    ok = result.get('success', False)
    flag = '1' if ok else '0'
    return RedirectResponse(f'/?refreshed={flag}', status_code=303)


@app.post('/action/save')
def action_save(
    flow2api_url: str = Form(...),
    connection_token: str = Form(...),
    chrome_profile_dir: str = Form(...),
    remote_debugging_port: int = Form(...),
    display: str = Form(...),
    refresh_interval_minutes: int = Form(...),
):
    cfg = load_config(CFG_PATH)
    cfg.update({
        'flow2api_url': flow2api_url,
        'connection_token': connection_token,
        'chrome_profile_dir': chrome_profile_dir,
        'remote_debugging_port': int(remote_debugging_port),
        'display': display,
        'refresh_interval_minutes': int(refresh_interval_minutes),
    })
    _write_config(cfg)
    return RedirectResponse('/?saved=1', status_code=303)
