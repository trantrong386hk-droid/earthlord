-- 为 user_items 表添加 AI 物品支持字段
ALTER TABLE user_items
ADD COLUMN is_ai_generated BOOLEAN DEFAULT FALSE,
ADD COLUMN ai_name TEXT,
ADD COLUMN ai_category TEXT,
ADD COLUMN ai_rarity TEXT,
ADD COLUMN ai_story TEXT;

-- 添加注释
COMMENT ON COLUMN user_items.is_ai_generated IS '是否为 AI 生成的物品';
COMMENT ON COLUMN user_items.ai_name IS 'AI 生成的物品名称';
COMMENT ON COLUMN user_items.ai_category IS 'AI 生成的物品分类';
COMMENT ON COLUMN user_items.ai_rarity IS 'AI 生成的稀有度';
COMMENT ON COLUMN user_items.ai_story IS 'AI 生成的背景故事';
