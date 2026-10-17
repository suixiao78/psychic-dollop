# -*- coding: utf-8 -*-
"""
Import 2027 public & industry knowledge bank into assets/questions.json.
Run from repo root:
    python tools/import_2027_public_bank.py --write
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
from collections import OrderedDict

import fitz

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
PDF_PATH = r"D:\Downloads\9.国家电网有限公司高校毕业生招聘考试公共与行业知识题库（2027版）.pdf"

SUBJECT_ID = "sub_public_industry"
SUBJECT_NAME = "公共与行业知识"
CHAPTER_ID = "ch_public_2027"
CHAPTER_NAME = "2027版公共与行业知识题库"


def clean_text(text: str) -> str:
    text = re.sub(r"第\s*\d+\s*页\s*/\s*\d+\s*页", "", text)
    text = text.replace("国家电网有限公司高校毕业生招聘考试", "")
    text = text.replace("公共与行业知识题库", "")
    text = text.replace("\xa0", " ")
    text = re.sub(r"[ \t]+", " ", text)
    return text


def normalize_answer(raw: str) -> str:
    raw = raw.strip()
    if raw in ("正确", "对", "", "A", "a"):
        return "A"
    if raw in ("错误", "错", "", "B", "b"):
        return "B"
    return "".join(sorted(set(re.findall(r"[A-Fa-f]", raw.upper()))))


def parse_options(body: str):
    body = re.split(r"答案\s*[：:]", body)[0]
    first = re.search(r"A\s*[\.\、．:：]\s*", body)
    if not first:
        return "", []
    stem = body[:first.start()]
    option_text = body[first.start():]
    pattern = re.compile(
        r"([A-F])\s*[\.\、．:：]\s*(.*?)(?=(?:\s*[A-F]\s*[\.\、．:：])|\Z)",
        re.S,
    )
    options = []
    for m in pattern.finditer(option_text):
        content = re.sub(r"\s+", " ", m.group(2)).strip(" ：:;；,，。|")
        if content:
            options.append({"key": m.group(1), "text": content})
    dedup = OrderedDict()
    for o in options:
        dedup.setdefault(o["key"], o)
    return stem, [dedup[k] for k in sorted(dedup.keys())]


def parse_pdf(path: str):
    doc = fitz.open(path)
    text = "\n".join(doc.load_page(i).get_text("text") for i in range(doc.page_count))
    doc.close()
    text = clean_text(text)

    sections = []
    for m in re.finditer(
        r"(?m)^\s*[一二三四五六七八九十]+\s*[、.．]\s*(单选题|多选题|判断题|选择题)",
        text,
    ):
        sections.append((m.start(), m.group(1)))

    def section_type(pos: int) -> str:
        current = ""
        for p, name in sections:
            if p < pos:
                current = name
            else:
                break
        return current

    q_matches = list(re.finditer(r"(?m)^\s*(\d{1,4})\s*[、.．]\s*", text))
    items = []
    for idx, m in enumerate(q_matches):
        qnum = int(m.group(1))
        start = m.end()
        end = q_matches[idx + 1].start() if idx + 1 < len(q_matches) else len(text)
        body = text[start:end]
        ans_m = re.search(
            r"答案\s*[：:]\s*([A-Fa-f]+|正确|错误|对|错||)",
            body,
        )
        if not ans_m:
            continue
        answer = normalize_answer(ans_m.group(1))
        if not answer:
            continue
        stem, options = parse_options(body)
        sec = section_type(m.start())
        qtype = "single"
        if "多" in sec:
            qtype = "multiple"
        elif "判断" in sec:
            qtype = "judge"
        if len(answer) > 1:
            qtype = "multiple"
        if qtype == "judge" and len(options) < 2:
            options = [
                {"key": "A", "text": "正确"},
                {"key": "B", "text": "错误"},
            ]
        if len(options) < 2:
            continue
        if qtype == "single" and len(options) == 2:
            texts = " ".join(o["text"] for o in options)
            if ("正确" in texts or "对" in texts) and ("错误" in texts or "错" in texts):
                qtype = "judge"
        answer_keys = set(answer)
        option_keys = {o["key"] for o in options}
        if not answer_keys.issubset(option_keys):
            continue
        stem = re.sub(r"\s+", " ", stem).strip(" ：:;；,，。|")
        explanation_m = re.search(r"解析\s*[：:]\s*(.*)", body, re.S)
        explanation = ""
        if explanation_m:
            explanation = re.sub(r"\s+", " ", explanation_m.group(1)).strip(" ：:;；,，。|")
        items.append(
            {
                "id": f"public2027_{qnum:04d}",
                "qnum": qnum,
                "type": qtype,
                "stem": stem,
                "options": options,
                "answer": list(answer),
                "explanation": explanation,
            }
        )
    return items


def make_json_items(parsed):
    result = []
    for item in parsed:
        for level in ["专科", "本科", "硕士"]:
            result.append(
                {
                    "id": item["id"],
                    "examLevel": level,
                    "subjectId": SUBJECT_ID,
                    "subjectName": SUBJECT_NAME,
                    "chapterId": CHAPTER_ID,
                    "chapterName": CHAPTER_NAME,
                    "type": item["type"],
                    "stem": item["stem"],
                    "options": item["options"],
                    "answer": item["answer"],
                    "explanation": item["explanation"],
                    "difficulty": 1,
                    "sourceFile": PDF_PATH,
                    "sourceLocator": f"第{item['qnum']}题",
                    "reviewStatus": "auto",
                    "confidence": 0.9,
                    "images": [],
                    "sourceImage": "",
                    "needsImage": False,
                    "imageStatus": "none",
                }
            )
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    parsed = parse_pdf(PDF_PATH)
    json_items = make_json_items(parsed)
    print("PARSED_UNIQUE", len(parsed), "JSON_RECORDS", len(json_items))

    data_path = os.path.join(ASSETS, "questions.json")
    data = json.loads(open(data_path, encoding="utf-8").read())

    # replace existing public industry subject if present
    data["subjects"] = [
        s for s in data["subjects"] if s.get("id") != SUBJECT_ID
    ]
    data["subjects"].append(
        {
            "id": SUBJECT_ID,
            "name": SUBJECT_NAME,
            "chapters": [
                {
                    "id": CHAPTER_ID,
                    "name": CHAPTER_NAME,
                    "questions": json_items,
                }
            ],
        }
    )

    if args.write:
        with open(data_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        report_path = os.path.join(ASSETS, "import_report.csv")
        with open(report_path, "a", newline="", encoding="utf-8-sig") as f:
            writer = csv.writer(f)
            writer.writerow(
                [
                    "public_2027",
                    PDF_PATH,
                    len(json_items),
                    f"公共与行业知识 {len(parsed)} 题，按通用加入专科/本科/硕士",
                ]
            )
        print("WROTE", data_path)


if __name__ == "__main__":
    main()