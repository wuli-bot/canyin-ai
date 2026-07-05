-- ============================================================
-- 餐饮AI店长 · 望月湖店模拟数据沙盘
-- 纯增量：创建新门店 + 菜品 + 15天日报 + 交易流水 + 库存
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-07-02
-- ============================================================

-- ============================================================
-- 0. 创建望月湖店
-- ============================================================
INSERT INTO stores (store_name, store_code, address, contact_person, phone, business_hours, platform_accounts, status, owner_id, settings)
VALUES (
  '哇塞猛火猪油炒饭（望月湖店）',
  'WM001',
  '长沙市岳麓区望月湖',
  '艾刃',
  '19770809',
  '{"open":"10:00","close":"21:00"}'::jsonb,
  '{"meituan":"shop_wm001_mt","douyin":"shop_wm001_dy","jd":"shop_wm001_jd"}'::jsonb,
  'active',
  'owner_default',
  '{"theme":"dark","auto_reply":true,"mock_data":true}'::jsonb
) ON CONFLICT (store_code) DO NOTHING;

-- ============================================================
-- 1. 菜品表（store_dishes）—— 14款产品 × 2版本 = 28条
-- ============================================================
INSERT INTO store_dishes (store_id, dish_name, category, price, cost, gross_margin, status, is_featured, is_new, sort_order, description, total_sold, total_revenue, daily_avg_sold, platform_prices)
SELECT s.id, d.dish_name, d.category, d.price, d.cost, d.gross_margin, d.status, d.is_featured, d.is_new, d.sort_order, d.description, d.total_sold, d.total_revenue, d.daily_avg_sold, d.platform_prices::jsonb
FROM stores s
CROSS JOIN (VALUES
  -- 引流款
  ('一口香酱油炒饭（基础版）','主食',9.9,3.0,70.0,'available',true,false,1,'引流爆款，猪油酱油炒饭',3200,31680,213,'{"meituan":10.9,"jd":9.9}'),
  ('一口香酱油炒饭（加量版）','主食',11.9,3.5,71.0,'available',false,false,2,'450g加量版',1200,14280,80,'{"meituan":12.9,"jd":11.9}'),
  -- 招牌款
  ('哇塞蛋炒饭（基础版）','主食',11.0,3.0,73.0,'available',true,false,3,'招牌蛋炒饭，猛火猪油',4100,45100,273,'{"meituan":12.0,"jd":11.0}'),
  ('哇塞蛋炒饭（加量版）','主食',13.0,3.5,73.0,'available',false,false,4,'450g加量版',1800,23400,120,'{"meituan":14.0,"jd":13.0}'),
  -- 常规款
  ('老干妈蛋炒饭（基础版）','主食',12.0,3.0,75.0,'available',false,false,5,'老干妈酱+蛋+炒饭',2100,25200,140,'{"meituan":13.0,"jd":12.0}'),
  ('老干妈蛋炒饭（加量版）','主食',14.0,3.5,75.0,'available',false,false,6,'450g加量版',800,11200,53,'{"meituan":15.0,"jd":14.0}'),
  ('扬州炒饭（基础版）','主食',14.0,3.0,79.0,'available',false,false,7,'经典扬州炒饭',1500,21000,100,'{"meituan":15.0,"jd":14.0}'),
  ('扬州炒饭（加量版）','主食',16.0,3.5,78.0,'available',false,false,8,'450g加量版',500,8000,33,'{"meituan":17.0,"jd":16.0}'),
  ('广式香肠蛋炒饭（基础版）','主食',17.0,6.0,65.0,'available',false,false,9,'广式腊肠+蛋+炒饭',1300,22100,87,'{"meituan":18.0,"jd":17.0}'),
  ('广式香肠蛋炒饭（加量版）','主食',19.0,6.5,66.0,'available',false,false,10,'450g加量版',450,8550,30,'{"meituan":20.0,"jd":19.0}'),
  ('黑椒烤肠蛋炒饭（基础版）','主食',17.0,6.0,65.0,'available',false,false,11,'黑椒烤肠+蛋+炒饭',1100,18700,73,'{"meituan":18.0,"jd":17.0}'),
  ('黑椒烤肠蛋炒饭（加量版）','主食',19.0,6.5,66.0,'available',false,false,12,'450g加量版',400,7600,27,'{"meituan":20.0,"jd":19.0}'),
  ('港式肉肠蛋炒饭（基础版）','主食',17.0,6.0,65.0,'available',false,false,13,'港式肉肠+蛋+炒饭',950,16150,63,'{"meituan":18.0,"jd":17.0}'),
  ('港式肉肠蛋炒饭（加量版）','主食',19.0,6.5,66.0,'available',false,false,14,'450g加量版',350,6650,23,'{"meituan":20.0,"jd":19.0}'),
  -- 高利润款
  ('辣椒炒肉蛋炒饭（基础版）','主食',19.0,6.0,68.0,'available',true,false,15,'湖南辣椒炒肉+蛋+炒饭',2800,53200,187,'{"meituan":20.0,"jd":19.0}'),
  ('辣椒炒肉蛋炒饭（加量版）','主食',21.0,6.5,69.0,'available',false,false,16,'450g加量版',1000,21000,67,'{"meituan":22.0,"jd":21.0}'),
  ('梅菜扣肉蛋炒饭（基础版）','主食',19.0,6.0,68.0,'available',false,false,17,'梅菜扣肉+蛋+炒饭',1200,22800,80,'{"meituan":20.0,"jd":19.0}'),
  ('梅菜扣肉蛋炒饭（加量版）','主食',21.0,6.5,69.0,'available',false,false,18,'450g加量版',400,8400,27,'{"meituan":22.0,"jd":21.0}'),
  ('牛肉蛋炒饭（基础版）','主食',21.0,6.0,71.0,'available',true,false,19,'鲜牛肉+蛋+炒饭',2400,50400,160,'{"meituan":22.0,"jd":21.0}'),
  ('牛肉蛋炒饭（加量版）','主食',23.0,6.5,72.0,'available',false,false,20,'450g加量版',900,20700,60,'{"meituan":24.0,"jd":23.0}'),
  ('整块鸡排蛋炒饭（基础版）','主食',21.0,6.0,71.0,'available',false,false,21,'整块鸡排+蛋+炒饭',1100,23100,73,'{"meituan":22.0,"jd":21.0}'),
  ('整块鸡排蛋炒饭（加量版）','主食',23.0,6.5,72.0,'available',false,false,22,'450g加量版',380,8740,25,'{"meituan":24.0,"jd":23.0}'),
  ('怀旧脆油渣蛋炒饭（基础版）','主食',17.0,6.0,65.0,'available',true,false,23,'猪油渣+蛋+炒饭，怀旧口味',1600,27200,107,'{"meituan":18.0,"jd":17.0}'),
  ('怀旧脆油渣蛋炒饭（加量版）','主食',19.0,6.5,66.0,'available',false,false,24,'450g加量版',550,10450,37,'{"meituan":20.0,"jd":19.0}'),
  -- 炒粉面
  ('素炒粉（基础版）','主食',9.0,2.5,72.0,'available',false,false,25,'素炒米粉',800,7200,53,'{"meituan":10.0,"jd":9.0}'),
  ('素炒粉（加量版）','主食',11.0,3.0,73.0,'available',false,false,26,'450g加量版',300,3300,20,'{"meituan":12.0,"jd":11.0}'),
  ('素炒方便面（基础版）','主食',9.0,2.5,72.0,'available',false,false,27,'素炒方便面',600,5400,40,'{"meituan":10.0,"jd":9.0}'),
  ('素炒方便面（加量版）','主食',11.0,3.0,73.0,'available',false,false,28,'450g加量版',200,2200,13,'{"meituan":12.0,"jd":11.0}')
) AS d(dish_name, category, price, cost, gross_margin, status, is_featured, is_new, sort_order, description, total_sold, total_revenue, daily_avg_sold, platform_prices)
WHERE s.store_code = 'WM001'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. 模块配置（store_configs）
-- ============================================================
INSERT INTO store_configs (store_id, modules_enabled, ai_settings, notification_settings, business_rules)
SELECT
  s.id,
  ARRAY['选址','开店','招牌','设备','菜单','成本','定价','库存','差评','财务','私域','复购','客服自动回复','MCP实时数据'],
  '{"model":"doubao-lite","temperature":0.7,"anti_ai_flavor":true}'::jsonb,
  '{"feishu_group":true,"daily_report":true,"alert_threshold":{"negative_reviews":3,"inventory":5}}'::jsonb,
  '{"pricing_strategy":"leiJun","decision_model":"leiJun_5models","auto_escalation":true,"mock_data":true}'::jsonb
