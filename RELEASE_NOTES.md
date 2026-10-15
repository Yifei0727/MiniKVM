### ✨ MiniKVM v1.0.0 (macOS Apple Silicon Native)

- **原生视频预览 (`AVFoundation`)**：自动发现并优先连接 `USB Video` 采集卡，低延迟硬件加速渲染。
- **全键盘与修饰键实时转发 (`CH9329`)**：支持 `9600` / `115200` 波特率自动探测、6 键无冲、单行状态栏按键回显与 `Cmd ➔ Ctrl` 映射。
- **绕过 macOS 系统快捷键拦截**：支持 `Fn + 顶部数字键 (1~0, -, =)` 映射 `F1~F12`（如 `Fn+Opt+1` 发送 `Alt+F1`、`Fn+Ctrl+Opt+6` 发送 `Ctrl+Alt+F6`），内置修饰键持续锁定与 Linux TTY 切换下拉菜单，并提供右上角 `?` 悬停帮助卡片。
- **鼠标绝对坐标同步**：支持视频画面内按比例（`0 ~ 4095`）左/右键点击、拖拽、移动与滚轮同步。
- **视频与键鼠事件 OSD 同步录制**：支持一键录制 `.mp4` 至系统视频目录（`~/Movies/MiniKVM-yyyy-MM-dd-HH-mm-ss.mp4`），画面右下角实时合成按键与鼠标轨迹字幕，并同步生成同名 `-events.log` 时间轴日志。

#### 📦 安装与运行
下载并解压 `MiniKVM-v1.0.0-macOS-arm64.zip`，双击 `MiniKVM.app`（或在终端执行 `open MiniKVM.app`）即可运行。
