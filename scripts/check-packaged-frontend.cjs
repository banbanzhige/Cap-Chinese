const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");

function validateFrontendDist(value, configDirectory) {
  assert.equal(typeof value, "string", "frontendDist must be a directory");
  assert.ok(!/^[a-z][a-z0-9+.-]*:/i.test(value), "frontendDist must not be a URL or Windows drive path: Tauri parses URLs before directories");
  assert.ok(!path.isAbsolute(value), "Use a portable relative frontendDist");
  const directory = path.resolve(configDirectory, value);
  assert.ok(fs.statSync(directory).isDirectory(), "frontendDist is not a directory");
  const html = fs.readFileSync(path.join(directory, "index.html"), "utf8");
  assert.ok(html.includes('lang="zh-CN"'), "Chinese entry page is missing");
  const refs = [...html.matchAll(/(?:src|href)="(\/_build\/[^"?#]+)(?:[?#][^"]*)?"/g)].map(match => match[1]);
  assert.ok(refs.some(ref => ref.endsWith(".js")), "Entry page must include compiled JavaScript");
  for (const ref of refs) assert.ok(fs.existsSync(path.join(directory, ref)), `Missing frontend asset ${ref}`);
  return { directory, entryAssets: refs.length };
}

if (require.main === module) {
  const config = JSON.parse(fs.readFileSync(path.join(root,"config/tauri.zh-package.json"),"utf8"));
  const configDirectory = path.join(root,"tooling/cargo-probe/apps/desktop/src-tauri");
  assert.throws(() => validateFrontendDist("F:/project/Cap Chinese/upstream/Cap/apps/desktop/.output/public",configDirectory), /must not be a URL/);
  assert.throws(() => validateFrontendDist("https://example.com",configDirectory), /must not be a URL/);
  const result = validateFrontendDist(config.build.frontendDist,configDirectory);
  console.log(`PASS packaged frontend directory, zh-CN index and ${result.entryAssets} entry assets; absolute-path regression rejected`);
}
module.exports = { validateFrontendDist };