FROM stores s WHERE s.store_code = 'WM001'
ON CONFLICT (store_id) DO NOTHING;

-- ============================================================
-- 3. 日报表（store_daily_summary）—— 7月1日-15日，15天
-- 营收波动规律：工作日1200-2000，周末1800-2500
-- ============================================================
INSERT INTO store_daily_summary (store_id, summary_date, total_revenue, total_cost, gross_profit, gross_margin_pct, order_count, avg_order_value, customer_count, new_customer_count, negative_reviews, inventory_alerts, food_safety_score, top_dishes, bottom_dishes, channel_breakdown, peak_hours, notes)
SELECT
  s.id,
  d.summary_date,
  d.total_revenue,
  d.total_cost,
  d.gross_profit,
  ROUND((d.gross_profit / d.total_revenue * 100)::numeric, 1),
  d.order_count,
  ROUND((d.total_revenue / d.order_count)::numeric, 1),
  d.customer_count,
  d.new_customer_count,
  d.negative_reviews,
  d.inventory_alerts,
  95 + (random() * 5)::int,
  d.top_dishes,
  d.bottom_dishes,
  d.channel_breakdown,
  d.peak_hours,
  CASE WHEN d.is_weekend THEN '周末高峰' ELSE '工作日正常' END
FROM stores s
CROSS JOIN (VALUES
  -- 7月1日 周二
  ('2026-07-01'::date, 1680.0, 588.0, 1092.0, 92, 18.3, 78, 65, 12, 0, 1,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":18,"revenue":198.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":14,"revenue":266.0},{"name":"一口香酱油炒饭（基础版）","qty":16,"revenue":158.4}]'::jsonb,
    '[{"name":"素炒方便面（加量版）","qty":1,"revenue":11.0}]'::jsonb,
    '{"meituan":{"revenue":840,"orders":46},"jd":{"revenue":420,"orders":23},"tangshi":{"revenue":420,"orders":23}}'::jsonb,
    '[{"hour":"11","order_count":15},{"hour":"12","order_count":28},{"hour":"18","order_count":20},{"hour":"19","order_count":18}]'::jsonb,
    true),
  -- 7月2日 周三
  ('2026-07-02'::date, 1520.0, 532.0, 988.0, 85, 17.9, 72, 60, 8, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":16,"revenue":176.0},{"name":"牛肉蛋炒饭（基础版）","qty":12,"revenue":252.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":11,"revenue":209.0}]'::jsonb,
    '[{"name":"港式肉肠蛋炒饭（加量版）","qty":1,"revenue":19.0}]'::jsonb,
    '{"meituan":{"revenue":760,"orders":43},"jd":{"revenue":380,"orders":21},"tangshi":{"revenue":380,"orders":21}}'::jsonb,
    '[{"hour":"11","order_count":14},{"hour":"12","order_count":25},{"hour":"18","order_count":18},{"hour":"19","order_count":15}]'::jsonb,
    false),
  -- 7月3日 周四
  ('2026-07-03'::date, 1450.0, 508.0, 942.0, 82, 17.7, 70, 55, 6, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":15,"revenue":165.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":10,"revenue":190.0},{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":9,"revenue":153.0}]'::jsonb,
    '[{"name":"素炒粉（加量版）","qty":1,"revenue":11.0}]'::jsonb,
    '{"meituan":{"revenue":725,"orders":41},"jd":{"revenue":363,"orders":20},"tangshi":{"revenue":362,"orders":21}}'::jsonb,
    '[{"hour":"11","order_count":13},{"hour":"12","order_count":24},{"hour":"18","order_count":17},{"hour":"19","order_count":14}]'::jsonb,
    false),
  -- 7月4日 周五
  ('2026-07-04'::date, 1850.0, 648.0, 1202.0, 98, 18.9, 83, 70, 15, 1, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":20,"revenue":220.0},{"name":"牛肉蛋炒饭（基础版）","qty":14,"revenue":294.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":13,"revenue":247.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":925,"orders":49},"jd":{"revenue":463,"orders":25},"tangshi":{"revenue":462,"orders":24}}'::jsonb,
    '[{"hour":"11","order_count":16},{"hour":"12","order_count":30},{"hour":"18","order_count":22},{"hour":"19","order_count":20}]'::jsonb,
    false),
  -- 7月5日 周六
  ('2026-07-05'::date, 2280.0, 798.0, 1482.0, 118, 19.3, 100, 88, 22, 1, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":24,"revenue":264.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":18,"revenue":342.0},{"name":"牛肉蛋炒饭（基础版）","qty":15,"revenue":315.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":1140,"orders":59},"jd":{"revenue":570,"orders":30},"tangshi":{"revenue":570,"orders":29}}'::jsonb,
    '[{"hour":"11","order_count":20},{"hour":"12","order_count":36},{"hour":"18","order_count":28},{"hour":"19","order_count":24}]'::jsonb,
    true),
  -- 7月6日 周日
  ('2026-07-06'::date, 2150.0, 753.0, 1397.0, 112, 19.2, 95, 80, 18, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":22,"revenue":242.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":16,"revenue":304.0},{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":12,"revenue":204.0}]'::jsonb,
    '[{"name":"素炒方便面（加量版）","qty":1,"revenue":11.0}]'::jsonb,
    '{"meituan":{"revenue":1075,"orders":56},"jd":{"revenue":538,"orders":28},"tangshi":{"revenue":537,"orders":28}}'::jsonb,
    '[{"hour":"11","order_count":19},{"hour":"12","order_count":34},{"hour":"18","order_count":26},{"hour":"19","order_count":22}]'::jsonb,
    true),
  -- 7月7日 周一
  ('2026-07-07'::date, 1380.0, 483.0, 897.0, 78, 17.7, 66, 50, 5, 0, 1,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":14,"revenue":154.0},{"name":"一口香酱油炒饭（基础版）","qty":13,"revenue":128.7},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":9,"revenue":171.0}]'::jsonb,
    '[{"name":"港式肉肠蛋炒饭（加量版）","qty":1,"revenue":19.0}]'::jsonb,
    '{"meituan":{"revenue":690,"orders":39},"jd":{"revenue":345,"orders":20},"tangshi":{"revenue":345,"orders":19}}'::jsonb,
    '[{"hour":"11","order_count":13},{"hour":"12","order_count":23},{"hour":"18","order_count":16},{"hour":"19","order_count":13}]'::jsonb,
    false),
  -- 7月8日 周二
  ('2026-07-08'::date, 1620.0, 567.0, 1053.0, 88, 18.4, 75, 62, 10, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":17,"revenue":187.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":12,"revenue":228.0},{"name":"牛肉蛋炒饭（基础版）","qty":11,"revenue":231.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":810,"orders":44},"jd":{"revenue":405,"orders":22},"tangshi":{"revenue":405,"orders":22}}'::jsonb,
    '[{"hour":"11","order_count":15},{"hour":"12","order_count":26},{"hour":"18","order_count":19},{"hour":"19","order_count":16}]'::jsonb,
    false),
  -- 7月9日 周三
  ('2026-07-09'::date, 1490.0, 522.0, 968.0, 84, 17.7, 71, 58, 7, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":15,"revenue":165.0},{"name":"扬州炒饭（基础版）","qty":10,"revenue":140.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":10,"revenue":190.0}]'::jsonb,
    '[{"name":"素炒粉（加量版）","qty":1,"revenue":11.0}]'::jsonb,
    '{"meituan":{"revenue":745,"orders":42},"jd":{"revenue":373,"orders":21},"tangshi":{"revenue":372,"orders":21}}'::jsonb,
    '[{"hour":"11","order_count":14},{"hour":"12","order_count":25},{"hour":"18","order_count":17},{"hour":"19","order_count":14}]'::jsonb,
    false),
  -- 7月10日 周四
  ('2026-07-10'::date, 1560.0, 546.0, 1014.0, 86, 18.1, 73, 60, 8, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":16,"revenue":176.0},{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":10,"revenue":170.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":10,"revenue":190.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":780,"orders":43},"jd":{"revenue":390,"orders":22},"tangshi":{"revenue":390,"orders":21}}'::jsonb,
    '[{"hour":"11","order_count":14},{"hour":"12","order_count":26},{"hour":"18","order_count":18},{"hour":"19","order_count":15}]'::jsonb,
    false),
  -- 7月11日 周五
  ('2026-07-11'::date, 1920.0, 672.0, 1248.0, 102, 18.8, 86, 72, 16, 1, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":21,"revenue":231.0},{"name":"牛肉蛋炒饭（基础版）","qty":15,"revenue":315.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":14,"revenue":266.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":960,"orders":51},"jd":{"revenue":480,"orders":26},"tangshi":{"revenue":480,"orders":25}}'::jsonb,
    '[{"hour":"11","order_count":17},{"hour":"12","order_count":31},{"hour":"18","order_count":23},{"hour":"19","order_count":21}]'::jsonb,
    false),
  -- 7月12日 周六
  ('2026-07-12'::date, 2450.0, 858.0, 1592.0, 126, 19.5, 106, 92, 25, 1, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":26,"revenue":286.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":20,"revenue":380.0},{"name":"牛肉蛋炒饭（基础版）","qty":16,"revenue":336.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":1225,"orders":63},"jd":{"revenue":613,"orders":32},"tangshi":{"revenue":612,"orders":31}}'::jsonb,
    '[{"hour":"11","order_count":21},{"hour":"12","order_count":38},{"hour":"18","order_count":30},{"hour":"19","order_count":25}]'::jsonb,
    true),
  -- 7月13日 周日
  ('2026-07-13'::date, 2380.0, 833.0, 1547.0, 122, 19.5, 103, 88, 20, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":25,"revenue":275.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":18,"revenue":342.0},{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":13,"revenue":221.0}]'::jsonb,
    '[{"name":"素炒方便面（加量版）","qty":1,"revenue":11.0}]'::jsonb,
    '{"meituan":{"revenue":1190,"orders":61},"jd":{"revenue":595,"orders":31},"tangshi":{"revenue":595,"orders":30}}'::jsonb,
    '[{"hour":"11","order_count":20},{"hour":"12","order_count":37},{"hour":"18","order_count":29},{"hour":"19","order_count":24}]'::jsonb,
    true),
  -- 7月14日 周一
  ('2026-07-14'::date, 1420.0, 497.0, 923.0, 80, 17.8, 68, 52, 6, 0, 1,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":15,"revenue":165.0},{"name":"一口香酱油炒饭（基础版）","qty":14,"revenue":138.6},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":10,"revenue":190.0}]'::jsonb,
    '[{"name":"港式肉肠蛋炒饭（加量版）","qty":1,"revenue":19.0}]'::jsonb,
    '{"meituan":{"revenue":710,"orders":40},"jd":{"revenue":355,"orders":20},"tangshi":{"revenue":355,"orders":20}}'::jsonb,
    '[{"hour":"11","order_count":13},{"hour":"12","order_count":24},{"hour":"18","order_count":17},{"hour":"19","order_count":14}]'::jsonb,
    false),
  -- 7月15日 周二（开业前最后一天模拟）
  ('2026-07-15'::date, 1700.0, 595.0, 1105.0, 93, 18.3, 79, 66, 11, 0, 0,
    '[{"name":"哇塞蛋炒饭（基础版）","qty":18,"revenue":198.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":14,"revenue":266.0},{"name":"牛肉蛋炒饭（基础版）","qty":12,"revenue":252.0}]'::jsonb,
    '[]'::jsonb,
    '{"meituan":{"revenue":850,"orders":47},"jd":{"revenue":425,"orders":23},"tangshi":{"revenue":425,"orders":23}}'::jsonb,
    '[{"hour":"11","order_count":15},{"hour":"12","order_count":28},{"hour":"18","order_count":20},{"hour":"19","order_count":17}]'::jsonb,
    false)
) AS d(summary_date, total_revenue, total_cost, gross_profit, order_count, avg_order_value, customer_count, new_customer_count, negative_reviews, inventory_alerts, top_dishes, bottom_dishes, channel_breakdown, peak_hours, is_weekend)
WHERE s.store_code = 'WM001'
ON CONFLICT (store_id, summary_date) DO NOTHING;

