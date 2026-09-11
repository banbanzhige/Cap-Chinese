# Cap-ZH-Patcher 工作环境

为 Windows x64 / Cap 0.5.9 准备的隔离 P0 工作区。当前只准备开发环境，没有汉化已安装的 Cap，没有生成可用补丁。

## 当前状态（2026-09-11）

- 官方源码已下载至 `upstream/Cap`，固定 tag `cap-v0.5.9`、提交 `c6b83804d2e9fa8757b75268e573b8ff113141bb`。保持原始源码不变，未创建提交或发布远程仓库。
- Node 24.15.0 满足上游 Node >=20 要求；实际依赖安装/构建兼容性尚未验证。
- 项目专用 pnpm 10.5.2 已安装并验证；安装使用 `--ignore-scripts`，未修改全局包管理器。
- 已检测 VS Build Tools 17.14、MSVC 14.44、CMake、Ninja、Vcpkg、WebView2。
- 缺少上游脚本指定路径的 LLVM `libclang.dll`；需在 Visual Studio Installer 中补齐 C++ Clang tools for Windows。
- 现有 Rust stable 为 1.94.1，但仓库固定 1.88.0，后续并存安装，不修改系统默认工具链。
- F 盘仅约 5.4 GiB 空闲，暂不安装完整 JS/Rust/FFmpeg/ONNX 依赖，不启动构建。脚本以 50 GiB 作为本项目的保守空间检查阈值，不代表上游公布的最低需求；最终占用尚未实测。
- 尚未执行桌面启动、录制、导出、还原验收。
- 已验证：PowerShell 脚本语法、JSON 解析、pnpm 版本、x64 开发终端中的 CMake/Ninja/Vcpkg、上游工作树干净及锁文件哈希。

## 目录与入口

| 路径 | 用途 |
| --- | --- |
| `upstream/Cap` | 独立的官方 Git checkout；源码工作在此进行 |
| `config/upstream.lock.json` | 上游提交、工具版本和两个依赖锁文件的 SHA-256 |
| `tooling` | 工作区专用 pnpm 10.5.2，不安装到全局 |
| `scripts/doctor.ps1` | 只读环境检查，不自动下载或运行构建 |
| `scripts/enter-dev.ps1` | 初始化当前 PowerShell 的 x64 C++ 工具路径 |
| `scripts/pnpm.ps1` | 自动进入上游目录并调用本地 pnpm |
| `docs/P0.md` | 本轮范围、下一阶段验收与安全边界 |

从本工作区根目录执行：

```powershell
./scripts/doctor.ps1
./scripts/pnpm.ps1 --version
```

可用 `./scripts/doctor.ps1 -RequireBuildReady` 在存在待办时返回非零退出码。检查通过只代表初步条件和文件存在，不代表编译或功能验收通过。

## 空间问题解决后的准备顺序

优先在用户确认后，将整个工作区复制到 D/E 盘的短路径，核对源码和锁文件后再继续；不要擅自删除 F 盘原目录。上游脚本在多个位置硬编码 `target`，不能仅设置 `CARGO_TARGET_DIR` 就假设完成迁移。

1. 通过 Visual Studio Installer 给现有 Build Tools 补齐 C++ Clang tools for Windows，确认 `VC/Tools/LLVM/x64/bin/libclang.dll` 存在；安装器可能要求管理员权限。
2. 并存安装固定 Rust：`rustup toolchain install 1.88.0 --profile minimal --component rustfmt --component clippy`。不执行 `rustup default`。
3. 如果本地 pnpm 尚未安装，执行 `npm.cmd ci --prefix tooling --cache tooling/.npm-cache --ignore-scripts --no-audit --no-fund`。
4. 初始化当前终端：`. ./scripts/enter-dev.ps1`。只影响当前进程；关闭终端即可丢弃环境变量变更。
5. `./scripts/pnpm.ps1 install --frozen-lockfile`：首次安装按上游完整 workspace 方式验证，可能下载大量依赖；不更新锁文件，也不安装网页数据库服务。
6. `./scripts/pnpm.ps1 env-setup`：仅选择 Desktop；服务地址按上游默认 `https://cap.so`，不是 Cap 团队成员则跳过 bypass secret。这个步骤只生成配置，不需要账号密钥；不启动云服务或 Docker。
7. `./scripts/pnpm.ps1 cap-setup`：执行上游原生依赖准备，下载 FFmpeg 7.1、ONNX Runtime 1.24.2，并生成 `.cargo/config.toml`。
8. 再次执行 `./scripts/doctor.ps1 -RequireBuildReady`；随后进入 P0 未修改源码的构建验证。

以上重型准备命令尚未执行；需要正常网络访问 GitHub、npm、Rust 分发服务。不要使用绕过 TLS、关闭杀毒软件或更改全局执行策略的方式处理下载/运行失败。

## 构建与启动边界

上游构建入口是 `./scripts/pnpm.ps1 tauri:build`，会先构建 sidecar，再构建前端和 Tauri。上游 `dev:desktop` 也会触发原生准备及 sidecar 编译，不是轻量预览。

本轮未运行这些命令。P0 首次构建前需确认不生成官方身份的安装器/更新产物；首选无安装器的隔离测试产物。启动前检查开发版数据目录、`cap-desktop` 协议及 `.cap` 关联注册行为，不能仅凭 `so.cap.desktop.dev` 就承诺完全隔离。不要将开发版 EXE 直接覆盖到官方安装目录。

## 依据

- [官方固定版本源码](https://github.com/CapSoftware/Cap/tree/cap-v0.5.9)，实际已下载并核对本地 `CONTRIBUTING.md`、`rust-toolchain.toml`、`package.json`、`scripts/setup.js`、桌面 prepare/build 脚本。
- [旧译文参考项目](https://github.com/PingGai/Cap-Chinese)，仅记录来源，尚未导入译文；复用前核对来源和许可证。
- 立项任务：`codex://threads/01a08f53-ac5f-7a50-943d-4353200c6c9f`。
