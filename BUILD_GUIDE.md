# XRShowMaster 构建指南

## ⚠️ 服务器限制说明

由于编译服务器是 Linux 系统，无法直接生成 Windows EXE。有两种解决方案：

---

## 方案一：本地 Windows 构建（推荐）

### 步骤 1：准备 Windows 电脑

1. 安装 **Node.js 20+**
   - 下载: https://nodejs.org/
   - 建议安装 LTS 版本

2. 安装 **Rust**
   - 下载: https://rustup.rs/
   - 运行安装程序，选择默认选项

3. 安装 **Visual Studio Build Tools** (用于编译 Tauri)
   - 下载: https://visualstudio.microsoft.com/visual-cpp-build-tools/
   - 选择 "C++ build tools"

### 步骤 2：获取代码

从服务器下载项目到本地：

```bash
# 在服务器上打包
cd /root/.openclaw/workspace/xrshowmaster
tar -czvf xrshowmaster.tar.gz . --exclude=node_modules --exclude=src-tauri/target
```

或者使用 scp 复制：

```bash
# 在本地 Windows 命令行
scp root@你的服务器IP:/root/.openclaw/workspace/xrshowmaster .
```

### 步骤 3：构建 EXE

```bash
# 进入项目目录
cd xrshowmaster

# 安装依赖
npm install

# 构建 EXE (首次可能需要 20-40 分钟)
npm run tauri build
```

EXE 位置: `src-tauri/target/release/XRShowMaster.exe`

---

## 方案二：GitHub Actions 自动构建

### 步骤 1：推送代码到 GitHub

1. 创建 GitHub 仓库: https://github.com/new
2. 推送代码:

```bash
cd /root/.openclaw/workspace/xrshowmaster
git remote add origin https://github.com/你的用户名/xrshowmaster.git
git push -u origin master
```

### 步骤 2：创建 Release 触发构建

1. 在 GitHub 仓库页面点击 "Create a new release"
2. Tag version 填写: `v0.1.0`
3. 点击 "Publish release"

### 步骤 3：下载 EXE

构建完成后（10-15分钟），在 Release 页面下载 EXE。

---

## 当前已实现功能

| 功能 | 状态 |
|------|------|
| 摄像头采集 | ✅ |
| 绿幕抠像 | ✅ |
| 3D场景（赛博修仙） | ✅ |
| 背景切换 | ✅ |
| 本地录制 | ✅ |

## 待实现功能

- [ ] 推流到 B站/抖音
- [ ] 3D模型道具
- [ ] 虚拟屏幕（PPT投屏）
- [ ] 多机位切换

---

## 问题排查

### 摄像头无法启动
- 确保没有其他程序占用摄像头
- 检查浏览器权限设置

### 绿幕效果不好
- 使用纯绿色背景
- 确保光线充足均匀
- 背景与人物颜色对比明显

### 构建失败
- 确保网络畅通（需要下载依赖）
- 检查磁盘空间（需要 5GB+）
