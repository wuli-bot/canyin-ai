-- ============================================================
-- 餐饮AI店长 V2 - 多店+客服+日报 新增表SQL
-- 纯增量，不修改V1任何表
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-07-01
-- ============================================================

-- ============================================================
-- 1. 门店主表（多店管理的核心）
-- ============================================================
CREATE TABLE IF NOT EXISTS stores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_name TEXT NOT NULL,
  store_code TEXT UNIQUE NOT NULL,  -- 简短标识码，如 WH001
  address TEXT,
  contact_person TEXT,
  phone TEXT,
  business_hours TEXT,  -- 如 "10:00-22:00"
  platform_accounts JSONB DEFAULT '{}',  -- {"meituan": "shop_id", "douyin": "shop_id", "jd": "shop_id"}
  status TEXT DEFAULT 'active',  -- active/suspended/closed
  owner_id TEXT,  -- 管理者账号标识
  logo_url TEXT,
  settings JSONB DEFAULT '{}',  -- 门店级自定义配置
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. 客服对话记录表（统一入口，所有渠道对话沉淀）
-- ============================================================
CREATE TABLE IF NOT EXISTS conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  channel TEXT NOT NULL,  -- wechat/douyin/juqing/gzh/meituan/tel
  customer_name TEXT,
  customer_external_id TEXT,  -- 外部平台的客户标识
  customer_phone TEXT,
  messages JSONB NOT NULL DEFAULT '[]',  -- [{role:"customer"|"ai"|"human", content, timestamp, source}]
  intent_tags TEXT[] DEFAULT '{}',  -- 识别出的意图标签
  status TEXT DEFAULT 'open',  -- open/ai_replied/escalated/resolved/closed
  assigned_to TEXT DEFAULT 'ai',  -- 'ai' 或具体人工客服名
  ai_response_count INTEGER DEFAULT 0,
  human_takeover BOOLEAN DEFAULT false,
  human_takeover_at TIMESTAMPTZ,
  satisfaction_score NUMERIC,  -- 1-5
  resolution_notes TEXT,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. 门店交易表（各店订单/交易流水）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  transaction_date DATE NOT NULL,
  transaction_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  order_no TEXT,
  channel TEXT NOT NULL,  -- meituan/dianping/tangshi/juqing/online
  items JSONB NOT NULL DEFAULT '[]',  -- [{name, qty, price, subtotal}]
  total_amount NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC DEFAULT 0,
  platform_fee NUMERIC DEFAULT 0,  -- 平台抽佣
  delivery_fee NUMERIC DEFAULT 0,
  actual_amount NUMERIC DEFAULT 0,  -- 实际到手
  payment_method TEXT,  -- online/cash/wechat/alipay
  status TEXT DEFAULT 'completed',  -- completed/refunded/cancelled/pending
  customer_name TEXT,
  customer_phone TEXT,
  customer_note TEXT,
  raw_data JSONB,  -- 原始平台数据备份
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. 门店菜品表（各店菜品库，独立于V1的菜单模块）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_dishes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  dish_name TEXT NOT NULL,
  category TEXT,  -- 主食/小吃/饮品/套餐
  price NUMERIC NOT NULL,
  cost NUMERIC,
  gross_margin NUMERIC,  -- 毛利率百分比
  status TEXT DEFAULT 'available',  -- available/soldout/seasonal/disabled
  is_featured BOOLEAN DEFAULT false,  -- 是否推荐/招牌
  is_new BOOLEAN DEFAULT false,  -- 是否新品
  sort_order INTEGER DEFAULT 0,
  description TEXT,
  image_url TEXT,
  total_sold NUMERIC DEFAULT 0,  -- 累计销量
  total_revenue NUMERIC DEFAULT 0,  -- 累计营收
  daily_avg_sold NUMERIC DEFAULT 0,  -- 日均销量（缓存）
  last_sold_date DATE,
  platform_prices JSONB DEFAULT '{}',  -- {"meituan": 15, "dianping": 16}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. 门店日报汇总表（每日关键指标，多店对比用）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_daily_summary (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  summary_date DATE NOT NULL,
  total_revenue NUMERIC DEFAULT 0,
  total_cost NUMERIC DEFAULT 0,
  gross_profit NUMERIC DEFAULT 0,
  gross_margin_pct NUMERIC,  -- 毛利率百分比
  order_count INTEGER DEFAULT 0,
  avg_order_value NUMERIC,
  customer_count INTEGER DEFAULT 0,
  new_customer_count INTEGER DEFAULT 0,
  negative_reviews INTEGER DEFAULT 0,
  inventory_alerts INTEGER DEFAULT 0,
  food_safety_score NUMERIC,  -- 食安评分
  top_dishes JSONB DEFAULT '[]',  -- [{name, qty, revenue}]
  bottom_dishes JSONB DEFAULT '[]',  -- 滞销菜品
  channel_breakdown JSONB DEFAULT '{}',  -- {"meituan": {revenue, orders}, "tangshi": {...}}
  peak_hours JSONB DEFAULT '[]',  -- [{hour, order_count}]
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(store_id, summary_date)
);

