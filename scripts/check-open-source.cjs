const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const read = (file) =>
	fs.readFileSync(path.join(root, file), "utf8").replaceAll("\r\n", "\n");
const documents = [
	"README.md",
	"NOTICE",
	"docs/LICENSING.md",
	"docs/OPEN-SOURCE.md",
	"docs/DEVELOPMENT.md",
	"docs/THIRD-PARTY-NOTICES.md",
	"docs/WORKFLOW.md",
];
let links = 0;
for (const file of documents) {
	const content = read(file);
	assert.ok(!/[\uFFFD]/.test(content), `Invalid encoding in ${file}`);
	for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
		const target = match[1].split("#")[0];
		if (!target || /^[a-z][a-z0-9+.-]*:/i.test(target)) continue;
		assert.ok(
			fs.existsSync(path.resolve(root, path.dirname(file), target)),
			`${file}: missing link ${target}`,
		);
		links++;
	}
}
const cap = read("licenses/Cap-LICENSE");
assert.equal(
	read("LICENSE").trim(),
	cap
		.slice(cap.indexOf("                    GNU AFFERO GENERAL PUBLIC LICENSE"))
		.trim(),
	"AGPL standard text was changed",
);
assert.ok(read("NOTICE").includes("AGPL-3.0-only"));
for (const file of ["desktop-0.5.9.patch", "native-0.5.9.patch"]) {
	const content = read(`translations/${file}`);
	assert.ok(content.startsWith("diff --git "), `Not a git patch: ${file}`);
	assert.ok(!content.includes("diff --git a/.env "), "Private .env included");
	assert.ok(
		!/diff --git a\/.*(?:tauri\.ts|\.d\.ts) /.test(content),
		"Generated file included",
	);
}
const ignored = [
	"dist/private.zip",
	"output/playwright/private.png",
	".playwright-cli/private.yml",
	"artifacts/test.cap",
	"config/zh-package-result.json",
	"config/zh-startup-verification.json",
	"tooling/.npm-cache/test",
	"upstream/Cap/.env",
	".env",
	"private.key",
];
for (const file of ignored) {
	execFileSync("git", [
		"-C",
		root,
		"check-ignore",
		"--quiet",
		"--no-index",
		file,
	]);
}
const candidates = execFileSync(
	"git",
	["-C", root, "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
	{ encoding: "utf8" },
)
	.split("\0")
	.filter(Boolean);
const disallowed = candidates.filter(
	(file) =>
		/^(?:dist|output|\.playwright-cli|artifacts|upstream|references)\//.test(
			file,
		) || /\.(?:exe|dll|pdb|dmp|pem|key)$/.test(file),
);
assert.deepEqual(
	disallowed,
	[],
	"Private/runtime artifacts are exposed as Git candidates",
);
console.log(
	`PASS ${documents.length} public documents, ${links} relative links, exact AGPL text, complete patch presence, ${ignored.length} ignore cases; no runtime artifacts in current Git candidates`,
);
console.log(
	"This check does not certify license compliance or scan Git history for secrets.",
);
