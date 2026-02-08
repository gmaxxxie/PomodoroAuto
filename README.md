# PomodoroAuto

macOS 菜单栏番茄钟应用：自动识别前台应用并自动开始/暂停计时，让专注更自然。

## Release 下载

- 最新版本：[`v0.1.2`](https://github.com/gmaxxxie/PomodoroAuto/releases/tag/v0.1.2)
- 最新发布页：[`Releases`](https://github.com/gmaxxxie/PomodoroAuto/releases/latest)
- 下载后推荐使用 `.dmg` 安装；也可下载 `.zip` 直接运行 `PomodoroAuto.app`

## 功能亮点

- 自动开始/暂停：根据前台应用自动触发计时
- 全屏规则：全屏应用可按规则视为工作或非工作
- 统计面板：查看今日工作时长和番茄数
- 菜单栏快捷操作：开始/暂停、重置、设置、统计一键可达
- 多语言支持：支持跟随系统语言

## 使用截图

![菜单栏（空闲状态）](pic/截屏2026-02-08%2021.02.48.png)
![菜单栏（计时中）](pic/截屏2026-02-08%2021.03.08.png)
![设置面板](pic/截屏2026-02-08%2021.03.37.png)

## 安装与启动

### 方式一：使用 Release（推荐）

1. 打开 [`Releases`](https://github.com/gmaxxxie/PomodoroAuto/releases/latest)
2. 下载 `PomodoroAuto-<tag>-macOS.dmg`（或 `.zip`）
3. 拖入 Applications 后启动应用

### 方式二：本地构建

```bash
# Debug 构建
swift build

# 运行
.build/debug/PomodoroAuto
```

也可使用项目脚本：

```bash
./install.sh
# 或
./run.sh
```

## 首次使用（必做）

### 1) 授权辅助功能权限

首次启动时，应用会请求辅助功能权限（用于检测前台应用，不需要屏幕录制权限）。

- macOS 12+：系统设置 → 隐私与安全性 → 辅助功能
- 如果曾授权过旧版本，先移除旧授权再重新打开应用

### 2) 设置计时与规则

点击菜单栏图标 → `Settings`：

- `Work minutes`：每个工作番茄时长（默认 25）
- `Break minutes`：每次休息时长（默认 5）
- `Auto start/pause`：是否根据前台应用自动开始/暂停
- `Auto-start allowlist`：允许触发自动计时的应用（Bundle ID，逗号分隔）
- `Fullscreen non-work`：全屏状态默认按非工作处理
- `Fullscreen work allowlist`：全屏下仍按工作处理的应用（Bundle ID，逗号分隔）

### 3) 日常使用流程

1. 打开在白名单中的工作应用（如 `com.apple.dt.Xcode`）
2. 计时自动开始；切换到非工作应用会自动暂停
3. 需要手动控制时，可在菜单栏点击 `Start/Pause` 与 `Reset`
4. 随时在 `Stats` 查看今日累计数据

## 快捷键

- `Space`：开始/暂停
- `R`：重置
- `S`：打开统计
- `,`：打开设置
- `Q`：退出

## 规则说明

1. Safari 全屏始终视为非工作状态
2. 自动开始白名单外的应用不会触发自动计时
3. 全屏工作白名单中的应用在全屏时仍按工作处理

## 常见问题

### 自动计时没有触发

- 检查是否已授予辅助功能权限
- 检查 `Auto start/pause` 是否启用
- 检查当前应用 Bundle ID 是否在 `Auto-start allowlist`

### 如何获取应用 Bundle ID

可在终端执行（示例）：

```bash
osascript -e 'id of app "Xcode"'
```

## 开发与发布

### 本地开发

```bash
# Debug 构建
swift build

# Release 构建
swift build --configuration release

# 运行测试
swift test

# 清理构建
swift package clean
```

### 自动发布到 GitHub Release

仓库已配置工作流：`/.github/workflows/release.yml`

1. 打标签并推送：

```bash
git tag v0.1.3
git push origin v0.1.3
```

2. 工作流自动生成并上传：

- `PomodoroAuto-<tag>-macOS.zip`
- `PomodoroAuto-<tag>-macOS.dmg`

## 系统要求

- macOS 12.0+
- Xcode 15+（源码构建时）

## 数据存储

- 配置和统计数据存储在 `UserDefaults`
- 历史缓存最多保留 1000 条或 24 小时
