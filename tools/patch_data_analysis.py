# -*- coding: utf-8 -*-
"""
Patch data-analysis questions so their source images include the shared material.
Run from repo root:
    python tools/patch_data_analysis.py --write
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
from pathlib import Path

import fitz
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
IMAGES = ASSETS / "question_images"

SPEC = importlib.util.spec_from_file_location(
    "build_question_bank", ROOT / "tools" / "build_question_bank.py"
)
bq = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bq)


def parse_qnum(item: dict) -> int | None:
    m = re.search(r"(\d+)", item.get("sourceLocator") or "")
    return int(m.group(1)) if m else None


def parse_qid(item: dict) -> str | None:
    m = re.search(r"id\s+([^,\s]+)", item.get("sourceLocator") or "")
    return m.group(1) if m else None


def safe_name(item: dict) -> str:
    raw = f"{item.get('id', 'q')}_material_full"
    return re.sub(r"[^0-9A-Za-z._-]+", "_", raw).strip("_")[:120] + ".jpg"


def render_clip(doc, page_index: int, y0: float, y1: float, zoom: float = 1.5):
    page = doc.load_page(page_index)
    y0 = max(0, min(y0, page.rect.height))
    y1 = max(0, min(y1, page.rect.height))
    if y1 <= y0 + 2:
        y1 = page.rect.height
    clip = fitz.Rect(0, y0, page.rect.width, y1)
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=clip)
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    pix = None
    return img


def vconcat(images: list[Image.Image]) -> Image.Image:
    if not images:
        raise ValueError("no images to concat")
    width = max(img.width for img in images)
    height = sum(img.height for img in images)
    canvas = Image.new("RGB", (width, height), "white")
    y = 0
    for img in images:
        if img.mode != "RGB":
            img = img.convert("RGB")
        canvas.paste(img, (0, y))
        y += img.height
    return canvas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    data = json.loads((ASSETS / "questions.json").read_text(encoding="utf-8"))
    all_items = [q for s in data["subjects"] for ch in s["chapters"] for q in ch["questions"]]

    by_file: dict[str, list[dict]] = {}
    for item in all_items:
        path = item.get("sourceFile") or ""
        if path:
            by_file.setdefault(path, []).append(item)

    updated = 0
    files_to_delete: set[str] = set()

    for source_file, items in by_file.items():
        if not os.path.exists(source_file):
            continue
        doc = fitz.open(source_file)
        # find the last data-analysis marker in the document
        marker_page = None
        marker_rect = None
        for page_index in range(doc.page_count):
            page = doc.load_page(page_index)
            for marker in ["资料分析", "根据以下资料", "根据上述资料"]:
                rects = page.search_for(marker)
                if rects:
                    marker_page = page_index
                    marker_rect = rects[-1]
        if marker_page is None or marker_rect is None:
            doc.close()
            continue

        # locate every question in this PDF
        located = []
        for item in items:
            qnum = parse_qnum(item)
            qid = parse_qid(item)
            if qnum is None:
                continue
            stype = bq._source_type(item)
            page_index, page, rect = bq.find_header_rect(
                doc, qnum, qid=qid, source_type=stype
            )
            if page is None:
                continue
            located.append((qnum, qid, stype, page_index, page, rect, item))

        # first data-analysis question after the marker
        candidates = []
        for entry in located:
            qnum, qid, stype, page_index, page, rect, item = entry
            if page_index > marker_page or (
                page_index == marker_page and rect.y0 > marker_rect.y0 + 2
            ):
                candidates.append(entry)
        if not candidates:
            doc.close()
            continue
        candidates.sort(key=lambda x: x[0])
        first_qnum, _, first_stype, first_page_index, first_page, first_rect, first_item = candidates[0]

        # data-analysis group: all questions with qnum >= first_qnum in this file
        group = [e for e in located if e[0] >= first_qnum]
        if not group:
            doc.close()
            continue

        # render material region: marker -> first question
        material_images = []
        for page_index in range(marker_page, first_page_index + 1):
            y0 = marker_rect.y0 - 5 if page_index == marker_page else 0
            y1 = first_rect.y0 - 5 if page_index == first_page_index else doc.load_page(page_index).rect.height
            material_images.append(render_clip(doc, page_index, y0, y1))
        if not material_images:
            doc.close()
            continue

        for qnum, qid, stype, page_index, page, rect, item in group:
            # cut question region at next question / page bottom, then remove answer area
            next_page_index, next_rect = bq.find_next_rect(doc, page_index, qnum, stype)
            start_y = max(0, rect.y0 - 10)
            if next_page_index == page_index and next_rect is not None:
                end_y = min(page.rect.height, next_rect.y0 - 10)
            else:
                end_y = page.rect.height
            if end_y <= start_y + 20:
                end_y = page.rect.height
            start_y, end_y = bq.adjust_crop_bounds(
                page, stype, start_y, end_y, include_material=False
            )
            question_img = render_clip(doc, page_index, start_y, end_y)

            combined = vconcat(material_images + [question_img])
            filename = safe_name(item)
            out_path = IMAGES / filename
            combined.save(out_path, quality=82)
            combined.close()

            new_path = "assets/question_images/" + filename
            # remove old image if it was a material crop and no longer referenced by this item
            old_images = list(item.get("images") or [])
            for old in old_images:
                if old.startswith("assets/question_images/"):
                    files_to_delete.add(old)
            item["images"] = [new_path]
            item["sourceImage"] = ""
            item["needsImage"] = True
            item["imageStatus"] = "material_full"
            updated += 1

        doc.close()

    # delete stale material images that are no longer referenced anywhere
    referenced = set()
    for item in all_items:
        for img in item.get("images") or []:
            referenced.add(img)
        if item.get("sourceImage"):
            referenced.add(item["sourceImage"])

    removed = 0
    for rel in files_to_delete:
        if rel in referenced:
            continue
        path = ROOT / rel
        if path.exists():
            path.unlink()
            removed += 1

    print("UPDATED", updated, "REMOVED_STALE_IMAGES", removed)
    if args.write:
        (ASSETS / "questions.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print("WROTE questions.json")


if __name__ == "__main__":
    main()