// Pull the EN/KM text objects out of the web app source, so the Flutter app uses the exact same words.
const fs = require("fs");
// usage: node tool/extract_texts.js ../bizhub/src assets/i18n
const SRC = (process.argv[2] || "../bizhub/src").replace(/\/?$/, "/");
function objAfter(src, marker) {
  const at = src.indexOf(marker);
  if (at < 0) throw new Error("marker not found: " + marker);
  let i = src.indexOf("{", at) , depth = 0, q = null;
  if (src.slice(at + marker.length).trimStart()[0] === "[") i = src.indexOf("[", at);
  const start = i;
  for (; i < src.length; i++) {
    const c = src[i];
    if (q) { if (c === "\\") { i++; continue; } if (c === q) q = null; continue; }
    if (c === '"' || c === "'" || c === "`") { q = c; continue; }
    if (c === "/" && src[i + 1] === "/") { i = src.indexOf("\n", i); continue; }
    if (c === "{" || c === "[") depth++;
    if (c === "}" || c === "]") { depth--; if (depth === 0) return src.slice(start, i + 1); }
  }
  throw new Error("unbalanced " + marker);
}
// helpers some text files call inside their objects (pf themeNames spreads recipeNames(lang): the app reads those names from recipes_data.dart)
const evalObj = (code) => new Function("recipeNames", `return (${code});`)(() => ({}));
// functions → text with {n} placeholder
function plain(v) {
  if (typeof v === "function") { try { return String(v("{n}")); } catch { return ""; } }
  if (Array.isArray(v)) return v.map(plain);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, plain(x)]));
  return v;
}
const read = (f) => fs.readFileSync(SRC + f, "utf8");
const pick = (f, marker) => plain(evalObj(objAfter(read(f), marker)));
// objects built with a helper function (pos/restThemes.js: T(en, km, d_en, d_km, {...}))
const pickT = (f, marker) => plain(new Function("T", `return (${objAfter(read(f), marker)});`)((en, km, d_en, d_km) => ({ en, km, d_en, d_km })));

