# -*- coding: utf-8 -*-
"""
Build assets/questions.json from the first batch of text-layer PDF question banks.
Run from the repository root:
    python tools/build_question_bank.py --write
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import json
import os
import re
from collections import OrderedDict

import fitz

ROOT = r"D:\Downloads\电网"

BAD_STEM_PARTS = [
    "准考证号", "身份证号", "姓名:", "姓名：", "答题分析", "排行榜",
    "本次成绩", "试卷 公众号", "综合单选", "全部试题", "在线测评试卷",
    "试卷加载完毕", "您的分数是", "购资料加微信", "vivi视频模拟电网考试",
]

FOOTER_PARTS = [
    "vivi视频模拟电网考试", "在线测评试卷", "试卷加载完毕", "您的分数是",
    "购资料加微信", "公众号：", "扫码", "淘宝", "青云学堂",
]

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
WS_RE = re.compile(r"\s+")


def clean_line(line: str) -> str:
    s = line.strip()
    if not s:
        return ""
    if s == "|":
        return ""
    for bad in FOOTER_PARTS:
        if bad in s:
            return ""
    s = s.replace("|", " ")
    s = WS_RE.sub(" ", s).strip()
    return s


def extract_text(path: str) -> str:
    doc = fitz.open(path)
    parts = []
    for i in range(doc.page_count):
        try:
            parts.append(doc.load_page(i).get_text("text"))
        except Exception:
            parts.append("")
    doc.close()
    return "\n".join(parts)


def clean_text(text: str) -> str:
    lines = [clean_line(line) for line in text.splitlines()]
    return "\n".join(line for line in lines if line)


def norm_answer(raw: str) -> str:
    letters = re.findall(r"[A-Fa-f]", raw.upper())
    return "".join(sorted(set(letters)))


def clean_block_text(text: str) -> str:
    text = WS_RE.sub(" ", text)
    text = text.replace("您的答案", "")
    text = text.replace("正确答案", "")
    return text.strip(" ：:;；,，。|\t\r\n")


def has_bad_stem(stem: str) -> bool:
    if len(stem) < 5:
        return True
    for bad in BAD_STEM_PARTS:
        if bad in stem:
            return True
    return False


def parse_options(segment: str, multi_style: bool = False) -> list[dict]:
    options = []
    if multi_style:
        # 22学霸团 style: A. text B. text ...
        pattern = re.compile(r"(?m)([A-F])\s*[\.．、:：]\s*(.*?)(?=(?:\s+[A-F]\s*[\.．、:：])|\Z)", re.S)
    else:
        # vivi style: A、text B、text ...
        pattern = re.compile(r"([A-F])\s*[、.．:：]\s*(.*?)(?=(?:\s*[A-F]\s*[、.．:：])|\Z)", re.S)
    for m in pattern.finditer(segment):
        key = m.group(1).upper()
        content = WS_RE.sub(" ", m.group(2)).strip()
        content = content.strip(" ：:;；,，。|")
        if content:
            options.append({"key": key, "text": content})
    # dedupe
    dedup = OrderedDict()
    for o in options:
        if o["key"] not in dedup:
            dedup[o["key"]] = o
    return [dedup[k] for k in sorted(dedup.keys())]


def make_item(
    base_id: str,
    levels: list[str],
    subject_id: str,
    subject_name: str,
    chapter_id: str,
    chapter_name: str,
    qtype: str,
    stem: str,
    options: list[dict],
    answer: str,
    explanation: str,
    source_file: str,
    source_locator: str,
    confidence: float,
    images: list[str] | None = None,
) -> list[dict]:
    result = []
    if not answer or len(options) < 2:
        return result
    option_keys = {o["key"] for o in options}
    if any(ch not in option_keys for ch in answer):
        return result
    for level in levels:
        result.append({
            "id": base_id,
            "examLevel": level,
            "subjectId": subject_id,
            "subjectName": subject_name,
            "chapterId": chapter_id,
            "chapterName": chapter_name,
            "type": qtype,
            "stem": stem,
            "options": options,
            "answer": list(answer),
            "explanation": explanation,
            "difficulty": 1,
            "images": images or [],
            "imageStatus": "none",
            "sourceFile": source_file,
            "sourceLocator": source_locator,
            "reviewStatus": "auto",
            "confidence": confidence,
        })
    return result


# ---------------------------------------------------------------------------
# vivi mock papers: question + answer + explanation in one PDF
# ---------------------------------------------------------------------------

def parse_vivi_file(path: str, level: str, subject_id: str, subject_name: str, counter: list[int]):
    text = clean_text(extract_text(path))
    chapter_name = os.path.splitext(os.path.basename(path))[0]
    chapter_id = re.sub(r"[^0-9A-Za-z一-龥]+", "_", chapter_name).strip("_")
    chunks = re.split(r"(?=第\s*\d+\s*题)", text)
    items = []
    for chunk in chunks:
        m_num = re.match(r"\s*第\s*(\d+)\s*题", chunk)
        if not m_num:
            continue
        qnum = int(m_num.group(1))
        ans_m = re.search(r"正确答案\s*[：:]\s*([A-Fa-f][A-Fa-f\s、,，]*)", chunk)
        if not ans_m:
            continue
        answer = norm_answer(ans_m.group(1))
        if not answer:
            continue
        body = re.split(r"您的答案|正确答案", chunk)[0]
        first_opt = re.search(r"(?<![A-Za-z])A\s*[、.．:：]", body)
        if not first_opt:
            continue
        stem = body[:first_opt.start()]
        stem = re.sub(r"^\s*第\s*\d+\s*题.*?\n", "", stem, flags=re.S)
        stem = WS_RE.sub(" ", stem).strip(" )）(（：:;；,，。|")
        if has_bad_stem(stem):
            continue
        options = parse_options(body[first_opt.start():], multi_style=False)
        if len(options) < 2:
            continue
        # type
        qtype = "single"
        if len(answer) > 1:
            qtype = "multiple"
        elif len(options) == 2 and any("正确" in o["text"] for o in options) and any("错误" in o["text"] for o in options):
            qtype = "judge"
        exp_m = re.search(r"分析\s*[：:]\s*(.*)", chunk, re.S)
        explanation = ""
        if exp_m:
            explanation = WS_RE.sub(" ", exp_m.group(1)).strip()
            explanation = explanation.strip(" ：:;；,，。|")
            if explanation in ("无", "无解析", "略"):
                explanation = ""
        counter[0] += 1
        base_id = f"vivi_bk_{counter[0]:05d}"
        items.extend(make_item(
            base_id, [level], subject_id, subject_name, chapter_id, chapter_name,
            qtype, stem, options, answer, explanation, path, f"第{qnum}题", 0.85,
        ))
    return items


# ---------------------------------------------------------------------------
# 22学霸团-style: questions + answers + explanations in one PDF
# ---------------------------------------------------------------------------

def parse_xueba_file(path: str, level: str, subject_id: str, subject_name: str, counter: list[int]):
    text = clean_text(extract_text(path))
    chapter_name = os.path.splitext(os.path.basename(path))[0]
    chapter_id = re.sub(r"[^0-9A-Za-z一-龥]+", "_", chapter_name).strip("_")
    chunks = re.split(r"(?=^\s*\d+\s*\.\s*\[(?:单选题|多选题|判断题|单选|多选|判断)\])", text, flags=re.M)
    items = []
    for chunk in chunks:
        m_head = re.match(r"\s*(\d+)\s*\.\s*\[(单选题|多选题|判断题|单选|多选|判断)\]", chunk)
        if not m_head:
            continue
        qnum = int(m_head.group(1))
        qtype_raw = m_head.group(2)
        qtype = "single"
        if "多" in qtype_raw:
            qtype = "multiple"
        elif "判断" in qtype_raw:
            qtype = "judge"
        ans_m = re.search(r"正确答案\s*[:：]\s*[|\s]*([A-Fa-f][A-Fa-f\s、,，]*)", chunk, re.S)
        if not ans_m:
            continue
        answer = norm_answer(ans_m.group(1))
        if not answer:
            continue
        body = re.split(r"题目解析\s*[:：]", chunk)[0]
        first_opt = re.search(r"(?<![A-Za-z])A\s*[\.．、:：]\s*", body)
        if not first_opt:
            continue
        stem = body[m_head.end():first_opt.start()]
        stem = re.sub(r"考生答案.*?分数\s*[:：]\s*[\d./]+分", " ", stem, flags=re.S)
        stem = WS_RE.sub(" ", stem).strip(" )）(（：:;；,，。|")
        # remove score tail
        stem = re.sub(r"\(\s*\d+(?:\.\d+)?\s*分\s*\)\s*$", "", stem).strip()
        if has_bad_stem(stem):
            continue
        options = parse_options(body[first_opt.start():], multi_style=True)
        if len(options) < 2:
            continue
        if qtype == "single" and len(answer) > 1:
            qtype = "multiple"
        if qtype == "judge" and len(options) == 2:
            pass
        exp_m = re.search(r"题目解析\s*[:：]\s*(.*)", chunk, re.S)
        explanation = ""
        if exp_m:
            explanation = WS_RE.sub(" ", exp_m.group(1)).strip()
            explanation = explanation.strip(" ：:;；,，。|")
            if explanation in ("无解析", "无", "略"):
                explanation = ""
        counter[0] += 1
        base_id = f"xueba_bk_{counter[0]:05d}"
        items.extend(make_item(
            base_id, [level], subject_id, subject_name, chapter_id, chapter_name,
            qtype, stem, options, answer, explanation, path, f"第{qnum}题", 0.85,
        ))
    return items


# ---------------------------------------------------------------------------
# ly pair: question PDF + answer PDF matched by question id
# ---------------------------------------------------------------------------

def parse_ly_questions(path: str) -> dict:
    text = clean_text(extract_text(path))
    result = {}
    chunks = re.split(r"(?=^\s*\d+\.\s*【[^】]+】)", text, flags=re.M)
    for chunk in chunks:
        m = re.match(r"\s*(\d+)\.\s*【([^】]+)】\s*(.*)", chunk, re.S)
        if not m:
            continue
        qnum = int(m.group(1))
        qid = m.group(2).strip()
        body = m.group(3)
        first_opt = re.search(r"(?<![A-Za-z])A\s*[\.．、:：]\s*", body)
        if not first_opt:
            continue
        stem = body[:first_opt.start()]
        stem = WS_RE.sub(" ", stem).strip(" ：:;；,，。|")
        options = parse_options(body[first_opt.start():], multi_style=True)
        if len(options) < 2 or has_bad_stem(stem):
            continue
        result[qid] = {"qnum": qnum, "stem": stem, "options": options}
    return result


def parse_ly_answers(path: str) -> dict:
    text = clean_text(extract_text(path))
    result = {}
    chunks = re.split(r"(?=^\s*\d+\.\s*【[^】]+】)", text, flags=re.M)
    for chunk in chunks:
        m = re.match(r"\s*(\d+)\.\s*【([^】]+)】\s*(.*)", chunk, re.S)
        if not m:
            continue
        qnum = int(m.group(1))
        qid = m.group(2).strip()
        body = m.group(3)
        ans_m = re.search(r"【答案】\s*([A-Fa-f][A-Fa-f\s、,，]*)", body)
        if not ans_m:
            ans_m = re.search(r"^\s*([A-Fa-f][A-Fa-f\s、,，]*)\s*【答案】", body, re.S)
        if not ans_m:
            continue
        answer = norm_answer(ans_m.group(1))
        if not answer:
            continue
        exp_m = re.search(r"【解析】\s*(.*)", body, re.S)
        explanation = ""
        if exp_m:
            explanation = WS_RE.sub(" ", exp_m.group(1)).strip(" ：:;；,，。|")
            if explanation in ("无", "无解析", "略"):
                explanation = ""
        result[qid] = {"qnum": qnum, "answer": answer, "explanation": explanation}
    return result


def parse_ly_pair(q_path: str, a_path: str, subject_id: str, subject_name: str, chapter_id: str,
                  chapter_name: str, levels: list[str], counter: list[int]):
    questions = parse_ly_questions(q_path)
    answers = parse_ly_answers(a_path)
    items = []
    for qid, q in questions.items():
        a = answers.get(qid)
        if not a:
            continue
        qtype = "multiple" if len(a["answer"]) > 1 else "single"
        if len(q["options"]) == 2 and any("正确" in o["text"] for o in q["options"]) and any("错误" in o["text"] for o in q["options"]):
            qtype = "judge"
        counter[0] += 1
        base_id = f"ly_{counter[0]:05d}"
        items.extend(make_item(
            base_id, levels, subject_id, subject_name, chapter_id, chapter_name,
            qtype, q["stem"], q["options"], a["answer"], a["explanation"],
            q_path, f"题号 {q['qnum']} / id {qid}", 0.95,
        ))
    return items


# ---------------------------------------------------------------------------
# Image extraction
# ---------------------------------------------------------------------------

IMAGE_HINTS = [
    "如图", "如图所示", "所示", "如下图", "下图", "上图", "图片",
    "波形图", "电路图", "相量图", "示意图", "结构图", "图1", "图2",
    "（图", "(图", "如上图",
]


def has_image_hint(item: dict) -> bool:
    text = item.get("stem", "")
    for opt in item.get("options", []):
        text += " " + opt.get("text", "")
    return any(hint in text for hint in IMAGE_HINTS)


def safe_image_name(item: dict) -> str:
    raw = f"{item.get('id', 'q')}_{item.get('sourceLocator', '')}"
    return re.sub(r"[^0-9A-Za-z._-]+", "_", raw).strip("_")[:120] + ".png"


def _source_type(item: dict) -> str:
    sid = item.get("subjectId", "")
    if sid == "sub_vivi_mock":
        return "vivi"
    if sid == "sub_xueba_mock":
        return "xueba"
    if sid in ("sub_power_system", "sub_relay", "sub_high_voltage"):
        return "ly"
    return "unknown"


def find_header_rect(doc, qnum, qid=None, source_type="unknown"):
    headers = []
    if source_type == "vivi":
        headers = [f"第{qnum}题"]
    elif source_type == "xueba":
        headers = [
            f"{qnum}. [单选题]", f"{qnum}. [多选题]", f"{qnum}. [判断题]",
            f"{qnum}.", f"{qnum}．",
        ]
    elif source_type == "ly":
        if qid:
            headers = [f"{qnum}.【{qid}】", qid]
        else:
            headers = [f"{qnum}."]
    else:
        headers = [str(qnum)]

    for page_index in range(doc.page_count):
        page = doc.load_page(page_index)
        for header in headers:
            if not header:
                continue
            rects = page.search_for(header)
            if rects:
                return page_index, page, rects[0]
    return None, None, None


def find_next_rect(doc, start_page_index, qnum, source_type):
    if source_type == "vivi":
        patterns = [f"第{qnum + 1}题"]
    elif source_type == "xueba":
        patterns = [
            f"{qnum + 1}. [单选题]", f"{qnum + 1}. [多选题]",
            f"{qnum + 1}. [判断题]", f"{qnum + 1}.", f"{qnum + 1}．",
        ]
    elif source_type == "ly":
        patterns = [f"{qnum + 1}.【", f"{qnum + 1}."]
    else:
        patterns = [str(qnum + 1)]

    for page_index in range(start_page_index, doc.page_count):
        page = doc.load_page(page_index)
        for pattern in patterns:
            rects = page.search_for(pattern)
            if rects:
                return page_index, rects[0]
    return None, None


def attach_images(all_items, assets_root):
    os.makedirs(assets_root, exist_ok=True)
    cache = {}
    attached = 0
    skipped = 0

    for item in all_items:
        if not has_image_hint(item):
            item["images"] = []
            item["imageStatus"] = "none"
            continue

        source_file = item.get("sourceFile") or ""
        source_locator = item.get("sourceLocator") or ""
        qnum_match = re.search(r"(\d+)", source_locator)
        qnum = int(qnum_match.group(1)) if qnum_match else None
        qid_match = re.search(r"id\s+([^,\s]+)", source_locator)
        qid = qid_match.group(1) if qid_match else None
        stype = _source_type(item)

        if not source_file or qnum is None:
            item["images"] = []
            item["imageStatus"] = "not_found"
            skipped += 1
            continue

        key = (source_file, qnum, qid, stype)
        if key in cache:
            item["images"] = cache[key]
            item["imageStatus"] = "cropped" if cache[key] else "not_found"
            continue

        try:
            doc = fitz.open(source_file)
            page_index, page, rect = find_header_rect(doc, qnum, qid=qid, source_type=stype)
            if page is None:
                for pi in range(doc.page_count):
                    p = doc.load_page(pi)
                    if qid and p.search_for(qid):
                        page_index, page, rect = pi, p, fitz.Rect(0, 0, p.rect.width, p.rect.height)
                        break
                    if (not qid) and p.search_for(str(qnum)):
                        page_index, page, rect = pi, p, fitz.Rect(0, 0, p.rect.width, p.rect.height)
                        break

            if page is None:
                doc.close()
                item["images"] = []
                item["imageStatus"] = "not_found"
                cache[key] = []
                skipped += 1
                continue

            start_y = max(0, rect.y0 - 10)
            next_page_index, next_rect = find_next_rect(doc, page_index, qnum, stype)
            if next_page_index == page_index and next_rect is not None:
                end_y = min(page.rect.height, next_rect.y0 - 10)
            else:
                end_y = page.rect.height
            if end_y <= start_y + 20:
                end_y = page.rect.height

            clip = fitz.Rect(0, start_y, page.rect.width, end_y)
            filename = safe_image_name(item)
            out_path = os.path.join(assets_root, filename)
            pix = page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5), clip=clip)
            pix.save(out_path)
            pix = None
            doc.close()

            asset_path = "assets/question_images/" + filename
            item["images"] = [asset_path]
            item["imageStatus"] = "cropped"
            cache[key] = [asset_path]
            attached += 1
        except Exception:
            item["images"] = []
            item["imageStatus"] = "error"
            cache[key] = []
            skipped += 1

    return attached, skipped


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build():
    all_items = []
    counter = [0]
    report = []

    # vivi本科
    vivi_dir = os.path.join(ROOT, r"新考纲vivi模拟卷本科")
    for path in sorted(glob.glob(os.path.join(vivi_dir, "*.pdf"))):
        items = parse_vivi_file(path, "本科", "sub_vivi_mock", "vivi模拟卷", counter)
        all_items.extend(items)
        report.append({"source_type": "vivi", "file": path, "imported": len(items), "note": "本科；题+答案+解析在同一 PDF"})

    # 22学霸团
    xueba_dir = os.path.join(ROOT, r"22学霸团8套模拟卷（后面带答案）\本科")
    for path in sorted(glob.glob(os.path.join(xueba_dir, "*.pdf"))):
        items = parse_xueba_file(path, "本科", "sub_xueba_mock", "学霸团模拟卷", counter)
        all_items.extend(items)
        report.append({"source_type": "xueba", "file": path, "imported": len(items), "note": "本科；部分图片题已跳过"})

    # ly pairs
    ly_base = os.path.join(ROOT, r"ly题库\25ly协议班模拟卷")
    ly_pairs = [
        ("电分-题库文档.pdf", "电分-答案文档.pdf", "sub_power_system", "电力系统分析", "ch_ly_edian", "25ly协议班模拟卷"),
        ("继保-题库文档.pdf", "继保-答案文档.pdf", "sub_relay", "继电保护", "ch_ly_jibao", "25ly协议班模拟卷"),
        ("高压硕士-题库文档.pdf", "高压硕士-答案文档.pdf", "sub_high_voltage", "高电压技术", "ch_ly_hv_master", "25ly协议班模拟卷硕士"),
    ]
    for q_name, a_name, sid, sname, cid, cname in ly_pairs:
        q_path = os.path.join(ly_base, q_name)
        a_path = os.path.join(ly_base, a_name)
        if not os.path.exists(q_path) or not os.path.exists(a_path):
            continue
        levels = ["硕士"] if "硕士" in q_name else ["专科", "本科", "硕士"]
        items = parse_ly_pair(q_path, a_path, sid, sname, cid, cname, levels, counter)
        all_items.extend(items)
        report.append({"source_type": "ly", "file": q_path, "imported": len(items), "note": "题库+答案；非硕士默认按通用加入三个层次"})

    # 高压 本科/通用 copy
    alt_base = os.path.join(ROOT, r"1\25模拟卷\25珞研协议班模拟卷")
    q_path = os.path.join(alt_base, "高压-题库文档.pdf")
    a_path = os.path.join(alt_base, "高压-答案文档.pdf")
    if os.path.exists(q_path) and os.path.exists(a_path):
        items = parse_ly_pair(q_path, a_path, "sub_high_voltage", "高电压技术", "ch_ly_hv", "25ly协议班模拟卷", ["专科", "本科", "硕士"], counter)
        all_items.extend(items)
        report.append({"source_type": "ly", "file": q_path, "imported": len(items), "note": "题库+答案；通用层次"})

    assets_root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "question_images")
    attached, skipped = attach_images(all_items, assets_root)
    report.append({"source_type": "images", "file": assets_root, "imported": attached, "note": f"自动裁图成功 {attached} 张，失败 {skipped} 张"})

    # group into app JSON schema
    subjects = OrderedDict()
    for item in all_items:
        sid = item["subjectId"]
        if sid not in subjects:
            subjects[sid] = {
                "id": sid,
                "name": item["subjectName"],
                "chapters": OrderedDict(),
            }
        subj = subjects[sid]
        cid = item["chapterId"]
        if cid not in subj["chapters"]:
            subj["chapters"][cid] = {
                "id": cid,
                "name": item["chapterName"],
                "questions": [],
            }
        subj["chapters"][cid]["questions"].append(item)

    data = {
        "version": 1,
        "appName": "国家电网刷题助手",
        "generatedAt": dt.datetime.now().isoformat(timespec="seconds"),
        "examLevels": ["专科", "本科", "硕士", "通用"],
        "subjects": [],
    }
    for subj in subjects.values():
        chapters = []
        for ch in subj["chapters"].values():
            ch["questions"].sort(key=lambda x: x["id"])
            chapters.append(ch)
        chapters.sort(key=lambda x: x["name"])
        subj["chapters"] = chapters
        data["subjects"].append(subj)
    data["subjects"].sort(key=lambda x: x["name"])

    return data, report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="write assets/questions.json and assets/import_report.csv")
    args = parser.parse_args()
    data, report = build()
    total = sum(len(ch["questions"]) for subj in data["subjects"] for ch in subj["chapters"])
    print("TOTAL_QUESTIONS", total)
    for r in report:
        print(r["source_type"], r["imported"], os.path.basename(r["file"]))
    if args.write:
        assets = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
        os.makedirs(assets, exist_ok=True)
        with open(os.path.join(assets, "questions.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        with open(os.path.join(assets, "import_report.csv"), "w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=["source_type", "file", "imported", "note"])
            w.writeheader()
            w.writerows(report)
        print("WROTE", len(data["subjects"]), "subjects", total, "questions")


if __name__ == "__main__":
    main()