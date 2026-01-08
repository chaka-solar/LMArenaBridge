@echo off
REM ==================================================================================
REM PostgreSQL 批量扫描脚本执行器 (Windows 版本)
REM 功能：自动执行所有批次脚本并收集结果
REM ==================================================================================

setlocal enabledelayedexpansion

REM 配置参数（请根据实际情况修改）
set DB_HOST=localhost
set DB_PORT=5432
set DB_NAME=
set DB_USER=postgres
set OUTPUT_DIR=results

REM 颜色输出（Windows 10+）
set "ESC="

REM 解析命令行参数
:parse_args
if "%~1"=="" goto check_params
if /i "%~1"=="-h" (
    set DB_HOST=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--host" (
    set DB_HOST=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-p" (
    set DB_PORT=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--port" (
    set DB_PORT=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-d" (
    set DB_NAME=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--database" (
    set DB_NAME=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-u" (
    set DB_USER=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--user" (
    set DB_USER=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="-o" (
    set OUTPUT_DIR=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--output" (
    set OUTPUT_DIR=%~2
    shift
    shift
    goto parse_args
)
if /i "%~1"=="--help" (
    goto show_usage
)
echo 错误: 未知选项 %~1
goto show_usage

:show_usage
echo.
echo 使用方式:
echo     %~nx0 [选项]
echo.
echo 选项:
echo     -h, --host HOST         数据库主机 (默认: localhost)
echo     -p, --port PORT         数据库端口 (默认: 5432)
echo     -d, --database DB       数据库名称 (必需)
echo     -u, --user USER         数据库用户 (默认: postgres)
echo     -o, --output DIR        输出目录 (默认: results)
echo     --help                  显示此帮助信息
echo.
echo 环境变量:
echo     PGPASSWORD              数据库密码
echo.
echo 示例:
echo     %~nx0 -h localhost -d mydb -u postgres -o results
echo.
echo     set PGPASSWORD=secret
echo     %~nx0 -d mydb
echo.
exit /b 1

:check_params
if "%DB_NAME%"=="" (
    echo 错误: 必须指定数据库名称
    echo.
    goto show_usage
)

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 检查 psql 是否可用
where psql >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: psql 命令未找到
    echo 请安装 PostgreSQL 客户端工具并添加到 PATH
    exit /b 1
)

echo ==========================================
echo PostgreSQL 批量扫描执行器
echo ==========================================
echo 数据库: %DB_USER%@%DB_HOST%:%DB_PORT%/%DB_NAME%
echo 输出目录: %OUTPUT_DIR%
echo ==========================================
echo.

REM 测试数据库连接
echo 测试数据库连接...
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -c "SELECT 1;" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] 数据库连接失败
    echo 请检查连接参数和 PGPASSWORD 环境变量
    exit /b 1
)
echo [成功] 数据库连接成功
echo.

REM 创建汇总文件
set SUMMARY_FILE=%OUTPUT_DIR%\summary_all_batches.txt
echo PostgreSQL 批量扫描结果汇总 > "%SUMMARY_FILE%"
echo 生成时间: %date% %time% >> "%SUMMARY_FILE%"
echo 数据库: %DB_NAME% >> "%SUMMARY_FILE%"
echo ========================================== >> "%SUMMARY_FILE%"
echo. >> "%SUMMARY_FILE%"

REM 执行所有批次
set TOTAL_BATCHES=0
set SUCCESS=0
set FAILED=0

for %%f in (batch_*.sql) do (
    set /a TOTAL_BATCHES+=1
)

set CURRENT=0

for %%f in (batch_*.sql) do (
    set /a CURRENT+=1
    set BATCH_NAME=%%~nf
    set OUTPUT_FILE=%OUTPUT_DIR%\!BATCH_NAME!_output.txt
    
    echo [!CURRENT!/%TOTAL_BATCHES%] 执行批次: !BATCH_NAME!
    echo   输出文件: !OUTPUT_FILE!
    
    REM 记录开始时间
    set START_TIME=%time%
    
    REM 执行批次脚本
    psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -f "%%f" > "!OUTPUT_FILE!" 2>&1
    
    if !ERRORLEVEL! equ 0 (
        echo   [成功] 完成
        set /a SUCCESS+=1
        
        REM 提取结果并添加到汇总
        echo 批次: !BATCH_NAME! >> "%SUMMARY_FILE%"
        findstr /C:"找到匹配" "!OUTPUT_FILE!" >> "%SUMMARY_FILE%" 2>nul
        echo. >> "%SUMMARY_FILE%"
    ) else (
        echo   [失败] 执行失败
        set /a FAILED+=1
        
        echo 批次: !BATCH_NAME! - 执行失败 >> "%SUMMARY_FILE%"
        echo 请查看: !OUTPUT_FILE! >> "%SUMMARY_FILE%"
        echo. >> "%SUMMARY_FILE%"
    )
    
    echo.
)

REM 显示执行摘要
echo ==========================================
echo 执行完成！
echo ==========================================
echo 总批次数: %TOTAL_BATCHES%
echo 成功: %SUCCESS%
echo 失败: %FAILED%
echo ==========================================
echo.
echo 结果文件：
echo   - 汇总: %SUMMARY_FILE%
echo   - 详细输出: %OUTPUT_DIR%\*_output.txt
echo.
echo 查看包含匹配结果的批次：
echo   findstr /M "找到匹配" %OUTPUT_DIR%\*_output.txt
echo.
echo ==========================================

endlocal
