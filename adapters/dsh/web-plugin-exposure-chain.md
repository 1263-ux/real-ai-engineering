# Web 插件 settings 暴露链路（DSH）

> 来源：dsh-oks / dev-loop 真实事故（2026-08-19）——「插件注册了 namespace，但浏览器看不到」。
> 用途：任何 DSH Web 插件接入前的链路检查清单，避免重复踩「注册 ≠ 暴露」。

## 链路（先画图，再动代码）

```
host register → settings service → api proxy expose → client scope → UI render
```

1. **host register** — 插件调用 `ctx.settings.register(ns, schema, ...)` 注册 namespace。
2. **settings service**（`@deepseek-ai/dsh-settings`）— 负责注册与存储（写回配置文件）。
3. **api proxy expose**（`@deepseek-ai/dsh-host-apiproxy`）— `WEB_SETTINGS_NAMESPACES` 白名单决定哪些 namespace 能通过 `settings.describe` 暴露给浏览器。**不在白名单 = 注册了也看不见。**
4. **client scope** — 客户端 `settingsScope.bind({ namespace })` 只对已暴露的 namespace 生效；未暴露 → `unavailable`。
5. **UI render** — settings card 读取已暴露 namespace；暴露失败表现为「按钮出现、控制台干净、卡片空白」。

## 关键教训

- **注册 ≠ 暴露**：插件 `register()` 成功不代表浏览器 API 能读到。读路径（describe）与写路径共用同一 allowlist，读写一起被白名单门控。
- **两个产物都要改**：runtime `lib/index.js` 与类型声明 `lib/types/api-proxy.js` 各有一份 `WEB_SETTINGS_NAMESPACES`——只改一处会导致行为不一致。
- **检查顺序**：插件 register → settings 服务有 namespace → host allowlist 含 namespace → client scope / UI。逐跳验证，别从中间猜。
- **跨层问题审查前置**：链路假设先让独立审查验证，再动代码（dev-loop v3.3）。

## 补丁纪律（安装态 vs 上游）

- node_modules / 本地产物修改 = **安装态补丁**，必须标记：为什么改 / 怎么验证 / 怎么回滚 / 如何上游化。
- 长期修复应进上游（如 `packages/host/apiproxy`），不是本机安装目录——重装 / reconcile / 升级会覆盖。

## 运行态验收（AC 模板）

- [ ] `settings.describe` 返回含 `oks`（或目标 namespace）
- [ ] 设置写回更新对应配置文件
- [ ] 浏览器卡片显示真实字段
- [ ] 控制台无报错
- [ ] 相关 tools / hooks / skills 回归