const out = {
  messages: pick("i18n/messages.js", "export const MESSAGES ="),
  home: pick("homepage/content.js", "export const HOME_TEXT ="),
  dash: pick("dashboard/client/dash-text.js", "const TEXT ="),
  sa: pick("dashboard/super_admin/text.js", "const TEXT ="),
  lic: pick("dashboard/client/licenses/text.js", "const TEXT ="),
  phone: pick("homepage/auth/phone.jsx", "const TEXT ="),
  coin: pick("dashboard/client/licenses/CoinShop.jsx", "const TEXT ="),
  bizInfo: pick("dashboard/client/bizTypeInfo.js", "export const BIZ_INFO ="),
  bizWords: pick("dashboard/client/bizTypeInfo.js", "export const BIZ_INFO_WORDS ="),
  support: pick("dashboard/support/text.js", "export const SP_TEXT ="),
  ah: pick("dashboard/super_admin/HolidaysAdminPage.jsx", "const TEXT ="),
  pr: pick("dashboard/admin/prices/PricesPage.jsx", "const TEXT ="),
  tgb: pick("dashboard/admin/homepage/TelegramBotCard.jsx", "const TEXT ="),
  card: pick("namecard/text.js", "const TEXT ="),
  pf: pick("namecard/portfolioText.js", "const TEXT ="),
  rest: pick("dashboard/client/restaurant/text.js", "const TEXT ="),
  stock: pick("dashboard/client/restaurant/stock-text.js", "const TEXT ="),
  report: pick("dashboard/client/restaurant/report-text.js", "const TEXT ="),
  pos: pick("dashboard/client/restaurant/pos-text.js", "const TEXT ="),
  promo: pick("dashboard/client/restaurant/promo-text.js", "const TEXT ="),
  tg: pick("dashboard/client/restaurant/tg-text.js", "const TEXT ="),
  extras: pick("dashboard/client/restaurant/extras-text.js", "const TEXT ="),
  rw: pick("dashboard/client/restaurant/rw-text.js", "const TEXT ="),
  inbox: pick("dashboard/client/restaurant/inbox-text.js", "const TEXT ="),
  branches: pick("dashboard/client/branches/BranchesTab.jsx", "const TEXT ="),
  apptab: pick("dashboard/client/restaurant/AppTab.jsx", "const TEXT ="),
  to: pick("dashboard/client/restaurant/to-text.js", "const TEXT ="),
  ws: pick("dashboard/client/restaurant/ws-text.js", "const TEXT ="),
  site: pick("site/text.js", "export const SITE_TEXT ="),
  stheme: pick("site/text.js", "export const SITE_THEMES ="),
  mart: pick("dashboard/client/mart/text.js", "export const MART_TEXT ="),
  mw: pick("dashboard/client/mart/wtext.js", "export const W_TEXT ="),
  mx: pick("dashboard/client/mart/xtext.js", "export const X_TEXT ="),
  addfind: pick("dashboard/client/restaurant/AddonsTab.jsx", "const FIND ="),
  rtheme: pick("pos/themes.js", "export const RECEIPT_THEMES ="),
  dtheme: pick("pos/themes.js", "export const DISPLAY_THEMES ="),
  qtheme: pick("pos/themes.js", "export const QR_THEMES ="),
  otheme: pick("pos/themes.js", "export const ORDER_THEMES ="),
  ptheme: pick("pos/themes.js", "export const POINTS_THEMES ="),
  postheme: pickT("pos/restThemes.js", "export const REST_POS_LOOKS ="),
  gh: (() => {
    // the guest house words: GH_TEXT + the newer add-ons from gh3-text.js MORE (merged like text.js does)
    const g = pick("dashboard/client/guesthouse/text.js", "export const GH_TEXT =");
    const more = pick("dashboard/client/guesthouse/gh3-text.js", "export const MORE =");
    for (const l of ["en", "km"]) {
      const { tabs, addonInfo, staffRoles, sources, ...rest } = more[l];
      Object.assign(g[l].tabs, tabs);
      Object.assign(g[l].sources, sources);
      Object.assign(g[l].staffRoles, staffRoles);
      Object.assign(g[l].addonInfo, addonInfo);
      Object.assign(g[l], rest);
    }
    return g;
  })(),
  gx: pick("dashboard/client/guesthouse/gh3-text.js", "export const X3_TEXT ="),
  gpr: pick("dashboard/client/guesthouse/gh2-text.js", "export const PR_TEXT ="),
  gcu: pick("dashboard/client/guesthouse/gh2-text.js", "export const CU_TEXT ="),
  gws: pick("dashboard/client/guesthouse/ws-text.js", "export const WS_TEXT ="),
  gs: pick("gsite/text.js", "export const GS_TEXT ="),
  att: pick("dashboard/client/attendance/text.js", "const TEXT ="),
  atai: pick("dashboard/client/attendance/addon-info.js", "const TEXT ="),
  atx: pick("dashboard/client/attendance/AddonTabs.jsx", "const T ="),
  atad: pick("dashboard/client/attendance/AddonsTab.jsx", "const T ="),
  atdy: pick("dashboard/client/attendance/DaysTabs.jsx", "const T ="),
  atot: pick("dashboard/client/attendance/DaysTabs.jsx", "const OT ="),
  aten: pick("dashboard/client/attendance/EngageTabs.jsx", "const T ="),
  atlk: pick("dashboard/client/attendance/LooksTab.jsx", "const LT ="),
  atro: pick("dashboard/client/attendance/RosterTab.jsx", "const T ="),
  atsx: pick("dashboard/client/attendance/StaffExtras.jsx", "const T ="),
  atwb: (() => {
    // KM is { ...EN, ... }
    const f = "dashboard/client/attendance/website-text.js";
    const EN = pick(f, "const EN =");
    const KM = plain(new Function("EN", `return (${objAfter(read(f), "const KM =")});`)(EN));
    return { en: EN, km: KM };
  })(),
  sax: pick("attend/text.js", "export const TEXT ="),
  kq: pick("attend/KioskView.jsx", "export const KT ="),
  webt: pick("web/text.js", "export const WEB_TEXT ="),
  qg: (() => {
    const f = "dashboard/client/qrgen/text.js";
    const T = pick(f, "const TEXT ="), M = pick(f, "const MORE =");
    for (const l of ["en", "km"]) for (const [k, v] of Object.entries(M[l])) {
      if (v && typeof v === "object" && !Array.isArray(v) && T[l][k] && typeof T[l][k] === "object") Object.assign(T[l][k], v);
      else T[l][k] = v;
    }
    return T;
  })(),
  wb: { en: pick("dashboard/client/website/text.js", "const en ="), km: pick("dashboard/client/website/text.js", "const km =") },
  // website blocks: names, groups, field labels, choices
  wbk: (() => {
    const f = "wsite/blocks.js";
    const B = pick(f, "export const BLOCK_NAMES ="), G = pick(f, "export const GROUP_NAMES ="), F = pick(f, "export const FIELD_NAMES ="), C = pick(f, "export const CHOICE_NAMES =");
    const one = (l) => ({ block: B[l], group: G[l], field: F[l], choice: C[l] });
    return { en: one("en"), km: one("km") };
  })(),
  fb: pick("dashboard/client/flipbook/text.js", "const TEXT ="),
  mq: pick("dashboard/client/menuqr/text.js", "const TEXT ="),
  debt: { en: pick("dashboard/client/debt/text.js", "const en ="), km: pick("dashboard/client/debt/text.js", "const km =") },
  // Digital Note: the owner dashboard + public page words (text.js merges text2…text6 the same way)
  note: (() => {
    const d = "dashboard/client/note/";
    const parts = [["text.js", ""], ["text2.js", "2"], ["text3.js", "3"], ["text4.js", "4"], ["text5.js", "5"], ["text6.js", "6"]];
    const one = (l) => Object.assign({}, ...parts.map(([f, n]) => pick(d + f, n ? `export const ${l}${n} =` : `const ${l} =`)));
    return { en: one("en"), km: one("km") };
  })(),
  // Loyalty Stamp Card: the owner's words + the customer / desk pages' words
  sc: pick("dashboard/client/stamp/text.js", "const TEXT ="),
  scp: pick("stamp/text.js", "const TEXT ="),
  // Event Tickets: the owner's words + the public pages' words (event page, order, ticket, certificate)
  ev: pick("dashboard/client/event/text.js", "const TEXT ="),
  evp: pick("evpub/text.js", "const TEXT ="),
  // attendance looks: name + description per language
  atlook: (() => {
    const f = "attend/looks.js";
    const lists = { app: pick(f, "export const APP_LOOKS ="), qr: pick(f, "export const QR_LOOKS ="), kiosk: pick(f, "export const KIOSK_LOOKS =") };
    const one = (l) => Object.fromEntries(Object.entries(lists).map(([k, list]) => [k, Object.fromEntries(Object.entries(list).map(([key, v]) => [key, { name: v[l], what: l === "km" ? v.d_km : v.d_en }]))]));
    return { en: one("en"), km: one("km") };
  })(),
  // "Delete my account" (Google Play rule): the web's card on My account
  del: pick("dashboard/client/account/DeleteAccount.jsx", "export const DEL_TEXT ="),
  grc: pick("pos/guesthouse/GhReceipt.jsx", "const T ="),
  gdv: pick("pos/guesthouse/DisplayView.jsx", "const T ="),
};
// one flat map per language: section.key → text (nested objects keep their path)
const langs = {};
for (const lang of ["en", "km"]) {
  const flat = {};
  const put = (prefix, v) => {
    if (v && typeof v === "object" && !Array.isArray(v)) for (const [k, x] of Object.entries(v)) put(prefix ? `${prefix}.${k}` : k, x);
    else flat[prefix] = v;
  };
  for (const [sec, v] of Object.entries(out)) {
    put(sec, v[lang] ?? v);
  }
  langs[lang] = flat;
}
fs.mkdirSync(process.argv[3], { recursive: true });
for (const [lang, flat] of Object.entries(langs)) fs.writeFileSync(`${process.argv[3]}/${lang}.json`, JSON.stringify(flat, null, 1));
console.log(Object.keys(langs.en).length, "en keys,", Object.keys(langs.km).length, "km keys");
