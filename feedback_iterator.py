#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
客服反馈驱动智能体迭代系统 - 周度分析报告生成器

功能：
1. 读取过去7天conversations表数据
2. 自动打标（7类标签）
3. 筛选好建议
4. 生成升级建议报告
5. 推送报告供用户审核

作者：戊离
版本：1.0.0
"""

import asyncio
import json
import re
import logging
from datetime import datetime, timedelta, date
from typing import Any, Optional
from collections import Counter, defaultdict
import httpx

# ============================================================
# 配置
# ============================================================

SUPABASE_URL = "https://vovzgflfdwngfuqnxjc.supabase.co"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h"

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("feedback_iterator")


# ============================================================
# 标签识别规则
# ============================================================

# 7类标签的正则/关键词规则
LABEL_RULES = {
    "high_freq_question": {
        "patterns": [
            r"(有没有|有没有.+的)",
            r"(今天|现在|目前).+(特价|活动|优惠|折扣)",
            r"(价格|多少钱|怎么卖|怎么算)",
            r"(几点|什么时候|营业时间|开门|关门)",
            r"(位置|在哪|地址|怎么走|路线)",
            r"(外卖|配送|送餐|送到|多久能到)",
            r"(有没有.+套餐|套餐.*价格|组合.*优惠)",
            r"(能不能.*便宜|打折|优惠)",
        ],
        "description": "高频问题 - 客户反复咨询的内容",
        "min_occurrence": 5,
    },
    "knowledge_gap": {
        "patterns": [
            r"(不知道|不清楚|不确定)",  # Bot端
            r"(暂无|目前.*没有|这个.*不太确定)",  # Bot不确定回答
        ],
        "bot_indicators": ["抱歉", "暂时无法", "不确定", "目前没有", "不清楚"],
        "description": "知识空白 - Bot回答不了的问题",
        "min_occurrence": 1,
    },
    "feature_request": {
        "patterns": [
            r"(你们能不能|能不能.*帮我|可以不可以)",
            r"(要是有.+就好了|如果能.+就好|希望.*能)",
            r"(建议.*加|增加.*功能|开发.*功能)",
            r"(有没有.*计算|有没有.*分析|有没有.*报告)",
            r"(帮我算|帮我查|帮我统计)",
        ],
        "description": "功能需求 - 客户提出的功能诉求",
        "min_occurrence": 1,
    },
    "competitor_mention": {
        "patterns": [
            r"(隔壁|对面|另一家|其他店|别家)",
            r"(美团|饿了么|京东外卖)",
            r"(比.+便宜|比.+好吃|比.+好)",
            r"(之前.+吃|以前.+点)",
        ],
        "keywords": ["客如云", "二维火", "美味不用等", "收钱吧", "美团收银"],
        "description": "竞品情报 - 客户提到的竞争对手",
        "min_occurrence": 1,
    },
    "sentiment_signal": {
        "patterns": [
            r"(怎么这么贵|太贵了|贵了)",
            r"(不好吃|难吃|口味.*差)",
            r"(太慢了|等太久|太久了|慢死)",
            r"(不满意|不行|太差|垃圾)",
            r"(态度.*差|服务.*不好|爱理不理)",
            r"(分量.*少|不够.*吃|没吃饱)",
        ],
        "description": "情绪信号 - 客户不满/抱怨",
        "min_occurrence": 1,
    },
    "good_suggestion": {
        # 好建议需要同时满足3个条件，单独判断
        "positive_indicators": [
            r"(不错|挺好|挺好.*的|可以|建议|如果.*就更好)",
            r"(想法|主意|点子|思路)",
        ],
        "specific_indicators": [
            r"(如果|要是|建议|可以试试|不如|何不)",
            r"(加个|加上|增加|配上|搭配)",
        ],
        "actionable_indicators": [
            r"(功能|菜|口味|价格|包装|配送|服务|环境)",
            r"(推出|上线|增加|改善|优化|升级|添加)",
        ],
        "description": "好建议 - 正面+具体+可操作的客户想法",
        "min_occurrence": 1,
    },
    "repeated_consult": {
        "description": "重复咨询 - 同一客户重复问同类问题",
        "min_occurrence": 2,  # 同一客户≥2次
        "requires_session_analysis": True,
    },
}

# 竞品关键词库
COMPETITOR_KEYWORDS = [
    "客如云", "二维火", "美味不用等", "收钱吧", "美团收银",
    "哗啦啦", "银豹", "奥琦玮", "餐道", "天财商龙",
    "茶百道", "蜜雪冰城", "瑞幸", "麦当劳", "肯德基",
]


# ============================================================
# Supabase 查询
# ============================================================

async def fetch_conversations(client: httpx.AsyncClient, store_id: str, days: int = 7) -> list:
    """获取过去N天的对话数据"""
    since = (datetime.now() - timedelta(days=days)).isoformat()
    
    response = await client.get(
        f"{SUPABASE_URL}/rest/v1/conversations",
        params={
            "store_id": f"eq.{store_id}",
            "created_at": f"gte.{since}",
            "order": "created_at.asc",
            "limit": 1000,
        },
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
        }
    )
    
    if response.status_code == 200:
        return response.json()
    else:
        logger.error(f"Failed to fetch conversations: {response.status_code}")
        return []


async def save_labels(client: httpx.AsyncClient, labels: list) -> bool:
    """批量保存标签到 feedback_labels 表"""
    if not labels:
        return True
    
    response = await client.post(
        f"{SUPABASE_URL}/rest/v1/feedback_labels",
        json=labels,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
    )
    
    if response.status_code in (200, 201):
        logger.info(f"Saved {len(labels)} labels")
        return True
    else:
        logger.error(f"Failed to save labels: {response.status_code} - {response.text}")
        return False


async def save_report(client: httpx.AsyncClient, report: dict) -> Optional[str]:
    """保存迭代报告"""
    response = await client.post(
        f"{SUPABASE_URL}/rest/v1/iteration_reports",
        json=report,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        }
    )
    
    if response.status_code in (200, 201):
        data = response.json()
        return data[0]["id"] if data else None
    else:
        logger.error(f"Failed to save report: {response.status_code} - {response.text}")
        return None


async def save_tasks(client: httpx.AsyncClient, tasks: list) -> bool:
    """批量保存迭代任务"""
    if not tasks:
        return True
    
    response = await client.post(
        f"{SUPABASE_URL}/rest/v1/iteration_tasks",
        json=tasks,
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
    )
    
    if response.status_code in (200, 201):
        logger.info(f"Saved {len(tasks)} tasks")
        return True
    else:
        logger.error(f"Failed to save tasks: {response.status_code} - {response.text}")
        return False


# ============================================================
# 打标引擎
# ============================================================

def tag_conversation(message: dict, all_messages: list) -> list:
    """
    对单条对话消息进行打标
    
    Returns:
        list of {label_type, label_value, confidence, source_role, source_text, ...}
    """
    labels = []
    text = message.get("content", "")
    role = message.get("role", "customer")
    session_id = message.get("session_id", "")
    
    # 跳过Bot回复的打标（除非是知识空白检测）
    if role == "bot":
        # 只检测知识空白（Bot回答不了）
        for pattern in LABEL_RULES["knowledge_gap"]["bot_indicators"]:
            if pattern in text:
                labels.append({
                    "label_type": "knowledge_gap",
                    "label_value": f"Bot不确定回答: {text[:50]}",
                    "confidence": 0.7,
                    "source_role": "bot",
                    "source_text": text,
                })
                break
        return labels
    
    # 客户消息打标
    for label_type, rules in LABEL_RULES.items():
        if label_type == "repeated_consult":
            continue  # 需要session分析，单独处理
        if label_type == "good_suggestion":
            continue  # 需要三条件联合判断，单独处理
        
        patterns = rules.get("patterns", [])
        keywords = rules.get("keywords", [])
        
        for pattern in patterns:
            if re.search(pattern, text):
                labels.append({
                    "label_type": label_type,
                    "label_value": text[:100],
                    "confidence": 0.8,
                    "source_role": "customer",
                    "source_text": text,
                })
                break
        else:
            for keyword in keywords:
                if keyword in text:
                    labels.append({
                        "label_type": label_type,
                        "label_value": keyword,
                        "confidence": 0.9,
                        "source_role": "customer",
                        "source_text": text,
                    })
                    break
    
    # 好建议：三条件联合判断
    if _is_good_suggestion(text):
        labels.append({
            "label_type": "good_suggestion",
            "label_value": text[:100],
            "confidence": 0.85,
            "source_role": "customer",
            "source_text": text,
            "suggestion_actionable": True,
            "suggestion_direction": _extract_direction(text),
        })
    
    return labels


def _is_good_suggestion(text: str) -> bool:
    """判断是否为好建议：正面+具体+可操作"""
    rules = LABEL_RULES["good_suggestion"]
    
    has_positive = any(re.search(p, text) for p in rules["positive_indicators"])
    has_specific = any(re.search(p, text) for p in rules["specific_indicators"])
    has_actionable = any(re.search(p, text) for p in rules["actionable_indicators"])
    
    return has_positive and has_specific and has_actionable


def _extract_direction(text: str) -> str:
    """提取建议的改进方向"""
    directions = {
        "菜品": r"(菜|口味|味道|食材|配菜|加料)",
        "价格": r"(价格|便宜|优惠|折扣|套餐)",
        "配送": r"(配送|外卖|送餐|包装|保温)",
        "服务": r"(服务|态度|速度|响应)",
        "功能": r"(功能|计算|分析|报告|查询)",
        "环境": r"(环境|装修|卫生|座位)",
    }
    for direction, pattern in directions.items():
        if re.search(pattern, text):
            return direction
    return "其他"


def detect_repeated_consults(messages: list) -> list:
    """检测重复咨询：同一session中客户重复问同类问题"""
    labels = []
    
    # 按session分组
    sessions = defaultdict(list)
    for msg in messages:
        if msg.get("role") == "customer":
            sessions[msg.get("session_id", "")].append(msg)
    
    for session_id, msgs in sessions.items():
        if len(msgs) < 2:
            continue
        
        # 简单相似度判断：检查是否有重复的关键词
        question_counter = Counter()
        for msg in msgs:
            # 提取问句特征
            text = msg.get("content", "")
            # 去除常见词，保留核心词
            core = re.sub(r"[的了是在我你他她它吗呢吧啊哦嗯]", "", text)
            # 取前20字符作为特征
            feature = core[:20]
            if len(feature) > 3:
                question_counter[feature] += 1
        
        for feature, count in question_counter.items():
            if count >= 2:
                labels.append({
                    "label_type": "repeated_consult",
                    "label_value": f"重复咨询: {feature}...",
                    "confidence": 0.7,
                    "source_role": "customer",
                    "source_text": f"session={session_id}, feature={feature}",
                })
    
    return labels


# ============================================================
# 报告生成器
# ============================================================

def generate_weekly_report(labels: list, messages: list, week_number: str) -> dict:
    """生成周度升级建议报告"""
    
    # 1. 高频问题（去重+排序）
    question_counter = Counter()
    question_examples = defaultdict(list)
    for label in labels:
        if label["label_type"] == "high_freq_question":
            # 提取核心问题
            question = _extract_core_question(label.get("source_text", ""))
            question_counter[question] += 1
            if len(question_examples[question]) < 3:
                question_examples[question].append(label.get("source_text", "")[:50])
    
    high_freq = [
        {"question": q, "count": c, "examples": question_examples[q]}
        for q, c in question_counter.most_common(10)
    ]
    
    # 2. 知识空白
    gap_counter = Counter()
    for label in labels:
        if label["label_type"] == "knowledge_gap":
            gap_counter[label["label_value"][:50]] += 1
    
    knowledge_gaps = [
        {"gap": g, "count": c}
        for g, c in gap_counter.most_common(10)
    ]
    
    # 3. 功能需求
    feature_counter = Counter()
    feature_examples = defaultdict(list)
    for label in labels:
        if label["label_type"] == "feature_request":
            feature = _extract_feature_name(label.get("source_text", ""))
            feature_counter[feature] += 1
            if len(feature_examples[feature]) < 3:
                feature_examples[feature].append(label.get("source_text", "")[:50])
    
    feature_requests = [
        {"feature": f, "count": c, "examples": feature_examples[f]}
        for f, c in feature_counter.most_common(10)
    ]
    
    # 4. 竞品情报
    competitor_counter = Counter()
    for label in labels:
        if label["label_type"] == "competitor_mention":
            competitor_counter[label["label_value"]] += 1
    
    competitor_mentions = [
        {"competitor": c, "count": n}
        for c, n in competitor_counter.most_common(5)
    ]
    
    # 5. 情绪趋势
    negative_count = sum(1 for l in labels if l["label_type"] == "sentiment_signal")
    total_customer_msgs = sum(1 for m in messages if m.get("role") == "customer")
    satisfaction_rate = round((1 - negative_count / max(total_customer_msgs, 1)) * 100, 1)
    
    sentiment_summary = {
        "satisfaction_rate": satisfaction_rate,
        "last_week_rate": None,  # 需要查询上周数据
        "negative_count": negative_count,
        "top_complaints": _extract_top_complaints(labels),
    }
    
    # 6. 好建议
    good_suggestions = [
        {
            "suggestion": l["label_value"],
            "direction": l.get("suggestion_direction", "其他"),
            "source_text": l.get("source_text", "")[:80],
        }
        for l in labels
        if l["label_type"] == "good_suggestion"
    ]
    # 去重
    seen = set()
    unique_suggestions = []
    for s in good_suggestions:
        key = s["suggestion"][:30]
        if key not in seen:
            seen.add(key)
            unique_suggestions.append(s)
    good_suggestions = unique_suggestions
    
    # 7. 生成建议动作
    suggested_actions = _generate_actions(high_freq, knowledge_gaps, feature_requests, good_suggestions)
    
    # 8. 生成Markdown报告
    report_md = _generate_markdown(
        week_number, high_freq, knowledge_gaps, feature_requests,
        competitor_mentions, sentiment_summary, good_suggestions
    )
    
    return {
        "week_number": week_number,
        "report_date": date.today().isoformat(),
        "high_freq_questions": high_freq,
        "knowledge_gaps": knowledge_gaps,
        "feature_requests": feature_requests,
        "competitor_mentions": competitor_mentions,
        "sentiment_summary": sentiment_summary,
        "good_suggestions": good_suggestions,
        "suggested_actions": suggested_actions,
        "report_markdown": report_md,
        "total_conversations_analyzed": len(set(m.get("session_id", "") for m in messages)),
        "total_labels_generated": len(labels),
    }


def _extract_core_question(text: str) -> str:
    """提取核心问题（去除修饰词）"""
    # 简单实现：取前20个有效字符
    cleaned = re.sub(r"[？?！!。，,]", "", text)
    return cleaned[:25].strip()


def _extract_feature_name(text: str) -> str:
    """提取功能名称"""
    patterns = {
        "成本计算": r"(成本|算.*钱|利润|毛利)",
        "库存查询": r"(库存|还有多少|剩.*个|缺货)",
        "菜单分析": r"(菜单|菜品.*分析|哪个.*卖.*好|最赚钱)",
        "日报": r"(日报|今天.*赚|营业.*数据|汇总)",
        "自动回复": r"(自动.*回复|差评.*回复|怎么.*回复)",
    }
    for name, pattern in patterns.items():
        if re.search(pattern, text):
            return name
    return "未分类功能"


def _extract_top_complaints(labels: list) -> list:
    """提取主要不满意原因"""
    complaints = Counter()
    for label in labels:
        if label["label_type"] == "sentiment_signal":
            text = label.get("source_text", "")
            if re.search(r"(贵|价格)", text):
                complaints["价格偏高"] += 1
            elif re.search(r"(慢|等|久)", text):
                complaints["速度太慢"] += 1
            elif re.search(r"(不好吃|难吃|口味)", text):
                complaints["口味不佳"] += 1
            elif re.search(r"(态度|服务)", text):
                complaints["服务态度"] += 1
            elif re.search(r"(分量|不够)", text):
                complaints["分量不足"] += 1
            else:
                complaints["其他"] += 1
    return [{"reason": r, "count": c} for r, c in complaints.most_common(5)]


def _generate_actions(high_freq, knowledge_gaps, feature_requests, good_suggestions) -> list:
    """根据分析结果生成建议动作"""
    actions = []
    
    # 知识库新增建议
    for item in high_freq[:5]:
        if item["count"] >= 3:
            actions.append({
                "action_type": "knowledge_add",
                "target": "客服Bot知识库",
                "description": f"新增FAQ: {item['question']}（出现{item['count']}次）",
                "priority": "high" if item["count"] >= 10 else "medium",
            })
    
    # 知识空白补充
    for item in knowledge_gaps[:3]:
        actions.append({
            "action_type": "knowledge_update",
            "target": "客服Bot知识库",
            "description": f"补充知识空白: {item['gap']}（出现{item['count']}次）",
            "priority": "high",
        })
    
    # 功能需求
    for item in feature_requests[:3]:
        if item["count"] >= 2:
            actions.append({
                "action_type": "feature_dev",
                "target": item["feature"],
                "description": f"开发功能: {item['feature']}（被提及{item['count']}次）",
                "priority": "high" if item["count"] >= 5 else "medium",
            })
    
    # 好建议
    for suggestion in good_suggestions[:3]:
        actions.append({
            "action_type": "prompt_adjust",
            "target": f"客服Prompt-{suggestion.get('direction', '其他')}",
            "description": f"采纳建议: {suggestion['suggestion'][:50]}",
            "priority": "low",
        })
    
    return actions


def _generate_markdown(week_number, high_freq, knowledge_gaps, feature_requests, 
                       competitor_mentions, sentiment_summary, good_suggestions) -> str:
    """生成Markdown格式的升级建议报告"""
    
    md = f"""## 🍃 智能体升级建议报告（{week_number}）

