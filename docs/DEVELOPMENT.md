# 开发与补丁说明

## 仓库形态

本仓库存储中文适配工作区，而非上游完整源码。`upstream/Cap` 与 `tooling/cargo-probe` 是维护者本地的两个 checkout，不会随 Git 克隆而出现。

- `translations/desktop-0.5.9.patch`：完整前端/共享界面改动，已包含第一批设置汉化。
- `translations/native-0.5.9.patch`：原生菜单、标题、通知、配置隔离及窗口初始化修复；包括 Cargo.lock 自身版本 0.5.8 → 0.5.9 的一行修正，依赖版本不升级。
- `translations/settings-0.5.9.patch`：历史设置补丁，**不要和完整前端补丁叠加**。
- `config/tauri.zh-source.json`：供单源码目录构建使用的便携配置。
- `config/tauri.zh-package.json`：供维护者本地双目录布局使用，不能与上一份配置混淆。

两个完整补丁的基底均为官方 `cap-v0.5.9`、提交 `c6b83804d2e9fa8757b75268e573b8ff113141bb`。不得直接应用到其他版本。

## 在新目录准备合并后的完整源码

以下为 PowerShell 命令，从本仓库根目录执行。使用新建的 `work/Cap`；如该目录已有内容，先检查，**不要覆盖或清空它**。

```powershell
git clone --branch cap-v0.5.9 --single-branch https://github.com/CapSoftware/Cap.git work/Cap
git -C work/Cap rev-parse HEAD
```

确认输出等于上述固定提交。然后：

```powershell
$capFrontendPatch = Join-Path (Get-Location) 'translations/desktop-0.5.9.patch'
$capNativePatch = Join-Path (Get-Location) 'translations/native-0.5.9.patch'
git -C work/Cap apply --check --ignore-space-change $capFrontendPatch $capNativePatch
# 只在 --check 成功后应用。
git -C work/Cap apply --ignore-space-change $capFrontendPatch $capNativePatch
Copy-Item config/tauri.zh-source.json work/Cap/apps/desktop/src-tauri/tauri.zh.conf.json
Copy-Item config/desktop.env.example work/Cap/.env
```

`.env` 模板只有公开默认配置，不含账号密钥。不要将个人 `.env`、store 或录屏复制到准备公开的源码目录。两个 checkout 里的生成型 `tauri.ts`、`.d.ts` 等文件不应手改。

上游部分 Rust 文件保留 CRLF，补丁上下文会遇到行尾差异，所以使用 `--ignore-space-change` 匹配上下文；这不意味着可以忽略版本不一致。已在固定提交的全新源码副本验证补丁应用，必须仍先执行 `--check`。

## 构建环境

现有 R2 的本地验证环境：Windows x64、Node 24.15.0、pnpm 10.5.2、Rust 1.88.0、Visual Studio Build Tools 2022 17.14（C++、LLVM/Clang、CMake/Ninja）、WebView2。上游原生 setup 脚本使用 FFmpeg 7.1、ONNX Runtime 1.24.2。网络和足够磁盘空间也是必要条件。

保留上游工具链 pin，不更改系统默认 Rust。pnpm 可通过本仓库 `tooling/package-lock.json` 安装在本地，不要求改全局包管理器。

在 x64 VS Developer PowerShell 中，从本仓库根目录执行：

```powershell
npm.cmd ci --prefix tooling --cache tooling/.npm-cache --ignore-scripts --no-audit --no-fund
$capPnpm = Join-Path (Get-Location) 'tooling/node_modules/pnpm/bin/pnpm.cjs'
Push-Location work/Cap
try {
    & node $capPnpm install --frozen-lockfile
    & node $capPnpm cap-setup
    & node $capPnpm --filter @cap/desktop build:sidecar
    & node $capPnpm build --filter @cap/desktop
    $capConfig = Join-Path (Get-Location) 'apps/desktop/src-tauri/tauri.zh.conf.json'
    & node $capPnpm --filter @cap/desktop exec tauri build --debug --no-bundle --config $capConfig -- --locked
} finally {
    Pop-Location
}
```

每一步都要检查退出码，发生错误即停止，不要继续打包。这些是根据现有构建链整理的新目录指引，不宣称已在一台空白机器上完整重建验收。

只安装 Build Tools 的机器上，上游 LLVM 检测可能漏掉安装路径；核对 `.cargo/config.toml` 和当前进程 `LIBCLANG_PATH`。不要关闭安全软件、跳过 TLS 或改全局执行策略解决环境问题。

## 页面路径与打包注意事项

`frontendDist` 保持 `../.output/public` 这类相对目录。**不要用 `F:/...`、`C:/...` 或 `file://...`**：Tauri 可能把带 scheme 的字符串解释成 URL，导致前端没有嵌入 EXE。`--config` 文件自身可以使用绝对路径，这和配置内的 frontendDist 不同。

`target/debug/Cap Chinese.exe` 运行时还需要对应 sidecar、DLL、assets 和 WebView2，不能只发 EXE。镜像中的素材和依赖许可需要单独核对，见 [发布清单](OPEN-SOURCE.md)。

维护者本地 `scripts/package-chinese.ps1` 有特定双工作树、CLI 暂存文件和英文基线哈希保护，它**不是新克隆后可以直接调用的通用打包器**。不要为让它通过而随意去掉备份校验。重新分发时应先完成对应源码和第三方许可检查。

## 现有工作区的检查

以下命令针对维护者既有双工作树布局：

```powershell
node scripts/check-localization.cjs
node scripts/check-desktop-l10n.cjs
node scripts/check-packaged-frontend.cjs
node scripts/check-window-init.cjs
```

代码与静态包检查不能替代实际启动：至少检查首次启动/已登录主界面、窗口切换、资源加载、页面脚本错误和正常退出。录制/导出要单独验收，不与启动通过混为一谈。
