-- ============================================
-- 闲置物品交换系统
-- 包含：idle_items 表、idle_item_comments 表、
--       Storage Bucket、RLS 策略
-- ============================================

-- MARK: - Storage Bucket

INSERT INTO storage.buckets (id, name, public)
VALUES ('idle-items', 'idle-items', false)
ON CONFLICT (id) DO NOTHING;

-- Storage 策略：认证用户可上传到自己文件夹
CREATE POLICY "auth_users_upload_own_folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'idle-items'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Storage 策略：认证用户可查看所有图片
CREATE POLICY "auth_users_read_all"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'idle-items');

-- Storage 策略：认证用户可删除自己文件夹的图片
CREATE POLICY "auth_users_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'idle-items'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- MARK: - idle_items 表

CREATE TABLE IF NOT EXISTS idle_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT NOT NULL,
    title TEXT NOT NULL CHECK (char_length(title) <= 50),
    description TEXT NOT NULL CHECK (char_length(description) <= 500),
    condition TEXT NOT NULL CHECK (condition IN ('new', 'like_new', 'good', 'fair', 'poor')),
    desired_exchange TEXT CHECK (char_length(desired_exchange) <= 200),
    photo_urls TEXT[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed', 'exchanged')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 索引
CREATE INDEX idx_idle_items_owner ON idle_items(owner_id);
CREATE INDEX idx_idle_items_status ON idle_items(status);
CREATE INDEX idx_idle_items_created ON idle_items(created_at DESC);

-- 自动更新 updated_at
CREATE OR REPLACE FUNCTION update_idle_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_idle_items_updated_at
    BEFORE UPDATE ON idle_items
    FOR EACH ROW
    EXECUTE FUNCTION update_idle_items_updated_at();

-- RLS
ALTER TABLE idle_items ENABLE ROW LEVEL SECURITY;

-- 认证用户可查看活跃物品或自己的物品
CREATE POLICY "idle_items_select"
ON idle_items FOR SELECT
TO authenticated
USING (status = 'active' OR owner_id = auth.uid());

-- 认证用户可添加自己的物品
CREATE POLICY "idle_items_insert"
ON idle_items FOR INSERT
TO authenticated
WITH CHECK (owner_id = auth.uid());

-- 认证用户可修改自己的物品
CREATE POLICY "idle_items_update"
ON idle_items FOR UPDATE
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- 认证用户可删除自己的物品
CREATE POLICY "idle_items_delete"
ON idle_items FOR DELETE
TO authenticated
USING (owner_id = auth.uid());

-- MARK: - idle_item_comments 表

CREATE TABLE IF NOT EXISTS idle_item_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES idle_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    content TEXT NOT NULL CHECK (char_length(content) <= 300),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 索引
CREATE INDEX idx_idle_item_comments_item ON idle_item_comments(item_id);
CREATE INDEX idx_idle_item_comments_created ON idle_item_comments(created_at);

-- RLS
ALTER TABLE idle_item_comments ENABLE ROW LEVEL SECURITY;

-- 认证用户可查看所有评论
CREATE POLICY "idle_item_comments_select"
ON idle_item_comments FOR SELECT
TO authenticated
USING (true);

-- 认证用户可添加评论
CREATE POLICY "idle_item_comments_insert"
ON idle_item_comments FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 认证用户可删除自己的评论
CREATE POLICY "idle_item_comments_delete"
ON idle_item_comments FOR DELETE
TO authenticated
USING (user_id = auth.uid());