**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M')}
**分析对话数**: {sentiment_summary.get('total_conversations', 'N/A')}

---

### 一、知识库新增建议

"""
    if high_freq:
        for item in high_freq[:5]:
            md += f"- **建议新增FAQ**: \"{item['question']}\"（出现{item['count']}次）\n"
    else:
        md += "- 本周无高频问题\n"
    
    if knowledge_gaps:
        md += "\n**知识空白补充**:\n"
        for item in knowledge_gaps[:3]:
            md += f"- 补充: \"{item['gap']}\"（出现{item['count']}次）\n"
    
    md += "\n### 二、功能优化建议\n\n"
    if feature_requests:
        for item in feature_requests[:5]:
            md += f"- **{item['feature']}**: 被提及{item['count']}次\n"
    else:
        md += "- 本周无功能需求\n"
    
    md += "\n### 三、竞品情报\n\n"
    if competitor_mentions:
        total_competitor = sum(c["count"] for c in competitor_mentions)
        md += f"- 竞品提及总次数: {total_competitor}次\n"
        for item in competitor_mentions[:3]:
            md += f"- \"{item['competitor']}\"（{item['count']}次）\n"
    else:
        md += "- 本周无竞品提及\n"
    
    md += "\n### 四、情绪趋势\n\n"
    md += f"- 本周满意度: {sentiment_summary.get('satisfaction_rate', 'N/A')}%\n"
    last_week = sentiment_summary.get('last_week_rate')
    if last_week is not None:
        trend = "↑" if sentiment_summary['satisfaction_rate'] > last_week else "↓"
        md += f"- 上周满意度: {last_week}% {trend}\n"
    
    if sentiment_summary.get('top_complaints'):
        md += "- 主要不满意原因:\n"
        for complaint in sentiment_summary['top_complaints'][:3]:
            md += f"  - {complaint['reason']}（{complaint['count']}次）\n"
    
    md += "\n### 五、好建议汇总\n\n"
    if good_suggestions:
        for i, s in enumerate(good_suggestions[:5], 1):
            md += f"{i}. [{s.get('direction', '其他')}] {s['suggestion'][:60]}\n"
    else:
        md += "- 本周无好建议\n"
    
    md += f"""
