-- =============================================
-- 交易系统数据库迁移
-- 实现玩家之间的异步挂单交易系统
-- =============================================

-- =============================================
-- 1. 创建 trade_offers 表（交易挂单）
-- =============================================
CREATE TABLE trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT,
    offering_items JSONB NOT NULL,  -- [{"name": "木材", "quantity": 10}]
    requesting_items JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'expired')),
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    completed_by_user_id UUID REFERENCES auth.users(id),
    completed_by_username TEXT
);

-- 添加索引
CREATE INDEX idx_trade_offers_owner ON trade_offers(owner_id);
CREATE INDEX idx_trade_offers_status ON trade_offers(status);
CREATE INDEX idx_trade_offers_expires ON trade_offers(expires_at);
CREATE INDEX idx_trade_offers_created ON trade_offers(created_at DESC);

-- 添加注释
COMMENT ON TABLE trade_offers IS '交易挂单表';
COMMENT ON COLUMN trade_offers.offering_items IS '提供的物品列表 JSON';
COMMENT ON COLUMN trade_offers.requesting_items IS '请求的物品列表 JSON';
COMMENT ON COLUMN trade_offers.status IS '挂单状态: active/completed/cancelled/expired';

-- =============================================
-- 2. 创建 trade_history 表（交易历史）
-- =============================================
CREATE TABLE trade_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID REFERENCES trade_offers(id) ON DELETE SET NULL,
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_username TEXT,
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    buyer_username TEXT,
    items_exchanged JSONB NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    seller_rating INT CHECK (seller_rating >= 1 AND seller_rating <= 5),
    buyer_rating INT CHECK (buyer_rating >= 1 AND buyer_rating <= 5),
    seller_comment TEXT,
    buyer_comment TEXT
);

-- 添加索引
CREATE INDEX idx_trade_history_seller ON trade_history(seller_id);
CREATE INDEX idx_trade_history_buyer ON trade_history(buyer_id);
CREATE INDEX idx_trade_history_completed ON trade_history(completed_at DESC);

-- 添加注释
COMMENT ON TABLE trade_history IS '交易历史记录表';
COMMENT ON COLUMN trade_history.items_exchanged IS '交换的物品详情 JSON';
COMMENT ON COLUMN trade_history.seller_rating IS '卖家评分 1-5';
COMMENT ON COLUMN trade_history.buyer_rating IS '买家评分 1-5';

-- =============================================
-- 3. 启用 RLS（行级安全）
-- =============================================
ALTER TABLE trade_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_history ENABLE ROW LEVEL SECURITY;

-- trade_offers 策略
-- 所有登录用户可查看 active 挂单或自己的挂单
CREATE POLICY "Anyone can view active offers or own offers" ON trade_offers
    FOR SELECT USING (status = 'active' OR owner_id = auth.uid());

-- 用户只能创建自己的挂单
CREATE POLICY "Users can insert own offers" ON trade_offers
    FOR INSERT WITH CHECK (owner_id = auth.uid());

-- 用户可以更新自己的挂单，或者任何登录用户可以更新（用于接受交易）
CREATE POLICY "Users can update offers" ON trade_offers
    FOR UPDATE USING (owner_id = auth.uid() OR auth.uid() IS NOT NULL);

-- 用户只能删除自己的挂单
CREATE POLICY "Users can delete own offers" ON trade_offers
    FOR DELETE USING (owner_id = auth.uid());

-- trade_history 策略
-- 用户只能查看自己参与的交易
CREATE POLICY "Users can view own trade history" ON trade_history
    FOR SELECT USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 用户可以更新自己参与的交易（用于评价）
CREATE POLICY "Users can update own trade history" ON trade_history
    FOR UPDATE USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- =============================================
