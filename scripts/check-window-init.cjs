const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname,"../tooling/cargo-probe/apps/desktop/src-tauri/src/windows.rs"),"utf8");
const template = source.match(/r#"(\(function\(\).*?background-color:.*?\)\(\);)"#/)[1];
const script = template.replaceAll("{bg_color}","#ffffff").replaceAll("{{","{").replaceAll("}}","}");
for (const early of [false,true]) {
  let ready;
  const styles = [];
  const root = {appendChild: style => styles.push(style)};
  const document = {
    documentElement: early ? null : root,
    createElement: tag => { assert.equal(tag,"style");return {}; },
    addEventListener: (event,callback,options) => { assert.equal(event,"DOMContentLoaded");assert.equal(options.once,true);ready=callback; }
  };
  vm.runInNewContext(script,{document});
  if (early) {assert.equal(styles.length,0);document.documentElement=root;ready();}
  assert.equal(styles.length,1);
  assert.equal(styles[0].textContent,"html,body{background-color:#ffffff}");
}
console.log("PASS window initialization before and after documentElement exists");
