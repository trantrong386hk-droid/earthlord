-- ============================================
-- 闲置物品交换历史记录
-- 在 accept_exchange_request 执行后，自动插入 trade_history 记录
-- ============================================

-- MARK: - idle_item_requests 表（如果不存在则创建）

CREATE TABLE IF NOT EXISTS idle_item_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES idle_items(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    requester_username TEXT NOT NULL,
    message TEXT CHECK (char_length(message) <= 200),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_idle_item_requests_item ON idle_item_requests(item_id);
CREATE INDEX IF NOT EXISTS idx_idle_item_requests_requester ON idle_item_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_idle_item_requests_status ON idle_item_requests(status);

-- RLS
ALTER TABLE idle_item_requests ENABLE ROW LEVEL SECURITY;

-- 认证用户可查看物品相关请求（物品主人）或自己发起的请求
DROP POLICY IF EXISTS "idle_item_requests_select" ON idle_item_requests;
CREATE POLICY "idle_item_requests_select"
ON idle_item_requests FOR SELECT
TO authenticated
USING (
    requester_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM idle_items
        WHERE idle_items.id = idle_item_requests.item_id
        AND idle_items.owner_id = auth.uid()
    )
);

-- 认证用户可发起请求
DROP POLICY IF EXISTS "idle_item_requests_insert" ON idle_item_requests;
CREATE POLICY "idle_item_requests_insert"
ON idle_item_requests FOR INSERT
TO authenticated
WITH CHECK (requester_id = auth.uid());

-- 物品主人可更新请求状态
DROP POLICY IF EXISTS "idle_item_requests_update" ON idle_item_requests;
CREATE POLICY "idle_item_requests_update"
ON idle_item_requests FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM idle_items
        WHERE idle_items.id = idle_item_requests.item_id
        AND idle_items.owner_id = auth.uid()
    )
);

-- MARK: - 允许 trade_history 插入（用于闲置交换）

-- 添加策略允许插入 trade_history（通过 SECURITY DEFINER 函数）
DROP POLICY IF EXISTS "Allow insert via function" ON trade_history;
CREATE POLICY "Allow insert via function"
ON trade_history FOR INSERT
TO authenticated
WITH CHECK (seller_id = auth.uid() OR buyer_id = auth.uid());

-- MARK: - accept_exchange_request 函数

CREATE OR REPLACE FUNCTION accept_exchange_request(request_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request idle_item_requests%ROWTYPE;
    v_item idle_items%ROWTYPE;
    v_owner_id UUID;
    v_owner_username TEXT;
    v_requester_id UUID;
    v_requester_username TEXT;
    v_item_title TEXT;
BEGIN
    -- 获取当前用户
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION '用户未登录';
    END IF;

    -- 锁定并获取请求
    SELECT * INTO v_request FROM idle_item_requests
    WHERE id = request_id FOR UPDATE;

    IF v_request IS NULL THEN
        RAISE EXCEPTION '交换请求不存在';
    END IF;

    -- 验证请求状态
    IF v_request.status != 'pending' THEN
        RAISE EXCEPTION '请求已被处理';
    END IF;

    -- 获取物品信息
    SELECT * INTO v_item FROM idle_items
    WHERE id = v_request.item_id FOR UPDATE;

    IF v_item IS NULL THEN
        RAISE EXCEPTION '物品不存在';
    END IF;

    -- 验证当前用户是物品所有者
    IF v_item.owner_id != auth.uid() THEN
        RAISE EXCEPTION '只有物品主人可以接受请求';
    END IF;

    -- 验证物品状态
    IF v_item.status != 'active' THEN
        RAISE EXCEPTION '物品已下架或已交换';
    END IF;

    -- 保存交易双方信息
    v_owner_id := v_item.owner_id;
    v_owner_username := v_item.owner_username;
    v_requester_id := v_request.requester_id;
    v_requester_username := v_request.requester_username;
    v_item_title := v_item.title;

    -- 1. 将当前请求标记为 accepted
    UPDATE idle_item_requests
    SET status = 'accepted'
    WHERE id = request_id;

    -- 2. 将该物品的其他 pending 请求标记为 rejected
    UPDATE idle_item_requests
    SET status = 'rejected'
    WHERE item_id = v_request.item_id
      AND id != request_id
      AND status = 'pending';

    -- 3. 将物品标记为已交换
    UPDATE idle_items
    SET status = 'exchanged'
    WHERE id = v_request.item_id;

    -- 4. 插入交易历史记录
    -- seller = 物品原主 (owner)
    -- buyer = 交换请求者 (requester)
    -- offered = 物品标题（owner 给出的闲置物品）
    -- requested = 空数组（闲置交换不涉及游戏物品支付）
    INSERT INTO trade_history (
        offer_id,
        seller_id,
        seller_username,
        buyer_id,
        buyer_username,
        items_exchanged,
        completed_at
    ) VALUES (
        NULL,  -- 无 trade_offer 关联
        v_owner_id,
        v_owner_username,
        v_requester_id,
        v_requester_username,
        jsonb_build_object(
            'offered', jsonb_build_array(
                jsonb_build_object('name', v_item_title, 'quantity', 1)
            ),
            'requested', '[]'::jsonb
        ),
        now()
    );

END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION accept_exchange_request(UUID) IS '接受闲置物品交换请求，原子操作：更新请求状态、拒绝其他请求、标记物品已交换、记录交易历史';
