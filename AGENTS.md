# Cap-ZH-Patcher workspace

- Target Windows x64, official Cap `cap-v0.5.9`; exact source and lockfile hashes are in `config/upstream.lock.json`.
- User has explicitly requested full desktop localization and an unpack-and-run Chinese package. Translate the remaining desktop UI and native menus, bundle runtime DLLs/sidecars/assets, source changes and licenses. Do not expand recording diagnostics or overwrite installed Cap. Report remaining untranslated technical/server content and unverified runtime layout honestly.
- Translation source is `upstream/Cap/apps/desktop/src`; native preview build reuses the isolated `tooling/cargo-probe` and embeds the translated frontend output. Preserve original upstream commit/lockfiles and existing English baseline EXEs.
- Use `translations/settings.zh-CN.json` for reviewed source-location mappings, and `scripts/check-localization.cjs` to verify protected command/config/layout tokens. Never translate enum values, routes, shortcuts, template placeholders or user content.
- `upstream/Cap` is a separate upstream Git checkout. Read its AGENTS.md before working there. Keep its original lockfiles and toolchain pin.
- Never overwrite installed Cap, recordings, settings, credentials, original backups, or official update preferences. Do not force-stop Cap.
- Do not change license/payment checks, claim official signatures, or disable security software.
- Do not start dev servers automatically. Before running an experimental desktop build, review data directories, protocol/file registration, and side effects.
- Run `scripts/doctor.ps1` before large dependency downloads or builds. Resolve low disk space first; do not delete unrelated files or relocate the workspace without user approval.
- No global Node/pnpm/Rust-default changes. Use the project pnpm wrapper and the upstream Rust 1.88.0 pin.
- Distinguish environment readiness, successful compilation, and actual recording/export/restore validation. None implies the next.

## Repository hygiene (mandatory)

- This is a source-patch workspace, not an upstream mirror. Git may contain only root project files, `.github`, `.vscode`, public `config/docs/licenses/scripts/translations`, and `tooling/package*.json`.
- Never add nested checkouts, `node_modules`, `target`, `dist`, `output`, `artifacts`, browser snapshots, logs, machine-result JSON, credentials, or private recordings. Never use `git add -f` to defeat these exclusions.
- Preserve local historical notes under ignored `docs/local`; do not let obsolete P0/preview notes drive the current workflow. Do not delete nested `.git` directories to silence a Git UI.
- Before handoff run `node scripts/check-open-source.cjs` and `node scripts/check-repo-hygiene.cjs`. Check `git diff --check` for touched files. Fail if a Git candidate exceeds 2 MiB or the source workspace exceeds 20 MiB; investigate instead of raising limits silently.
- No staging, commits, pushes, tag creation, history rewriting or GitHub releases unless the user explicitly asks. Hygiene work alone does not authorize remote synchronization.

## Release identity and single-version output (mandatory)

- `config/release.json` is the single source for version, locale, platform, revision and build kind. Canonical output is `<version>-<locale>`, currently `0.5.9-zh-CN`. Do not add `r2`, timestamps, `final`, or Chinese suffixes to deliverable filenames.
- `dist` contains exactly one version: `0.5.9-zh-CN/`, `0.5.9-zh-CN.zip`, `0.5.9-zh-CN-source.zip`. The runtime folder contains the matching source archive too. The EXE stays `Cap Chinese.exe`.
- Same-upstream-version changes increment `revision`, not the package filename. Upstream upgrades change version, pinned commit/lock metadata, patch filenames, build inputs and docs together. Never bump version without actually migrating source.
- Run `scripts/package-chinese.ps1 -Replace -Prune` only after source checks/build/startup verification. It builds in ignored staging, verifies before replacing, and verifies the published package again. A same-name previous build is retained in the staging `previous` folder for recovery, not advertised as another release; do not silently delete rollback data.
- `scripts/clean-dist.ps1` previews exact obsolete deliverables; `-Apply` requires a valid current release and deletes only known versioned entries directly under resolved `dist`. Unknown entries or reparse points must block cleanup. Never clean the workspace/upstream/tooling/artifacts roots.
- An old package must not be removed before its verified replacement exists. Preserve original English baseline EXEs and backups outside dist. Report deleted deliverables and recovery limitations.
- Preserve matching source, LICENSE, NOTICE and third-party notices. Public binary distribution still requires the checks in `docs/OPEN-SOURCE.md`; CI success is not legal clearance.

## Iteration workflow

- Follow `docs/WORKFLOW.md`: inspect → modify source → export complete patches → scoped tests → build → actual startup checks → stage/package/verify → prune old dist → hygiene check.
- Do not replace runtime validation with file checks. Do not use computer-use or expand recording diagnostics. Keep account/licensing checks intact, and distinguish existing-login startup from a newly tested login flow.
- Keep the frontend directory relative (never a drive URL) and run `check-packaged-frontend.cjs` plus `check-window-init.cjs` for startup changes.
