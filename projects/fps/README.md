# 第一人称射击

《Godot 4.7 互动教程》配套示例工程。

## 打开方式
1. 安装 Godot 4.7.2（标准版即可，不需要 .NET 版）：https://godotengine.org/download
2. 打开 Godot → 项目管理器 →「导入」→ 选择本文件夹里的 `project.godot`
3. 按 F5 运行

## 操作
先点击画面锁定鼠标（Esc 释放）。鼠标转视角，左键开火，WASD 移动，Shift 冲刺，空格跳，Ctrl/C 蹲，R 换弹，1/2/Q 切枪

## 参数
所有可调参数都在 `params.json` 里登记，对应脚本里的 `@export` 变量，可以直接在检查器里改。
如果你是从网页上「下载当前参数」得到的工程，`params.json` 里带 `"value"` 的项会在启动时覆盖默认值
（由自动加载脚本 `tuning.gd` 负责）。想恢复默认，删掉那些 `"value"` 即可。

## 许可
示例代码可自由使用。中文字体为 Noto Sans SC 子集，SIL Open Font License（见 fonts/OFL.txt）。
