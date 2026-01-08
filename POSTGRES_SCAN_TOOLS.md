# PostgreSQL 数据库扫描工具

本项目包含一套完整的 PostgreSQL 数据库批量扫描工具，用于在数据库中查找包含特定值的所有表和字段。

## 📁 工具位置

所有 PostgreSQL 扫描工具位于：`postgres_scan_scripts/` 目录

## 🎯 功能

- **批量扫描**：自动扫描数据库中的所有表，查找包含 '訂單' 和 '出貨單' 的记录
- **分批处理**：每批 100 个表（可配置），生成独立可执行的 SQL 脚本
- **智能过滤**：自动排除系统表（pg_*, information_schema.*）
- **全字段搜索**：扫描所有可转换为文本的列类型
- **详细输出**：显示表名、列名、匹配行数和示例数据
- **跨平台支持**：Linux、macOS、Windows

## 🚀 快速开始

### 方式 1：快速扫描（小型数据库，< 100 个表）

```bash
cd postgres_scan_scripts
psql -U postgres -d your_database -f quick_scan_single_batch.sql > results.txt
```

### 方式 2：完整扫描（中大型数据库）

```bash
cd postgres_scan_scripts

# 1. 安装依赖（仅需一次）
pip install psycopg2-binary

# 2. 生成批次脚本
python generate_scan_batches.py \
    --host localhost \
    --database your_database \
    --user postgres \
    --output-dir ./batches

# 3. 执行所有批次
./run_all_batches.sh -d your_database -u postgres -o ./results
```

## 📚 完整文档

进入 `postgres_scan_scripts/` 目录查看完整文档：

- **[README.md](postgres_scan_scripts/README.md)** - 完整技术文档和使用指南
- **[QUICKSTART.md](postgres_scan_scripts/QUICKSTART.md)** - 快速开始指南
- **[INDEX.md](postgres_scan_scripts/INDEX.md)** - 文件索引和导航
- **[SUMMARY.md](postgres_scan_scripts/SUMMARY.md)** - 项目总结

## 📦 包含的工具

### Python 工具
- `generate_scan_batches.py` - 批次脚本生成器

### SQL 脚本
- `quick_scan_single_batch.sql` - 快速单批次扫描
- `generate_batch_scripts.sql` - 批次信息生成器
- `batch_template.sql` - 批次脚本模板
- `example_batch_001_001_100.sql` - 示例批次脚本

### Shell 脚本
- `run_all_batches.sh` - Linux/macOS 批量执行器
- `run_all_batches.bat` - Windows 批量执行器

### 配置文件
- `config.example.env` - 环境变量配置示例

## 💡 使用场景

1. **数据审计**：查找特定值在数据库中的分布情况
2. **数据迁移**：定位需要迁移或转换的数据
3. **合规检查**：查找包含特定术语的所有记录
4. **问题排查**：快速定位数据异常

## ⚙️ 系统要求

- PostgreSQL 9.6+
- Python 3.6+（使用 Python 工具时）
- psycopg2-binary（使用 Python 工具时）
- Bash 4.0+（使用 Shell 脚本时）

## 🔒 安全性

- 所有操作均为只读（SELECT 查询）
- 支持 `.pgpass` 文件和环境变量配置密码
- 建议使用只读数据库账户
- 不在命令行直接暴露密码

## 📊 输出示例

```
========================================
批次 001 扫描完成
========================================

 批次 | 表名              | 列名        | 搜索值  | 匹配行数 | 示例数据
------+-------------------+-------------+---------+----------+------------------
    1 | public.orders     | order_type  | 訂單    |      156 | 訂單-20240108-001
    1 | public.shipments  | type        | 出貨單  |      234 | 出貨單-2024-001

统计信息：
 扫描表数 | 找到匹配的列数 | 总匹配行数
----------+----------------+------------
      100 |              2 |        390
```

## 🆘 获取帮助

```bash
cd postgres_scan_scripts

# Python 脚本帮助
python generate_scan_batches.py --help

# Shell 脚本帮助
./run_all_batches.sh --help

# 查看文档
cat README.md
cat QUICKSTART.md
```

## 📝 注意事项

1. 首次使用建议在测试环境验证
2. 大型数据库建议在非高峰期执行
3. 可根据需要调整批次大小和搜索值
4. 执行前确保有足够的磁盘空间存储结果

---

**相关链接**：
- [完整文档](postgres_scan_scripts/README.md)
- [快速开始](postgres_scan_scripts/QUICKSTART.md)
- [示例脚本](postgres_scan_scripts/example_batch_001_001_100.sql)

**版本**：1.0.0  
**创建日期**：2024-01-08  
**状态**：✅ 生产就绪
