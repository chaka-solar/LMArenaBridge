#!/bin/bash
# ==================================================================================
# PostgreSQL 扫描工具 - 安装验证脚本
# 功能：验证所有必需文件是否存在且可执行
# ==================================================================================

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "PostgreSQL 扫描工具 - 安装验证"
echo -e "==========================================${NC}"
echo ""

# 验证计数器
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# 检查函数
check_file() {
    local file=$1
    local description=$2
    local should_be_executable=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} $description: ${RED}文件不存在${NC}"
        echo "   期望位置: $file"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
    
    if [ "$should_be_executable" = "yes" ] && [ ! -x "$file" ]; then
        echo -e "${YELLOW}⚠${NC} $description: ${YELLOW}文件存在但不可执行${NC}"
        echo -e "   修复命令: ${BLUE}chmod +x $file${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} $description"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
}

# 检查命令
check_command() {
    local cmd=$1
    local description=$2
    local optional=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if command -v $cmd &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -1 || echo "版本未知")
        echo -e "${GREEN}✓${NC} $description: ${GREEN}已安装${NC}"
        echo "   $version"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$optional" = "optional" ]; then
            echo -e "${YELLOW}⚠${NC} $description: ${YELLOW}未安装（可选）${NC}"
        else
            echo -e "${RED}✗${NC} $description: ${RED}未安装（必需）${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
        return 1
    fi
}

echo -e "${BLUE}--- 核心文件检查 ---${NC}"
check_file "generate_scan_batches.py" "Python 脚本生成器" "yes"
check_file "run_all_batches.sh" "Unix 批量执行器" "yes"
check_file "run_all_batches.bat" "Windows 批量执行器" "no"
echo ""

echo -e "${BLUE}--- SQL 脚本检查 ---${NC}"
check_file "quick_scan_single_batch.sql" "快速扫描脚本" "no"
check_file "generate_batch_scripts.sql" "批次信息生成器" "no"
check_file "batch_template.sql" "批次脚本模板" "no"
check_file "example_batch_001_001_100.sql" "示例批次脚本" "no"
echo ""

echo -e "${BLUE}--- 文档文件检查 ---${NC}"
check_file "README.md" "完整文档" "no"
check_file "QUICKSTART.md" "快速指南" "no"
check_file "INDEX.md" "文件索引" "no"
check_file "SUMMARY.md" "项目总结" "no"
echo ""

echo -e "${BLUE}--- 配置文件检查 ---${NC}"
check_file "config.example.env" "配置示例" "no"
check_file ".gitignore" "Git 忽略规则" "no"
echo ""

echo -e "${BLUE}--- 系统依赖检查 ---${NC}"
check_command "psql" "PostgreSQL 客户端" "required"
check_command "python3" "Python 3" "optional"
check_command "bash" "Bash Shell" "required"
echo ""

echo -e "${BLUE}--- Python 依赖检查 ---${NC}"
if command -v python3 &> /dev/null; then
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if python3 -c "import psycopg2" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} psycopg2: ${GREEN}已安装${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${YELLOW}⚠${NC} psycopg2: ${YELLOW}未安装（可选）${NC}"
        echo -e "   安装命令: ${BLUE}pip install psycopg2-binary${NC}"
    fi
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if python3 -m py_compile generate_scan_batches.py 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Python 脚本语法: ${GREEN}正确${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}✗${NC} Python 脚本语法: ${RED}错误${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC} 跳过 Python 依赖检查（Python 3 未安装）"
fi
echo ""

# 文件大小统计
echo -e "${BLUE}--- 文件大小统计 ---${NC}"
echo "文档文件:"
du -h README.md QUICKSTART.md INDEX.md SUMMARY.md 2>/dev/null | awk '{print "  " $2 ": " $1}'
echo ""
echo "脚本文件:"
du -h generate_scan_batches.py run_all_batches.sh quick_scan_single_batch.sql 2>/dev/null | awk '{print "  " $2 ": " $1}'
echo ""

# 显示总结
echo -e "${BLUE}=========================================="
echo "验证结果总结"
echo -e "==========================================${NC}"
echo -e "总检查项: $TOTAL_CHECKS"
echo -e "${GREEN}通过: $PASSED_CHECKS${NC}"
echo -e "${RED}失败: $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！工具集已就绪。${NC}"
    echo ""
    echo "下一步："
    echo "  1. 查看快速指南: cat QUICKSTART.md"
    echo "  2. 执行快速扫描: psql -U postgres -d mydb -f quick_scan_single_batch.sql"
    echo "  3. 生成批次脚本: python3 generate_scan_batches.py --help"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ 有 $FAILED_CHECKS 项检查失败。${NC}"
    echo ""
    echo "修复建议："
    
    if ! command -v psql &> /dev/null; then
        echo "  • 安装 PostgreSQL 客户端:"
        echo "    Ubuntu/Debian: sudo apt-get install postgresql-client"
        echo "    macOS: brew install postgresql"
        echo "    Windows: 下载并安装 PostgreSQL"
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo "  • 安装 Python 3:"
        echo "    Ubuntu/Debian: sudo apt-get install python3 python3-pip"
        echo "    macOS: brew install python3"
        echo "    Windows: 从 python.org 下载安装"
    fi
    
    if command -v python3 &> /dev/null && ! python3 -c "import psycopg2" 2>/dev/null; then
        echo "  • 安装 psycopg2:"
        echo "    pip3 install psycopg2-binary"
    fi
    
    echo ""
    echo "即使有失败项，部分工具仍可使用："
    echo "  • 如果 psql 可用，可使用 quick_scan_single_batch.sql"
    echo "  • 如果 Python 可用，可使用完整的批次生成功能"
    echo ""
    exit 1
fi
