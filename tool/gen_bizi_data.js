// Bizi in the app: make lib/features/bizi/bizi_data.dart from the website's Bizi files, so the app uses the same
// words, how-tos and page names as the web (edit them only there):
//   bizhub/src/dashboard/bizi/text.js       → text   (EN / KM)
//   bizhub/src/dashboard/bizi/help.js       → help   (the how-tos)
//   bizhub/src/dashboard/bizi/smart.js      → words  (more words per section) · suggest (smart-word chips)
//   bizhub/src/dashboard/bizi/pages.gen.js  → pages  (each type's sections, EN / KM) — only the sections this app has
//                                                     (the keys of `const _tabs` in each type's page)
//   node tool/gen_bizi_data.js [../bizhub/src]   (then: dart format -l 200 lib/features/bizi/bizi_data.dart)
const fs = require("fs");
const path = require("path");
const SRC = (process.argv[2] || "../bizhub/src").replace(/\/?$/, "/");
const LIB = path.join(__dirname, "../lib/");
const OUT = path.join(LIB, "features/bizi/bizi_data.dart");

// the object or array literal after a marker (strings and comments skipped)
function literalAfter(src, marker) {
  const at = src.indexOf(marker);
  if (at < 0) throw new Error("not found: " + marker);
  let i = at + marker.length;
  while (src[i] !== "{" && src[i] !== "[") i++;
  const start = i;
  let depth = 0;
  let q = null;
  for (; i < src.length; i++) {
    const c = src[i];
    if (q) {
      if (c === "\\") i++;
      else if (c === q) q = null;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") q = c;
    else if (c === "/" && src[i + 1] === "/") i = src.indexOf("\n", i);
    else if (c === "{" || c === "[") depth++;
    else if (c === "}" || c === "]") {
      depth -= 1;
      if (depth === 0) return new Function(`return (${src.slice(start, i + 1)});`)();
    }
  }
  throw new Error("unbalanced: " + marker);
}
const read = (f) => fs.readFileSync(SRC + f, "utf8");

const text = literalAfter(read("dashboard/bizi/text.js"), "const TEXT =");
const help = literalAfter(read("dashboard/bizi/help.js"), "export const HELP =");
const words = literalAfter(read("dashboard/bizi/smart.js"), "export const TAB_WORDS =");
const suggest = literalAfter(read("dashboard/bizi/smart.js"), "export const SUGGEST =");
const webPages = literalAfter(read("dashboard/bizi/pages.gen.js"), "export const BIZI_PAGES =");

// the sections each type has in this app
const PAGE_FILES = {
  restaurant: "restaurant/rest_page.dart",
  mart: "mart/mart_page.dart",
  guest_house: "guesthouse/gh_page.dart",
  attendance: "attendance/at_page.dart",
  menu_qr: "menuqr/mq_page.dart",
  flipbook: "flipbook/fb_page.dart",
  website: "website/wb_page.dart",
  qr_gen: "qrgen/qg_page.dart",
  debt_book: "debt/dk_page.dart",
  event: "event/ev_page.dart",
  tg_store: "tgstore/ts_page.dart",
  stamp_card: "stamp/sc_page.dart",
};
const pages = {};
for (const [type, file] of Object.entries(PAGE_FILES)) {
  const dart = fs.readFileSync(path.join(LIB, "features", file), "utf8");
  const m = dart.match(/const _tabs = <String, IconData>\{([\s\S]*?)\n\};/);
  if (!m) throw new Error(`no _tabs in ${file}`);
  const keys = [...m[1].matchAll(/^\s*'([a-z_]+)'\s*:/gm)].map((x) => x[1]);
  pages[type] = (webPages[type]?.tabs || []).filter(([k]) => keys.includes(k));
}

// web links → the app's own screens (a how-to's "Open" button)
const APP_HREF = { "/app/licenses?tab=coins": "/o/coins", "/app/businesses": "/o/business", "/app/licenses": "/o/licenses", "/app/account": "/account", "/app/settings": "/account", "/app/support": "/o/support", "/app/updates": "/updates", "/app/dashboard": "/o/home" };
for (const a of help) {
  if (a.href) {
    if (!APP_HREF[a.href]) throw new Error(`help ${a.id}: no app screen for ${a.href}`);
    a.href = APP_HREF[a.href];
  }
}

// the BizHub team's Bizi (super admin): its pages, how-tos, chips — web pages → the admin app's screens
const adminSrc = read("dashboard/bizi/admin-help.js");
const ADMIN_ROUTE = (href) => {
  const [p, q = ""] = href.split("?");
  const map = {
    "/app/super-admin/dashboard": "/a/dash",
    "/app/super-admin/coin-orders": "/a/orders",
    "/app/super-admin/inbox": "/a/inbox",
    "/app/super-admin/customers": "/a/customers",
    "/app/super-admin/businesses": "/a/businesses",
    "/app/super-admin/coins": q.includes("tab=cards") ? "/a/cards" : "/a/coins",
    "/app/super-admin/licenses": "/a/licenses",
    "/app/super-admin/prices": "/a/prices",
    "/app/super-admin/holidays": "/a/holidays",
    "/app/super-admin/website": "/a/homepage",
    "/app/admin/users": "/a/users",
    "/app/admin/activity-log": "/a/activity",
  };
  if (!map[p]) throw new Error(`admin: no app screen for ${href}`);
  return map[p];
};
const admin = {
  pages: literalAfter(adminSrc, "export const ADMIN_PAGES =").map(([href, en, km, more]) => [ADMIN_ROUTE(href), en, km, more]),
  help: literalAfter(adminSrc, "export const ADMIN_HELP =").map((a) => ({ ...a, href: ADMIN_ROUTE(a.href) })),
  suggest: literalAfter(adminSrc, "export const ADMIN_SUGGEST ="),
};
// two web pages that are one screen in the app
admin.pages = admin.pages.filter((p, i, all) => all.findIndex((x) => x[0] === p[0]) === i || p[0] === "/a/cards");

const data = { text, help, words, suggest, pages, admin };
// JSON is a Dart literal once "$" can't start an interpolation
const lit = JSON.stringify(data, null, 1).replace(/\$/g, "\\$");
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(
  OUT,
  `// GENERATED by tool/gen_bizi_data.js from the website (bizhub/src/dashboard/bizi/) — do not edit here.
// Bizi, the BizHub helper: its words (EN / KM), the how-tos, more words per section, the smart-word chips, and the
// sections of each business type this app has.
const biziData = <String, dynamic>${lit};
`,
);
console.log(`bizi_data.dart: ${help.length} how-tos, ${Object.keys(pages).length} types`);