-- ============================================================
-- 4. 交易流水（store_transactions）—— 每天抽样3-5笔代表订单
-- ============================================================
-- 为避免SQL过长，每天生成3笔代表性订单（午高峰/晚高峰/下午茶）
INSERT INTO store_transactions (store_id, transaction_date, transaction_time, order_no, channel, items, total_amount, discount_amount, platform_fee, delivery_fee, actual_amount, payment_method, status, customer_name)
SELECT s.id, t.tran_date, t.tran_time, t.order_no, t.channel, t.items, t.total_amount, t.discount_amount, t.platform_fee, t.delivery_fee, t.actual_amount, t.payment_method, t.status, t.customer_name
FROM stores s
CROSS JOIN (VALUES
  -- 7月1日
  ('2026-07-01'::date, '2026-07-01 11:32:00'::timestamptz, 'WM20260701-001', 'meituan', '[{"name":"哇塞蛋炒饭（基础版）","qty":2,"price":11.0,"subtotal":22.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":1,"price":19.0,"subtotal":19.0}]'::jsonb, 41.0, 3.0, 8.2, 0.0, 29.8, 'online', 'completed', '张先生'),
  ('2026-07-01'::date, '2026-07-01 12:15:00'::timestamptz, 'WM20260701-002', 'jd', '[{"name":"牛肉蛋炒饭（基础版）","qty":1,"price":21.0,"subtotal":21.0},{"name":"哇塞蛋炒饭（加量版）","qty":1,"price":13.0,"subtotal":13.0}]'::jsonb, 34.0, 2.0, 6.8, 0.0, 25.2, 'online', 'completed', '李女士'),
  ('2026-07-01'::date, '2026-07-01 18:45:00'::timestamptz, 'WM20260701-003', 'tangshi', '[{"name":"一口香酱油炒饭（基础版）","qty":1,"price":9.9,"subtotal":9.9},{"name":"哇塞蛋炒饭（基础版）","qty":1,"price":11.0,"subtotal":11.0},{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":1,"price":17.0,"subtotal":17.0}]'::jsonb, 37.9, 0.0, 0.0, 0.0, 37.9, 'cash', 'completed', '王先生'),
  -- 7月5日 周六高峰
  ('2026-07-05'::date, '2026-07-05 11:45:00'::timestamptz, 'WM20260705-001', 'meituan', '[{"name":"辣椒炒肉蛋炒饭（基础版）","qty":3,"price":19.0,"subtotal":57.0},{"name":"哇塞蛋炒饭（基础版）","qty":2,"price":11.0,"subtotal":22.0}]'::jsonb, 79.0, 5.0, 15.8, 0.0, 58.2, 'online', 'completed', '刘先生'),
  ('2026-07-05'::date, '2026-07-05 12:30:00'::timestamptz, 'WM20260705-002', 'jd', '[{"name":"牛肉蛋炒饭（加量版）","qty":2,"price":23.0,"subtotal":46.0}]'::jsonb, 46.0, 3.0, 9.2, 0.0, 33.8, 'online', 'completed', '陈女士'),
  ('2026-07-05'::date, '2026-07-05 19:00:00'::timestamptz, 'WM20260705-003', 'tangshi', '[{"name":"哇塞蛋炒饭（基础版）","qty":2,"price":11.0,"subtotal":22.0},{"name":"整块鸡排蛋炒饭（基础版）","qty":1,"price":21.0,"subtotal":21.0}]'::jsonb, 43.0, 0.0, 0.0, 0.0, 43.0, 'wechat', 'completed', '赵先生'),
  -- 7月12日 周六最高峰
  ('2026-07-12'::date, '2026-07-12 11:50:00'::timestamptz, 'WM20260712-001', 'meituan', '[{"name":"牛肉蛋炒饭（基础版）","qty":2,"price":21.0,"subtotal":42.0},{"name":"辣椒炒肉蛋炒饭（基础版）","qty":2,"price":19.0,"subtotal":38.0}]'::jsonb, 80.0, 6.0, 16.0, 0.0, 58.0, 'online', 'completed', '孙先生'),
  ('2026-07-12'::date, '2026-07-12 12:20:00'::timestamptz, 'WM20260712-002', 'jd', '[{"name":"哇塞蛋炒饭（基础版）","qty":3,"price":11.0,"subtotal":33.0},{"name":"扬州炒饭（基础版）","qty":1,"price":14.0,"subtotal":14.0}]'::jsonb, 47.0, 2.0, 9.4, 0.0, 35.6, 'online', 'completed', '周女士'),
  ('2026-07-12'::date, '2026-07-12 18:30:00'::timestamptz, 'WM20260712-003', 'tangshi', '[{"name":"怀旧脆油渣蛋炒饭（基础版）","qty":2,"price":17.0,"subtotal":34.0},{"name":"哇塞蛋炒饭（加量版）","qty":1,"price":13.0,"subtotal":13.0}]'::jsonb, 47.0, 0.0, 0.0, 0.0, 47.0, 'cash', 'completed', '吴先生')
) AS t(tran_date, tran_time, order_no, channel, items, total_amount, discount_amount, platform_fee, delivery_fee, actual_amount, payment_method, status, customer_name)
WHERE s.store_code = 'WM001'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. 食材库存（ingredient_inventory）—— 主要食材
-- ============================================================
INSERT INTO ingredient_inventory (ingredient_name, category, supplier_id, batch_no, purchase_date, expiry_date, shelf_life_days, quantity, unit, storage_location, status)
SELECT i.ingredient_name, i.category, NULL, i.batch_no, i.purchase_date, i.expiry_date, i.shelf_life_days, i.quantity, i.unit, i.storage_location, i.status
FROM (VALUES
  ('大米','主食',NULL,'RICE-20260701','2026-07-01'::date,'2027-01-01'::date,180,50.0,'kg','常温','normal'),
  ('鸡蛋','蛋类',NULL,'EGG-20260702','2026-07-02'::date,'2026-07-19'::date,17,8.0,'kg','冷藏','normal'),
  ('猪油','调料',NULL,'LO-20260701','2026-07-01'::date,'2026-10-01'::date,90,5.0,'kg','冷藏','normal'),
  ('酱油','调料',NULL,'SOY-20260701','2026-07-01'::date,'2027-07-01'::date,365,3.0,'L','常温','normal'),
  ('广式香肠','肉类',NULL,'SAU-20260702','2026-07-02'::date,'2026-07-16'::date,14,2.0,'kg','冷藏','warning'),
  ('黑椒烤肠','肉类',NULL,'BST-20260702','2026-07-02'::date,'2026-07-16'::date,14,1.5,'kg','冷藏','warning'),
  ('港式肉肠','肉类',NULL,'HKT-20260702','2026-07-02'::date,'2026-07-16'::date,14,1.2,'kg','冷藏','warning'),
  ('牛肉','肉类',NULL,'BEF-20260702','2026-07-02'::date,'2026-07-05'::date,3,0.8,'kg','冷冻','critical'),
  ('鸡排','肉类',NULL,'CHK-20260701','2026-07-01'::date,'2026-07-15'::date,14,1.0,'kg','冷冻','normal'),
  ('辣椒','蔬菜',NULL,'CHI-20260702','2026-07-02'::date,'2026-07-05'::date,3,0.5,'kg','冷藏','critical'),
  ('老干妈酱','调料',NULL,'LGM-20260701','2026-07-01'::date,'2027-07-01'::date,365,0.5,'kg','常温','normal'),
  ('梅菜','蔬菜',NULL,'MC-20260702','2026-07-02'::date,'2026-07-09'::date,7,0.3,'kg','冷藏','normal'),
  ('猪油渣','肉类',NULL,'YZ-20260701','2026-07-01'::date,'2026-07-08'::date,7,0.4,'kg','冷藏','normal'),
  ('米粉','主食',NULL,'MF-20260701','2026-07-01'::date,'2026-10-01'::date,90,2.0,'kg','常温','normal'),
  ('方便面','主食',NULL,'Noodle-20260701','2026-07-01'::date,'2027-01-01'::date,180,1.0,'kg','常温','normal'),
  ('食用油','调料',NULL,'OIL-20260701','2026-07-01'::date,'2027-01-01'::date,180,4.0,'L','常温','normal'),
  ('葱','蔬菜',NULL,'SCL-20260702','2026-07-02'::date,'2026-07-05'::date,3,0.3,'kg','冷藏','critical'),
  ('蒜末','调料',NULL,'GAR-20260701','2026-07-01'::date,'2026-07-15'::date,14,0.2,'kg','冷藏','normal')
) AS i(ingredient_name, category, supplier_id, batch_no, purchase_date, expiry_date, shelf_life_days, quantity, unit, storage_location, status)
WHERE NOT EXISTS (
  SELECT 1 FROM ingredient_inventory inv
  WHERE inv.ingredient_name = i.ingredient_name
  AND inv.batch_no = i.batch_no
);

