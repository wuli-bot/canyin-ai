# 餐饮AI店长 MCP Server 对外开放文档

> 版本：1.0.0 | 更新时间：2026-07-01
> 状态：初稿 | 待公网部署后正式上线

---

## 一、服务概述

餐饮AI店长 MCP Server 是面向餐饮行业的标准化数据接口服务，兼容 Model Context Protocol (MCP) 标准协议。任何支持 MCP 的 AI Agent（千问、微信AI、ChatGPT、Claude 等）均可通过标准协议调用我们的餐饮数据能力。

**服务地址**：`https://mcp.canyin-ai.com/mcp`（待部署）
**REST API**：`https://mcp.canyin-ai.com/api/`（待部署）
**协议版本**：JSON-RPC 2.0

---

## 二、可用工具列表

| 工具名 | 功能 | 参数 |
|--------|------|------|
| `get_menu` | 查询门店菜品列表 | store_id(可选), category(可选), status(可选) |
| `get_inventory_status` | 查询库存状态和预警 | store_id(可选), alert_only(可选) |
| `get_store_info` | 查询门店基本信息 | store_id 或 store_code（二选一） |
| `get_daily_summary` | 查询门店日报数据 | store_id(必填), date(可选) |

---

## 三、MCP 协议调用

### 3.1 列出所有工具

```bash
curl -X GET https://mcp.canyin-ai.com/mcp
```

返回：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "get_menu",
        "description": "查询门店菜品列表...",
        "inputSchema": { ... }
      }
    ]
  }
}
```

### 3.2 调用工具

```bash
curl -X POST https://mcp.canyin-ai.com/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_store_info",
      "arguments": {"store_code": "WH001"}
    }
  }'
```

返回：
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{...门店数据...}"
      }
    ]
  }
}
```

---

## 四、REST API 快速测试

适合非 MCP 场景的快速数据获取：

```bash
# 获取门店信息
curl "https://mcp.canyin-ai.com/api/store?store_code=WH001"

# 获取菜品列表
curl "https://mcp.canyin-ai.com/api/menu"

# 获取库存预警
curl "https://mcp.canyin-ai.com/api/inventory?alert_only=true"

# 获取日报
curl "https://mcp.canyin-ai.com/api/daily-summary?store_id=STORE_ID&date=2026-07-01"
```

---

## 五、认证方式

### 5.1 API Key 认证

所有请求需在 Header 中携带 API Key：

```
Authorization: Bearer YOUR_API_KEY
```

### 5.2 获取 API Key

1. 访问 https://canyin-ai.com/dashboard
2. 注册/登录账号
3. 进入「开发者设置」→「API Keys」
4. 点击「创建新密钥」，设置权限范围
5. 复制密钥（仅显示一次）

### 5.3 权限范围

| 权限 | 说明 |
|------|------|
| `menu:read` | 读取菜品数据 |
| `inventory:read` | 读取库存数据 |
| `store:read` | 读取门店信息 |
| `summary:read` | 读取日报数据 |
| `all:read` | 全部读取权限 |

---

## 六、接口规范

### 6.1 请求格式

- 协议：HTTPS（强制）
- 编码：UTF-8
- Content-Type：application/json
- 方法：GET（查询）/ POST（MCP调用）

### 6.2 响应格式

```json
{
  "success": true,
  "count": 10,
  "data": [ ... ],
  "message": "可选的附加信息"
}
```

错误响应：
```json
{
  "success": false,
  "error": "错误描述",
  "code": 400
}
```

### 6.3 限流策略

| 套餐 | 请求频率 | 日配额 |
|------|---------|--------|
| 免费版 | 10次/分钟 | 1000次/天 |
| 标准版 | 60次/分钟 | 50000次/天 |
| 企业版 | 不限 | 不限 |

超出限流返回 HTTP 429：
```json
{
  "success": false,
  "error": "Rate limit exceeded. Retry after 60 seconds.",
  "code": 429,
  "retry_after": 60
}
```

### 6.4 版本管理

API 版本通过 URL 路径管理：
- 当前版本：`/v1/`
- 示例：`https://mcp.canyin-ai.com/v1/mcp`

版本更新时旧版本保留至少12个月。

---

## 七、与外部 AI 集成示例

### 7.1 千问 App

```python
# 在千问 Agent 配置中添加 MCP 工具
# 工具端点：https://mcp.canyin-ai.com/mcp
# 认证：API Key

# 千问 Agent 会自动调用我们的工具来回答餐饮相关问题
# 例如："帮我查一下门店WH001今天的营收"
# → 千问自动调用 get_daily_summary(store_id="WH001")
```

### 7.2 微信 AI

```python
import httpx

# 微信 AI Agent 通过 HTTP 调用
response = httpx.post(
    "https://mcp.canyin-ai.com/mcp",
    headers={
        "Authorization": "Bearer YOUR_API_KEY",
        "Content-Type": "application/json"
    },
    json={
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "get_menu",
            "arguments": {"category": "主食"}
        }
    }
)
```

### 7.3 ChatGPT / Claude（Function Calling）

```python
import openai

client = openai.OpenAI(api_key="your-openai-key")

# 定义我们的 MCP 工具为 Function
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_store_info",
            "description": "查询餐饮门店基本信息",
            "parameters": {
                "type": "object",
                "properties": {
                    "store_code": {
                        "type": "string",
                        "description": "门店编码，如 WH001"
                    }
                }
            }
        }
    }
]

# 用户提问
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "门店WH001在哪里？"}],
    tools=tools
)

# GPT 会返回 function_call，我们执行后返回结果
```

---

## 八、数据说明

### 8.1 数据来源

所有数据来自餐饮AI店长系统的 Supabase 数据库：
- `stores` — 门店主表
- `store_dishes` — 门店菜品表
- `store_daily_summary` — 门店日报表
- `ingredient_inventory` — 食材库存表

### 8.2 数据更新频率

- 菜品数据：实时
- 库存数据：实时
- 日报数据：每日凌晨自动生成
- 门店信息：手动更新后实时生效

### 8.3 数据权限

- 每个 API Key 绑定到特定门店
- 跨门店查询需要企业版权限
- 所有查询操作均有日志记录

---

## 九、SDK 支持（规划中）

| 语言 | 状态 | 说明 |
|------|------|------|
| Python | ✅ 已可用 | pip install canyin-mcp |
| JavaScript | ⏳ 开发中 | npm install @canyin/mcp |
| Java | 🔜 计划中 | - |

---

## 十、常见问题

### Q: 如何申请 API Key？
A: 访问 https://canyin-ai.com/dashboard 注册账号后在「开发者设置」中创建。

### Q: 支持哪些 MCP 客户端？
A: 支持所有兼容 JSON-RPC 2.0 标准的 MCP 客户端，包括但不限于千问 App、ChatGPT、Claude、LangChain 等。

### Q: 数据安全性如何保障？
A: 全链路 HTTPS 加密，API Key 认证，所有操作有审计日志。企业版支持 IP 白名单。

### Q: 可以自定义数据字段吗？
A: 企业版支持自定义数据导出格式，请联系客服。

### Q: 服务可用性 SLA 是多少？
A: 标准版 99.5%，企业版 99.9%。

---

## 十一、联系方式

- 技术支持：Air19770809（微信）
- 邮箱：wuli@coze.email
- 文档更新：https://github.com/wuli-bot/canyin-ai
- 问题反馈：https://github.com/wuli-bot/canyin-ai/issues