---

> 📋 请审核后回复「确认执行」触发自动升级
> 或回复具体条目如「执行建议1、3」选择性执行
"""
    return md


# ============================================================
# 主流程
# ============================================================

async def run_weekly_analysis(store_id: str = None, days: int = 7):
    """执行周度分析"""
    
    logger.info("🚀 开始执行客服反馈周度分析...")
    
    # 获取门店ID
    if not store_id:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{SUPABASE_URL}/rest/v1/stores",
                params={"select": "id", "limit": 1},
                headers={"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"}
            )
            if resp.status_code == 200 and resp.json():
                store_id = resp.json()[0]["id"]
            else:
                logger.error("无法获取门店ID")
                return None
    
    logger.info(f"📍 门店ID: {store_id}")
    
    async with httpx.AsyncClient() as client:
        # 1. 获取对话数据
        messages = await fetch_conversations(client, store_id, days)
        logger.info(f"📥 获取到 {len(messages)} 条对话记录")
        
        if not messages:
            logger.info("📭 本周无新对话，跳过分析")
            return None
        
        # 2. 自动打标
        all_labels = []
        for msg in messages:
            msg_labels = tag_conversation(msg, messages)
            for label in msg_labels:
                label["store_id"] = store_id
                label["conversation_id"] = msg.get("id")
                all_labels.append(label)
        
        # 检测重复咨询
        repeated_labels = detect_repeated_consults(messages)
        for label in repeated_labels:
            label["store_id"] = store_id
        all_labels.extend(repeated_labels)
        
        logger.info(f"🏷️ 共生成 {len(all_labels)} 个标签")
        
        # 3. 保存标签
        await save_labels(client, all_labels)
        
        # 4. 生成周度报告
        week_number = datetime.now().strftime("%Y-W%W")
        report = generate_weekly_report(all_labels, messages, week_number)
        report["store_id"] = store_id
        
        # 5. 保存报告
        report_id = await save_report(client, report)
        logger.info(f"📊 报告已保存，ID: {report_id}")
        
        # 6. 生成任务
        tasks = []
        for action in report.get("suggested_actions", []):
            task = {
                "report_id": report_id,
                "task_type": action["action_type"],
                "title": action["description"],
                "description": action["description"],
                "target_module": action["target"],
                "priority": action["priority"],
                "status": "pending",
            }
            tasks.append(task)
        
        if tasks:
            await save_tasks(client, tasks)
            logger.info(f"📋 生成 {len(tasks)} 个迭代任务")
        
        # 7. 输出报告
        print("\n" + "="*60)
        print(report["report_markdown"])
        print("="*60)
        
        return report


if __name__ == "__main__":
    asyncio.run(run_weekly_analysis())
