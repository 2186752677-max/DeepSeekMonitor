# DeepSeek Monitor

实时监控 DeepSeek API 用量和余额的 macOS 菜单栏工具。

## 功能

- 📊 菜单栏实时显示 DeepSeek 余额
- 🔄 自动刷新（可设置 1 分钟 ~ 1 小时间隔）
- 📉 追踪 API 消耗金额
- 🔐 API Key 安全存储于本地钥匙串
- 🎯 仅菜单栏运行，无 Dock 图标

## 安装

1. 从 [Releases](../../releases) 下载最新 DMG
2. 双击 DMG，将 `DeepSeekMonitor.app` 拖入 `Applications`
3. 首次打开：右键 app → 打开（绕过 Gatekeeper）
4. 点击菜单栏图标 → 设置 → 输入 [DeepSeek API Key](https://platform.deepseek.com/api_keys)
5. 保存后即刻显示余额

## 系统要求

- macOS 13 (Ventura) 或更新版本
- Apple Silicon (M1/M2/M3/M4/M5) 或 Intel Mac

## 开发

```bash
# 构建
swift build -c release

# 打包 DMG
bash package-dmg.sh
```
