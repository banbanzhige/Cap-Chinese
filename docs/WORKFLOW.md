# 版本迭代与仓库卫生工作流

## 一、只同步源码

Git 保留文档、许可、配置模板、脚本、完整补丁和工具版本清单。上游 checkout、依赖、EXE/DLL、运行包、源码 ZIP、测试截图、日志和机器结果均只留本地。

历史 P0 文档归入 `docs/local`；旧预览配置、旧设置补丁不再作为公共主线。不要删除本地上游仓库或 `.git` 来减少 Git UI 的条目。VS Code 配置已关闭自动发现嵌套仓库；其他客户端仍可能单独展示嵌套仓库，这与根仓库是否忽略它们是两回事。

检查命令（不安装依赖、不启动应用）：

```powershell
node scripts/check-open-source.cjs
node scripts/check-repo-hygiene.cjs
git status --short
git diff --check
```

门禁会拒绝运行产物、私密目录、超 2 MiB 的单文件、超 20 MiB 的源码候选，以及 dist 中的多余版本。不通过时排查原因，不随意放宽限制。`.gitignore` 不影响已跟踪文件；已跟踪历史文件应先保留到本地归档，再提交其移出源码树的变化。不要在未检查暂存内容时运行全量提交。

`.github/workflows/repository-hygiene.yml` 在 push/PR/manual 上只运行轻量检查，不下载 Cap 依赖、不构建 Windows EXE、不自动上传产物、不创建 Release。它会在这些文件提交并推送后生效。

## 二、版本与命名

唯一入口：`config/release.json`。

- 上游版本 `version`：当前 `0.5.9`，必须匹配 upstream.lock.json 的 tag。
- 语言 `locale`：`zh-CN`；平台记录为 `windows-x64`。
- 同上游版本修复/汉化迭代增加 `revision`，文件名不增加 `r2/final/时间戳`。
- 构建类型 `build` 保持诚实，当前是未签名社区 Debug。

唯一对外交付集合：

```text
dist/
  0.5.9-zh-CN/             # 可直接运行的完整目录
  0.5.9-zh-CN.zip          # 同一版的运行压缩包
  0.5.9-zh-CN-source.zip   # 同一版的对应源码
```

这三个条目是同一版本，不是三个发行版。运行目录内也包含对应源码与 release.json。哈希和 revision 区分同名文件的不同构建；旧验证记录不得自动算作新 EXE 的验收。

## 三、一次迭代

1. 检查 Git 状态、磁盘和用户改动；先运行 doctor.ps1。不要修改系统默认工具链。
2. 按固定版本修改前端和隔离原生源码，不翻译内部标识，不改授权/付费逻辑。
3. 导出完整前端/原生补丁，应用到干净的固定提交做 `git apply --check --ignore-space-change` 检查。完整补丁包含历史设置汉化，不叠加旧设置补丁。
4. 执行适用的文案检查、Biome、Rust fmt/check 和构建。启动问题还必须运行页面路径与窗口初始化回归检查。
5. 实际启动新 EXE 验证相关界面并正常退出；不使用 computer-use，不把启动通过宣称为录制/导出全部通过。
6. 确认当前版本元数据后打包：

```powershell
./scripts/package-chinese.ps1 -Replace -Prune
./scripts/verify-chinese-package.ps1
node scripts/check-repo-hygiene.cjs
```

打包器先在 `output/package-staging/<唯一ID>` 生成并校验，成功后再放入 dist；同名旧产物先保留到本次 staging 的 `previous`，失败时可人工恢复。不要将 staging 目录提交 Git；完成验收后可明确选定并清理不再需要的 staging，但不能递归删除 output 根目录来省事。

`-Prune` 只清理 dist 中可识别的其他发行名称，必须在当前包再次校验成功后执行。单独使用时默认预览：

```powershell
./scripts/clean-dist.ps1
./scripts/clean-dist.ps1 -Apply
```

清理不处理未知条目、符号链接/联接点，不修改日常 Cap 或英文基线。删除的旧 dist 包不进入回收站，应提前确认不再需要。

## 四、升级上游

先选择并验证新上游提交，再同步 release.version、upstream.lock.json、补丁文件名、工具/依赖要求、基线与说明。不要只改一个版本号就声称支持新版。当前原生打包器仍依赖本地已验证环境和特定基线；升级时必须审查这些约束。

源码可先公开；对外发布 EXE/ZIP 必须另行完成 [开源发布清单](OPEN-SOURCE.md) 的第三方分发审查。此工作流不会自行 git add/commit/push 或创建远程 Release。