-- ============================================================
-- 6. 模拟数据标记
-- ============================================================
-- 在store_configs中标记模拟数据状态
UPDATE store_configs
SET business_rules = business_rules || '{"mock_data":true,"mock_period":"2026-07-01 to 2026-07-15","real_data_start":"2026-07-16"}'::jsonb
WHERE store_id = (SELECT id FROM stores WHERE store_code = 'WM001');

-- ============================================================
-- 验证查询（执行后可查看数据）
-- ============================================================
-- 门店数
SELECT '门店' as type, count(*) as cnt FROM stores WHERE store_code = 'WM001';
-- 菜品数
SELECT '菜品' as type, count(*) as cnt FROM store_dishes WHERE store_id = (SELECT id FROM stores WHERE store_code = 'WM001');
-- 日报数
SELECT '日报' as type, count(*) as cnt FROM store_daily_summary WHERE store_id = (SELECT id FROM stores WHERE store_code = 'WM001');
-- 交易流水数
SELECT '交易流水' as type, count(*) as cnt FROM store_transactions WHERE store_id = (SELECT id FROM stores WHERE store_code = 'WM001');
-- 库存数
SELECT '库存' as type, count(*) as cnt FROM ingredient_inventory;
-- 库存预警
SELECT '库存预警' as type, count(*) as cnt FROM ingredient_inventory WHERE status IN ('warning','critical');
