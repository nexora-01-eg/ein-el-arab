---
name: ein-el-arab
description: 3ain el-Arab (عين العرب) — a smart image sorter and feedback tool. Scans a folder for images, captures previews so the AI can SEE each image (vision), classifies them (type, quality, subject), generates a VISUAL feedback report as PNG images, extracts on-screen text from images by reading them with vision, suggests smart renames, and (with approval) applies the renames. Use when the user says "صنّف الصور", "رتب الصور", "صنفلي الصور", "عين العرب", "3ain el arab", "sort my images", "classify my images", "feedback on my images", "what's in these images", or wants a report on a folder of images as images.
---

# 3ain el-Arab — عين العرب (Eye of the Arabs)

أداة ذكية بتشوف الصور، بتصنّفها، بتعمل فيدباك بصري، بتستخرج النصوص من الصور، وبتحسن أسماءها.

## Philosophy
- **The AI is the eye.** No external OCR / classifiers required. This agent reads each captured preview image with vision and decides: category, quality score, notes (feedback), extracted text, and suggested rename.
- **Never destructive.** Renames go through dryrun first; a backup folder is always created on apply.
- **Feedback = images.** The output is a visual report (PNG pages) that the user can open, not just a text dump.

## Architecture

```
scan-images.ps1 → manifest.json
screenshot-images.ps1 → screenshots/*.png   (previews for the AI to see)
  → (agent reads previews with vision, writes classifications.json)
make-report.ps1 → ein-report/report_page_N.png  (visual feedback report)
rename-images.ps1 → renames after approval
```

All scripts live in the `scripts/` subfolder of this skill.

## Phase 0 — Locate the folder
Ask the user which folder holds the images (absolute Windows path). Confirm it exists.

## Phase 1 — Scan
```powershell
& 'C:\Users\fagr\.config\opencode\skills\ein-el-arab\scripts\scan-images.ps1' -Root 'D:\some-images'
```
Writes `manifest.json` beside the images listing path/name/extension/size/modified/folder.
Only raster/vector image extensions are included (jpg/png/webp/gif/bmp/svg/tiff/heic/avif).

## Phase 2 — Capture previews
```powershell
& 'C:\Users\fagr\.config\opencode\skills\ein-el-arab\scripts\screenshot-images.ps1' -Manifest 'D:\some-images\manifest.json'
```
Headless Chrome opens each image in a minimal HTML page (filename bar + image) and screenshots it to `screenshots/{index}_{name}_preview.png`.

## Phase 3 — Read & classify (agent does this with VISION)
For each preview, **open the image with the Read tool** and observe it. Then decide and write a `classifications.json` array:

```json
[
  {
    "path": "D:\\some-images\\img001.png",
    "name": "img001.png",
    "category": "1-صورة فوتوغرافية",
    "score": 0.9,
    "notes": "صورة واضحة، إضاءة جيدة، موضوع: منتج.",
    "extracted_text": "any readable text inside the image, or empty",
    "suggested_name": "منتج-لابتوب-اسود.png"
  }
]
```

### Categories
- `1-صورة فوتوغرافية` — photos
- `2-سكرين شوت` — screenshots (UI captures)
- `3-مستند` — document scan / receipt / form (has text)
- `4-تصميم جرافيك` — graphic design / poster / banner
- `5-رسم/توضيح` — illustration / drawing / logo
- `6-رسمة/سكريبت يدوي` — handwriting / sketch
- `7-ميتا/خلفية` — abstract / background / texture
- `8-أخرى` — other

### Quality feedback notes (write in Arabic)
Say what you see — subject, clarity, lighting, focus, text readability — and one concrete suggestion.

### Extracting text (OCR by vision)
If the image contains readable text (screenshot text, signs, documents, receipts), transcribe it faithfully into `extracted_text`. This is the "ينسخ النصوص من الصور ويبعتلك نصوص" part — surface these to the user in the chat too.

### Suggested rename
Derive a meaningful Arabic (or mixed) filename from the content. Keep it short. Slug-safe characters only (no `\ / : * ? " < > |`).

## Phase 4 — Show the user the extracted texts + proposed renames + feedback
Before renaming, present a readable summary in chat:
- For each image: name → extracted text (if any) → category → proposed new name.
- Ask: which ones to rename? All of them or a subset? (The user is the decision maker.)

## Phase 5 — Build the visual feedback report
```powershell
& 'C:\Users\fagr\.config\opencode\skills\ein-el-arab\scripts\make-report.ps1' -Classification 'D:\some-images\classifications.json'
```
Writes `ein-report/report_page_N.png` — a branded RTL visual report showing each image thumbnail + name + category + score + notes + extracted text. Open one page with the Read tool to verify it looks right.

## Phase 6 — Rename (with approval)
```powershell
# preview first
& 'C:\Users\fagr\.config\opencode\skills\ein-el-arab\scripts\rename-images.ps1' -Classification 'D:\some-images\classifications.json' -Mode dryrun

# apply after user confirms
& 'C:\Users\fagr\.config\opencode\skills\ein-el-arab\scripts\rename-images.ps1' -Classification 'D:\some-images\classifications.json' -Mode apply
```
`apply` copies each original to `renamed-backup/` before renaming. A `rename-results.json` is written.

## Important Rules
1. **NEVER delete or move originals.** This tool only renames in place; renaming is reversible via backup.
2. **Dryrun before apply, always.** The user confirms final names.
3. **Batch previews** — if there are many images, read and classify in batches of ~20, keep the agent from choking.
4. **Arabic-first** — categories, notes, and suggested names are in Arabic. Extract text faithfully in its original language.
5. **Verify the report visually** — open a generated `report_page_N.png` to confirm it rendered cleanly.
6. **Encoding** — scripts are ASCII-safe; Arabic text is written into JSON/HTML via normal UTF-8 file writes. Don't hardcode Arabic in .ps1.
7. **Manifest path discovery** — scripts locate `screenshots/` and `ein-report/` as siblings of the manifest's folder. Keep the manifest in the image folder.

## Usage Flow (Agent)
1. Ask which folder → confirm path exists
2. `scan-images.ps1` → read manifest, report count
3. `screenshot-images.ps1` → previews
4. Read each preview (vision): classify + score + notes + extracted_text + suggested_name → write `classifications.json`
5. Show the user the extracted texts, feedback, and proposed renames; get approval
6. `make-report.ps1` → visual feedback report images
7. `rename-images.ps1` dryrun → show table → apply on approval
8. Show final summary (what was renamed, where the report is)
