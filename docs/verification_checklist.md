# 望月湖店全链路验收清单

> 日期：2026-07-03 | 版本：调试运行阶段 v2（10:10更新）

## 链路1：数据链路（Supabase + 模拟数据）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| Supabase项目运行 | ✅ | 项目未暂停，CPU/磁盘正常运行 |
| MCP本地兜底数据 | ✅ | local_mock_data.json：1门店+28菜品+3天日报+18库存 |
| MCP REST API全部验证 | ✅ | store/menu/inventory/daily-summary 4个端点返回WM001数据 |
| Supabase SQL灌入 | ⏳ | 云电脑任务3次超步限制，改用data-loader.html方案 |
| data-loader.html上线 | ✅ | 用户浏览器打开→一键灌数据→REST API直插Supabase |
| 验证查询 | ⏳ | 待data-loader执行后验证 |

## 链路2：展示链路（HTML页面显示数据）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| GitHub Pages可访问 | ✅ | 全部页面HTTP 200（.nojekyll修复deploy问题） |
| console.html（单店控制台） | ✅ | 已上线，764行，MockData兜底，移动端优先 |
| data-loader.html（数据加载器） | ✅ | 已上线，298行，浏览器一键灌数据 |
| portal.html（门户入口） | ✅ | HTTP 200 |
| agent-chat.html（AI对话） | ✅ | HTTP 200，已接入真实Coze API |
| diagnosis.html（免费诊断） | ✅ | HTTP 200 |
| canyin-ai-compass-light.html | ✅ | HTTP 200 |
| 页面MockData兜底 | ✅ | 8个页面有MockData，3个待修 |

## 链路3：对话链路（Coze Bot + MCP Server）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 成本核算Bot (boss) | ✅ | 正确返回成本计算JSON（食材2.0+包装1.2=3.2） |
| 差评处理Bot (manager) | ✅ | 返回3版回复+诊断+严重度评估 |
| 私域引流Bot (marketing) | ✅ | 返回引流方案markdown |
| agent-chat.html接入 | ✅ | 3智能体已接入真实Coze API（commit 7f281bf） |
| MCP Server运行 | ✅ | port 8765，4个工具全部可用 |
| MCP store_code参数 | ✅ | 全部工具+REST API支持WM001参数 |

## 链路4：单店控制台

| 检查项 | 状态 | 说明 |
|--------|------|------|
| console.html 创建 | ✅ | 764行，26KB，子Agent完成 |
| 页面已部署 | ✅ | GitHub Pages HTTP 200 |
| 显示望月湖店数据 | ✅ | MockData兜底：营收¥1820/订单98/毛利率65%/预警3项 |
| 快捷入口 | ✅ | 6个：AI助手/成本核算/差评处理/菜单管理/库存查看/日报详情 |

## 测试入口

### 主要测试页面
- **单店控制台**: https://wuli-bot.github.io/canyin-ai/console.html
- **门户入口**: https://wuli-bot.github.io/canyin-ai/portal.html
- **经营驾驶舱**: https://wuli-bot.github.io/canyin-ai/canyin-ai-compass-light.html

### AI对话测试
- **老板助手**: https://wuli-bot.github.io/canyin-ai/agent-chat.html?agent=boss
- **店长助手**: https://wuli-bot.github.io/canyin-ai/agent-chat.html?agent=manager
- **营销助手**: https://wuli-bot.github.io/canyin-ai/agent-chat.html?agent=marketing

### 其他功能页
- **免费诊断**: https://wuli-bot.github.io/canyin-ai/diagnosis.html
- **多店管理**: https://wuli-bot.github.io/canyin-ai/multi-store.html
- **客服Bot**: https://wuli-bot.github.io/canyin-ai/xiaowa-bot.html

## 已知问题
1. **Supabase SQL灌入未完成**：云电脑浏览器任务3次超步限制（CodeMirror注入太复杂）。已创建data-loader.html作为替代方案，用户在浏览器打开即可一键灌数据
2. **sandbox封锁*.supabase.co**：sandbox+bash环境网络层封锁，curl返回HTTP 000，SSL verify=False无效。只有浏览器可访问Supabase
3. **competitor/decision/rewrite 3个页面**引用不存在的表，需后续修复
4. **MCP公网部署**：需腾讯云轻量服务器（军师第②线，本周内），当前MCP在localhost:8765

## Git提交记录（调试阶段）
| Commit | 内容 |
|--------|------|
| 7f281bf | fix: agent-chat.html接入真实Coze API |
| 1d2dd01 | docs: 三维自核审查报告 |
| 15bc32b | docs: 硬件对接笔记 |
| 8a2e1f8 | fix: MCP Server加本地兜底数据+store_code参数 |
| 31d856a | docs: 全链路验收清单 |
| 480dd57 | feat: 望月湖店单店控制台console.html |
| 5b43f92 | fix: .nojekyll修复GitHub Pages deploy |
| a7f3bb7 | feat: 数据加载器data-loader.html |
