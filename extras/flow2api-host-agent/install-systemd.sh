#!/usr/bin/env bash
# Flow2API Host Agent - systemd installer
# Usage: bash install-systemd.sh [install-dir]
set -e

INSTALL_DIR="${1:-/opt/flow2api-host-agent}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="$(command -v python3)"
UVICORN="$(command -v uvicorn || echo '')"

echo "==> Installing to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy files
echo "==> Copying files..."
cp -r "$SCRIPT_DIR/scripts" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/web" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/systemd" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/docs" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
[ -f "$SCRIPT_DIR/agent.toml" ] && cp "$SCRIPT_DIR/agent.toml" "$INSTALL_DIR/" || cp "$SCRIPT_DIR/agent.example.toml" "$INSTALL_DIR/agent.toml"

# Install Python dependencies
echo "==> Installing Python dependencies..."
"$PYTHON" -m pip install -q -r "$INSTALL_DIR/requirements.txt"

# Write browser service
cat > /etc/systemd/system/flow2api-host-agent-browser.service << EOF
[Unit]
Description=Flow2API Host Agent - Chrome Browser
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash -c 'DISPLAY=\$(grep -Po "(?<=display = \").*(?=\")" $INSTALL_DIR/agent.toml) $PYTHON $INSTALL_DIR/scripts/agent.py --config $INSTALL_DIR/agent.toml login'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Write daemon service
cat > /etc/systemd/system/flow2api-host-agent.service << EOF
[Unit]
Description=Flow2API Host Agent - Token Auto Refresh Daemon
After=network.target flow2api-host-agent-browser.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment=PYTHONPATH=$INSTALL_DIR
ExecStart=$PYTHON $INSTALL_DIR/scripts/agent.py --config $INSTALL_DIR/agent.toml daemon
Restart=always
RestartSec=15
StandardOutput=append:/var/log/flow2api-host-agent.log
StandardError=append:/var/log/flow2api-host-agent.log

[Install]
WantedBy=multi-user.target
EOF

# Write Web UI service
if [ -n "$UVICORN" ]; then
cat > /etc/systemd/system/flow2api-host-agent-ui.service << EOF
[Unit]
Description=Flow2API Host Agent - Web UI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment=PYTHONPATH=$INSTALL_DIR
ExecStart=$UVICORN web.app:app --host 0.0.0.0 --port 38110
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

# Reload and enable
echo "==> Enabling services..."
systemctl daemon-reload
systemctl enable flow2api-host-agent-browser.service
systemctl enable flow2api-host-agent.service
[ -n "$UVICORN" ] && systemctl enable flow2api-host-agent-ui.service

echo ""
echo "✅ Installation complete!"
echo ""
echo "Services installed:"
echo "  flow2api-host-agent-browser  - Chrome browser (persistent)"
echo "  flow2api-host-agent          - Token auto-refresh daemon"
[ -n "$UVICORN" ] && echo "  flow2api-host-agent-ui       - Web UI on port 38110"
echo ""
echo "Next steps:"
echo "  1. Edit config: $INSTALL_DIR/agent.toml"
echo "  2. Start browser and login: systemctl start flow2api-host-agent-browser"
echo "  3. Start daemon: systemctl start flow2api-host-agent"
[ -n "$UVICORN" ] && echo "  4. Start Web UI: systemctl start flow2api-host-agent-ui"
echo ""
echo "Logs: journalctl -u flow2api-host-agent -f"
