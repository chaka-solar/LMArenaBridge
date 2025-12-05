#!/bin/sh

set -e

# 安装 Python 依赖
pip install -r requirements.txt

# 安装 browserforge 数据文件
python -c "from browserforge.fingerprints import Fingerprint; from browserforge.headers import HeaderGenerator; print('Browserforge ready')" || true

# 安装 camoufox 浏览器
python -m camoufox fetch || true

# 或者如果用 playwright
# playwright install --with-deps chromium
