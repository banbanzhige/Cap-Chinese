const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const ts = require("../upstream/Cap/node_modules/typescript");
const root = path.resolve(__dirname, "..");
const repo = path.join(root, "upstream/Cap");
const manifest = require("../translations/settings.zh-CN.json");
const normalize = (text) => text.replace(/\s+/g, " ").trim();
function inspect(file, content) {
	const source = ts.createSourceFile(
		file,
		content,
		ts.ScriptTarget.Latest,
		true,
		ts.ScriptKind.TSX,
	);
	assert.equal(source.parseDiagnostics.length, 0, `${file}: TSX syntax`);
	const protectedTokens = [],
		text = [];
	function visit(node) {
		const parent = node.parent;
		if (ts.isStringLiteral(node) || ts.isJsxText(node))
			text.push(normalize(node.text));
		if (ts.isImportDeclaration(node))
			protectedTokens.push(node.getText(source));
		if (
			ts.isJsxAttribute(node) &&
			["class", "href", "id", "type", "disabled"].includes(node.name.text)
		)
			protectedTokens.push(node.getText(source));
		if (
			ts.isPropertyAssignment(node) &&
			["value", "id", "href"].includes(node.name.getText(source))
		)
			protectedTokens.push(node.getText(source));
		if (
			ts.isCallExpression(node) &&
			/^(commands\.|handleChange$|setSettings$|trackEvent$|authStore\.|hotkeysStore\.)/.test(
				node.expression.getText(source),
			)
		)
			protectedTokens.push(node.getText(source).replace(/\s+/g, " "));
		if (
			ts.isStringLiteral(node) &&
			ts.isBinaryExpression(parent) &&
			[
				ts.SyntaxKind.EqualsEqualsEqualsToken,
				ts.SyntaxKind.ExclamationEqualsEqualsToken,
			].includes(parent.operatorToken.kind)
		)
			protectedTokens.push(parent.getText(source));
		ts.forEachChild(node, visit);
	}
	visit(source);
	return { protectedTokens: protectedTokens.map(normalize), text };
}
let total = 0;
for (const [file, entries] of Object.entries(manifest)) {
	const relative = `apps/desktop/src/routes/(window-chrome)/${file}`;
	const original = execFileSync(
		"git",
		[
			"-c",
			`safe.directory=${repo.replaceAll("\\", "/")}`,
			"-C",
			repo,
			"show",
			`HEAD:${relative}`,
		],
		{ encoding: "utf8" },
	);
	const current = fs.readFileSync(path.join(repo, relative), "utf8");
	const before = inspect(file, original),
		after = inspect(file, current);
	assert.deepEqual(
		after.protectedTokens,
		before.protectedTokens,
		`${file}: protected behavior/layout tokens changed`,
	);
	for (const [, translated] of Object.values(entries))
		assert(
			after.text.includes(translated),
			`${file}: missing translation ${translated}`,
		);
	console.log(
		`PASS ${file}: ${Object.keys(entries).length} manifest entries; protected tokens unchanged`,
	);
	total += Object.keys(entries).length;
}
console.log(
	`PASS ${total} manifest entries plus manually localized dynamic messages`,
);
