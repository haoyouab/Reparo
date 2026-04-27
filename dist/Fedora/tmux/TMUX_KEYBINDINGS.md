# Tmux 快捷键与使用指南

> Prefix 键为 `Ctrl-a`（以下表格中 `<prefix>` 均指 `Ctrl-a`）
>
> 基于 [gpakosz/.tmux](https://github.com/gpakosz/.tmux) 配置，含 tmux-resurrect / tmux-continuum 插件。

---

## 通用操作

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `r` | 重新加载 tmux 配置 |
| `<prefix>` + `e` | 在新窗口中编辑 `~/.tmux.conf.local` 并自动 reload |
| `<prefix>` + `t` | 显示时钟（24 小时制） |
| `<prefix>` + `?` | 显示所有快捷键（内置） |
| `<prefix>` + `:` | 进入 tmux 命令行 |
| `Ctrl-l` | 清除屏幕和滚动历史（无需 prefix） |

## Session 管理

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `Ctrl-c` | 创建新 session |
| `<prefix>` + `Ctrl-f` | 按名称查找并切换 session |
| `<prefix>` + `$` | 重命名当前 session（内置） |
| `<prefix>` + `s` | 列出所有 session 并切换（内置） |
| `<prefix>` + `d` | 断开当前 session（内置） |

## 窗口（Window）管理

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `c` | 创建新窗口（内置） |
| `<prefix>` + `&` | 关闭当前窗口（内置，需确认） |
| `<prefix>` + `,` | 重命名当前窗口（内置） |
| `<prefix>` + `Ctrl-h` | 切换到上一个窗口（可重复） |
| `<prefix>` + `Ctrl-l` | 切换到下一个窗口（可重复） |
| `<prefix>` + `Tab` | 切换到上次活跃的窗口 |
| `<prefix>` + `0`-`9` | 按编号切换窗口（内置，编号从 1 开始） |
| `<prefix>` + `w` | 从列表中选择窗口（内置） |

## 窗格（Pane）管理

### 创建与关闭

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `-` | 水平分割（上下） |
| `<prefix>` + `_` | 垂直分割（左右） |
| `<prefix>` + `x` | 关闭当前窗格（内置，需确认） |

### 导航

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `h` | 移动到左侧窗格（可重复） |
| `<prefix>` + `j` | 移动到下方窗格（可重复） |
| `<prefix>` + `k` | 移动到上方窗格（可重复） |
| `<prefix>` + `l` | 移动到右侧窗格（可重复） |
| `<prefix>` + `q` | 显示窗格编号并按编号跳转（内置） |

### 调整大小

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `H` | 向左扩展 2 格（可重复） |
| `<prefix>` + `J` | 向下扩展 2 格（可重复） |
| `<prefix>` + `K` | 向上扩展 2 格（可重复） |
| `<prefix>` + `L` | 向右扩展 2 格（可重复） |
| `<prefix>` + `z` | 最大化/还原当前窗格（内置） |

### 交换与布局

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `>` | 将当前窗格与下一个交换 |
| `<prefix>` + `<` | 将当前窗格与上一个交换 |
| `<prefix>` + `+` | 最大化当前窗格（自定义实现） |
| `<prefix>` + `Space` | 循环切换窗格布局（内置） |

## 复制模式（Vi 风格）

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `Enter` | 进入复制模式 |
| `v` | 开始选择（复制模式中） |
| `Ctrl-v` | 切换矩形选择（复制模式中） |
| `y` | 复制选中内容并退出复制模式 |
| `Escape` | 退出复制模式 |
| `H` | 跳到行首（复制模式中） |
| `L` | 跳到行尾（复制模式中） |

## 粘贴缓冲区

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `b` | 列出所有粘贴缓冲区 |
| `<prefix>` + `p` | 从最新缓冲区粘贴 |
| `<prefix>` + `P` | 选择缓冲区并粘贴 |
| `<prefix>` + `y` | 复制 tmux 缓冲区到系统剪贴板（自动检测 pbcopy/xsel/xclip） |

## 其他工具

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `m` | 开关鼠标模式 |
| `<prefix>` + `U` | urlview — 提取并打开当前窗格中的 URL |
| `<prefix>` + `F` | fpp (Facebook PathPicker) — 提取并选择当前窗格中的文件路径 |
| `<prefix>` + `g` | 加载 debug 布局（`~/.tmux.conf.debug`，用于 GDB dashboard 多窗格调试） |

## TPM 插件管理

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `I`（大写） | 安装 tmux.conf.local 中声明的新插件 |
| `<prefix>` + `U`（大写） | 更新所有已安装插件 |
| `<prefix>` + `Alt` + `u` | 卸载已从配置中移除的插件 |

## tmux-resurrect / tmux-continuum

| 快捷键 | 说明 |
|--------|------|
| `<prefix>` + `Ctrl-s` | 手动保存 tmux 会话（窗口、窗格、运行中的程序） |
| `<prefix>` + `Ctrl-r` | 手动恢复上次保存的 tmux 会话 |
| *自动* | tmux-continuum 每 15 分钟自动保存，tmux 启动时自动恢复 |

### 恢复内容说明

| 恢复项 | 支持情况 |
|--------|----------|
| 窗口和窗格布局 | 自动恢复 |
| 窗格工作目录 | 自动恢复 |
| 窗格内运行的程序 | 自动恢复（配置 `@resurrect-processes ':all:'`） |
| 窗格内终端输出 | 自动恢复（配置 `@resurrect-capture-pane-contents 'on'`） |
| Vim/Neovim 多 buffer 和窗口分割 | 需要 nvim 退出前保存 `Session.vim`（已在 autocmds.lua 中配置） |

## Debug 布局（`<prefix>` + `g`）

加载 `~/.tmux.conf.debug` 后创建多窗格调试布局，用于 GDB dashboard 输出到独立窗格：

```
+--------+------+------------+
|  Stack 25%    |            |
+--------+------+ Source 65% |
|        |      |            |
| Vars   | Exp  +------------+
|  60%   | 40%  | GDB Input  |
|  55%h  |      |    35%     |
+--------+------+            |
| Asm   20%     |            |
+---------------+------------+
      50%            50%
```

窗格编号：1=Stack, 2=Variables, 3=Assembly, 4=Expressions, 5=Source, 6=GDB Input

使用方式：按 `<prefix>` + `g` 后，在 GDB Input 窗格中运行 `gdb ./program` 或 `sgdb qemu-system-x86_64`。

Watch 变量快捷命令：`ew <expr>` 添加监视，`eu <expr>` 移除，`ec` 清空全部。
Variables 和 Stack 模块支持翻页：`dashboard variables scroll 10` / `dashboard stack scroll 5`（负数向上）。

## 配置选项参考

| 选项 | 当前值 | 说明 |
|------|--------|------|
| Prefix 键 | `Ctrl-a` | GNU Screen 风格 |
| 历史行数 | 20000 | scrollback buffer |
| 窗口编号起始 | 1 | 非默认的 0 |
| 新窗口保留路径 | 否 | 新窗口在默认目录打开 |
| 新窗格保留路径 | 是 | 分割窗格继承当前目录 |
| 状态栏位置 | 底部（默认） | 可改为 top |
| 鼠标模式 | 关闭（默认） | `<prefix>` + `m` 开关 |
| 时钟样式 | 24 小时制 | `<prefix>` + `t` 查看 |
| Powerline 分隔符 | 已启用 | 需要 Powerline 字体 |
