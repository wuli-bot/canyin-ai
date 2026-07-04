-- ============================================================
-- 餐饮AI店长 - AI自主结算模块 建表SQL（纯增量）
-- 不修改现有任何表，仅新增2张表
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-07-05
-- ============================================================

-- ============================================================
-- 1. agent_auth（智能体结算授权表）
-- 控制每个AI Agent能花多少钱、用什么支付、是否需要老板确认
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_auth (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id TEXT NOT NULL,                          -- Coze Bot ID
  agent_name TEXT NOT NULL,                         -- 显示名称
  store_id UUID REFERENCES stores(id),             -- 所属门店（NULL=全局）
  payment_channels JSONB DEFAULT '[]',              -- ["wechat","alipay"] 支持的支付渠道
  single_limit NUMERIC DEFAULT 0,                   -- 单笔限额（元）
  daily_limit NUMERIC DEFAULT 0,                    -- 日累计限额（元）
  monthly_limit NUMERIC DEFAULT 0,                  -- 月累计限额（元）
  requires_approval BOOLEAN DEFAULT true,           -- 每笔交易是否需要老板确认
  approvers JSONB DEFAULT '[]',                      -- ["老板"] 谁有权审批
  auto_approve_below NUMERIC DEFAULT 0,              -- 低于此金额自动通过（元）
  status TEXT DEFAULT 'active',                     -- active/frozen/disabled
  frozen_reason TEXT,                               -- 冻结原因
  frozen_at TIMESTAMPTZ,                            -- 冻结时间
  today_spent NUMERIC DEFAULT 0,                    -- 今日已花（运行时更新）
  today_date DATE DEFAULT CURRENT_DATE,             -- 今日日期标记
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(agent_id, store_id)
);

-- ============================================================
-- 2. settlement_records（结算记录表）
-- 每一笔AI经手的收支流水，完整存证可追溯
-- ============================================================
CREATE TABLE IF NOT EXISTS settlement_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id TEXT NOT NULL,                          -- 哪个Agent操作的
  agent_name TEXT NOT NULL,                         -- Agent名称（冗余，便于查询）
  store_id UUID REFERENCES stores(id),             -- 门店
  task_id TEXT,                                     -- 关联的任务/订单ID
  task_type TEXT,                                   -- order采购/procurement/营销refund/refund/other
  amount NUMERIC NOT NULL DEFAULT 0,                -- 金额（元）
  channel TEXT DEFAULT 'mock',                     -- wechat/alipay/mock
  type TEXT NOT NULL DEFAULT 'expense',             -- income收入/expense支出
  status TEXT DEFAULT 'pending',                   -- pending/confirmed/failed/cancelled
  reference_id TEXT,                                -- 第三方交易号（Mock时为本地流水号）
  description TEXT,                                 -- 这笔钱花在哪/收在哪
  approved_by TEXT,                                 -- 审批人（老板微信名等）
  approved_at TIMESTAMPTZ,                          -- 审批时间
  mock BOOLEAN DEFAULT true,                       -- true=模拟交易（未接真实支付）
  metadata JSONB DEFAULT '{}',                     -- 扩展字段（订单详情、供应商信息等）
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. 索引（加速查询）
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_agent_auth_agent_id ON agent_auth(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_auth_status ON agent_auth(status);
CREATE INDEX IF NOT EXISTS idx_settlement_agent_id ON settlement_records(agent_id);
CREATE INDEX IF NOT EXISTS idx_settlement_store_id ON settlement_records(store_id);
CREATE INDEX IF NOT EXISTS idx_settlement_created_at ON settlement_records(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_settlement_status ON settlement_records(status);
CREATE INDEX IF NOT EXISTS idx_settlement_type ON settlement_records(type);

-- ============================================================
-- 4. RLS 行级安全策略
-- ============================================================
ALTER TABLE agent_auth ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlement_records ENABLE ROW LEVEL SECURITY;

-- 匿名用户可读（调试阶段，上线后收紧）
CREATE POLICY "anon_read_agent_auth" ON agent_auth FOR SELECT TO anon USING (true);
CREATE POLICY "anon_all_settlement_records" ON settlement_records FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 5. 自动更新 updated_at 触发器
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_agent_auth_updated ON agent_auth;
CREATE TRIGGER trg_agent_auth_updated
  BEFORE UPDATE ON agent_auth
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 6. 初始数据：为现有5个Agent创建默认授权配置
-- ============================================================
INSERT INTO agent_auth (agent_id, agent_name, store_id, payment_channels, single_limit, daily_limit, monthly_limit, requires_approval, approvers, auto_approve_below, status)
SELECT
  bot.id,
  bot.name,
  NULL,
  '["mock"]'::jsonb,
  100,
  500,
  5000,
  true,
  '["老板"]'::jsonb,
  20,
  'active'
FROM (VALUES
  ('7651922196432338995', '成本核算助手'),
  ('7651944084466794550', '差评处理助手'),
  ('7651952126398054435', '私域引流助手'),
  ('7651953305891405870', '小哇客服'),
  ('7652253691269103651', '语音总控')
) AS bot(id, name)
WHERE NOT EXISTS (SELECT 1 FROM agent_auth WHERE agent_id = bot.id);

-- ============================================================
-- 7. Mock交易示例数据（让审计页面一打开就有数据看）
-- ============================================================
INSERT INTO settlement_records (agent_id, agent_name, store_id, task_id, task_type, amount, channel, type, status, description, approved_by, mock, created_at)
SELECT
  r.agent_id,
  r.agent_name,
  NULL,
  'mock-task-' || gs,
  CASE (gs % 3)
    WHEN 0 THEN 'order'
    WHEN 1 THEN 'procurement'
    ELSE 'marketing'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 28.50
    WHEN 1 THEN 156.00
    ELSE 5.00
  END,
  'mock',
  CASE (gs % 3)
    WHEN 0 THEN 'income'
    ELSE 'expense'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 'confirmed'
    WHEN 1 THEN 'confirmed'
    ELSE 'pending'
  END,
  CASE (gs % 3)
    WHEN 0 THEN '顾客语音点餐收款'
    WHEN 1 THEN '库存预警自动采购鸡蛋5斤'
    ELSE '老客复购自动发券'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 'auto'
    WHEN 1 THEN '老板'
    ELSE NULL
  END,
  true,
  NOW() - (gs || ' hours')::interval
FROM generate_series(1, 12) AS gs
CROSS JOIN (VALUES
  ('7652253691269103651', '语音总控'),
  ('7651952126398054435', '私域引流助手'),
  ('7651922196432338995', '成本核算助手')
) AS r(agent_id, agent_name)
WHERE NOT EXISTS (SELECT 1 FROM settlement_records LIMIT 1);

-- ============================================================
-- 执行完成。
-- 验证：
--   SELECT * FROM agent_auth;
--   SELECT * FROM settlement_records ORDER BY created_at DESC LIMIT 20;
-- ============================================================
