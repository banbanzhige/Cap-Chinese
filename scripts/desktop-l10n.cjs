const fs = require("node:fs");
const path = require("node:path");
const ts = require("../upstream/Cap/node_modules/typescript");
const root = path.resolve(__dirname, "..");
const manualUi = JSON.parse(fs.readFileSync(path.join(root,"translations/desktop-manual-ui.json"),"utf8"));
const normalize = (s) => s.replace(/\s+/g, " ").trim();
const uiNames = new Set(["label", "title", "description", "placeholder", "tooltip", "tooltipText", "alt", "aria-label", "summary", "subtitle", "text", "message", "okLabel", "cancelLabel", "bestFor", "emptyMessage", "helperText", "heading", "question", "answer", "hint", "cancel", "ok"]);
const sources = ["apps/desktop/src", "packages/ui-solid/src"];
function filesAt(base) {
  return sources.flatMap(dir => fs.existsSync(path.join(base,dir)) ? fs.readdirSync(path.join(base,dir),{recursive:true}).filter(f=>/\.(tsx?|jsx?)$/.test(f)&&!/(?:\.d\.ts$|\.test\.|\/tauri\.ts$|\\tauri\.ts$)/.test(f)).map(f=>path.join(dir,f).replaceAll("\\","/")) : []);
}
function isUi(node) {
  if(manualUi[node.getSourceFile().fileName]?.[node.text])return true;
  if(ts.isJsxText(node)) return true;
  let p=node.parent;
  if(ts.isJsxAttribute(p)) return uiNames.has(p.name.text) || ["content","name"].includes(p.name.text);
  if(ts.isPropertyAssignment(p)) {
    let a=p;while(a&&!ts.isVariableDeclaration(a))a=a.parent;
    const mapName=a?.name?.getText()||"";
    return uiNames.has(p.name.getText()) || (p.name.getText()==="name" && /^[A-Z]/.test(node.text || "")) || /(?:_LABELS|_PHRASE|_SHORT|_NOUN|BACKGROUND_SOURCES|BACKGROUND_THEMES|LAYER_NAMES)$/.test(mapName);
  }
  if(ts.isVariableDeclaration(p)) return /^(?:NO_CAMERA|NO_MICROPHONE|noResultsMessage|searchPlaceholder|settingsTitle)$/.test(p.name.getText());
  if(ts.isCallExpression(p)) return /(?:toast\.(?:success|error|loading)|(?:^|\.)(?:confirm|ask|message|setTitle|setError|setErrorMessage|setUpdateStatus))$/.test(p.expression.getText());
  if(ts.isNewExpression(p)) return p.expression.getText()==="Error";
  if(ts.isReturnStatement(p)) return true;
  if(ts.isBinaryExpression(p) && [ts.SyntaxKind.EqualsEqualsEqualsToken,ts.SyntaxKind.ExclamationEqualsEqualsToken,ts.SyntaxKind.EqualsEqualsToken,ts.SyntaxKind.ExclamationEqualsToken].includes(p.operatorToken.kind)) return false;
  while(p && (ts.isConditionalExpression(p)||ts.isBinaryExpression(p)||ts.isParenthesizedExpression(p)||ts.isJsxExpression(p))) {
    if(ts.isJsxExpression(p)) return !ts.isJsxAttribute(p.parent) || uiNames.has(p.parent.name.text) || ["children","content","name"].includes(p.parent.name.text);
    if(ts.isVariableDeclaration(p.parent))return /^(?:noResultsMessage|searchPlaceholder|settingsTitle)$/.test(p.parent.name.getText());
    if(ts.isPropertyAssignment(p.parent)) return uiNames.has(p.parent.name.getText());
    if(ts.isReturnStatement(p.parent)) return true;
    p=p.parent;
  }
  return false;
}
function scan(file, source) {
  const ast=ts.createSourceFile(file,source,ts.ScriptTarget.Latest,true,/x$/.test(file)?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  const rows=[];
  function visit(n, address) {
    const jsx=ts.isJsxText(n), template=ts.isTemplateExpression(n);
    if(jsx||template||ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n)) {
      const key=normalize(template?n.head.text+n.templateSpans.map((s,i)=>`{${i}}${s.literal.text}`).join(""):n.text);
      if(key && /[A-Za-z\u4e00-\u9fff]/.test(key)) {
        const start=n.getStart(ast), lc=ast.getLineAndCharacterOfPosition(start);
        rows.push({file,key,address,start,end:n.end,line:lc.line+1,kind:jsx?"jsx":template?"template":"literal",safe:isUi(n),expressions:template?n.templateSpans.map(s=>s.expression.getText(ast)):[],context:normalize(n.parent.getText(ast)).slice(0,180)});
      }
    }
    let i=0;
    ts.forEachChild(n,c=>visit(c,`${address}.${i++}`));
  }
  visit(ast,"0");
  return {ast,rows};
}
function dictionary() {
  const result={};
  const settings=JSON.parse(fs.readFileSync(path.join(root,"translations/settings.zh-CN.json"),"utf8"));
  for(const entries of Object.values(settings))for(const pair of Object.values(entries))result[pair[0]]=pair[1];
  for(const f of fs.readdirSync(path.join(root,"translations")).filter(f=>/^desktop-\d.*\.json$/.test(f)).sort()) Object.assign(result,JSON.parse(fs.readFileSync(path.join(root,"translations",f),"utf8")));
  for(const entries of Object.values(manualUi))Object.assign(result,entries);
  return result;
}
module.exports={scan,isUi,filesAt,dictionary};
const mode=require.main===module?(process.argv[2]||"inventory"):"library";
if(mode==="reference") {
  const english=path.join(root,"references/Cap-English-0.3.72"),chinese=path.join(root,"references/Cap-Chinese");
  const map={},conflicts=[];
  for(const file of filesAt(english)) {
    if(!fs.existsSync(path.join(chinese,file)))continue;
    const a=scan(file,fs.readFileSync(path.join(english,file),"utf8")).rows;
    const b=scan(file,fs.readFileSync(path.join(chinese,file),"utf8")).rows;
    const byAddress=new Map(b.map(r=>[r.address,r]));
    for(const x of a) { const y=byAddress.get(x.address); if(!y||x.kind!==y.kind||!x.safe||!y.safe||/[\u4e00-\u9fff]/.test(x.key)||!/[\u4e00-\u9fff]/.test(y.key))continue;
      if(map[x.key]&&map[x.key]!==y.key){conflicts.push(x.key);continue;}
      map[x.key]=y.key;
    }
  }
  console.log(JSON.stringify({map,conflicts}));
} else if(mode!=="library") {
  const base=path.join(root,"upstream/Cap"),dict=dictionary();
  const all=filesAt(base).flatMap(file=>scan(file,fs.readFileSync(path.join(base,file),"utf8")).rows);
  const eligible=all.filter(r=>r.safe&&!/[\u4e00-\u9fff]/.test(r.key)&&r.key!=="Export cancelled");
  if(mode==="unmatched-known") {
    for(const r of all.filter(r=>!r.safe&&dict[r.key]&&!/[\u4e00-\u9fff]/.test(r.key)))console.log(JSON.stringify({key:r.key,file:r.file,line:r.line,context:r.context}));
  } else if(mode==="keys") {
    const unique=[...new Set(eligible.filter(r=>!dict[r.key]&&(!process.argv[3]||r.file.includes(process.argv[3]))).map(r=>r.key))];
    console.log(JSON.stringify(unique,null,2));
  } else if(mode==="summary") {
    const byFile={}; for(const r of eligible)byFile[r.file]=(byFile[r.file]||0)+1;
    console.log(JSON.stringify({total:eligible.length,unique:new Set(eligible.map(r=>r.key)).size,covered:eligible.filter(r=>dict[r.key]).length,byFile},null,2));
  } else if(mode==="inventory") {
    const seen=new Set();for(const r of eligible){if(dict[r.key]||seen.has(r.key)|| (process.argv[3]&&!r.file.includes(process.argv[3])))continue;seen.add(r.key);console.log(JSON.stringify({key:r.key,where:`${r.file}:${r.line}`,context:r.context}));}
  } else if(mode==="patch") {
    let patch="*** Begin Patch\n",count=0;
    for(const file of [...new Set(eligible.filter(r=>dict[r.key]).map(r=>r.file))]) {
      if(process.argv[3]&&!file.includes(process.argv[3]))continue;
      const source=fs.readFileSync(path.join(base,file),"utf8");
      const selected=eligible.filter(r=>r.file===file&&dict[r.key]);
      const edits=selected.filter(r=>!selected.some(p=>p!==r&&p.kind==="template"&&p.start<=r.start&&p.end>=r.end)).map(r=>{
        let value=dict[r.key];if(typeof value!=="string")throw Error(`Bad translation ${r.key}`);
        if(r.kind==="template"){
          for(let i=0;i<r.expressions.length;i++)if(!value.includes(`{${i}}`))throw Error(`Missing placeholder ${r.key}`);
          value="`"+value.replaceAll("`","\\`").replaceAll("${","\\${").replace(/\{(\d+)\}/g,(_,i)=>{if(!r.expressions[+i])throw Error(`Unknown placeholder ${r.key}`);return "${"+r.expressions[+i]+"}";})+"`";
        }else if(r.kind==="jsx"){value=source.slice(r.start,r.end).replace(/\S[\s\S]*\S|\S/,()=>value);}else value=JSON.stringify(value);
        return {...r,value};
      });
      let result=source;for(const e of [...edits].sort((a,b)=>b.start-a.start))result=result.slice(0,e.start)+e.value+result.slice(e.end);
      if(scan(file,result).ast.parseDiagnostics.length)throw Error(`Invalid TSX ${file}`);
      const ranges=[];
      for(const e of edits.sort((a,b)=>a.start-b.start)){const start=source.lastIndexOf("\n",e.start-1)+1;const next=source.indexOf("\n",e.end);const end=next<0?source.length:next+1;const p=ranges.at(-1);if(p&&start<=p.end){p.end=Math.max(p.end,end);p.edits.push(e);}else ranges.push({start,end,edits:[e]});}
      patch+=`*** Update File: ${path.join(base,file).replaceAll("\\","/")}\n`;
      for(const r of ranges){const old=source.slice(r.start,r.end);let updated=old;for(const e of [...r.edits].sort((a,b)=>b.start-a.start))updated=updated.slice(0,e.start-r.start)+e.value+updated.slice(e.end-r.start);patch+="@@\n"+old.replace(/\r?\n$/,"").split(/\r?\n/).map(l=>"-"+l).join("\n")+"\n"+updated.replace(/\r?\n$/,"").split(/\r?\n/).map(l=>"+"+l).join("\n")+"\n";}
      count+=edits.length;
    }
    console.log(JSON.stringify({count,patch:patch+"*** End Patch"}));
  }
}
