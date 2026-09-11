const assert=require("node:assert/strict");
const fs=require("node:fs");
const path=require("node:path");
const {execFileSync}=require("node:child_process");
const ts=require("../upstream/Cap/node_modules/typescript");
const {scan,isUi}=require("./desktop-l10n.cjs");
const {polish}=require("./polish-desktop-l10n.cjs");
const repo=path.resolve(__dirname,"../upstream/Cap");
const git=(...args)=>execFileSync("git",["-c",`safe.directory=${repo.replaceAll("\\","/")}`,"-c","core.autocrlf=false","-C",repo,...args],{encoding:"utf8",maxBuffer:20*1024*1024});
const files=git("diff","--name-only").trim().split(/\r?\n/).filter(f=>/\.(tsx?|jsx?)$/.test(f)&&!f.endsWith(".d.ts"));
function protectedStrings(file,source){
  const {ast}=scan(file,source.replaceAll("\r\n","\n"));assert.equal(ast.parseDiagnostics.length,0,`${file}: syntax error`);
  const values=[];
  const identifiers=[];
  function visit(n){
    if((ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n))&&n.text.trim())values.push({text:n.text,ui:isUi(n)});
    if(ts.isNumericLiteral(n))values.push({text:n.text,ui:false});
    if(ts.isIdentifier(n))identifiers.push(n.text);
    ts.forEachChild(n,visit);
  }
  visit(ast);return {values,identifiers};
}
let checked=0;
for(const file of files){
  if(/routes\/\(window-chrome\)\/(settings\.tsx|settings\/(general|hotkeys|recordings)\.tsx)$/.test(file))continue;
  let original=polish(file,git("show",`HEAD:${file}`));
  if(file.endsWith("/ExportPage.tsx"))original=original.replace('option.label === "Social Media"','option.value === "Social"');
  if(file.endsWith("/RecoveryToast.tsx"))original=original.replace('rec().segmentCount !== 1 ? "s" : ""','rec().segmentCount !== 1 ? "" : ""');
  if(file.endsWith("/onboarding.tsx"))original=original.replace('["Record", "Stop", "Share link"]','["Record", "停止", "分享链接"]');
  const current=fs.readFileSync(path.join(repo,file),"utf8");
  const before=protectedStrings(file,original),after=protectedStrings(file,current);
  assert.equal(after.values.length,before.values.length,`${file}: literal count changed`);
  assert.deepEqual(after.values.filter((_,i)=>!before.values[i].ui).map(v=>v.text),before.values.filter(v=>!v.ui).map(v=>v.text),`${file}: non-UI literals or numeric values changed`);
  assert.deepEqual(after.identifiers.sort(),before.identifiers.sort(),`${file}: code identifier counts changed`);
  checked++;
}
console.log(`PASS ${checked} newly translated source files: syntax, non-UI literal values, numbers and identifiers unchanged`);
