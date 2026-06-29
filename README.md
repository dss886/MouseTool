# MouseTool

MouseTool 是一个很小的 macOS 菜单栏应用。按住鼠标右键并水平拖动时，它会切换系统的 Space。

## 行为

- 按住鼠标右键向左拖动，切换到右侧 Space。
- 按住鼠标右键向右拖动，切换到左侧 Space。
- 触发 Space 切换后，应用会拦截这次右键事件，避免留下右键菜单。
- 应用只显示在菜单栏，不常驻 Dock。

## 使用条件

需要先启用 macOS 自带的 Space 切换快捷键：

- 系统设置 -> 键盘 -> 键盘快捷键 -> 调度中心
- 启用 `向左移动一个空间`，快捷键修改为 `Control + 1`
- 启用 `向右移动一个空间`，快捷键修改为 `Control + 2`

MouseTool 发送的是 `Control + 1` 和 `Control + 2`，所以系统快捷键需要和这两个组合保持一致。

MouseTool 还需要辅助功能权限：

- 系统设置 -> 隐私与安全性 -> 辅助功能
- 添加或启用 MouseTool

应用首次启动时会请求这个权限，菜单里也提供了打开辅助功能设置页的入口。

## 开发调试

开发调试时，可以用 Xcode 打开 `MouseTool.xcodeproj`，直接运行 `MouseTool` target。也可以在终端里构建 Debug：

```sh
xcodebuild -project MouseTool.xcodeproj -scheme MouseTool -configuration Debug build
```

## Build Release

在项目根目录执行：

```sh
xcodebuild -project MouseTool.xcodeproj -scheme MouseTool -configuration Release build
```

如果想强制清理后重新打包：

```sh
xcodebuild -project MouseTool.xcodeproj -scheme MouseTool -configuration Release clean build
```

Release 构建脚本会在构建结束时复制：

```sh
~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/MouseTool.app
```

到：

```sh
/Applications/MouseTool.app
```

之后可以直接从 Finder 或终端启动：

```sh
open /Applications/MouseTool.app
```

### 可选：生成 Archive

如果只是自己使用，一般不需要 Archive；Release build 已经够用。需要保留一个 `.xcarchive` 时可以执行：

```sh
xcodebuild -project MouseTool.xcodeproj -scheme MouseTool -configuration Release -archivePath build/MouseTool.xcarchive archive
```

如果 `xcodebuild` 提示缺少必要的 Xcode 插件或系统内容，可以先运行：

```sh
xcodebuild -runFirstLaunch
```

## 调整参数

手势参数在 `MouseTool/MouseGestureController.swift` 里：

- `switchThreshold`：触发切换前需要拖动的水平距离。
- `directionLockRatio`：拖动方向需要多接近水平。
