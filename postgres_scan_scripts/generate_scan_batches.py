#!/usr/bin/env python3
"""
PostgreSQL 批量扫描脚本生成器

功能：
- 连接到 PostgreSQL 数据库
- 获取所有需要扫描的表（排除系统表）
- 生成批处理 SQL 脚本，每批 100 个表
- 每个批次脚本独立可执行

使用方式：
    python generate_scan_batches.py --host localhost --port 5432 --database mydb --user postgres

依赖：
    pip install psycopg2-binary
"""

import argparse
import os
import sys
from datetime import datetime
from typing import List, Tuple

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("错误: 需要安装 psycopg2-binary")
    print("执行: pip install psycopg2-binary")
    sys.exit(1)


def get_tables(conn) -> List[Tuple[int, str, str]]:
    """获取所有需要扫描的表"""
    query = """
        SELECT 
            row_number() OVER (ORDER BY schemaname, tablename) AS seq_num,
            schemaname,
            tablename
        FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND schemaname NOT LIKE 'pg_%'
        ORDER BY schemaname, tablename;
    """
    
    with conn.cursor() as cur:
        cur.execute(query)
        return cur.fetchall()


def get_columns(conn, schema: str, table: str) -> List[str]:
    """获取表的所有列名"""
    query = """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position;
    """
    
    with conn.cursor() as cur:
        cur.execute(query, (schema, table))
        return [row[0] for row in cur.fetchall()]


def generate_table_scan_block(seq_num: int, schema: str, table: str, columns: List[str], batch_num: int) -> str:
    """生成单个表的扫描 SQL 代码块"""
    full_table = f"{schema}.{table}"
    search_values = ["訂單", "出貨單"]
    
    blocks = []
    blocks.append(f"-- 表 {seq_num}: {full_table}")
    blocks.append(f"\\echo '正在扫描表 {seq_num}: {full_table} ...'")
    blocks.append("")
    
    for search_value in search_values:
        for column in columns:
            # 生成动态 SQL 检查语句
            blocks.append(f"-- 检查列: {column}")
            blocks.append("DO $$")
            blocks.append("DECLARE")
            blocks.append("    v_count BIGINT;")
            blocks.append("    v_sample TEXT;")
            blocks.append("BEGIN")
            blocks.append("    BEGIN")
            blocks.append(f"        -- 尝试将列转换为文本并搜索")
            blocks.append(f"        EXECUTE format(")
            blocks.append(f"            'SELECT COUNT(*), MAX(%I::text) FROM {full_table} WHERE %I::text LIKE ''%%%s%%''',")
            blocks.append(f"            '{column}', '{column}', '{search_value}'")
            blocks.append(f"        ) INTO v_count, v_sample;")
            blocks.append(f"        ")
            blocks.append(f"        IF v_count > 0 THEN")
            blocks.append(f"            INSERT INTO temp_scan_results_{batch_num} ")
            blocks.append(f"            VALUES ({batch_num}, '{schema}', '{table}', '{column}', '{search_value}', v_count, v_sample);")
            blocks.append(f"            RAISE NOTICE '  ✓ 找到匹配: %.% (列: %) - % 行', '{schema}', '{table}', '{column}', v_count;")
            blocks.append(f"        END IF;")
            blocks.append(f"    EXCEPTION")
            blocks.append(f"        WHEN OTHERS THEN")
            blocks.append(f"            -- 跳过无法转换为文本的列类型")
            blocks.append(f"            NULL;")
            blocks.append(f"    END;")
            blocks.append("END $$;")
            blocks.append("")
    
    blocks.append("")
    return "\n".join(blocks)


def generate_batch_script(batch_num: int, tables: List[Tuple[int, str, str]], 
                         conn, output_dir: str) -> str:
    """生成单个批次的完整脚本"""
    if not tables:
        return None
    
    start_seq = tables[0][0]
    end_seq = tables[-1][0]
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 读取模板
    template_path = os.path.join(os.path.dirname(__file__), "batch_template.sql")
    if os.path.exists(template_path):
        with open(template_path, 'r', encoding='utf-8') as f:
            template = f.read()
    else:
        # 如果模板不存在，使用内置简化版本
        template = create_inline_template()
    
    # 生成所有表的扫描块
    scan_blocks = []
    for seq_num, schema, table in tables:
        try:
            columns = get_columns(conn, schema, table)
            if columns:
                block = generate_table_scan_block(seq_num, schema, table, columns, batch_num)
                scan_blocks.append(block)
        except Exception as e:
            print(f"警告: 无法获取表 {schema}.{table} 的列信息: {e}")
            continue
    
    # 替换模板变量
    script = template.replace("{BATCH_NUMBER}", str(batch_num))
    script = script.replace("{START_SEQ}", str(start_seq))
    script = script.replace("{END_SEQ}", str(end_seq))
    script = script.replace("{TIMESTAMP}", timestamp)
    script = script.replace("{TABLE_SCAN_BLOCKS}", "\n".join(scan_blocks))
    
    # 写入文件
    filename = f"batch_{batch_num:03d}_{start_seq:04d}_{end_seq:04d}.sql"
    filepath = os.path.join(output_dir, filename)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(script)
    
    return filename


