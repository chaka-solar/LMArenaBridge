-- ==================================================================================
-- PostgreSQL 批量表扫描脚本生成器
-- 功能：动态生成批处理脚本，每批扫描 100 个表
-- 搜索目标：'訂單' 和 '出貨單'
-- ==================================================================================

-- 第一步：创建临时表存储所有需要扫描的表
DROP TABLE IF EXISTS temp_tables_to_scan;
CREATE TEMP TABLE temp_tables_to_scan AS
SELECT 
    row_number() OVER (ORDER BY schemaname, tablename) AS seq_num,
    schemaname,
    tablename,
    schemaname || '.' || tablename AS full_table_name
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND schemaname NOT LIKE 'pg_%'
ORDER BY schemaname, tablename;

-- 第二步：显示表的总数和批次信息
DO $$
DECLARE
    total_tables INTEGER;
    total_batches INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_tables FROM temp_tables_to_scan;
    total_batches := CEIL(total_tables / 100.0);
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE '扫描配置信息';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '需要扫描的表总数: %', total_tables;
    RAISE NOTICE '批次大小: 100 个表/批';
    RAISE NOTICE '总批次数: %', total_batches;
    RAISE NOTICE '搜索目标值: ''訂單'', ''出貨單''';
    RAISE NOTICE '==========================================';
END $$;

-- 第三步：查看每个批次包含的表列表
SELECT 
    CEIL(seq_num / 100.0) AS batch_number,
    MIN(seq_num) AS start_seq,
    MAX(seq_num) AS end_seq,
    COUNT(*) AS tables_in_batch,
    MIN(full_table_name) AS first_table,
    MAX(full_table_name) AS last_table
FROM temp_tables_to_scan
GROUP BY CEIL(seq_num / 100.0)
ORDER BY batch_number;

-- 第四步：显示批次脚本生成说明
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '如何生成和执行批处理脚本：';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '1. 使用提供的 generate_scan_batches.py 生成所有批次脚本';
    RAISE NOTICE '2. 或者手动使用 batch_template.sql 模板创建脚本';
    RAISE NOTICE '3. 执行每个批次脚本：';
    RAISE NOTICE '   psql -U username -d database -f batch_001_100.sql > output_batch_001.txt';
    RAISE NOTICE '4. 查看输出文件中的搜索结果';
    RAISE NOTICE '==========================================';
END $$;

-- 第五步：导出表列表供 Python 脚本使用（可选）
\copy (SELECT seq_num, schemaname, tablename, full_table_name FROM temp_tables_to_scan ORDER BY seq_num) TO '/tmp/tables_list.csv' WITH CSV HEADER;

SELECT 'Tables list exported to /tmp/tables_list.csv' AS status;
