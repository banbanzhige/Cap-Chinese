# 中文版对应源码与重建

本目录以官方 Cap `cap-v0.5.9`、提交 `c6b83804d2e9fa8757b75268e573b8ff113141bb` 为基底，叠加前端汉化及原生窗口/托盘/通知中文文案。

原生调整还包括：独立日志和 CLI 配置/凭据/录屏目录；Windows Debug 主程序不打开控制台；Cargo.lock 的 Cap 自身版本 0.5.8 修正为 0.5.9（所有依赖版本保持不变）。没有改变许可证验证、付费判断或服务器地址。

`zh-build/tauri.zh.json` 配置独立名称、标识、协议，禁止生成安装器及官方更新包。`zh-build/translations` 记录汉化清单；`zh-build/workspace-scripts` 保存本地构建/验证脚本作为审计材料，其中部分脚本面向原双工作树布局，不能在这里直接执行。

## 重建环境

Windows x64；Node 24.15.0（上游要求 >=20）；pnpm 10.5.2；Rust 1.88.0；Visual Studio Build Tools 2022 17.14 的 C++ 工具、LLVM/Clang、CMake/Ninja；WebView2。首次依赖准备需要联网。

在 x64 VS Developer PowerShell 中，进入解压后的源码根目录：

```powershell
pnpm install --frozen-lockfile
Copy-Item zh-build/desktop.env.example .env
pnpm cap-setup
pnpm --filter @cap/desktop build:sidecar
pnpm build --filter @cap/desktop
$capZhConfig = Join-Path (Get-Location) 'zh-build/tauri.zh.json'
pnpm --filter @cap/desktop exec tauri build --debug --no-bundle --config $capZhConfig -- --locked
```

如果只安装 Build Tools，上游 `cap-setup` 的 LLVM 检测可能漏掉安装路径；在当前终端设置实际 `LIBCLANG_PATH`，并核对生成的 `.cargo/config.toml`。不要改默认 Rust 工具链或关闭系统安全功能。

构建使用上游 setup.js 固定的 FFmpeg 7.1 和 ONNX Runtime 1.24.2；缓存不在源码包中，脚本会下载。最终 EXE 位于 `target/debug/Cap Chinese.exe`，运行还需要同目录 sidecar、DLL、assets 和 WebView2。开发环境差异与工具链元数据可能使重建的二进制哈希不同。

本源码包不含私人 `.env`、账号、录屏、node_modules 或 target。`desktop.env.example` 仅为公开默认配置。官方源文件许可证及版权声明保留。

R2 修正：frontendDist 必须保持相对目录；不要改为 `F:/...` 等带盘符路径，Tauri 会优先将其反序列化为 URL 而不是嵌入目录。窗口背景初始化现在等待 documentElement 存在。回归检查位于 zh-build/workspace-scripts/check-packaged-frontend.cjs 和 check-window-init.cjs（原双工作树审计布局）。
