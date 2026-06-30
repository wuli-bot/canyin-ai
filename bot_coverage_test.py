#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小哇客服Bot回复链路覆盖率测试
模拟20+真实对话场景，验证7层回复链路的命中准确性
"""

import re
import json

# ============================================================
# 从 xiaowa-bot.html 提取的核心逻辑（复现）
# ============================================================

KNOWLEDGE_BASE = {
    "营业时间": {
        "answer": "我们每天早上10:00开门，晚上21:00打烊。中午高峰期11:30-13:00，建议错峰下单~",
        "keywords": ["营业时间", "几点", "开门", "关门", "打烊"]
    },
    "门店位置": {
        "answer": "我们在湖南外国语职业学院北食堂，进来就能看到「哇塞猛火猪油炒饭」的招牌🍜",
        "keywords": ["位置", "地址", "在哪", "怎么走", "路线"]
    },
    "外卖配送": {
        "answer": "支持美团外卖和饿了么配送，一般25-40分钟送到。校内配送会更快一些~",
        "keywords": ["外卖", "配送", "送餐", "多久到", "送达", "美团", "饿了么"]
    },
    "支付方式": {
        "answer": "支持微信支付、支付宝、现金，也可以刷校园卡~",
        "keywords": ["支付", "付款", "怎么付", "微信", "支付宝", "现金"]
    },
    "招牌推荐": {
        "answer": "我们的招牌是「招牌猪油炒饭」，用猛火铁锅现炒，粒粒分明，锅气十足！如果想丰富一点，推荐「腊肉猪油炒饭」，腊肉的烟熏香配上猪油的醇厚，绝了🔥\n\n想看完整菜单可以问我「有什么菜」哦~",
        "keywords": ["招牌", "有什么特色", "必点", "特色菜"]
    },
    "转人工": {
        "answer": "HUMAN_TRANSFER",
        "keywords": ["转人工", "人工客服", "找人工", "真人", "找老板"]
    },
}

WECHAT_ID = 'Air19770809'

def generate_reply(user_text, dishes_cache=None):
    """复现 generateReply 逻辑"""
    text = user_text.lower()
    
    # Layer 1: 知识库匹配
    for key, entry in KNOWLEDGE_BASE.items():
        if any(kw in text for kw in entry["keywords"]):
            return entry["answer"], f"Layer1:{key}"
    
    # Layer 2: 菜品查询
    if match_dish_query(text):
        return handle_dish_query(text, dishes_cache), "Layer2:菜品查询"
    
    # Layer 3: 价格查询
    if match_price_query(text):
        return handle_price_query(text, dishes_cache), "Layer3:价格查询"
    
    # Layer 4: 套餐查询
    if any(kw in text for kw in ['套餐', '组合', '搭配']):
        return handle_combo_query(), "Layer4:套餐推荐"
    
    # Layer 5: 功能需求/竞品检测
    if match_feature_request(text) or match_competitor(text):
        return "感谢你的建议！我记下来了，会反馈给产品团队。如果有其他问题随时问我~", "Layer5:功能/竞品"
    
    # Layer 6: 情绪信号
    if match_negative_sentiment(text):
        return "抱歉给你带来了不好的体验😔 我帮你转接人工客服，让老板亲自来帮你处理，好吗？", "Layer6:情绪安抚"
    
    # Layer 7: 兜底（知识空白）
    return f"这个问题我暂时不太确定呢~ 我帮你问问老板，或者你可以直接加老板微信咨询：\n\n微信号：{WECHAT_ID}", "Layer7:兜底"


def match_dish_query(text):
    return any(kw in text for kw in ['菜', '菜单', '有什么', '吃什么', '推荐'])

def handle_dish_query(text, dishes_cache):
    if not dishes_cache:
        return f"菜品数据暂时加载不了，不过我们的招牌猪油炒饭一定有！你加老板微信确认下最新菜单吧~ 微信号：{WECHAT_ID}"
    return "我们目前的菜单🍜\n\n（展示菜品列表）\n\n想吃什么直接告诉我就行~"

def match_price_query(text):
    return any(kw in text for kw in ['价格', '多少钱', '怎么卖', '贵不贵'])

def handle_price_query(text, dishes_cache):
    if not dishes_cache:
        return "价格方面，主食一般在13-25元之间，小吃8-10元，饮品6-8元。具体菜单你可以看看我们的菜品页~"
    return "我们主食价格从¥13到¥25不等，丰俭由人~"

def handle_combo_query():
    return "目前我们还没有固定套餐，但我可以给你推荐几个超值搭配：\n\n💰 经济搭配：「鸡蛋猪油炒饭」¥13 + 「凉拌黄瓜」¥8 = ¥21\n🔥 人气搭配：「招牌猪油炒饭」¥15 + 「冰镇酸梅汤」¥6 = ¥21\n👑 豪华搭配：「虾仁猪油炒饭」¥25 + 「酸辣土豆丝」¥10 + 「柠檬红茶」¥8 = ¥43\n\n你想试试哪个搭配？"

def match_feature_request(text):
    patterns = ['能不能', '可以不可以', '要是有', '如果能', '建议', '希望']
    return any(p in text for p in patterns)

def match_competitor(text):
    competitors = ['隔壁', '对面', '另一家', '其他店']
    return any(c in text for c in competitors)

def match_negative_sentiment(text):
    negatives = ['太贵了', '不好吃', '太慢', '不满意', '太差', '垃圾', '分量少']
    return any(n in text for n in negatives)


# ============================================================
# 测试用例（20+真实场景）
# ============================================================

TEST_CASES = [
    # Layer 1: 知识库匹配（6个）
    {"input": "你们几点开门？", "expected_layer": "Layer1", "expected_content": "10:00", "desc": "营业时间-开门"},
    {"input": "营业时间是什么时候", "expected_layer": "Layer1", "expected_content": "10:00", "desc": "营业时间-直问"},
    {"input": "你们几点关门", "expected_layer": "Layer1", "expected_content": "21:00", "desc": "营业时间-关门"},
    {"input": "你们在哪啊", "expected_layer": "Layer1", "expected_content": "北食堂", "desc": "门店位置"},
    {"input": "地址发一下", "expected_layer": "Layer1", "expected_content": "北食堂", "desc": "门店位置-地址"},
    {"input": "外卖多久能到", "expected_layer": "Layer1", "expected_content": "25-40", "desc": "外卖配送"},
    {"input": "可以微信支付吗", "expected_layer": "Layer1", "expected_content": "微信", "desc": "支付方式"},
    {"input": "你们招牌是什么", "expected_layer": "Layer1", "expected_content": "招牌猪油炒饭", "desc": "招牌推荐"},
    {"input": "有什么好吃的推荐", "expected_layer": "Layer2", "expected_content": "菜单", "desc": "招牌推荐-变体→菜品列表"},
    {"input": "转人工", "expected_layer": "Layer1", "expected_content": "HUMAN_TRANSFER", "desc": "转人工"},
    {"input": "找老板", "expected_layer": "Layer1", "expected_content": "HUMAN_TRANSFER", "desc": "转人工-变体"},
    
    # Layer 2: 菜品查询（3个）
    {"input": "你们有什么菜", "expected_layer": "Layer2", "expected_content": "菜单", "desc": "菜品查询-直接"},
    {"input": "今天吃什么好", "expected_layer": "Layer2", "expected_content": "菜单", "desc": "菜品查询-口语"},
    {"input": "菜单发我看看", "expected_layer": "Layer2", "expected_content": "菜单", "desc": "菜品查询-菜单"},
    
    # Layer 3: 价格查询（2个）
    {"input": "炒饭多少钱", "expected_layer": "Layer3", "expected_content": "价格", "desc": "价格查询-单品"},
    {"input": "你们东西贵不贵", "expected_layer": "Layer3", "expected_content": "价格", "desc": "价格查询-贵不贵"},
    
    # Layer 4: 套餐查询（2个）
    {"input": "有没有套餐", "expected_layer": "Layer4", "expected_content": "搭配", "desc": "套餐-直接"},
    {"input": "帮我搭配一下", "expected_layer": "Layer4", "expected_content": "搭配", "desc": "套餐-搭配"},
    
    # Layer 5: 功能需求/竞品（2个）
    {"input": "你们能不能加个辣椒", "expected_layer": "Layer5", "expected_content": "感谢", "desc": "功能需求"},
    {"input": "隔壁那家比你们便宜", "expected_layer": "Layer5", "expected_content": "感谢", "desc": "竞品提及"},
    
    # Layer 6: 情绪信号（2个）
    {"input": "太贵了吧这也", "expected_layer": "Layer6", "expected_content": "转接人工", "desc": "情绪-太贵"},
    {"input": "等太慢了不满意", "expected_layer": "Layer6", "expected_content": "转接人工", "desc": "情绪-不满"},
    
    # Layer 7: 兜底（2个）
    {"input": "你们食材是哪进的", "expected_layer": "Layer7", "expected_content": "微信号", "desc": "兜底-食材来源"},
    {"input": "有会员吗", "expected_layer": "Layer7", "expected_content": "微信号", "desc": "兜底-会员"},
    {"input": "可以预定吗", "expected_layer": "Layer7", "expected_content": "微信号", "desc": "兜底-预定"},
    {"input": "你们招人不", "expected_layer": "Layer7", "expected_content": "微信号", "desc": "兜底-招聘"},

    # 修复验证: 之前被错误拦截的用例
    {"input": "美团上能点吗", "expected_layer": "Layer1", "expected_content": "美团", "desc": "🔧修复-美团→外卖配送"},
    {"input": "饿了么有吗", "expected_layer": "Layer1", "expected_content": "饿了么", "desc": "🔧修复-饿了么→外卖配送"},
    {"input": "推荐一下你们有什么好吃的", "expected_layer": "Layer2", "expected_content": "菜单", "desc": "🔧修复-推荐→菜品列表"},
]


# ============================================================
# 执行测试
# ============================================================

def run_tests():
    print("=" * 70)
    print("🍜 小哇客服Bot回复链路覆盖率测试")
    print("=" * 70)
    
    total = len(TEST_CASES)
    passed = 0
    failed = 0
    layer_hits = {"Layer1": 0, "Layer2": 0, "Layer3": 0, "Layer4": 0, "Layer5": 0, "Layer6": 0, "Layer7": 0}
    layer_expected = {"Layer1": 0, "Layer2": 0, "Layer3": 0, "Layer4": 0, "Layer5": 0, "Layer6": 0, "Layer7": 0}
    failures = []
    
    for i, tc in enumerate(TEST_CASES, 1):
        reply, hit_layer = generate_reply(tc["input"])
        
        # 统计层级命中
        expected_layer = tc["expected_layer"]
        layer_expected[expected_layer] = layer_expected.get(expected_layer, 0) + 1
        layer_hits[hit_layer.split(":")[0]] = layer_hits.get(hit_layer.split(":")[0], 0) + 1
        
        # 验证命中层级
        actual_layer = hit_layer.split(":")[0]
        layer_ok = actual_layer == expected_layer
        
        # 验证内容包含关键词
        content_ok = tc["expected_content"] in reply
        
        if layer_ok and content_ok:
            passed += 1
            status = "✅"
        else:
            failed += 1
            status = "❌"
            failures.append({
                "case": tc["desc"],
                "input": tc["input"],
                "expected_layer": expected_layer,
                "actual_layer": actual_layer,
                "layer_ok": layer_ok,
                "content_ok": content_ok,
                "reply_preview": reply[:60] + "..." if len(reply) > 60 else reply,
            })
        
        print(f"  {status} [{i:02d}] {tc['desc']:<20} 输入:「{tc['input']}」→ {hit_layer}")
    
    # 汇总
    print("\n" + "=" * 70)
    print(f"📊 测试汇总")
    print(f"=" * 70)
    print(f"  总用例: {total}")
    print(f"  通过: {passed} ({passed/total*100:.1f}%)")
    print(f"  失败: {failed} ({failed/total*100:.1f}%)")
    
    print(f"\n📈 各层级命中分布:")
    for layer in ["Layer1", "Layer2", "Layer3", "Layer4", "Layer5", "Layer6", "Layer7"]:
        expected = layer_expected.get(layer, 0)
        actual = layer_hits.get(layer, 0)
        bar = "█" * actual
        print(f"  {layer}: {actual:>2}次 (期望{expected}次) {bar}")
    
    if failures:
        print(f"\n❌ 失败用例详情:")
        for f in failures:
            print(f"  [{f['case']}] 输入:「{f['input']}」")
            print(f"    期望: {f['expected_layer']}, 实际: {f['actual_layer']}, 层级匹配: {'✅' if f['layer_ok'] else '❌'}, 内容匹配: {'✅' if f['content_ok'] else '❌'}")
            print(f"    回复: {f['reply_preview']}")
    
    # 覆盖率分析
    print(f"\n📋 覆盖率分析:")
    print(f"  Layer1 (知识库):  {layer_hits['Layer1']}/{layer_expected['Layer1']} ✅" if layer_hits['Layer1'] == layer_expected['Layer1'] else f"  Layer1 (知识库):  {layer_hits['Layer1']}/{layer_expected['Layer1']} ⚠️")
    print(f"  Layer2 (菜品查询): {layer_hits['Layer2']}/{layer_expected['Layer2']} ✅" if layer_hits['Layer2'] == layer_expected['Layer2'] else f"  Layer2 (菜品查询): {layer_hits['Layer2']}/{layer_expected['Layer2']} ⚠️")
    print(f"  Layer3 (价格查询): {layer_hits['Layer3']}/{layer_expected['Layer3']} ✅" if layer_hits['Layer3'] == layer_expected['Layer3'] else f"  Layer3 (价格查询): {layer_hits['Layer3']}/{layer_expected['Layer3']} ⚠️")
    print(f"  Layer4 (套餐推荐): {layer_hits['Layer4']}/{layer_expected['Layer4']} ✅" if layer_hits['Layer4'] == layer_expected['Layer4'] else f"  Layer4 (套餐推荐): {layer_hits['Layer4']}/{layer_expected['Layer4']} ⚠️")
    print(f"  Layer5 (功能/竞品): {layer_hits['Layer5']}/{layer_expected['Layer5']} ✅" if layer_hits['Layer5'] == layer_expected['Layer5'] else f"  Layer5 (功能/竞品): {layer_hits['Layer5']}/{layer_expected['Layer5']} ⚠️")
    print(f"  Layer6 (情绪安抚): {layer_hits['Layer6']}/{layer_expected['Layer6']} ✅" if layer_hits['Layer6'] == layer_expected['Layer6'] else f"  Layer6 (情绪安抚): {layer_hits['Layer6']}/{layer_expected['Layer6']} ⚠️")
    print(f"  Layer7 (兜底):    {layer_hits['Layer7']}/{layer_expected['Layer7']} ✅" if layer_hits['Layer7'] == layer_expected['Layer7'] else f"  Layer7 (兜底):    {layer_hits['Layer7']}/{layer_expected['Layer7']} ⚠️")
    
    # 关键问题发现
    print(f"\n⚠️ 潜在问题:")
    issues = []
    
    # 问题1: "外卖多久到" vs Layer1外卖关键词 vs Layer3配送关键词 冲突
    # 外卖配送的keywords含"多久到"，价格查询不含 → 不冲突
    # 但"推荐"同时匹配Layer1(招牌)和Layer2(菜品查询)
    # 由于Layer1优先级高于Layer2，"推荐"会被Layer1拦截 → Layer2的推荐类问题永远到不了
    
    # 检查"推荐"的命中情况
    test_recommend = generate_reply("推荐一下你们有什么好吃的")
    print(f"  ⚠️ 「推荐一下你们有什么好吃的」→ {test_recommend[1]}")
    if "Layer1" in test_recommend[1]:
        print(f"     → 「推荐」被Layer1招牌推荐拦截，不会走到Layer2菜品列表")
        print(f"     → 影响：用户想看完整菜单但得到的是招牌推荐")
        issues.append("「推荐」关键词同时出现在Layer1和Layer2，Layer1优先级更高导致菜品列表展示被拦截")
    
    # 问题2: "美团"同时出现在Layer1(外卖配送)和Layer5(竞品)
    test_meituan = generate_reply("美团上能点吗")
    print(f"\n  ⚠️ 「美团上能点吗」→ {test_meituan[1]}")
    if "Layer1" in test_meituan[1]:
        print(f"     → 「美团」被Layer1外卖配送拦截（关键词包含'外卖'但不包含'美团'...）")
    elif "Layer5" in test_meituan[1]:
        print(f"     → 「美团」被Layer5竞品检测拦截，回复「感谢你的建议」——但用户只是问能不能在美团点！")
        issues.append("「美团」出现在竞品关键词中，但用户说「美团上能点吗」实际是在问外卖渠道，应走Layer1")
    
    # 问题3: "饿了么" 同样
    test_eleme = generate_reply("饿了么有吗")
    print(f"\n  ⚠️ 「饿了么有吗」→ {test_eleme[1]}")
    if "Layer5" in test_eleme[1]:
        print(f"     → 同上，「饿了么」被Layer5竞品检测拦截")
        issues.append("「饿了么」同理，被Layer5竞品检测误拦截")
    
    if not issues:
        print(f"  ✅ 未发现关键问题")
    
    # 修复建议
    if issues:
        print(f"\n🔧 修复建议:")
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}")
        print(f"\n  通用修复方案:")
        print(f"  - Layer5竞品关键词移除「美团」「饿了么」（这两个是外卖平台不是竞品）")
        print(f"  - Layer1招牌推荐的keywords移除「推荐」（或改为更精确的「招牌推荐」「有什么特色」）")
        print(f"  - Layer2菜品查询增加「推荐」匹配，但需调整优先级顺序")
    
    print(f"\n{'='*70}")
    print(f"测试完成 🍃")
    
    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "layer_hits": layer_hits,
        "failures": failures,
        "issues": issues,
    }


if __name__ == "__main__":
    result = run_tests()
