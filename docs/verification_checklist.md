# 望月湖店全链路验收清单

> 日期：2026-07-03 | 版本：调试运行阶段 v1

## 链路1：数据链路（Supabase + 模拟数据）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| Supabase项目运行 | ✅ | 项目未暂停，CPU/磁盘正常运行 |
| v2_schema.sql 执行 | ⏳ | 6张基础表（stores/conversations/transactions/dishes/summary/configs） |
| supabase_build.sql 执行 | ⏳ | 15张运营表（库存/食品安全/设备/员工等） |
| feedback_iteration_schema.sql | ⏳ | 3张迭代表（反馈标签/迭代报告/迭代任务） |
| v2_default_data.sql | ⏳ | WH001湖南外国语职业学院店默认数据 |
| mock_data_wangyuehu.sql | ⏳ | WM001望月湖店模拟数据（1门店+28菜品+3天日报+18库存） |
| 验证查询 | ⏳ | SELECT * FROM stores 能看到WM001 |

## 链路2：展示链路（HTML页面显示数据）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| GitHub Pages可访问 | ✅ | 30个HTML页面全部HTTP 200 |
| multi-store.html | ⏳ | 门店列表显示望月湖店 |
| canyin-ai-compass-light.html | ⏳ | 经营驾驶舱显示日报数据 |
| console.html（单店控制台） | ⏳ | 新建页面，显示望月湖店核心指标 |
| 页面MockData兜底 | ✅ | 8个页面有MockData，3个待修 |

## 链路3：对话链路（Coze Bot + MCP Server）

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 成本核算Bot (boss) | ✅ | 正确返回成本计算JSON（食材2.0+包装1.2=3.2） |
| 差评处理Bot (manager) | ✅ | 返回3版回复+诊断+严重度评估 |
| 私域引流Bot (marketing) | ✅ | 返回引流方案markdown |
| agent-chat.html接入 | ✅ | 3智能体已接入真实Coze API（commit 7f281bf） |
| MCP Server运行 | ✅ | port 8765，4个工具全部可用 |
| MCP本地兜底数据 | ✅ | Supabase不可用时自动切换本地数据 |
| MCP REST API全部验证 | ✅ | store/menu/inventory/daily-summary 4个端点通过 |

## 链路4：单店控制台

| 检查项 | 状态 | 说明 |
|--------|------|------|
| console.html 创建 | ⏳ | 子Agent创建中 |
| 页面可正常打开 | ⏳ | 待验证 |
| 显示望月湖店数据 | ⏳ | 待验证 |

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
1. **competitor/decision/rewrite 3个页面**引用不存在的表（competitors/decision_logs/rewrite_logs），Supabase中无对应schema
2. **MCP Server sandbox SSL限制**：sandbox无法直连Supabase，已用本地兜底数据解决
3. **GitHub Pages deploy偶发失败**：GitHub临时问题，旧版页面仍正常服务
4. **MCP公网部署**：需腾讯云轻量服务器（军师第②线，本周内）

## Git提交记录（调试阶段）
| Commit | 内容 |
|--------|------|
| 7f281bf | fix: agent-chat.html接入真实Coze API |
| 1d2dd01 | docs: 三维自核审查报告 |
| 15bc32b | docs: 硬件对接笔记 |
| 8a2e1f8 | fix: MCP Server加本地兜底数据+store_code参数 |
