@echo off
chcp 65001 >nul
echo ========================================
echo   XRShowMaster 本地构建脚本
echo ========================================
echo.

:: 检查 Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未找到 Node.js
    echo 请先安装 Node.js 20+: https://nodejs.org/
    pause
    exit /b 1
)

:: 检查 Rust
where cargo >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未找到 Rust
    echo 请先安装 Rust: https://rustup.rs/
    pause
    exit /b 1
)

echo [1/4] 安装依赖...
call npm install
if %errorlevel% neq 0 (
    echo [错误] npm install 失败
    pause
    exit /b 1
)

echo [2/4] 构建前端...
call npm run build
if %errorlevel% neq 0 (
    echo [错误] 前端构建失败
    pause
    exit /b 1
)

echo [3/4] 构建 Tauri 应用 (需要10-30分钟)...
call npm run tauri build
if %errorlevel% neq 0 (
    echo [错误] Tauri 构建失败
    pause
    exit /b 1
)

echo [4/4] 完成!
echo.
echo EXE 文件位于: src-tauri/target/release/XRShowMaster.exe
echo.
pause
