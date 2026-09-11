const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname,"../upstream/Cap");
const rules = {
  "apps/desktop/src/entry-server.tsx": [[/lang="en"/g,'lang="zh-CN"']],
  "apps/desktop/src/components/callback.template.ts": [
    [/lang="en"/g,'lang="zh-CN"'],
    [/<title>Cap Auth<\/title>/g,'<title>Cap 登录</title>'],
    [/You are now signed in\. Please re-open the Cap desktop app to continue\./g,'登录成功。请返回 Cap 桌面应用继续使用。']
  ],
  "apps/desktop/src/components/RecoveryToast.tsx": [[/\{rec\(\)\.segmentCount !== 1 \? "s?" : ""\}/g,""]],
  "apps/desktop/src/routes/(window-chrome)/settings/transcription.tsx": [[/\{hints\(\)\.length\} \{hints\(\)\.length === 1 \? "(?:item|项)" : "(?:items|项)"\}/g,"{hints().length} 项"]],
  "apps/desktop/src/routes/editor/ConfigSidebar.tsx": Object.entries({caption:"字幕",keyboard:"按键",text:"文字",audio:"音频",mask:"遮罩",zoom:"缩放",scene:"场景",clip:"视频"}).map(([en,zh])=>[
    new RegExp('\\{value\\(\\)\\.segments\\.length\\} (?:'+en+'|个'+zh+')\\{" "\\}\\s*\\{value\\(\\)\\.segments\\.length === 1\\s*\\? "(?:segment|个片段)"\\s*:\\s*"(?:segments|片段)"\\}\\{" "\\}\\s*(?:selected|已选中)','g'),
    '已选中 {value().segments.length} 个'+zh+'片段'
  ])
};
function polish(file,source){for(const [pattern,value] of rules[file]||[])source=source.replace(pattern,value);return source;}
module.exports={polish};
if(require.main===module){
  let patch="*** Begin Patch\n";
  for(const [file,replacements] of Object.entries(rules)){
    const source=fs.readFileSync(path.join(root,file),"utf8");
    const ranges=[];
    for(const [pattern,value] of replacements){for(const match of source.matchAll(pattern)){
      const start=source.lastIndexOf("\n",match.index-1)+1;
      const next=source.indexOf("\n",match.index+match[0].length);
      const end=next<0?source.length:next;
      const old=source.slice(start,end);
      const updated=old.slice(0,match.index-start)+value+old.slice(match.index-start+match[0].length);
      ranges.push([old,updated]);
    }}
    if(!ranges.length)continue;
    patch+=`*** Update File: ${path.join(root,file).replaceAll("\\","/")}\n`;
    for(const [old,updated] of ranges)patch+="@@\n"+old.split(/\r?\n/).map(s=>"-"+s).join("\n")+"\n"+updated.split(/\r?\n/).map(s=>"+"+s).join("\n")+"\n";
  }
  console.log(JSON.stringify({patch:patch+"*** End Patch"}));
}
