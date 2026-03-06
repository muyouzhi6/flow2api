# Flow2API Host Agent

一个运行在 **Linux 宿主机** 上的 Flow2API companion service，用于：

- 维护 Google Labs 登录浏览器 profile
- 通过 Chrome DevTools Protocol 读取 `__Secure-next-auth.session-token`
- 调用 Flow2API 的 `/api/plugin/update-token` 自动更新 token
- 提供 Web UI / systemd / 定时刷新能力

> 这个项目用于替代 Chrome 扩展的服务器端自动更新场景。

## 状态

当前目录为产品化骨架，核心 PoC 已验证成功。

## 设计文档

- `docs/PRODUCT_PLAN.md`
