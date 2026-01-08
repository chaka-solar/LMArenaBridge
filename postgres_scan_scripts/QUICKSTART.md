# 快速开始指南

## 🎯 最简单的使用方式

### 方式 1：一键扫描（小型数据库，< 100 个表）

```bash
# 直接执行快速扫描脚本
psql -U postgres -d your_database -f quick_scan_single_batch.sql > results.txt

# 查看结果
cat results.txt | grep "找到匹配"
```

**优点**：
- ✅ 无需安装额外工具
- ✅ 一条命令完成
- ✅ 适合快速测试

**限制**：
- ⚠️ 仅扫描前 100 个表

---

### 方式 2：完整扫描（中大型数据库）

#### 步骤 1：安装依赖（仅需一次）

```bash
pip install psycopg2-binary
```

#### 步骤 2：生成批次脚本

```bash
python generate_scan_batches.py \
    --host localhost \
    --database your_database \
    --user postgres \
    --output-dir ./batches
```

系统会提示输入密码。

#### 步骤 3：执行所有批次

```bash
./run_all_batches.sh -d your_database -u postgres -o ./results
```

或者单独执行某个批次：

```bash
cd batches
psql -U postgres -d your_database -f batch_001_0001_0100.sql > ../results/output_001.txt
```

---

## 📋 常见场景

### 场景 A：只想快速看看有没有匹配的数据

```bash
psql -U postgres -d mydb -f quick_scan_single_batch.sql 2>&1 | grep -A 5 "找到匹配"
```

### 场景 B：完整扫描，保存所有结果

```bash
# 1. 生成批次脚本
python generate_scan_batches.py -d mydb -u postgres --output-dir ./batches

# 2. 批量执行并保存结果
cd batches
for f in batch_*.sql; do
    echo "执行 $f ..."
    psql -U postgres -d mydb -f "$f" > "../results/$(basename $f .sql).txt" 2>&1
done

# 3. 查看所有匹配
cd ../results
grep "找到匹配" *.txt
```

### 场景 C：只扫描特定批次（例如批次 5-10）

```bash
./run_all_batches.sh -d mydb -u postgres --start 5 --end 10
```

### 场景 D：生产环境（谨慎操作）

```bash
# 1. 使用只读账户
python generate_scan_batches.py \
    --host prod-db.example.com \
    --database production \
    --user readonly_user \
    --output-dir ./prod_batches

# 2. 分批次逐个执行（避免一次性占用太多资源）
cd prod_batches
psql -h prod-db.example.com -U readonly_user -d production \
    -f batch_001_0001_0100.sql > ../results/batch_001.txt 2>&1

# 检查结果后再继续下一批
```

---

## 🔧 配置密码（推荐方式）

### 方法 A：使用 .pgpass 文件（推荐）

```bash
# 创建密码文件
cat > ~/.pgpass << 'EOF'
localhost:5432:mydb:postgres:your_password
prod-db:5432:production:readonly_user:prod_password
EOF

# 设置权限
chmod 600 ~/.pgpass

# 现在可以无密码连接
psql -U postgres -d mydb -c "SELECT 1;"
```

### 方法 B：使用环境变量

```bash
# 临时设置（当前会话）
export PGPASSWORD='your_password'
psql -U postgres -d mydb -f quick_scan_single_batch.sql

# 或使用配置文件
cp config.example.env config.env
# 编辑 config.env 填入实际值
source config.env
./run_all_batches.sh
```

---

## 📊 查看结果

### 查看所有匹配的表

```bash
grep "找到匹配" results/*.txt | cut -d: -f2- | sort -u
```

### 统计总匹配行数

```bash
grep "总匹配行数" results/*.txt | awk '{sum += $NF} END {print "总计:", sum}'
```

### 生成 CSV 报告

```bash
# 从输出中提取表格数据
cat results/*.txt | grep -E "^\s+[0-9]+\s+\|" | \
    sed 's/|/,/g' | sed 's/^ *//;s/ *$//' > scan_report.csv
```

### 查找特定表的结果

```bash
grep -r "public.orders" results/
```

---

## ⚡ 性能提示

1. **小数据库（< 100 表）**：直接用 `quick_scan_single_batch.sql`
2. **中等数据库（100-500 表）**：生成批次脚本，顺序执行
3. **大型数据库（> 500 表）**：
   - 使用更小的批次（`--batch-size 50`）
   - 并行执行多个批次
   - 在非高峰期执行

### 并行执行示例

```bash
# 使用 GNU Parallel（需要安装）
cd batches
ls batch_*.sql | parallel -j 4 \
    "psql -U postgres -d mydb -f {} > ../results/{/.}_output.txt"
```

---

## ❓ 故障排查

### 问题：命令未找到

```
bash: psql: command not found
```

**解决**：安装 PostgreSQL 客户端
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# macOS
brew install postgresql

# Windows
# 下载并安装 PostgreSQL，然后添加到 PATH
```

### 问题：连接被拒绝

```
psql: error: connection to server at "localhost", port 5432 failed
```

**解决**：
1. 检查 PostgreSQL 服务是否运行
2. 验证主机名和端口
3. 检查防火墙设置

### 问题：密码认证失败

```
psql: error: FATAL:  password authentication failed
```

**解决**：
1. 使用 `.pgpass` 文件或 `PGPASSWORD` 环境变量
2. 验证用户名和密码
3. 检查 `pg_hba.conf` 配置

### 问题：权限不足

```
ERROR:  permission denied for table xxx
```

**解决**：
```sql
-- 授予查询权限
GRANT SELECT ON ALL TABLES IN SCHEMA public TO your_user;
GRANT USAGE ON SCHEMA public TO your_user;
```

---

## 🎓 进阶技巧

### 自定义搜索值

编辑 `generate_scan_batches.py` 第 57 行：

```python
v_search_values TEXT[] := ARRAY['訂單', '出貨單', '發票'];
```

### 搜索特定 Schema

修改生成脚本中的表过滤条件：

```sql
WHERE schemaname = 'public'  -- 只扫描 public schema
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
```

### 添加进度延迟（减少数据库负载）

在批次脚本的表循环中添加：

```sql
DO $$ BEGIN PERFORM pg_sleep(0.5); END $$;  -- 每个表之间暂停 0.5 秒
```

---

## 📞 需要帮助？

1. 查看完整文档：`README.md`
2. 检查示例脚本：`example_batch_001_001_100.sql`
3. 查看脚本输出的错误信息
4. 验证数据库连接和权限

---

**提示**：首次使用建议在测试环境上运行，确认脚本行为符合预期后再在生产环境使用。
