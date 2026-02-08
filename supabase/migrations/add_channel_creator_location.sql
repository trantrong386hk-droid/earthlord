-- 为 communication_channels 表添加创建者位置字段
-- 使用 PostGIS GEOGRAPHY 类型存储 WGS-84 坐标

-- 确保 PostGIS 扩展已启用
CREATE EXTENSION IF NOT EXISTS postgis;

-- 添加创建者位置字段
ALTER TABLE communication_channels
ADD COLUMN creator_location GEOGRAPHY(POINT, 4326);

-- 创建空间索引提升查询性能
CREATE INDEX idx_communication_channels_creator_location
ON communication_channels USING GIST (creator_location);

-- 添加注释
COMMENT ON COLUMN communication_channels.creator_location IS '频道创建者的GPS位置（WGS-84坐标，用于显示距离）';
