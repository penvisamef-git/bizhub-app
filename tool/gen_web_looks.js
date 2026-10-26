const fs=require("fs");
const src=fs.readFileSync("../bizhub/src/web/themes.js","utf8").replace(/export (const|function) /g,"$1 ")+"\nmodule.exports={WEB_LOOKS};";
const m={exports:{}}; new Function("module","exports",src)(m,m.exports);
const L=m.exports.WEB_LOOKS;
const hex=(h)=>{ if(!h) return "null"; let x=h.replace("#",""); if(x.length===3)x=x.split("").map(c=>c+c).join(""); if(!/^[0-9a-fA-F]{6}$/.test(x)) return "null"; return `Color(0xFF${x.toUpperCase()})`;};
const q=(s)=>JSON.stringify(s||"").replace(/\$/g,"\\$");
let out=`// GENERATED from src/web/themes.js (tool: genweb) — the 24 company website looks.\nimport 'package:flutter/material.dart';\n\nclass WebLook {\n  final String name, km, desc, descKm, nav, hero, svc;\n  final Color bg, fg, card, accent;\n  final Color? accent2;\n  final double r;\n  final bool glow, serif;\n  const WebLook({required this.name, required this.km, required this.desc, required this.descKm, required this.nav, required this.hero, required this.svc, required this.bg, required this.fg, required this.card, required this.accent, this.accent2, required this.r, this.glow = false, this.serif = false});\n  String nameOf(String lang) => lang == 'km' ? km : name;\n  String descOf(String lang) => lang == 'km' ? descKm : desc;\n}\n\nconst webLooks = <String, WebLook>{\n`;
for(const [k,v] of Object.entries(L)){
  const serif=/serif/i.test(v.head||"")&&!/sans/i.test(v.head||"") || /Playfair|Lora|Fraunces|Cormorant|Cinzel|Source Serif|DM Serif|Libre|Merriweather|Noto Serif/.test(v.head||"");
  out+=`  '${k}': WebLook(name: ${q(v.name)}, km: ${q(v.km)}, desc: ${q(v.desc)}, descKm: ${q(v.descKm)}, nav: '${v.nav}', hero: '${v.hero}', svc: '${v.svc}', bg: ${hex(v.bg)}, fg: ${hex(v.fg)}, card: ${hex(v.card)}, accent: ${hex(v.accent)}, accent2: ${hex(v.accent2)}, r: ${v.r||0}, glow: ${!!v.glow}, serif: ${serif}),\n`;
}
out+="};\n";
fs.writeFileSync("lib/features/attendance/at_web_looks.dart",out);
console.log(Object.keys(L).length);