-- 4. 辅助函数：添加物品到用户
-- =============================================
CREATE OR REPLACE FUNCTION add_item_to_user(p_user_id UUID, p_item_name TEXT, p_quantity INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item_def_id UUID;
    v_existing_id UUID;
    v_existing_qty INT;
BEGIN
    -- 查找物品定义 ID
    SELECT id INTO v_item_def_id FROM items WHERE name = p_item_name;
    IF v_item_def_id IS NULL THEN
        RAISE EXCEPTION '物品不存在: %', p_item_name;
    END IF;

    -- 检查用户是否已有该物品
    SELECT id, quantity INTO v_existing_id, v_existing_qty
    FROM user_items WHERE user_id = p_user_id AND item_id = v_item_def_id;

    IF v_existing_id IS NOT NULL THEN
        -- 更新现有数量
        UPDATE user_items SET quantity = quantity + p_quantity WHERE id = v_existing_id;
    ELSE
        -- 插入新记录
        INSERT INTO user_items (user_id, item_id, quantity, acquired_from)
        VALUES (p_user_id, v_item_def_id, p_quantity, 'trade');
    END IF;
END;
$$;

-- =============================================
-- 5. 接受交易 RPC 函数（确保原子性）
-- =============================================
CREATE OR REPLACE FUNCTION accept_trade_offer(p_offer_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offer trade_offers%ROWTYPE;
    v_buyer_id UUID;
    v_buyer_username TEXT;
    v_item JSONB;
    v_item_name TEXT;
    v_quantity INT;
    v_user_item_id UUID;
    v_current_qty INT;
BEGIN
    -- 获取当前用户
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '用户未登录');
    END IF;

    SELECT email INTO v_buyer_username FROM auth.users WHERE id = v_buyer_id;

    -- 锁定并获取挂单
    SELECT * INTO v_offer FROM trade_offers
    WHERE id = p_offer_id FOR UPDATE;

    -- 验证挂单存在
    IF v_offer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单不存在');
    END IF;

    -- 验证状态
    IF v_offer.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', '挂单已失效');
    END IF;

    -- 验证是否过期
    IF v_offer.expires_at < now() THEN
        UPDATE trade_offers SET status = 'expired' WHERE id = p_offer_id;
        RETURN jsonb_build_object('success', false, 'error', '挂单已过期');
    END IF;

    -- 不能接受自己的挂单
    IF v_offer.owner_id = v_buyer_id THEN
        RETURN jsonb_build_object('success', false, 'error', '不能接受自己的挂单');
    END IF;

    -- 验证买家库存（requesting_items 是买家需要支付的）
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        v_item_name := v_item->>'name';
        v_quantity := (v_item->>'quantity')::INT;

        SELECT ui.id, ui.quantity INTO v_user_item_id, v_current_qty
        FROM user_items ui
        JOIN items id ON ui.item_id = id.id
        WHERE ui.user_id = v_buyer_id AND id.name = v_item_name;

        IF v_current_qty IS NULL OR v_current_qty < v_quantity THEN
            RETURN jsonb_build_object('success', false, 'error',
                format('物品不足：%s 还需 %s 个', v_item_name, v_quantity - COALESCE(v_current_qty, 0)));
        END IF;
    END LOOP;

    -- 执行交换：扣除买家物品（requesting_items）
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        v_item_name := v_item->>'name';
        v_quantity := (v_item->>'quantity')::INT;

        SELECT ui.id, ui.quantity INTO v_user_item_id, v_current_qty
        FROM user_items ui
        JOIN items id ON ui.item_id = id.id
        WHERE ui.user_id = v_buyer_id AND id.name = v_item_name;

        IF v_current_qty = v_quantity THEN
            DELETE FROM user_items WHERE id = v_user_item_id;
        ELSE
            UPDATE user_items SET quantity = quantity - v_quantity WHERE id = v_user_item_id;
        END IF;
    END LOOP;

    -- 给买家添加物品（offering_items - 卖家提供的）
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.offering_items)
    LOOP
        v_item_name := v_item->>'name';
        v_quantity := (v_item->>'quantity')::INT;

        PERFORM add_item_to_user(v_buyer_id, v_item_name, v_quantity);
    END LOOP;

    -- 给卖家添加物品（requesting_items - 买家支付的）
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_offer.requesting_items)
    LOOP
        v_item_name := v_item->>'name';
        v_quantity := (v_item->>'quantity')::INT;

        PERFORM add_item_to_user(v_offer.owner_id, v_item_name, v_quantity);
    END LOOP;

    -- 更新挂单状态
    UPDATE trade_offers SET
        status = 'completed',
        completed_at = now(),
        completed_by_user_id = v_buyer_id,
        completed_by_username = v_buyer_username
    WHERE id = p_offer_id;

    -- 创建交易历史
    INSERT INTO trade_history (offer_id, seller_id, seller_username, buyer_id, buyer_username, items_exchanged)
    VALUES (p_offer_id, v_offer.owner_id, v_offer.owner_username, v_buyer_id, v_buyer_username,
        jsonb_build_object('offered', v_offer.offering_items, 'requested', v_offer.requesting_items));

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION accept_trade_offer(UUID) IS '接受交易挂单，原子操作确保交易安全';
COMMENT ON FUNCTION add_item_to_user(UUID, TEXT, INT) IS '添加物品到用户背包';
