-- ==================================================================================
-- PostgreSQL 表扫描批处理脚本示例
-- 批次: 001 (表 1 - 100)
-- 生成时间: 2024-01-08
-- ==================================================================================
-- 说明：
-- 1. 此脚本扫描第 1-100 个表，查找包含 '訂單' 或 '出貨單' 的记录
-- 2. 搜索所有可转换为文本的列类型
-- 3. 输出格式：表名 | 列名 | 找到的值 | 匹配行数
-- 4. 执行方式：psql -U username -d database -f example_batch_001_001_100.sql
-- 
-- 注意：这是一个示例文件，实际使用时请用 generate_scan_batches.py 生成
-- ==================================================================================

\timing on
\pset border 2

-- 开始标记
\echo ''
\echo '=========================================='
\echo '开始执行批次 001'
\echo '扫描表范围: 1 - 100'
\echo '=========================================='
\echo ''

-- 创建临时结果表
DROP TABLE IF EXISTS temp_scan_results_001;
CREATE TEMP TABLE temp_scan_results_001 (
    batch_number INTEGER,
    table_schema TEXT,
    table_name TEXT,
    column_name TEXT,
    search_value TEXT,
    match_count BIGINT,
    sample_data TEXT
);

-- ==================================================================================
-- 示例：扫描 public.orders 表
-- ==================================================================================

-- 表 1: public.orders
\echo '正在扫描表 1: public.orders ...'

-- 检查列: order_type (假设列)
DO $$
DECLARE
    v_count BIGINT;
    v_sample TEXT;
BEGIN
    -- 搜索 '訂單'
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.orders WHERE %I::text LIKE ''%%%s%%''',
            'order_type', 'order_type', '訂單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'orders', 'order_type', '訂單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.orders (列: order_type) - % 行', v_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            -- 跳过无法转换为文本的列类型
            NULL;
    END;
    
    -- 搜索 '出貨單'
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.orders WHERE %I::text LIKE ''%%%s%%''',
            'order_type', 'order_type', '出貨單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'orders', 'order_type', '出貨單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.orders (列: order_type) - % 行', v_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
END $$;

-- 检查列: description (假设列)
DO $$
DECLARE
    v_count BIGINT;
    v_sample TEXT;
BEGIN
    -- 搜索 '訂單'
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.orders WHERE %I::text LIKE ''%%%s%%''',
            'description', 'description', '訂單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'orders', 'description', '訂單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.orders (列: description) - % 行', v_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    
    -- 搜索 '出貨單'
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.orders WHERE %I::text LIKE ''%%%s%%''',
            'description', 'description', '出貨單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'orders', 'description', '出貨單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.orders (列: description) - % 行', v_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
END $$;

-- ==================================================================================
-- 示例：扫描 public.shipments 表
-- ==================================================================================

-- 表 2: public.shipments
\echo '正在扫描表 2: public.shipments ...'

-- 检查列: shipment_type (假设列)
DO $$
DECLARE
    v_count BIGINT;
    v_sample TEXT;
BEGIN
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.shipments WHERE %I::text LIKE ''%%%s%%''',
            'shipment_type', 'shipment_type', '訂單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'shipments', 'shipment_type', '訂單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.shipments (列: shipment_type) - % 行', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        EXECUTE format(
            'SELECT COUNT(*), MAX(%I::text) FROM public.shipments WHERE %I::text LIKE ''%%%s%%''',
            'shipment_type', 'shipment_type', '出貨單'
        ) INTO v_count, v_sample;
        
        IF v_count > 0 THEN
            INSERT INTO temp_scan_results_001 
            VALUES (1, 'public', 'shipments', 'shipment_type', '出貨單', v_count, v_sample);
            RAISE NOTICE '  ✓ 找到匹配: public.shipments (列: shipment_type) - % 行', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
END $$;

-- 注意：实际脚本会包含批次中所有表的扫描代码
-- 此处仅展示 2 个表作为示例

-- ==================================================================================
-- 批次 001 汇总结果
-- ==================================================================================

\echo ''
\echo '=========================================='
\echo '批次 001 扫描完成'
\echo '=========================================='
\echo ''

-- 显示找到结果的汇总
SELECT 
    batch_number AS "批次",
    table_schema || '.' || table_name AS "表名",
    column_name AS "列名",
    search_value AS "搜索值",
    match_count AS "匹配行数",
    LEFT(sample_data, 100) AS "示例数据（前100字符）"
FROM temp_scan_results_001
WHERE match_count > 0
ORDER BY table_schema, table_name, column_name, search_value;

-- 批次统计
\echo ''
\echo '=========================================='
\echo '批次统计信息'
\echo '=========================================='

SELECT 
    COUNT(DISTINCT table_schema || '.' || table_name) AS "扫描表数",
    COUNT(*) FILTER (WHERE match_count > 0) AS "找到匹配的列数",
    SUM(match_count) AS "总匹配行数"
FROM temp_scan_results_001;

\echo ''
\echo '=========================================='
\echo '批次 001 执行完毕'
\echo '提示：实际使用时请用 generate_scan_batches.py 生成完整脚本'
\echo '=========================================='