def create_inline_template() -> str:
    """创建内联模板（当外部模板文件不存在时使用）"""
    return """-- ==================================================================================
-- PostgreSQL 表扫描批处理脚本
-- 批次: {BATCH_NUMBER} (表 {START_SEQ} - {END_SEQ})
-- 生成时间: {TIMESTAMP}
-- ==================================================================================

\\timing on
\\pset border 2

\\echo ''
\\echo '=========================================='
\\echo '开始执行批次 {BATCH_NUMBER}'
\\echo '扫描表范围: {START_SEQ} - {END_SEQ}'
\\echo '=========================================='
\\echo ''

DROP TABLE IF EXISTS temp_scan_results_{BATCH_NUMBER};
CREATE TEMP TABLE temp_scan_results_{BATCH_NUMBER} (
    batch_number INTEGER,
    table_schema TEXT,
    table_name TEXT,
    column_name TEXT,
    search_value TEXT,
    match_count BIGINT,
    sample_data TEXT
);

{TABLE_SCAN_BLOCKS}

\\echo ''
\\echo '=========================================='
\\echo '批次 {BATCH_NUMBER} 扫描完成'
\\echo '=========================================='
\\echo ''

SELECT 
    batch_number AS "批次",
    table_schema || '.' || table_name AS "表名",
    column_name AS "列名",
    search_value AS "搜索值",
    match_count AS "匹配行数",
    LEFT(sample_data, 100) AS "示例数据"
FROM temp_scan_results_{BATCH_NUMBER}
WHERE match_count > 0
ORDER BY table_schema, table_name, column_name;

SELECT 
    COUNT(DISTINCT table_schema || '.' || table_name) AS "扫描表数",
    COUNT(*) FILTER (WHERE match_count > 0) AS "找到匹配的列数",
    SUM(match_count) AS "总匹配行数"
FROM temp_scan_results_{BATCH_NUMBER};
"""


def main():
    parser = argparse.ArgumentParser(
        description="生成 PostgreSQL 批量表扫描脚本",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--host", default="localhost", help="数据库主机 (默认: localhost)")
    parser.add_argument("--port", type=int, default=5432, help="数据库端口 (默认: 5432)")
    parser.add_argument("--database", required=True, help="数据库名称")
    parser.add_argument("--user", required=True, help="数据库用户名")
    parser.add_argument("--password", help="数据库密码 (如不提供则提示输入)")
    parser.add_argument("--output-dir", default="./batches", help="输出目录 (默认: ./batches)")
    parser.add_argument("--batch-size", type=int, default=100, help="每批表数量 (默认: 100)")
    
    args = parser.parse_args()
    
    # 获取密码
    password = args.password
    if not password:
        import getpass
        password = getpass.getpass(f"请输入用户 {args.user} 的密码: ")
    
    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)
    
    print(f"\n正在连接到数据库 {args.database}...")
    
    try:
        # 连接数据库
        conn = psycopg2.connect(
            host=args.host,
            port=args.port,
            database=args.database,
            user=args.user,
            password=password
        )
        
        print("✓ 数据库连接成功")
        print("\n正在获取表列表...")
        
        # 获取所有表
        tables = get_tables(conn)
        total_tables = len(tables)
        total_batches = (total_tables + args.batch_size - 1) // args.batch_size
        
        print(f"\n==========================================")
        print(f"扫描配置信息")
        print(f"==========================================")
        print(f"需要扫描的表总数: {total_tables}")
        print(f"批次大小: {args.batch_size} 个表/批")
        print(f"总批次数: {total_batches}")
        print(f"输出目录: {args.output_dir}")
        print(f"==========================================\n")
        
        # 生成批次脚本
        generated_files = []
        for batch_num in range(1, total_batches + 1):
            start_idx = (batch_num - 1) * args.batch_size
            end_idx = min(start_idx + args.batch_size, total_tables)
            batch_tables = tables[start_idx:end_idx]
            
            print(f"正在生成批次 {batch_num}/{total_batches} "
                  f"(表 {batch_tables[0][0]} - {batch_tables[-1][0]})...", end=" ")
            
            filename = generate_batch_script(batch_num, batch_tables, conn, args.output_dir)
            
            if filename:
                generated_files.append(filename)
                print(f"✓ {filename}")
            else:
                print("✗ 跳过")
        
        conn.close()
        
        print(f"\n==========================================")
        print(f"脚本生成完成！")
        print(f"==========================================")
        print(f"生成的脚本文件数: {len(generated_files)}")
        print(f"输出目录: {os.path.abspath(args.output_dir)}")
        print(f"\n执行方式：")
        print(f"  cd {args.output_dir}")
        print(f"  psql -U {args.user} -d {args.database} -f batch_001_*.sql > output_001.txt")
        print(f"  psql -U {args.user} -d {args.database} -f batch_002_*.sql > output_002.txt")
        print(f"  ...")
        print(f"\n或使用循环批量执行：")
        print(f"  for f in batch_*.sql; do")
        print(f"    psql -U {args.user} -d {args.database} -f \"$f\" > \"output_${{f%.sql}}.txt\"")
        print(f"  done")
        print(f"==========================================\n")
        
    except psycopg2.Error as e:
        print(f"\n错误: 数据库连接或查询失败")
        print(f"详细信息: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n错误: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
