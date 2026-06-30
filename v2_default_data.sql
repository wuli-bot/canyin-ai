-- V2默认数据：首家门店 + 默认配置
INSERT INTO stores (store_name, store_code, address, contact_person, phone, business_hours, platform_accounts, status, owner_id, settings)
VALUES (
  '哇塞猛火猪油炒饭',
  'WH001',
  '湖南外国语职业学院北食堂',
  '艾刃',
  '19770809',
  '{"open":"09:00","close":"21:00"}'::jsonb,
  '{"meituan":"shop_wh001_mt","douyin":"shop_wh001_dy","jd":"shop_wh001_jd"}'::jsonb,
  'active',
  'owner_default',
  '{"theme":"dark","auto_reply":true}'::jsonb
) ON CONFLICT (store_code) DO NOTHING;

-- 默认模块配置
INSERT INTO store_configs (store_id, modules_enabled, ai_settings, notification_settings, business_rules)
SELECT 
  s.id,
  ARRAY['选址','开店','招牌','设备','菜单','成本','定价','库存','差评','财务','私域','复购','客服自动回复','MCP实时数据'],
  '{"model":"doubao-lite","temperature":0.7,"anti_ai_flavor":true}'::jsonb,
  '{"feishu_group":true,"daily_report":true,"alert_threshold":{"negative_reviews":3,"inventory":5}}'::jsonb,
  '{"pricing_strategy":"leiJun","decision_model":"leiJun_5models","auto_escalation":true}'::jsonb
FROM stores s WHERE s.store_code = 'WH001'
ON CONFLICT (store_id) DO NOTHING;

-- 今日日报模板
INSERT INTO store_daily_summary (store_id, summary_date, total_revenue, total_cost, gross_profit, gross_margin_pct, order_count, avg_order_value, customer_count, negative_reviews, inventory_alerts, food_safety_score)
SELECT s.id, CURRENT_DATE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100
FROM stores s WHERE s.store_code = 'WH001'
ON CONFLICT (store_id, summary_date) DO NOTHING;
