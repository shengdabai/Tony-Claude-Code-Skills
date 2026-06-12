#!/usr/bin/env node
// 扫描 Z Turns 中文教材，提取标题、按系列定价、生成描述与封面，输出 /tmp/books.json
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const BASE = "$HOME/Desktop/项目开发/05-中文教学项目/04-中文教材生成工具/中文教材";
const COVERS = "/tmp/covers";
fs.mkdirSync(COVERS, { recursive: true });

// series: dir, price, template(convo|grammar)
const SERIES = [
  { name: "Amazon畅销系列", dir: `${BASE}/Amazon_KD畅销系列/新版`, price: "7.99", tpl: "convo" },
  { name: "自信表达专题", dir: `${BASE}/自信中文表达专题系列`, price: "9.99", tpl: "convo" },
  { name: "中文易错系列", dir: `${BASE}/中文易错电子书系列`, price: "7.99", tpl: "grammar" },
  { name: "Real-Life旗舰", dir: `${BASE}/30个真实场景`, price: "19.99", tpl: "convo" },
];

function findPdfs(dir) {
  const out = [];
  (function walk(d) {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const fp = path.join(d, e.name);
      if (e.isDirectory()) walk(fp);
      else if (/\.pdf$/i.test(e.name)) out.push(fp);
    }
  })(dir);
  return out.sort();
}

function titleLines(pdf) {
  try {
    return execFileSync("pdftotext", ["-f", "2", "-l", "2", pdf, "-"], { encoding: "utf8" })
      .split("\n").map((x) => x.trim()).filter(Boolean);
  } catch { return []; }
}

function parseTitle(lines, pdf) {
  const line1 = lines[0] || path.basename(pdf, ".pdf");
  const line2 = lines[1] && !/^(Author:|Website:|Series:|©)/.test(lines[1]) ? lines[1] : "";
  return { line1, line2 };
}

function makeName(line1, line2) {
  let name = line1;
  if (line2 && / · /.test(line2)) {
    // 取含字母最多的段作英文副标
    const eng = line2.split(" · ").map((s) => s.trim())
      .filter((p) => /[A-Za-z]/.test(p))
      .sort((a, b) => (b.match(/[A-Za-z]/g) || []).length - (a.match(/[A-Za-z]/g) || []).length)[0];
    if (eng && eng.length < 80) name = `${line1} — ${eng}`;
  }
  return name.slice(0, 120);
}

function makeDesc(tpl, line1, line2) {
  const titleLine = line1 + (line2 ? ` · ${line2}` : "");
  if (tpl === "grammar") {
    return [
      "Stop making the same Chinese mistakes.",
      "",
      "This bilingual e-book targets a grammar point English-speaking learners get wrong most often — and fixes it with clear contrasts, real-life examples, and focused drills.",
      "",
      "Each topic breaks down the rule, shows the mistakes learners actually make, and drills the correct pattern until it sticks. Every example comes with pinyin and English.",
      "",
      "Practical, focused, and built for fast improvement.",
      "",
      titleLine,
      "Z Turns Chinese · zturnsgo.com",
      "",
    ].join("\n");
  }
  return [
    "Speak real Chinese from day one.",
    "",
    "This bilingual e-book turns everyday situations into Chinese you can actually use. Natural dialogues, high-frequency patterns, and practical drills, built for English-speaking adult learners.",
    "",
    "Every topic is a complete lesson: core vocabulary and power sentences, a dialogue lab with substitution and shadowing practice, plus culture notes, common mistakes, and a review checklist.",
    "",
    "Every phrase comes with pinyin and English, so you can read it and say it correctly from day one.",
    "",
    titleLine,
    "Z Turns Chinese · zturnsgo.com",
    "",
  ].join("\n");
}

const books = [];
let idx = 0;
for (const s of SERIES) {
  if (!fs.existsSync(s.dir)) { console.error("MISSING DIR:", s.dir); continue; }
  for (const pdf of findPdfs(s.dir)) {
    idx++;
    const { line1, line2 } = parseTitle(titleLines(pdf), pdf);
    const name = makeName(line1, line2);
    const desc = makeDesc(s.tpl, line1, line2);
    const slug = "cover-" + idx;
    try { execFileSync("pdftoppm", ["-png", "-f", "1", "-l", "1", "-r", "150", pdf, `${COVERS}/${slug}`]); } catch {}
    let cover = "";
    for (const suf of ["-1.png", "-01.png", ".png"]) {
      if (fs.existsSync(`${COVERS}/${slug}${suf}`)) { cover = `${COVERS}/${slug}${suf}`; break; }
    }
    books.push({ series: s.name, price: s.price, pdf, name, line1, line2, desc, cover });
  }
}

fs.writeFileSync("/tmp/books.json", JSON.stringify(books, null, 2));
console.log("TOTAL BOOKS:", books.length);
books.forEach((b, i) => console.log(`${String(i + 1).padStart(2)}. [$${b.price}] ${b.name}  | cover:${b.cover ? "ok" : "MISSING"}`));
