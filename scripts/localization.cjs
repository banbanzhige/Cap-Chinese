const fs = require("node:fs");
const path = require("node:path");
const ts = require("../upstream/Cap/node_modules/typescript");
const root = path.resolve(__dirname, "..");
const routes = "apps/desktop/src/routes/(window-chrome)/";
const files = [
	"settings.tsx",
	"settings/general.tsx",
	"settings/hotkeys.tsx",
	"settings/recordings.tsx",
];
const normalize = (text) => text.replace(/\s+/g, " ").trim();
function inventory(file, source) {
	const ast = ts.createSourceFile(
		file,
		source,
		ts.ScriptTarget.Latest,
		true,
		ts.ScriptKind.TSX,
	);
	const rows = [];
	function visit(node) {
		const jsx = ts.isJsxText(node);
		if (
			jsx ||
			ts.isStringLiteral(node) ||
			ts.isNoSubstitutionTemplateLiteral(node)
		) {
			const text = normalize(node.text);
			const parent = node.parent;
			const start = node.getStart(ast);
			const pos = ast.getLineAndCharacterOfPosition(start);
			const context = parent.getText(ast).slice(0, 140).replace(/\s+/g, " ");
			if (
				/[A-Za-z\u4e00-\u9fff]/.test(text) &&
				!ts.isImportDeclaration(parent) &&
				!(
					ts.isJsxAttribute(parent) &&
					![
						"label",
						"title",
						"description",
						"placeholder",
						"alt",
						"aria-label",
					].includes(parent.name.text)
				) &&
				!/^(?:@|~|\.|\/|https?:)/.test(text) &&
				!text.includes("class=") &&
				!/\b(?:flex|rounded|px-|py-|text-|bg-|w-|h-|grid|gap-|border-|items-|justify-)\S*/.test(
					text,
				)
			) {
				rows.push({
					id: `${pos.line + 1}:${pos.character + 1}`,
					text,
					kind: jsx ? "jsx" : "literal",
					context,
					start,
					end: node.end,
				});
			}
		}
		ts.forEachChild(node, visit);
	}
	visit(ast);
	return { ast, rows };
}
const mode = process.argv[2] || "inventory";
if (mode === "inventory") {
	for (const file of files.filter(
		(f) => !process.argv[3] || f === process.argv[3],
	)) {
		const source = fs.readFileSync(
			path.join(root, "upstream/Cap", routes, file),
			"utf8",
		);
		console.log(file);
		for (const r of inventory(file, source).rows)
			console.log(
				JSON.stringify({ id: r.id, text: r.text, context: r.context }),
			);
	}
} else if (mode === "patch") {
	const manifest = JSON.parse(
		fs.readFileSync(
			path.join(root, "translations/settings.zh-CN.json"),
			"utf8",
		),
	);
	let patch = "*** Begin Patch\n";
	let count = 0;
	for (const [file, translations] of Object.entries(manifest)) {
		const absolute = path.join(root, "upstream/Cap", routes, file);
		const source = fs.readFileSync(absolute, "utf8");
		const { rows } = inventory(file, source);
		const edits = [];
		for (const [id, pair] of Object.entries(translations)) {
			const row = rows.find((r) => r.id === id);
			if (!row || row.text !== pair[0])
				throw new Error(`Source drift at ${file}:${id}`);
			const raw = source.slice(row.start, row.end);
			const replacement =
				row.kind === "jsx"
					? raw.replace(/\S[\s\S]*\S|\S/, pair[1])
					: JSON.stringify(pair[1]);
			edits.push({ ...row, replacement });
		}
		let result = source;
		for (const edit of edits.sort((a, b) => b.start - a.start))
			result =
				result.slice(0, edit.start) + edit.replacement + result.slice(edit.end);
		const parsed = ts.createSourceFile(
			file,
			result,
			ts.ScriptTarget.Latest,
			true,
			ts.ScriptKind.TSX,
		);
		if (parsed.parseDiagnostics.length)
			throw new Error(`Invalid translated syntax: ${file}`);
		patch += `*** Update File: ${absolute.replaceAll("\\", "/")}\n`;
		const ranges = [];
		for (const edit of [...edits].sort((a, b) => a.start - b.start)) {
			const start = source.lastIndexOf("\n", edit.start - 1) + 1;
			const next = source.indexOf("\n", edit.end);
			const end = next < 0 ? source.length : next + 1;
			const prior = ranges.at(-1);
			if (prior && start <= prior.end) {
				prior.end = Math.max(prior.end, end);
				prior.edits.push(edit);
			} else ranges.push({ start, end, edits: [edit] });
		}
		for (const range of ranges) {
			const old = source.slice(range.start, range.end).replace(/\r?\n$/, "");
			let updated = source.slice(range.start, range.end);
			for (const edit of [...range.edits].sort((a, b) => b.start - a.start))
				updated =
					updated.slice(0, edit.start - range.start) +
					edit.replacement +
					updated.slice(edit.end - range.start);
			updated = updated.replace(/\r?\n$/, "");
			patch +=
				"@@\n" +
				old
					.split(/\r?\n/)
					.map((l) => `-${l}`)
					.join("\n") +
				"\n" +
				updated
					.split(/\r?\n/)
					.map((l) => `+${l}`)
					.join("\n") +
				"\n";
		}
		count += edits.length;
	}
	patch += "*** End Patch";
	console.log(JSON.stringify({ patch, count }));
}
