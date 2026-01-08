#!/bin/bash
# ==================================================================================
# PostgreSQL 批量扫描脚本执行器
# 功能：自动执行所有批次脚本并收集结果
# ==================================================================================

set -e

# 配置参数（请根据实际情况修改）
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-postgres}"
OUTPUT_DIR="${OUTPUT_DIR:-./results}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示使用说明
show_usage() {
    cat << EOF
使用方式:
    $0 [选项]

选项:
    -h, --host HOST         数据库主机 (默认: localhost)
    -p, --port PORT         数据库端口 (默认: 5432)
    -d, --database DB       数据库名称 (必需)
    -u, --user USER         数据库用户 (默认: postgres)
    -o, --output DIR        输出目录 (默认: ./results)
    --help                  显示此帮助信息

环境变量:
    DB_HOST                 数据库主机
    DB_PORT                 数据库端口
    DB_NAME                 数据库名称
    DB_USER                 数据库用户
    PGPASSWORD              数据库密码
    OUTPUT_DIR              输出目录

示例:
    # 使用命令行参数
    $0 -h localhost -d mydb -u postgres -o ./results

    # 使用环境变量
    export DB_HOST=localhost
    export DB_NAME=mydb
    export DB_USER=postgres
    export PGPASSWORD=secret
    $0

    # 执行特定批次范围
    $0 -d mydb --start 1 --end 5
EOF
}

# 解析命令行参数
START_BATCH=1
END_BATCH=999

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            DB_HOST="$2"
            shift 2
            ;;
        -p|--port)
            DB_PORT="$2"
            shift 2
            ;;
        -d|--database)
            DB_NAME="$2"
            shift 2
            ;;
        -u|--user)
            DB_USER="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --start)
            START_BATCH="$2"
            shift 2
            ;;
        --end)
            END_BATCH="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$DB_NAME" ]; then
    echo -e "${RED}错误: 必须指定数据库名称${NC}"
    show_usage
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 检查 psql 是否可用
if ! command -v psql &> /dev/null; then
    echo -e "${RED}错误: psql 命令未找到${NC}"
    echo "请安装 PostgreSQL 客户端工具"
    exit 1
fi

# 查找所有批次脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPTS=($(ls -1 "$SCRIPT_DIR"/batch_*.sql 2>/dev/null | sort))

if [ ${#BATCH_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}警告: 未找到批次脚本文件${NC}"
    echo "请先运行 generate_scan_batches.py 生成批次脚本"
    exit 1
fi

echo "=========================================="
echo "PostgreSQL 批量扫描执行器"
echo "=========================================="
echo "数据库: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "输出目录: $OUTPUT_DIR"
echo "找到批次脚本: ${#BATCH_SCRIPTS[@]} 个"
echo "=========================================="
echo ""

# 测试数据库连接
echo -n "测试数据库连接... "
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}✓ 成功${NC}"
else
    echo -e "${RED}✗ 失败${NC}"
    echo "请检查数据库连接参数和密码（使用 PGPASSWORD 环境变量）"
    exit 1
fi

echo ""

# 创建汇总文件
SUMMARY_FILE="$OUTPUT_DIR/summary_all_batches.txt"
echo "PostgreSQL 批量扫描结果汇总" > "$SUMMARY_FILE"
echo "生成时间: $(date)" >> "$SUMMARY_FILE"
echo "数据库: $DB_NAME" >> "$SUMMARY_FILE"
echo "==========================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# 执行所有批次
TOTAL_BATCHES=${#BATCH_SCRIPTS[@]}
CURRENT=0
SUCCESS=0
FAILED=0

for BATCH_SCRIPT in "${BATCH_SCRIPTS[@]}"; do
    CURRENT=$((CURRENT + 1))
    BATCH_NAME=$(basename "$BATCH_SCRIPT" .sql)
    OUTPUT_FILE="$OUTPUT_DIR/${BATCH_NAME}_output.txt"
    
    # 提取批次编号
    BATCH_NUM=$(echo "$BATCH_NAME" | grep -oP 'batch_\K\d+' || echo "$CURRENT")
    
    # 检查是否在执行范围内
    if [ "$BATCH_NUM" -lt "$START_BATCH" ] || [ "$BATCH_NUM" -gt "$END_BATCH" ]; then
        continue
    fi
    
    echo -e "[$CURRENT/$TOTAL_BATCHES] 执行批次: ${YELLOW}$BATCH_NAME${NC}"
    echo "  输出文件: $OUTPUT_FILE"
    
    # 记录开始时间
    START_TIME=$(date +%s)
    
    # 执行批次脚本
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -f "$BATCH_SCRIPT" > "$OUTPUT_FILE" 2>&1; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "  ${GREEN}✓ 完成${NC} (耗时: ${DURATION}s)"
        SUCCESS=$((SUCCESS + 1))
        
        # 提取结果并添加到汇总
        echo "批次: $BATCH_NAME (耗时: ${DURATION}s)" >> "$SUMMARY_FILE"
        grep -A 100 "找到匹配" "$OUTPUT_FILE" | head -20 >> "$SUMMARY_FILE" 2>/dev/null || true
        echo "" >> "$SUMMARY_FILE"
    else
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "  ${RED}✗ 失败${NC} (耗时: ${DURATION}s)"
        FAILED=$((FAILED + 1))
        
        echo "批次: $BATCH_NAME - 执行失败" >> "$SUMMARY_FILE"
        echo "请查看: $OUTPUT_FILE" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
    fi
    
    echo ""
done

# 显示执行摘要
echo "=========================================="
echo "执行完成！"
echo "=========================================="
echo -e "总批次数: $TOTAL_BATCHES"
echo -e "${GREEN}成功: $SUCCESS${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo "=========================================="
echo ""
echo "结果文件："
echo "  - 汇总: $SUMMARY_FILE"
echo "  - 详细输出: $OUTPUT_DIR/*_output.txt"
echo ""
echo "查看包含匹配结果的批次："
echo "  grep -l '找到匹配' $OUTPUT_DIR/*_output.txt"
echo ""
echo "查看所有匹配的表："
echo "  grep '找到匹配' $OUTPUT_DIR/*_output.txt | cut -d: -f2-"
echo "=========================================="
