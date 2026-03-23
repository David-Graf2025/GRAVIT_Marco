import json
import re
from pathlib import Path

src = Path(r"C:\gravit_fresh\backend\tempton_doc_extracted.txt").read_text(encoding="utf-8", errors="ignore")
lines = [re.sub(r"\s+", " ", l).strip() for l in src.splitlines()]
pat = re.compile(r"^Bilder die bei einem\s+(.+?)\s+gemacht werden müssen:?$", re.I)

sections = []
current = None
for line in lines:
    match = pat.match(line)
    if match:
        if current:
            sections.append(current)
        current = {"name": match.group(1).strip(), "raw": [], "items": []}
        continue
    if current is not None:
        current["raw"].append(line)
if current:
    sections.append(current)

POP_TYPE_STOP = {
    "CO", "AP 2992", "AP 1496", "AP 1188", "CP/AP 2600",
    "FCP 1496", "FCP 3696", "FCP 400 v2", "AP 3696", "MP 400 v2"
}


def clean_item(text: str) -> str:
    text = text.strip().strip(":-")
    text = re.sub(r"^[a-j]\.?\s*", "", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip()


def slug(text: str) -> str:
    s = text.lower()
    repl = {
        "ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss",
        "/": "_", "+": "_", " ": "_", "-": "_",
    }
    for a, b in repl.items():
        s = s.replace(a, b)
    s = re.sub(r"[^a-z0-9_]+", "", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s

for section in sections:
    items = []
    rack = None
    in_mutual = False

    for raw in section["raw"]:
        line = clean_item(raw)
        if not line:
            continue
        if line.lower().startswith("bilder die bei einem"):
            break
        if line in POP_TYPE_STOP:
            continue

        if re.match(r"^(EQF|ODF|PMF|PPF|ODF/PPF|MPF|MP)\s*[- ]?\d+", line, re.I):
            rack = line
            in_mutual = False
            continue

        if line.lower().startswith("gegenseitiger pop"):
            in_mutual = True
            continue

        if line.lower().startswith("gesamtansicht rack") and rack:
            items.append(f"{rack} Gesamtansicht Rack")
            continue

        if line.lower().startswith("foto") or line.lower().startswith("fotos"):
            items.append(f"Gegenseitiger POP - {line}" if in_mutual else line)
            continue

        if "ups" in line.lower() or "usv" in line.lower() or "config" in line.lower():
            items.append(line)
            continue

    deduped = []
    seen = set()
    for item in items:
        key = item.lower()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)

    section["items"] = deduped

pop_types = [section["name"] for section in sections]

templates = []
for section in sections:
    template_id = f"tempton_{slug(section['name'])}"
    capture_steps = []
    for index, label in enumerate(section["items"], start=1):
        step_id = slug(label) or f"step_{index}"
        capture_steps.append(
            {
                "id": step_id,
                "label": label,
                "translationKey": f"photo_{step_id}",
                "required": index <= 3,
                "order": index,
            }
        )

    templates.append(
        {
            "templateId": template_id,
            "name": section["name"],
            "folderPattern": "{popId} {popType}",
            "fileNamePattern": "{popId}_{popType}_{photoVar}.jpg",
            "captureSteps": capture_steps,
        }
    )

payload = {
    "tenantId": "tempton",
    "name": "Tempton",
    "fields": [
        {
            "key": "popId",
            "type": "text",
            "label": "POP ID",
            "required": True,
            "placeholder": "z. B. APE-001",
        },
        {
            "key": "popType",
            "type": "dropdown",
            "label": "POP Typ",
            "required": True,
            "options": pop_types,
        },
    ],
    "storageTargets": [
        {
            "id": "mydrive",
            "type": "onedrive_personal",
            "label": "Tempton OneDrive",
            "icon": "📱",
            "subtitle": "Persoenlicher Upload fuer Tempton",
            "configurable": {"basePath": "/Tempton"},
        }
    ],
    "defaultStorageTargetId": "mydrive",
    "templates": templates,
    "defaultTemplateId": templates[0]["templateId"] if templates else "tempton_default",
}

out_path = Path(r"C:\gravit_fresh\backend\tempton-tenant-from-doc.json")
out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

print("pop types:", pop_types)
print("templates:", len(templates))
print("output:", out_path)
