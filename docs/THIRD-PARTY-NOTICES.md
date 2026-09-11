# Third-party components

Repository scope: this Git repository distributes source patches, translation mappings, scripts and documentation. Runtime DLLs and assets below describe the existing local test package; they are not included by a normal Git clone. This inventory is not a completed binary-redistribution clearance. See [publication checklist](OPEN-SOURCE.md) and [license scope](LICENSING.md).

- Cap 0.5.9: Cap Software, Inc. and contributors. Main source is AGPLv3; designated cap-camera*/scap-* crate families use MIT. Original notices are preserved in this repository's licenses/Cap-LICENSE and licenses/Cap-MIT-LICENSE. A binary release must include matching modified application source under an applicable source-delivery arrangement.
- Translation reference: PingGai/Cap-Chinese, commit 02f072d968274b09015554a047d47e05ddff74a8. Original license retained in licenses/Cap-Chinese-LICENSE.
- FFmpeg 7.1 shared full build by Gyan: GPL v3. Binary source: https://github.com/GyanD/codexffmpeg/releases/tag/7.1 . FFmpeg source revision identified by the distributor: https://github.com/FFmpeg/FFmpeg/commit/b08d7969c5 . See licenses/ffmpeg/LICENSE and README.txt for build configuration and upstream source information, including third-party components enabled in this build. FFmpeg DLLs are unmodified.
- ONNX Runtime 1.24.2: Microsoft and contributors, MIT. https://github.com/microsoft/onnxruntime/releases/tag/v1.24.2 . LICENSE and ThirdPartyNotices.txt are included in licenses/onnxruntime. DLLs are unmodified.
- Microsoft Visual C++ 14.44 runtime: Microsoft redistributable files from Visual Studio Build Tools 2022, Microsoft.VC143.CRT x64. These DLLs are proprietary Microsoft components and are not covered by Cap's AGPL. Use remains subject to Microsoft's applicable redistribution terms.
- WebView2: separately installed Microsoft runtime, not included in this archive. https://developer.microsoft.com/microsoft-edge/webview2/

The complete application's transitive dependency inventory is captured in Cargo.lock and pnpm-lock.yaml in the source archive. These locks identify dependency sources/versions; the archive does not vendor every third-party dependency. Before public redistribution, verify the applicable source-delivery obligations of all bundled GPL and other third-party components, including the FFmpeg full-build external libraries.
