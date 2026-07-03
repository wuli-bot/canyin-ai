#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
餐饮AI店长 MCP Server 基础版
提供门店数据查询能力，兼容MCP标准协议

Author: 餐饮AI店长
Version: 1.0.0
"""

import asyncio
import json
import logging
from datetime import date, datetime
from typing import Any, Optional
import httpx

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from sse_starlette.sse import EventSourceResponse
import uvicorn

# ============================================================
# 配置
# ============================================================

# Supabase 配置
SUPABASE_URL = "https://vovzgflfdwngfuqnxjc.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h"

# MCP 服务配置
MCP_HOST = "0.0.0.0"
MCP_PORT = 8765

# 日志配置
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("canyin_mcp")

# ============================================================
# FastAPI 应用
# ============================================================

app = FastAPI(
    title="餐饮AI店长 MCP Server",
    description="餐饮AI店长的MCP协议接口，提供门店数据查询能力",
    version="1.0.0"
)

# CORS 支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# HTTP 客户端
http_client: Optional[httpx.AsyncClient] = None

# 本地兜底数据（sandbox无法连接Supabase时使用）
local_data: dict = {}
_supabase_available: bool = False


def load_local_data():
    """加载本地兜底数据"""
    global local_data
    import os
    local_path = os.path.join(os.path.dirname(__file__), "local_mock_data.json")
    if os.path.exists(local_path):
        with open(local_path, "r", encoding="utf-8") as f:
            local_data = json.load(f)
        logger.info(f"📦 本地兜底数据已加载: {sum(1 for k in local_data if not k.startswith('_'))} 张表")


def query_local(table: str, params: dict = None, limit: int = 100) -> list:
    """从本地数据查询（简单过滤）"""
    rows = local_data.get(table, [])
    if not rows:
        return []
    if params:
        filtered = []
        for row in rows:
            match = True
            for key, value in params.items():
                row_val = row.get(key)
                if row_val is not None and row_val != value:
                    match = False
                    break
            if match:
                filtered.append(row)
        rows = filtered
    return rows[:limit]


@app.on_event("startup")
async def startup():
    """启动时初始化"""
    global http_client, _supabase_available
    load_local_data()
    http_client = httpx.AsyncClient(
        base_url=SUPABASE_URL,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json"
        },
        timeout=30.0
    )
    # 测试Supabase连接
    try:
        test_resp = await http_client.get("/rest/v1/stores?select=store_code&limit=1")
        _supabase_available = test_resp.status_code == 200
        if _supabase_available:
            logger.info("✅ Supabase连接正常")
        else:
            logger.warning(f"⚠️ Supabase连接异常(HTTP {test_resp.status_code})，使用本地兜底数据")
    except Exception:
        _supabase_available = False
        logger.warning("⚠️ Supabase无法连接，使用本地兜底数据")
    logger.info("🍜 餐饮AI店长 MCP Server 已启动")
    logger.info(f"📡 监听地址: http://{MCP_HOST}:{MCP_PORT}")
    logger.info("")
    logger.info("📋 可用工具:")
    logger.info("   1. get_menu        - 查询门店菜品列表")
    logger.info("   2. get_inventory_status - 查询库存状态")
    logger.info("   3. get_store_info  - 查询门店基本信息")
    logger.info("   4. get_daily_summary - 查询门店日报数据")
    logger.info("")


@app.on_event("shutdown")
async def shutdown():
    """关闭时清理"""
    global http_client
    if http_client:
        await http_client.aclose()
    logger.info("👋 餐饮AI店长 MCP Server 已关闭")


# ============================================================
# Supabase 工具函数
# ============================================================

async def supabase_query(
    table: str,
    params: dict = None,
    select: str = "*",
    limit: int = 100
) -> list:
    """
    查询 Supabase 表（失败时自动切换本地数据）
    """
    if not http_client:
        raise HTTPException(status_code=500, detail="HTTP client not initialized")
    
    # 优先尝试Supabase
    if _supabase_available:
        try:
            query_params = {"select": select, "limit": limit}
            if params:
                for key, value in params.items():
                    if isinstance(value, dict):
                        for op, val in value.items():
                            query_params[f"{key}.{op}"] = val
                    elif value is not None:
                        query_params[key] = value
            
            response = await http_client.get(
                f"/rest/v1/{table}",
                params=query_params
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.warning(f"Supabase query failed ({response.status_code}), 切换本地数据")
        except Exception as e:
            logger.warning(f"Supabase query error: {str(e)}, 切换本地数据")
    
    # 兜底：本地数据
    return query_local(table, params, limit)


async def supabase_query_single(
    table: str,
    params: dict = None,
    select: str = "*"
) -> Optional[dict]:
    """查询单条记录"""
    results = await supabase_query(table, params, select, limit=1)
    return results[0] if results else None


# ============================================================
# MCP 工具定义
# ============================================================

TOOLS = [
    {
        "name": "get_menu",
        "description": "查询门店菜品列表，返回菜品名、价格、成本、毛利率、是否特色菜、是否新品、销量等信息",
        "inputSchema": {
            "type": "object",
            "properties": {
                "store_id": {
                    "type": "string",
                    "description": "门店ID（可选）"
                },
                "store_code": {
                    "type": "string",
                    "description": "门店编码（可选），如：WM001"
                },
                "category": {
                    "type": "string",
                    "description": "菜品分类筛选（可选），如：主食、小吃、饮品、套餐"
                },
                "status": {
                    "type": "string",
                    "description": "菜品状态筛选（可选），如：available（在售）、soldout（售罄）、seasonal（季节限定）、disabled（下架）"
                }
            }
        }
    },
    {
        "name": "get_inventory_status",
        "description": "查询库存状态和低库存预警，返回食材名、当前库存、安全库存、状态等信息",
        "inputSchema": {
            "type": "object",
            "properties": {
                "store_id": {
                    "type": "string",
                    "description": "门店ID（可选）"
                },
                "store_code": {
                    "type": "string",
                    "description": "门店编码（可选），如：WM001"
                },
                "alert_only": {
                    "type": "boolean",
                    "description": "是否只返回预警项（true=仅预警/紧急，false=全部）",
                    "default": False
                }
            }
        }
    },
    {
        "name": "get_store_info",
        "description": "查询门店基本信息，返回店名、地址、营业时间、联系方式等",
        "inputSchema": {
            "type": "object",
            "properties": {
                "store_id": {
                    "type": "string",
                    "description": "门店ID（二选一）"
                },
                "store_code": {
                    "type": "string",
                    "description": "门店编码（二选一），如：WH001"
                }
            },
            "oneOf": [
                {"required": ["store_id"]},
                {"required": ["store_code"]}
            ]
        }
    },
    {
        "name": "get_daily_summary",
        "description": "查询门店日报数据，返回营收、成本、毛利、毛利率、订单数、客单价、差评数、库存预警数等",
        "inputSchema": {
            "type": "object",
            "properties": {
                "store_id": {
                    "type": "string",
                    "description": "门店ID（可选）"
                },
                "store_code": {
                    "type": "string",
                    "description": "门店编码（可选），如：WM001"
                },
                "date": {
                    "type": "string",
                    "description": "查询日期（可选，默认今天），格式：YYYY-MM-DD"
                }
            }
        }
    }
]


# ============================================================
# MCP 工具处理器
# ============================================================

async def handle_get_menu(params: dict) -> dict:
    """处理 get_menu 工具调用"""
    store_id = params.get("store_id")
    store_code = params.get("store_code")
    category = params.get("category")
    status = params.get("status")
    
    # store_code → store_id 解析
    if store_code and not store_id:
        store = await supabase_query_single("stores", {"store_code": store_code})
        if store:
            store_id = store.get("id")
    
    # 构建查询参数
    query_params = {}
    if store_id:
        query_params["store_id"] = store_id
    if category:
        query_params["category"] = category
    if status:
        query_params["status"] = status
    
    # 查询菜品
    dishes = await supabase_query("store_dishes", query_params)
    
    # 格式化结果
    result = []
    for dish in dishes:
        item = {
            "id": dish.get("id"),
            "name": dish.get("dish_name"),
            "category": dish.get("category"),
            "price": float(dish.get("price", 0)) if dish.get("price") else 0,
            "cost": float(dish.get("cost", 0)) if dish.get("cost") else None,
            "gross_margin": float(dish.get("gross_margin", 0)) if dish.get("gross_margin") else None,
            "is_featured": dish.get("is_featured", False),
            "is_new": dish.get("is_new", False),
            "total_sold": int(dish.get("total_sold", 0)) if dish.get("total_sold") else 0,
            "status": dish.get("status", "available"),
            "image_url": dish.get("image_url")
        }
        
        # 如果没有预存的毛利率，根据价格和成本计算
        if item["cost"] and item["price"] > 0 and not item["gross_margin"]:
            item["gross_margin"] = round((item["price"] - item["cost"]) / item["price"] * 100, 2)
        
        result.append(item)
    
    return {
        "success": True,
        "count": len(result),
        "data": result
    }


async def handle_get_inventory_status(params: dict) -> dict:
    """处理 get_inventory_status 工具调用"""
    store_id = params.get("store_id")
    store_code = params.get("store_code")
    alert_only = params.get("alert_only", False)
    
    # store_code → store_id 解析
    if store_code and not store_id:
        store = await supabase_query_single("stores", {"store_code": store_code})
        if store:
            store_id = store.get("id")
    
    # 查询库存表
    query_params = {}
    if store_id:
        query_params["store_id"] = store_id
    
    inventory = await supabase_query("ingredient_inventory", query_params)
    
    # 如果 ingredient_inventory 表不存在，返回友好的提示
    if not inventory:
        # 尝试查询日报中的库存预警数作为替代
        return {
            "success": True,
            "count": 0,
            "data": [],
            "message": "暂无库存数据，请确保 ingredient_inventory 表已创建"
        }
    
    # 格式化结果
    result = []
    for item in inventory:
        current_stock = float(item.get("current_stock", 0))
        safety_stock = float(item.get("safety_stock", 0))
        
        # 判断状态
        if current_stock <= 0:
            status = "紧急"
        elif current_stock <= safety_stock:
            status = "预警"
        else:
            status = "正常"
        
        inventory_item = {
            "id": item.get("id"),
            "ingredient_name": item.get("ingredient_name"),
            "current_stock": current_stock,
            "unit": item.get("unit", "份"),
            "safety_stock": safety_stock,
            "status": status,
            "last_updated": item.get("updated_at")
        }
        
        # 如果只返回预警项，跳过正常的
        if alert_only and status == "正常":
            continue
        
        result.append(inventory_item)
    
    return {
        "success": True,
        "count": len(result),
        "data": result
    }


async def handle_get_store_info(params: dict) -> dict:
    """处理 get_store_info 工具调用"""
    store_id = params.get("store_id")
    store_code = params.get("store_code")
    
    # 构建查询条件
    query_params = {}
    if store_id:
        query_params["id"] = store_id
    elif store_code:
        query_params["store_code"] = store_code
    else:
        return {
            "success": False,
            "error": "必须提供 store_id 或 store_code"
        }
    
    # 查询门店
    store = await supabase_query_single("stores", query_params)
    
    if not store:
        return {
            "success": False,
            "error": "未找到对应的门店"
        }
    
    return {
        "success": True,
        "data": {
            "id": store.get("id"),
            "store_name": store.get("store_name"),
            "store_code": store.get("store_code"),
            "address": store.get("address"),
            "contact_person": store.get("contact_person"),
            "phone": store.get("phone"),
            "business_hours": store.get("business_hours"),
            "status": store.get("status"),
            "platform_accounts": store.get("platform_accounts"),
            "created_at": store.get("created_at")
        }
    }


async def handle_get_daily_summary(params: dict) -> dict:
    """处理 get_daily_summary 工具调用"""
    store_id = params.get("store_id")
    store_code = params.get("store_code")
    query_date = params.get("date")
    
    # store_code → store_id 解析
    if store_code and not store_id:
        store = await supabase_query_single("stores", {"store_code": store_code})
        if store:
            store_id = store.get("id")
    
    if not store_id and not store_code:
        return {
            "success": False,
            "error": "必须提供 store_id"
        }
    
    # 处理日期，默认今天
    if query_date:
        try:
            target_date = datetime.strptime(query_date, "%Y-%m-%d").date()
        except ValueError:
            return {
                "success": False,
                "error": "日期格式错误，请使用 YYYY-MM-DD 格式"
            }
    else:
        target_date = date.today()
    
    # 查询日报
    query_params = {
        "store_id": store_id,
        "summary_date": str(target_date)
    }
    
    summary = await supabase_query_single("store_daily_summary", query_params)
    
    if not summary:
        return {
            "success": True,
            "data": {
                "store_id": store_id,
                "date": str(target_date),
                "message": "当日暂无日报数据"
            }
        }
    
    return {
        "success": True,
        "data": {
            "store_id": summary.get("store_id"),
            "date": summary.get("summary_date"),
            "revenue": float(summary.get("total_revenue", 0)),
            "cost": float(summary.get("total_cost", 0)),
            "gross_profit": float(summary.get("gross_profit", 0)),
            "gross_margin_pct": float(summary.get("gross_margin_pct", 0)) if summary.get("gross_margin_pct") else None,
            "order_count": summary.get("order_count", 0),
            "avg_order_value": float(summary.get("avg_order_value", 0)) if summary.get("avg_order_value") else None,
            "customer_count": summary.get("customer_count", 0),
            "negative_reviews": summary.get("negative_reviews", 0),
            "inventory_alerts": summary.get("inventory_alerts", 0),
            "top_dishes": summary.get("top_dishes", []),
            "channel_breakdown": summary.get("channel_breakdown", {})
        }
    }


async def handle_tool_call(tool_name: str, arguments: dict) -> dict:
    """统一工具调用处理"""
    handlers = {
        "get_menu": handle_get_menu,
        "get_inventory_status": handle_get_inventory_status,
        "get_store_info": handle_get_store_info,
        "get_daily_summary": handle_get_daily_summary
    }
    
    handler = handlers.get(tool_name)
    if not handler:
        return {
            "success": False,
            "error": f"未知工具: {tool_name}"
        }
    
    try:
        return await handler(arguments)
    except Exception as e:
        logger.error(f"Tool {tool_name} error: {str(e)}")
        return {
            "success": False,
            "error": f"执行出错: {str(e)}"
        }


# ============================================================
# MCP 协议端点
# ============================================================

@app.get("/")
async def root():
    """健康检查"""
    return {
        "status": "ok",
        "service": "餐饮AI店长 MCP Server",
        "version": "1.0.0",
        "tools": [t["name"] for t in TOOLS]
    }


@app.get("/mcp")
async def mcp_endpoint():
    """MCP 协议入口 - 返回可用工具列表"""
    return {
        "jsonrpc": "2.0",
        "result": {
            "tools": TOOLS
        }
    }


@app.post("/mcp")
async def mcp_tool_call(request: Request):
    """
    MCP 工具调用端点
    
    支持标准 JSON-RPC 2.0 格式:
    {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "get_menu",
            "arguments": {}
        }
    }
    """
    try:
        body = await request.json()
        logger.info(f"Received MCP request: {json.dumps(body, ensure_ascii=False)}")
        
        # 解析 JSON-RPC 请求
        method = body.get("method")
        request_id = body.get("id")
        params = body.get("params", {})
        
        # 处理不同的 MCP 方法
        if method == "tools/list":
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": TOOLS
                }
            }
        
        elif method == "tools/call":
            tool_name = params.get("name")
            tool_args = params.get("arguments", {})
            
            if not tool_name:
                return {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {
                        "code": -32602,
                        "message": "Missing tool name"
                    }
                }
            
            result = await handle_tool_call(tool_name, tool_args)
            
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(result, ensure_ascii=False, indent=2)
                        }
                    ]
                }
            }
        
        else:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
            
    except json.JSONDecodeError:
        return {
            "jsonrpc": "2.0",
            "id": None,
            "error": {
                "code": -32700,
                "message": "Parse error"
            }
        }
    except Exception as e:
        logger.error(f"MCP request error: {str(e)}")
        return {
            "jsonrpc": "2.0",
            "id": None,
            "error": {
                "code": -32603,
                "message": f"Internal error: {str(e)}"
            }
        }


@app.get("/tools/{tool_name}")
async def get_tool_info(tool_name: str):
    """获取指定工具的详细信息"""
    for tool in TOOLS:
        if tool["name"] == tool_name:
            return {
                "success": True,
                "data": tool
            }
    return {
        "success": False,
        "error": f"Tool not found: {tool_name}"
    }


# ============================================================
# 便捷 REST API 端点（可选，用于快速测试）
# ============================================================

@app.get("/api/menu")
async def api_get_menu(
    store_id: Optional[str] = None,
    store_code: Optional[str] = None,
    category: Optional[str] = None,
    status: Optional[str] = None
):
    """REST API: 获取菜品列表"""
    params = {}
    if store_id:
        params["store_id"] = store_id
    if store_code:
        params["store_code"] = store_code
    if category:
        params["category"] = category
    if status:
        params["status"] = status
    
    return await handle_get_menu(params)


@app.get("/api/inventory")
async def api_get_inventory(
    store_id: Optional[str] = None,
    store_code: Optional[str] = None,
    alert_only: bool = False
):
    """REST API: 获取库存状态"""
    params = {"alert_only": alert_only}
    if store_id:
        params["store_id"] = store_id
    if store_code:
        params["store_code"] = store_code
    return await handle_get_inventory_status(params)


@app.get("/api/store")
async def api_get_store(
    store_id: Optional[str] = None,
    store_code: Optional[str] = None
):
    """REST API: 获取门店信息"""
    params = {}
    if store_id:
        params["store_id"] = store_id
    if store_code:
        params["store_code"] = store_code
    return await handle_get_store_info(params)


@app.get("/api/daily-summary")
async def api_get_daily_summary(
    store_id: Optional[str] = None,
    store_code: Optional[str] = None,
    date: Optional[str] = None
):
    """REST API: 获取日报数据"""
    params = {}
    if store_id:
        params["store_id"] = store_id
    if store_code:
        params["store_code"] = store_code
    if date:
        params["date"] = date
    return await handle_get_daily_summary(params)


# ============================================================
# 主程序入口
# ============================================================

def main():
    """启动 MCP Server"""
    print("")
    print("=" * 50)
    print("🍜 餐饮AI店长 MCP Server")
    print("=" * 50)
    print("")
    print("📋 可用工具:")
    for i, tool in enumerate(TOOLS, 1):
        print(f"   {i}. {tool['name']:25s} - {tool['description'][:40]}...")
    print("")
    print(f"🔗 MCP 端点: http://{MCP_HOST}:{MCP_PORT}/mcp")
    print(f"📖 REST API: http://{MCP_HOST}:{MCP_PORT}/api/")
    print(f"📖 健康检查: http://{MCP_HOST}:{MCP_PORT}/")
    print("")
    print("=" * 50)
    print("")
    
    uvicorn.run(
        app,
        host=MCP_HOST,
        port=MCP_PORT,
        log_level="info"
    )


if __name__ == "__main__":
    main()
