# XRShowMaster 🎭

> 虚拟演播室 - 赛博修仙版

一款面向小白的虚拟演播室软件，集摄像头采集、绿幕抠像、3D场景渲染、本地录制于一体。

## ✨ 功能特性

- 📹 **摄像头采集** - 支持实时摄像头画面输入
- 🎨 **绿幕抠像** - 智能去除绿色/蓝色背景
- 🌆 **3D场景** - 赛博修仙风格虚拟背景
- 📱 **多背景切换** - 渐变/霓虹/仙山等多种风格
- ⏺ **本地录制** - 一键录制合成画面
- 🎬 **多机位模拟** - 预留扩展接口

## 🚀 快速开始

### 下载 EXE

前往 [Releases](https://github.com/your-repo/xrshowmaster/releases) 下载最新版本。

### 运行软件

1. 双击 `XRShowMaster.exe`
2. 点击"启动摄像头"
3. 站在绿幕前开始录制

## 🛠️ 开发

### 环境要求

- Node.js 20+
- Rust 1.70+
- Windows 10+

### 本地开发

```bash
# 安装依赖
npm install

# 启动开发模式
npm run tauri dev
```

### 构建 EXE

```bash
npm run tauri build
```

## 📋 技术栈

- **前端框架**: Vue 3 + TypeScript
- **桌面框架**: Tauri 2.0
- **3D渲染**: Three.js
- **抠像算法**: 颜色键控 (Chroma Key)

## 📄 许可证

MIT License
