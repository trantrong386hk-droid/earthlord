-- ============================================
-- 频道创建相关函数
-- ============================================

-- MARK: - generate_channel_code 函数（生成频道代码）

CREATE OR REPLACE FUNCTION generate_channel_code(p_channel_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_prefix TEXT;
    v_suffix TEXT;
    v_code TEXT;
    v_exists BOOLEAN;
    v_attempts INT := 0;
    v_max_attempts INT := 100;
BEGIN
    -- 根据频道类型确定前缀
    v_prefix := CASE p_channel_type
        WHEN 'walkie_talkie' THEN 'WLK'
        WHEN 'camping_radio' THEN 'CMP'
        WHEN 'satellite_phone' THEN 'SAT'
        WHEN 'official' THEN 'OFF'
        ELSE 'CHN'
    END;

    -- 循环生成唯一代码
    LOOP
        -- 生成 4 位随机后缀
        v_suffix := UPPER(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4));
        v_code := v_prefix || '-' || v_suffix;

        -- 检查代码是否已存在
        SELECT EXISTS(
            SELECT 1 FROM communication_channels WHERE channel_code = v_code
        ) INTO v_exists;

        -- 如果不存在则返回
        IF NOT v_exists THEN
            RETURN v_code;
        END IF;

        -- 防止无限循环
        v_attempts := v_attempts + 1;
        IF v_attempts >= v_max_attempts THEN
            RAISE EXCEPTION '无法生成唯一的频道代码';
        END IF;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION generate_channel_code(TEXT) IS '根据频道类型生成唯一的频道代码（如 WLK-A1B2）';

-- MARK: - create_channel_with_subscription 函数（创建频道并自动订阅）

CREATE OR REPLACE FUNCTION create_channel_with_subscription(
    p_creator_id UUID,
    p_channel_type TEXT,
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_channel_id UUID;
    v_channel_code TEXT;
    v_location_wkt TEXT;
BEGIN
    -- 验证用户已登录
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION '用户未登录';
    END IF;

    -- 验证创建者是当前用户
    IF p_creator_id != auth.uid() THEN
        RAISE EXCEPTION '无权限为其他用户创建频道';
    END IF;

    -- 生成频道代码
    v_channel_code := generate_channel_code(p_channel_type);

    -- 构造 PostGIS POINT（如果提供了坐标）
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        -- PostGIS POINT 格式: POINT(longitude latitude)
        -- 注意：PostGIS 使用 (经度 纬度) 顺序
        v_location_wkt := 'SRID=4326;POINT(' || p_longitude || ' ' || p_latitude || ')';
    ELSE
        v_location_wkt := NULL;
    END IF;

    -- 创建频道
    INSERT INTO communication_channels (
        creator_id,
        channel_type,
        channel_code,
        name,
        description,
        creator_location
    )
    VALUES (
        p_creator_id,
        p_channel_type,
        v_channel_code,
        p_name,
        p_description,
        v_location_wkt::geography
    )
    RETURNING id INTO v_channel_id;

    -- 自动订阅创建者
    INSERT INTO channel_subscriptions (user_id, channel_id)
    VALUES (p_creator_id, v_channel_id);

    RETURN v_channel_id;
END;
$$;

COMMENT ON FUNCTION create_channel_with_subscription IS '创建频道并自动订阅创建者，可选记录创建者GPS位置';
