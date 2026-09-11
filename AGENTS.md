# Cap-ZH-Patcher workspace

- Target Windows x64, official Cap `cap-v0.5.9`; exact source and lockfile hashes are in `config/upstream.lock.json`.
- Current scope is environment preparation and P0 only. Do not implement full translation or a patch installer without a follow-up request.
- `upstream/Cap` is a separate upstream Git checkout. Read its AGENTS.md before working there. Keep its original lockfiles and toolchain pin.
- Never overwrite installed Cap, recordings, settings, credentials, original backups, or official update preferences. Do not force-stop Cap.
- Do not change license/payment checks, claim official signatures, or disable security software.
- Do not start dev servers automatically. Before running an experimental desktop build, review data directories, protocol/file registration, and side effects.
- Run `scripts/doctor.ps1` before large dependency downloads or builds. Resolve low disk space first; do not delete unrelated files or relocate the workspace without user approval.
- No global Node/pnpm/Rust-default changes. Use the project pnpm wrapper and the upstream Rust 1.88.0 pin.
- Distinguish environment readiness, successful compilation, and actual recording/export/restore validation. None implies the next.
