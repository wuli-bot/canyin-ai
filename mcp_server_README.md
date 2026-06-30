# 餐饮AI店长 MCP Server

餐饮AI店长的MCP协议接口，提供门店数据查询能力供外部AI（千问/微信AI生态）调用。

## 快速启动

```bash
# 安装依赖
pip install -r mcp_requirements.txt

# 启动服务
python mcp_server.py
```

服务将监听 `http://0.0.0.0:8765`

## MCP 工具列表

| 工具名 | 说明 |
|--------|------|
| `get_menu` | 查询门店菜品列表 |
| `get_inventory_status` | 查询库存状态和低库存预警 |
| `get_store_info` | 查询门店基本信息 |
| `get_daily_summary` | 查询门店日报数据 |

## MCP 协议调用

### 1. 列出所有工具

```bash
curl -X GET http://localhost:8765/mcp
```

### 2. 调用工具

```bash
curl -X POST http://localhost:8765/mcp \
  -H "Content-Type: application/json" \
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

## REST API 快速测试

服务还提供了便捷的 REST API 端点：

```bash
# 获取门店信息
curl "http://localhost:8765/api/store?store_code=WH001"

# 获取菜品列表
curl "http://localhost:8765/api/menu"

# 获取日报
curl "http://localhost:8765/api/daily-summary?store_id=<STORE_ID>&date=2026-07-01"
```

## 工具参数说明

### get_menu
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| store_id | string | 否 | 门店ID |
| category | string | 否 | 分类筛选（主食/小吃/饮品/套餐） |
| status | string | 否 | 状态筛选（available/soldout/seasonal/disabled） |

### get_inventory_status
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| store_id | string | 否 | 门店ID |
| alert_only | boolean | 否 | 是否只返回预警项（默认false） |

### get_store_info
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| store_id | string | 二选一 | 门店ID |
| store_code | string | 二选一 | 门店编码（如WH001） |

### get_daily_summary
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| store_id | string | 是 | 门店ID |
| date | string | 否 | 日期（YYYY-MM-DD，默认今天） |

## 数据表依赖

需要确保 Supabase 中存在以下表：
- `stores` - 门店主表
- `store_dishes` - 门店菜品表
- `store_daily_summary` - 门店日报表
- `ingredient_inventory` - 食材库存表（可选，如不存在会返回友好提示）

## 与外部AI集成

### 千问
```python
import openai

client = openai.OpenAI(
    api_key="your-api-key",
    base_url="http://localhost:8765/mcp"
)

# 通过MCP工具调用
response = client.chat.completions.create(
    model="qwen",
    messages=[{"role": "user", "content": "查询门店WH001的今日日报"}]
)
```

### 微信AI生态
通过HTTP请求调用MCP接口获取数据。
