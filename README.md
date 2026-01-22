# PomodoroAuto

macOS 菜单栏番茄钟应用 - 自动识别工作界面并开始计时。

## 快速开始

### 方式一：直接运行（推荐用于测试）

```bash
swift run
```

### 方式二：构建可执行文件

```bash
swift build
.build/debug/PomodoroAuto
```

### 方式三：构建并安装到 Applications

```bash
swift build

# 创建应用包
mkdir -p ~/Desktop/PomodoroAuto.app/Contents/MacOS
mkdir -p ~/Desktop/PomodoroAuto.app/Contents/Resources

# 复制可执行文件
cp .build/debug/PomodoroAuto ~/Desktop/PomodoroAuto.app/Contents/MacOS/

# 创建 Info.plist
cat > ~/Desktop/PomodoroAuto.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PomodoroAuto</string>
    <key>CFBundleIdentifier</key>
    <string>com.pomodoroauto.app</string>
    <key>CFBundleName</key>
    <string>PomodoroAuto</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

# 复制应用图标
cp ./Assets/Icons/AppIcon.icns ~/Desktop/PomodoroAuto.app/Contents/Resources/AppIcon.icns

# 移动到 Applications 文件夹
mv ~/Desktop/PomodoroAuto.app /Applications/

# 运行
open /Applications/PomodoroAuto.app
```

## 首次使用

### 1. 授权辅助功能权限

首次启动时，应用会请求辅助功能权限：

- **macOS 12+**: 系统设置 → 隐私与安全性 → 辅助功能 → 点击"✕" → 重新打开应用 → 点击"打开"

### 2. 配置设置

点击菜单栏图标 → "Settings"

**基本设置：**
- Work minutes: 25（工作时间，分钟）
- Break minutes: 5（休息时间，分钟）

**自动开始/暂停：**
- 勾选 "Auto start/pause" 开启自动计时
- "Auto-start allowlist"：配置需要自动计时的应用
  - 手动输入 bundle ID（如 `com.apple.Xcode`）
  - 或点击 "Choose..." 按钮选择应用

**全屏规则：**
- 勾选 "Fullscreen non-work" 开启全屏检测
- "Fullscreen work allowlist"：配置全屏时仍视为工作的应用

### 3. 查看统计

点击菜单栏图标 → "Stats"

显示今天的：
- 累计工作时间
- 完成番茄数量

## 功能说明

### 状态机
- **Idle**: 空闲
- **Running**: 计时中
- **Paused**: 暂停
- **Completed**: 完成
- **Resting**: 休息中

### 快捷键
- `Space`: 开始/暂停
- `R`: 重置
- `S`: 打开统计
- `,`: 打开设置
- `Q`: 退出

### 规则说明
1. Safari 全屏始终视为非工作状态
2. 自动开始白名单：仅在白名单中的应用才会自动触发计时
3. 全屏白名单：即使全屏也视为工作的应用

## 构建

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

## 系统要求
- macOS 12.0+
- Xcode 15+ (包含 Swift 工具链)

## 数据存储
- 配置和统计数据存储在 UserDefaults
- 缓存最多保留 1000 条或 24 小时
