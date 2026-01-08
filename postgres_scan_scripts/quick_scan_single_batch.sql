-- ==================================================================================
-- PostgreSQL 快速扫描脚本 - 单批次版本
-- 功能：动态扫描数据库中的前 100 个表，查找 '訂單' 和 '出貨單'
-- 适用场景：快速测试或小型数据库
-- ==================================================================================
-- 使用方式：
--   psql -U username -d database -f quick_scan_single_batch.sql > scan_results.txt
-- ==================================================================================

\timing on
\pset border 2
\pset format wrapped

\echo ''
\echo '=========================================='
\echo 'PostgreSQL 快速扫描工具'
\echo '搜索值: ''訂單'', ''出貨單'''
\echo '=========================================='
\echo ''

-- 创建结果表
DROP TABLE IF EXISTS temp_scan_results;
CREATE TEMP TABLE temp_scan_results (
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    table_schema TEXT,
    table_name TEXT,
    column_name TEXT,
    search_value TEXT,
    match_count BIGINT,
    sample_data TEXT
);

-- 创建表列表
DROP TABLE IF EXISTS temp_tables_to_scan;
CREATE TEMP TABLE temp_tables_to_scan AS
SELECT 
    row_number() OVER (ORDER BY schemaname, tablename) AS seq_num,
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND schemaname NOT LIKE 'pg_%'
ORDER BY schemaname, tablename
LIMIT 100;  -- 限制为前 100 个表

-- 显示将要扫描的表
\echo '将要扫描的表列表：'
\echo '=========================================='
SELECT 
    seq_num AS "序号",
    schemaname AS "Schema",
    tablename AS "表名"
FROM temp_tables_to_scan
ORDER BY seq_num;

\echo ''
\echo '=========================================='
\echo '开始扫描...'
\echo '=========================================='
\echo ''

-- 动态扫描所有表的所有列
DO $$
DECLARE
    v_table RECORD;
    v_column RECORD;
    v_sql TEXT;
    v_count BIGINT;
    v_sample TEXT;
    v_total_tables INT;
    v_current_table INT := 0;
    v_search_values TEXT[] := ARRAY['訂單', '出貨單'];
    v_search_value TEXT;
BEGIN
    -- 获取总表数
    SELECT COUNT(*) INTO v_total_tables FROM temp_tables_to_scan;
    
    -- 遍历所有表
    FOR v_table IN 
        SELECT seq_num, schemaname, tablename 
        FROM temp_tables_to_scan 
        ORDER BY seq_num
    LOOP
        v_current_table := v_current_table + 1;
        RAISE NOTICE '[%/%] 正在扫描: %.% ...', 
            v_current_table, v_total_tables, v_table.schemaname, v_table.tablename;
        
        -- 遍历表的所有列
        FOR v_column IN
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = v_table.schemaname
              AND table_name = v_table.tablename
            ORDER BY ordinal_position
        LOOP
            -- 遍历搜索值
            FOREACH v_search_value IN ARRAY v_search_values
            LOOP
                BEGIN
                    -- 动态构造查询 SQL
                    v_sql := format(
                        'SELECT COUNT(*), MAX(%I::text) FROM %I.%I WHERE %I::text LIKE ''%%%s%%''',
                        v_column.column_name,
                        v_table.schemaname,
                        v_table.tablename,
                        v_column.column_name,
                        v_search_value
                    );
                    
                    -- 执行查询
                    EXECUTE v_sql INTO v_count, v_sample;
                    
                    -- 如果找到匹配，插入结果
                    IF v_count > 0 THEN
                        INSERT INTO temp_scan_results 
                            (table_schema, table_name, column_name, search_value, match_count, sample_data)
                        VALUES 
                            (v_table.schemaname, v_table.tablename, v_column.column_name, 
                             v_search_value, v_count, v_sample);
                        
                        RAISE NOTICE '  ✓ 找到匹配: %.% (列: %, 值: %) - % 行', 
                            v_table.schemaname, v_table.tablename, v_column.column_name,
                            v_search_value, v_count;
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        -- 跳过无法转换为文本的列类型（如 binary, bytea 等）
                        NULL;
                END;
            END LOOP;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '扫描完成！';
END $$;

-- ==================================================================================
-- 显示结果
-- ==================================================================================

\echo ''
\echo '=========================================='
\echo '扫描结果汇总'
\echo '=========================================='
\echo ''

-- 详细结果
\echo '找到匹配的记录：'
\echo '------------------------------------------'

SELECT 
    table_schema || '.' || table_name AS "表名",
    column_name AS "列名",
    search_value AS "搜索值",
    match_count AS "匹配行数",
    LEFT(sample_data, 80) AS "示例数据（前80字符）"
FROM temp_scan_results
WHERE match_count > 0
ORDER BY match_count DESC, table_schema, table_name, column_name;

\echo ''
\echo '=========================================='
\echo '统计信息'
\echo '=========================================='
\echo ''

-- 统计信息
SELECT 
    (SELECT COUNT(*) FROM temp_tables_to_scan) AS "扫描表总数",
    COUNT(DISTINCT table_schema || '.' || table_name) AS "找到匹配的表数",
    COUNT(DISTINCT table_schema || '.' || table_name || '.' || column_name) AS "找到匹配的列数",
    SUM(match_count) AS "总匹配行数"
FROM temp_scan_results
WHERE match_count > 0;

-- 按表统计
\echo ''
\echo '按表分组统计：'
\echo '------------------------------------------'

SELECT 
    table_schema || '.' || table_name AS "表名",
    COUNT(*) AS "匹配列数",
    SUM(match_count) AS "总行数",
    string_agg(DISTINCT search_value, ', ') AS "找到的值"
FROM temp_scan_results
WHERE match_count > 0
GROUP BY table_schema, table_name
ORDER BY SUM(match_count) DESC;

-- 按搜索值统计
\echo ''
\echo '按搜索值统计：'
\echo '------------------------------------------'

SELECT 
    search_value AS "搜索值",
    COUNT(DISTINCT table_schema || '.' || table_name) AS "出现在表数",
    COUNT(*) AS "出现在列数",
    SUM(match_count) AS "总行数"
FROM temp_scan_results
WHERE match_count > 0
GROUP BY search_value
ORDER BY SUM(match_count) DESC;

\echo ''
\echo '=========================================='
\echo '扫描完成！'
\echo '=========================================='
\echo ''
\echo '提示：'
\echo '  - 此脚本仅扫描前 100 个表'
\echo '  - 如需扫描更多表，使用 generate_scan_batches.py 生成批次脚本'
\echo '  - 结果已保存在临时表 temp_scan_results 中'
\echo '  - 会话结束后临时表将自动清除'
\echo ''

-- 可选：导出结果到 CSV
\echo '导出结果到 CSV（可选）：'
\echo '  \\copy (SELECT * FROM temp_scan_results WHERE match_count > 0) TO ''/tmp/scan_results.csv'' WITH CSV HEADER'
\echo ''
