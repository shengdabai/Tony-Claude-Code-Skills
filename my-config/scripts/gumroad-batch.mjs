#!/usr/bin/env node
// 批量在 Gumroad 建 E-book 产品草稿（含 PDF 上传），读 /tmp/books.json，进度存 /tmp/gumroad-progress.json
// 用法: node gumroad-batch.mjs [maxCount]   maxCount 限制本次建几本(测试用)，省略=全部
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const PORT = Number(process.env.GUMROAD_PORT || 9222), HOST = process.env.GUMROAD_HOST || "127.0.0.1";
const DATA = process.env.GUMROAD_DATA || path.join(os.homedir(), ".claude/scripts/gumroad-data");
const PROGRESS = path.join(DATA, "gumroad-progress.json");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const books = JSON.parse(fs.readFileSync(path.join(DATA, "books.json"), "utf8"));
let done = {};
try { done = JSON.parse(fs.readFileSync(PROGRESS, "utf8")); } catch {}

async function listTargets() { return await (await fetch(`http://${HOST}:${PORT}/json/list`)).json(); }
async function pickGumroad() {
  const l = await listTargets();
  return l.find((t) => /gumroad/.test(t.url || "") && t.type === "page") || l.find((t) => t.type === "page");
}
function connect(wsUrl) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(wsUrl);
    let id = 0; const p = new Map();
    ws.addEventListener("message", (m) => { const d = JSON.parse(m.data); if (d.id && p.has(d.id)) { p.get(d.id)(d); p.delete(d.id); } });
    ws.addEventListener("open", () => res({
      send: (m, pr = {}) => new Promise((rs, rj) => { const i = ++id; p.set(i, rs); ws.send(JSON.stringify({ id: i, method: m, params: pr })); setTimeout(() => { if (p.has(i)) { p.delete(i); rj(new Error("timeout " + m)); } }, 45000); }),
      close: () => ws.close(),
    }));
    ws.addEventListener("error", () => rej(new Error("ws err")));
    setTimeout(() => rej(new Error("open timeout")), 8000);
  });
}
async function ev(c, expr) { const r = await c.send("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true }); return r.result?.result?.value; }
async function evObj(c, expr) { const r = await c.send("Runtime.evaluate", { expression: expr, returnByValue: false }); return r.result?.result?.objectId; }
function setValExpr(sel, val) {
  return `(()=>{const el=document.querySelector(${JSON.stringify(sel)});if(!el)return "NF";const P=el.tagName==="TEXTAREA"?HTMLTextAreaElement:HTMLInputElement;const s=Object.getOwnPropertyDescriptor(P.prototype,"value").set;s.call(el,${JSON.stringify(val)});el.dispatchEvent(new Event("input",{bubbles:true}));el.dispatchEvent(new Event("change",{bubbles:true}));return String(el.value).slice(0,30);})()`;
}

async function createOne(book) {
  const page = await pickGumroad();
  const c = await connect(page.webSocketDebuggerUrl);
  await c.send("Page.enable"); await c.send("Runtime.enable"); await c.send("DOM.enable");
  // 1. 新建产品页
  await c.send("Page.navigate", { url: "https://gumroad.com/products/new" });
  await sleep(5000);
  // 2. 选 E-book
  await ev(c, `(()=>{const b=[...document.querySelectorAll("button")].find(x=>/^E-book/.test((x.innerText||"").trim()));if(b)b.click();})()`);
  await sleep(900);
  // 3. name + price
  await ev(c, setValExpr('input[id^="name-"]', book.name));
  await ev(c, setValExpr('input[id^="price-"]', String(book.price)));
  await sleep(600);
  // 4. Next: Customize
  await ev(c, `[...document.querySelectorAll("button")].find(x=>/Next:\\s*Customize/.test(x.innerText||""))?.click()`);
  await sleep(7000);
  const url = await ev(c, "location.href");
  const m = String(url).match(/products\/([^/]+)\/edit/);
  const permalink = m ? m[1] : null;
  if (!permalink) { c.close(); throw new Error("no permalink, url=" + url); }
  // 5. 描述
  const f = await ev(c, `(()=>{const e=document.querySelector('[aria-label="Description"]');if(!e)return "NO";e.focus();const r=document.createRange();r.selectNodeContents(e);r.collapse(false);const s=getSelection();s.removeAllRanges();s.addRange(r);return "ok";})()`);
  if (f === "ok") await c.send("Input.insertText", { text: book.desc });
  await sleep(500);
  // 6. 封面
  if (book.cover && fs.existsSync(book.cover)) {
    await ev(c, `(()=>{const ins=[...document.querySelectorAll("input[type=file]")].filter(e=>/png|jpe?g/.test(e.accept));const cc=ins[ins.length-1];if(cc)cc.id="__cover_input";})()`);
    const oid = await evObj(c, `document.querySelector("#__cover_input")`);
    if (oid) { await c.send("DOM.setFileInputFiles", { objectId: oid, files: [book.cover] }); await sleep(4500); }
  }
  // 7. Save and continue → content
  await ev(c, `[...document.querySelectorAll("button")].find(x=>/Save and continue/i.test(x.innerText||""))?.click()`);
  await sleep(6000);
  // 8. 上传 PDF：navigate 干净加载 content 页（关键），拦截 + click input + setFiles
  await c.send("Page.navigate", { url: `https://gumroad.com/products/${permalink}/edit/content` });
  await sleep(5500);
  await c.send("Page.setInterceptFileChooserDialog", { enabled: true });
  await ev(c, `(()=>{const i=document.querySelector("input[type=file]");if(i)i.click();})()`);
  await sleep(1500);
  const oid2 = await evObj(c, `document.querySelector("input[type=file]")`);
  if (oid2) await c.send("DOM.setFileInputFiles", { objectId: oid2, files: [book.pdf] });
  await c.send("Page.setInterceptFileChooserDialog", { enabled: false });
  // 等上传完成（%of 文字消失）
  let uploaded = false;
  for (let i = 0; i < 40; i++) {
    await sleep(1500);
    const up = await ev(c, `/\\d+%\\s*of/i.test(document.body.innerText)`);
    if (!up) {
      const hasFile = await ev(c, `/Download/i.test(document.body.innerText)`);
      if (hasFile) { uploaded = true; break; }
    }
  }
  await sleep(1000);
  // 9. Save changes
  await ev(c, `[...document.querySelectorAll("button")].find(x=>/Save changes/i.test(x.innerText||""))?.click()`);
  await sleep(3500);
  c.close();
  return { permalink, uploaded };
}

(async () => {
  const max = process.argv[2] ? Number(process.argv[2]) : Infinity;
  let count = 0;
  for (const book of books) {
    if (done[book.pdf] && done[book.pdf].permalink) { console.log("SKIP done:", book.name); continue; }
    if (count >= max) break;
    count++;
    try {
      const r = await createOne(book);
      done[book.pdf] = { permalink: r.permalink, uploaded: r.uploaded, name: book.name, price: book.price };
      fs.writeFileSync(PROGRESS, JSON.stringify(done, null, 2));
      console.log(`✓ [${r.permalink}] ${r.uploaded ? "FILE✓" : "FILE?"} $${book.price} ${book.name}`);
    } catch (e) {
      done[book.pdf] = { error: e.message, name: book.name };
      fs.writeFileSync(PROGRESS, JSON.stringify(done, null, 2));
      console.log(`✗ FAIL ${book.name} — ${e.message}`);
    }
  }
  const ok = Object.values(done).filter((x) => x.permalink).length;
  console.log(`\nBATCH DONE this run: ${count} | total created: ${ok}/${books.length}`);
})();
