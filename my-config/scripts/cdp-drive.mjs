#!/usr/bin/env node
// CDP 驱动 — node 原生 WS 直驱 Chrome 9222，绕过 web-access proxy 在 Chrome 148 上的 WS bug
// 用法:
//   node cdp-drive.mjs targets
//   node cdp-drive.mjs current
//   node cdp-drive.mjs nav <url> [waitMs]
//   node cdp-drive.mjs eval '<js表达式>'
//   node cdp-drive.mjs shot [file]
//   node cdp-drive.mjs click '<selector>'
//   node cdp-drive.mjs settext '<selector>' <text...>      # React 安全赋值(触发 input/change)
//   node cdp-drive.mjs upload '<selector>' <filepath>       # 文件上传(DOM.setFileInputFiles)
//   node cdp-drive.mjs waitfor '<selector>' [timeoutMs]
//   node cdp-drive.mjs dumpforms                            # 列出表单字段，帮助定位
// 环境变量: CDP_PORT(默认9222) CDP_TID(指定 page target id)
import fs from "node:fs";

const PORT = process.env.CDP_PORT || 9222;
const HOST = "127.0.0.1";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function listTargets() {
  const r = await fetch(`http://${HOST}:${PORT}/json/list`);
  return await r.json();
}

async function pickPage() {
  const list = await listTargets();
  const pages = list.filter((t) => t.type === "page");
  if (process.env.CDP_TID) {
    const m = pages.find((p) => p.id === process.env.CDP_TID);
    if (m) return m;
  }
  const g = pages.find((p) => /gumroad/.test(p.url || ""));
  if (g) return g;
  return pages[0];
}

function connect(wsUrl) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(wsUrl);
    let id = 0;
    const pending = new Map();
    ws.addEventListener("message", (m) => {
      const d = JSON.parse(m.data);
      if (d.id && pending.has(d.id)) {
        pending.get(d.id)(d);
        pending.delete(d.id);
      }
    });
    ws.addEventListener("open", () =>
      res({
        send: (method, params = {}) =>
          new Promise((rs, rj) => {
            const i = ++id;
            pending.set(i, rs);
            ws.send(JSON.stringify({ id: i, method, params }));
            setTimeout(() => {
              if (pending.has(i)) {
                pending.delete(i);
                rj(new Error("cmd timeout " + method));
              }
            }, 30000);
          }),
        close: () => ws.close(),
      })
    );
    ws.addEventListener("error", () => rej(new Error("ws error")));
    setTimeout(() => rej(new Error("ws open timeout")), 6000);
  });
}

async function evalVal(c, expr) {
  const r = await c.send("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.result?.exceptionDetails) return { __exception: r.result.exceptionDetails.text || "eval error" };
  return r.result?.result?.value;
}
async function evalObj(c, expr) {
  const r = await c.send("Runtime.evaluate", { expression: expr, returnByValue: false, awaitPromise: true });
  return r.result?.result?.objectId;
}

const [, , cmd, ...args] = process.argv;

(async () => {
  const page = await pickPage();
  if (!page) {
    console.log(JSON.stringify({ error: "no page target" }));
    process.exit(1);
  }
  const c = await connect(page.webSocketDebuggerUrl);
  await c.send("Page.enable");
  await c.send("Runtime.enable");
  await c.send("DOM.enable");
  let out;

  if (cmd === "targets") {
    out = (await listTargets()).map((t) => ({ id: t.id, type: t.type, url: t.url }));
  } else if (cmd === "current") {
    out = { url: await evalVal(c, "location.href"), title: await evalVal(c, "document.title") };
  } else if (cmd === "nav") {
    await c.send("Page.navigate", { url: args[0] });
    await sleep(Number(args[1] || 4000));
    out = { url: await evalVal(c, "location.href"), title: await evalVal(c, "document.title") };
  } else if (cmd === "eval") {
    out = await evalVal(c, args.join(" "));
  } else if (cmd === "shot") {
    const s = await c.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: true });
    const f = args[0] || "/tmp/cdp.png";
    fs.writeFileSync(f, Buffer.from(s.result.data, "base64"));
    out = { saved: f };
  } else if (cmd === "click") {
    out = await evalVal(
      c,
      `(()=>{const el=document.querySelector(${JSON.stringify(args[0])});if(!el)return "NOT_FOUND";el.scrollIntoView({block:"center"});el.click();return "clicked";})()`
    );
  } else if (cmd === "settext") {
    const sel = args[0];
    const text = args.slice(1).join(" ");
    out = await evalVal(
      c,
      `(()=>{const el=document.querySelector(${JSON.stringify(sel)});if(!el)return "NOT_FOUND";const proto=el.tagName==="TEXTAREA"?window.HTMLTextAreaElement.prototype:window.HTMLInputElement.prototype;const setter=Object.getOwnPropertyDescriptor(proto,"value").set;setter.call(el,${JSON.stringify(text)});el.dispatchEvent(new Event("input",{bubbles:true}));el.dispatchEvent(new Event("change",{bubbles:true}));el.blur&&el.blur();return "set:"+String(el.value).slice(0,40);})()`
    );
  } else if (cmd === "upload") {
    const sel = args[0];
    const file = args[1];
    const objectId = await evalObj(c, `document.querySelector(${JSON.stringify(sel)})`);
    if (!objectId) out = { error: "input not found: " + sel };
    else {
      await c.send("DOM.setFileInputFiles", { objectId, files: [file] });
      out = { uploaded: file };
    }
  } else if (cmd === "waitfor") {
    const sel = args[0];
    const to = Number(args[1] || 10000);
    const start = Date.now();
    let found = false;
    while (Date.now() - start < to) {
      const ok = await evalVal(c, `!!document.querySelector(${JSON.stringify(sel)})`);
      if (ok) {
        found = true;
        break;
      }
      await sleep(400);
    }
    out = { found, waited: Date.now() - start };
  } else if (cmd === "dumpforms") {
    out = await evalVal(
      c,
      `JSON.stringify([...document.querySelectorAll("input,textarea,select,[contenteditable=true],[role=textbox],button")].slice(0,80).map(e=>({tag:e.tagName,type:e.type||"",name:e.name||"",id:e.id||"",ph:e.placeholder||"",aria:e.getAttribute("aria-label")||"",txt:(e.innerText||e.value||"").slice(0,30)})))`
    );
  } else if (cmd === "richtext") {
    // selector, file —— focus contenteditable 并用 CDP Input.insertText 插入文件内容(适配 ProseMirror/TipTap)
    const sel = args[0];
    const file = args[1];
    const text = fs.readFileSync(file, "utf8");
    const f = await evalVal(
      c,
      `(()=>{const e=document.querySelector(${JSON.stringify(sel)});if(!e)return "NO_EL";e.focus();const r=document.createRange();r.selectNodeContents(e);r.collapse(false);const s=getSelection();s.removeAllRanges();s.addRange(r);return "focused";})()`
    );
    if (f === "NO_EL") out = { error: "editor not found: " + sel };
    else {
      await c.send("Input.insertText", { text });
      out = { inserted: text.length + " chars" };
    }
  } else {
    out = { error: "unknown cmd: " + cmd };
  }

  c.close();
  console.log(typeof out === "string" ? out : JSON.stringify(out));
  process.exit(0);
})().catch((e) => {
  console.log(JSON.stringify({ error: e.message }));
  process.exit(1);
});