-- ============================================================
-- 6. 门店模块配置表（控制各店启用哪些功能模块）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_configs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id) UNIQUE,
  modules_enabled TEXT[] DEFAULT '{}',  -- 启用的模块列表
  ai_settings JSONB DEFAULT '{}',  -- AI回复配置 {"tone": "friendly", "max_retries": 3}
  notification_settings JSONB DEFAULT '{}',  -- 推送配置 {"channels": ["feishu", "wechat"]}
  business_rules JSONB DEFAULT '{}',  -- 门店级业务规则
  auto_reply_templates JSONB DEFAULT '{}',  -- 自定义话术模板
  escalation_rules JSONB DEFAULT '{}',  -- 转人工规则
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 索引
-- ============================================================
-- stores
CREATE INDEX IF NOT EXISTS idx_stores_status ON stores(status);
CREATE INDEX IF NOT EXISTS idx_stores_code ON stores(store_code);
CREATE INDEX IF NOT EXISTS idx_stores_owner ON stores(owner_id);

-- conversations
CREATE INDEX IF NOT EXISTS idx_conv_store ON conversations(store_id);
CREATE INDEX IF NOT EXISTS idx_conv_channel ON conversations(channel);
CREATE INDEX IF NOT EXISTS idx_conv_status ON conversations(status);
CREATE INDEX IF NOT EXISTS idx_conv_assigned ON conversations(assigned_to);
CREATE INDEX IF NOT EXISTS idx_conv_last_msg ON conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_created ON conversations(created_at DESC);

-- store_transactions
CREATE INDEX IF NOT EXISTS idx_stx_store ON store_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_stx_date ON store_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_stx_channel ON store_transactions(channel);
CREATE INDEX IF NOT EXISTS idx_stx_status ON store_transactions(status);
CREATE INDEX IF NOT EXISTS idx_stx_order_no ON store_transactions(order_no);
CREATE INDEX IF NOT EXISTS idx_stx_store_date ON store_transactions(store_id, transaction_date);

-- store_dishes
CREATE INDEX IF NOT EXISTS idx_sd_store ON store_dishes(store_id);
CREATE INDEX IF NOT EXISTS idx_sd_status ON store_dishes(status);
CREATE INDEX IF NOT EXISTS idx_sd_category ON store_dishes(category);
CREATE INDEX IF NOT EXISTS idx_sd_featured ON store_dishes(is_featured);

-- store_daily_summary
CREATE INDEX IF NOT EXISTS idx_sds_store ON store_daily_summary(store_id);
CREATE INDEX IF NOT EXISTS idx_sds_date ON store_daily_summary(summary_date);
CREATE INDEX IF NOT EXISTS idx_sds_store_date ON store_daily_summary(store_id, summary_date);

-- store_configs
CREATE INDEX IF NOT EXISTS idx_sc_store ON store_configs(store_id);

-- ============================================================
-- RLS 策略
-- ============================================================
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_daily_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_configs ENABLE ROW LEVEL SECURITY;

-- 公开读取策略（调试阶段，正式上线后按 owner_id 隔离）
CREATE POLICY "Allow public read stores" ON stores FOR SELECT USING (true);
CREATE POLICY "Allow public insert stores" ON stores FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update stores" ON stores FOR UPDATE USING (true);

CREATE POLICY "Allow public read conversations" ON conversations FOR SELECT USING (true);
CREATE POLICY "Allow public insert conversations" ON conversations FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update conversations" ON conversations FOR UPDATE USING (true);

CREATE POLICY "Allow public read transactions" ON store_transactions FOR SELECT USING (true);
CREATE POLICY "Allow public insert transactions" ON store_transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update transactions" ON store_transactions FOR UPDATE USING (true);

CREATE POLICY "Allow public read dishes" ON store_dishes FOR SELECT USING (true);
CREATE POLICY "Allow public insert dishes" ON store_dishes FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update dishes" ON store_dishes FOR UPDATE USING (true);

CREATE POLICY "Allow public read daily_summary" ON store_daily_summary FOR SELECT USING (true);
CREATE POLICY "Allow public insert daily_summary" ON store_daily_summary FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update daily_summary" ON store_daily_summary FOR UPDATE USING (true);

CREATE POLICY "Allow public read configs" ON store_configs FOR SELECT USING (true);
CREATE POLICY "Allow public insert configs" ON store_configs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update configs" ON store_configs FOR UPDATE USING (true);

-- ============================================================
-- 插入默认门店（哇塞猛火猪油炒饭 - 首店）
-- ============================================================
INSERT INTO stores (store_name, store_code, address, contact_person, phone, business_hours, platform_accounts)
VALUES (
  '哇塞猛火猪油炒饭',
  'WH001',
  '湖南外国语职业学院北食堂',
  '艾刃',
  '',
  '10:00-21:00',
  '{"meituan": "", "douyin": "", "jd": ""}'
)
ON CONFLICT (store_code) DO NOTHING;
