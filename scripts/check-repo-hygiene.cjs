const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const git = (...args) =>
	execFileSync("git", ["-C", root, ...args], { encoding: "utf8" });
const release = JSON.parse(
	fs.readFileSync(path.join(root, "config/release.json"), "utf8"),
);
assert.match(release.version, /^\d+\.\d+\.\d+$/);
assert.equal(release.locale, "zh-CN");
assert.equal(release.platform, "windows-x64");
assert.ok(Number.isInteger(release.revision) && release.revision > 0);
const lock = JSON.parse(
	fs.readFileSync(path.join(root, "config/upstream.lock.json"), "utf8"),
);
assert.equal(
	lock.tag,
	`cap-v${release.version}`,
	"Release version differs from pinned source",
);
for (const type of ["desktop", "native"])
	assert.ok(
		fs.existsSync(
			path.join(root, `translations/${type}-${release.version}.patch`),
		),
		`Missing ${type} patch`,
	);
const files = [
	...new Set(
		git("ls-files", "--cached", "--others", "--exclude-standard", "-z")
			.split("\0")
			.filter(Boolean),
	),
];
const allowedRoot = new Set([
	".gitignore",
	".gitattributes",
	"AGENTS.md",
	"README.md",
	"LICENSE",
	"NOTICE",
]);
let bytes = 0;
let checked = 0;
for (const file of files) {
	const absolute = path.join(root, file);
	if (!fs.existsSync(absolute)) continue;
	assert.ok(
		allowedRoot.has(file) ||
			/^(?:\.github|\.vscode|config|docs|licenses|scripts|tooling|translations)\//.test(
				file,
			),
		`Unexpected Git candidate: ${file}`,
	);
	assert.ok(
		!/(?:^|\/)(?:node_modules|target|dist|output|artifacts|\.playwright-cli|\.npm-cache|\.pnpm-store|cargo-probe|local)(?:\/|$)/.test(
			file,
		),
		`Local artifacts must not be tracked: ${file}`,
	);
	assert.ok(
		!/\.(?:exe|dll|zip|7z|pdb|dmp|log|pem|key|bak|tmp)$/.test(file),
		`Binary/private file must not be tracked: ${file}`,
	);
	assert.ok(
		!/(?:^|\/)\.env(?:\.|$)/.test(file) || file.endsWith(".env.example"),
		`Private environment file: ${file}`,
	);
	assert.ok(
		!/^config\/.*(?:-result|-verification)\.json$/.test(file),
		`Machine result must stay local: ${file}`,
	);
	assert.ok(
		!/^tooling\//.test(file) || /^tooling\/package(?:-lock)?\.json$/.test(file),
		`Only tool manifests belong in tooling: ${file}`,
	);
	const stat = fs.statSync(absolute);
	assert.ok(stat.isFile(), `Nested repository or non-file candidate: ${file}`);
	assert.ok(stat.size <= 2 * 1024 * 1024, `File exceeds 2 MiB: ${file}`);
	bytes += stat.size;
	checked++;
}
assert.ok(
	bytes <= 20 * 1024 * 1024,
	"Source workspace exceeds 20 MiB; inspect generated files",
);
const dist = path.join(root, "dist");
if (fs.existsSync(dist)) {
	const name = `${release.version}-${release.locale}`;
	const keep = new Set([name, `${name}.zip`, `${name}-source.zip`]);
	const extras = fs.readdirSync(dist).filter((file) => !keep.has(file));
	assert.deepEqual(
		extras,
		[],
		"dist contains stale/unknown versions; run clean-dist.ps1 after verifying current package",
	);
}
console.log(
	`PASS repository hygiene: ${checked} source files, ${(bytes / 1024 / 1024).toFixed(2)} MiB; release ${release.version}-${release.locale}, revision ${release.revision}`,
);
