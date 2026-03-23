# 🛠️ Reparo

一键配置 Linux 开发环境的脚本集合，支持 **Fedora** 和 **Ubuntu**。

自动安装并配置以下工具：

| 工具 | 说明 |
|------|------|
| **Vim** | 编辑器 + 自定义配置 |
| **Neovim** | 现代编辑器 + clangd / tree-sitter |
| **Tmux** | 终端复用器 |
| **Powerline** | 状态栏美化 + gitstatus |
| **GDB** | 调试器 + pygments 语法高亮 |

## 📋 前置要求

- Bash 4.0+
- Git
- sudo 权限（用于安装软件包）
- 支持的发行版：Fedora 或 Ubuntu

## 🚀 快速开始

```bash
git clone https://github.com/haoyouab/Reparo.git
cd Reparo
bash setup
source ~/.bashrc
```

跳过 Neovim（节省时间，不安装 Rust/cargo）：

```bash
bash setup --skip-neovim
```

### 📦 离线模式

如果网络环境无法顺畅访问 GitHub（如 curl 下载缓慢），可以提前下载好安装包，使用 `--offline` 选项跳过网络下载：

```bash
bash setup --offline=/path/to/packages
```

离线目录中需要包含以下文件（从 GitHub Releases 下载）：

| 文件 | 来源 | 说明 |
|------|------|------|
| `nvim-linux-x86_64.tar.gz` | [neovim/neovim](https://github.com/neovim/neovim/releases) | Neovim 二进制（仅 Ubuntu 需要，aarch64 架构则下载对应版本） |
| `clangd-linux-*.zip` | [clangd/clangd](https://github.com/clangd/clangd/releases) | clangd 语言服务器 |

> Fedora 通过 `dnf` 安装 Neovim，因此只需准备 clangd 安装包。

## 🐳 Docker 开发环境

不想修改宿主机？可以在 Docker 容器中使用预配置好的开发环境：

```bash
# 构建 Fedora 开发环境（默认）
bash setup --docker

# 构建 Ubuntu 开发环境
bash setup --docker --ubuntu

# 跳过 Neovim（更快）
bash setup --docker --skip-neovim

# 使用离线安装包构建（避免容器内下载）
bash setup --docker --offline=/path/to/packages
bash setup --docker --ubuntu --offline=/path/to/packages
```

> 容器内用户名和 UID 自动与宿主机当前用户保持一致，挂载目录无权限问题。

### 快速进入容器

构建完成后，使用 `enter` 脚本快速进入容器：

```bash
# 进入 Ubuntu 容器（默认）
bash enter

# 进入 Fedora 容器
bash enter --fedora

# 交互式选择发行版
bash enter -i
```

`enter` 脚本会自动检测容器状态：已运行则直接连接，已停止则启动后连接，镜像不存在则提示构建。

### 手动启动容器

```bash
# 交互式启动
docker run -it reparo-dev-ubuntu

# 挂载宿主机项目目录
docker run -it -v $(pwd):/home/$(whoami)/project:z reparo-dev-ubuntu

# 后台运行，稍后连接
docker run -dit --name my-dev reparo-dev-ubuntu
docker exec -it my-dev bash
```

## 📁 项目结构

```
Reparo/
├── setup                    # 入口脚本，自动检测发行版
├── enter                    # 快速进入 Docker 容器
├── dist/
│   ├── common.sh            # 共享函数库（日志、备份、下载等）
│   ├── Fedora/
│   │   ├── setup.sh         # Fedora 专用安装脚本
│   │   ├── vim/             # Vim 配置文件
│   │   ├── tmux/            # Tmux 配置文件
│   │   ├── powerline/       # Powerline 配置文件
│   │   └── gdb/             # GDB 配置文件
│   └── Ubuntu/
│       ├── setup.sh         # Ubuntu 专用安装脚本
│       └── ...              # 同上
├── docker/
│   ├── build.sh             # Docker 构建编排脚本
│   ├── Dockerfile.fedora    # Fedora 开发环境镜像
│   └── Dockerfile.ubuntu    # Ubuntu 开发环境镜像
├── tests/
│   ├── run_tests.sh         # 单元测试（91 个测试用例）
│   ├── docker-test.sh       # Docker 集成测试运行器
│   ├── verify-setup.sh      # 安装后验证脚本
│   ├── Dockerfile.fedora    # Fedora 测试容器
│   └── Dockerfile.ubuntu    # Ubuntu 测试容器
└── .github/workflows/
    ├── ci.yml               # Lint（shellcheck + shfmt）+ 单元测试
    └── integration.yml      # Docker 集成测试
```

## ✨ 特性

- 🎨 **现代化 UI** — emoji 图标 + ANSI 彩色输出 + box-drawing 分隔符
- 🛡️ **健壮的错误处理** — 任意步骤失败立即中止，明确的错误提示
- 📦 **自动备份** — 覆盖前自动备份已有配置到 `~/.config-backup-<timestamp>/`
- 🏗️ **架构感知** — 自动检测 x86_64 / aarch64 下载对应二进制
- � **离线模式** — `--offline=DIR` 支持离线安装，无需访问 GitHub
- �🔄 **共享函数库** — `dist/common.sh` 消除重复代码
- 🐳 **Docker 开发环境** — 一键构建可直接使用的容器化开发环境
- 🐳 **Docker 测试** — 完整的容器化集成测试

## 🧪 测试

### 单元测试

```bash
bash tests/run_tests.sh
```

### Docker 集成测试

需要安装 Docker：

```bash
# 测试两个发行版
bash tests/docker-test.sh

# 仅测试 Fedora
bash tests/docker-test.sh --fedora

# 仅测试 Ubuntu
bash tests/docker-test.sh --ubuntu

# 跳过 Neovim（更快）
SKIP_NEOVIM=true bash tests/docker-test.sh
```

### GitHub Actions CI

- **Lint** — 每次 push / PR 自动运行 shellcheck、shfmt 检查和单元测试
- **Integration** — 手动触发或 push 到 main 时运行 Docker 集成测试

## 📄 License

MIT
