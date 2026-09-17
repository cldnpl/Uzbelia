# -*- coding: utf-8 -*-
"""Compile the authored curriculum modules into the JSON the app bundles."""
import json, re, sys, os, glob, importlib.util, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Resources", "Curriculum")

CYRILLIC = re.compile(r"[Ѐ-ӿ]")

def load(level):
    spec = importlib.util.spec_from_file_location(level, os.path.join(HERE, f"{level}.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_extra(level):
    """Themed vocabulary packs that become extra lessons inside their unit.

    A level can be split over several files (extra_b1.py, extra_b1b.py, ...);
    they are merged in filename order.
    """
    merged = {}
    for path in sorted(glob.glob(os.path.join(HERE, f"extra_{level}*.py"))):
        name = os.path.splitext(os.path.basename(path))[0]
        spec = importlib.util.spec_from_file_location(name, path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        for unit, packs in getattr(mod, "EXTRA", {}).items():
            merged.setdefault(unit, []).extend(packs)
    return merged

def bil(t):
    return {"it": t[0], "uz": t[1]}

def pair(p):
    return list(p)

problems = []
stats = {}
unit_ids = set()

def check_text(where, it, uz):
    if not it.strip() or not uz.strip():
        problems.append(f"{where}: empty side")
    if CYRILLIC.search(uz) or CYRILLIC.search(it):
        problems.append(f"{where}: cyrillic characters in '{it}' / '{uz}'")
    for bad in ("’", "ʻ", "ʼ"):
        if bad in uz:
            problems.append(f"{where}: non-ASCII apostrophe in '{uz}'")

def build(level):
    mod = load(level)
    extra = load_extra(level)
    units = []
    ids = set()
    pairs = 0
    lessons = 0
    for u in mod.UNITS:
        if u["id"] in ids:
            problems.append(f"duplicate unit id {u['id']}")
        ids.add(u["id"])
        unit_ids.add(u["id"])
        unit = {
            "id": u["id"],
            "title": bil(u["title"]),
            "icon": u.get("icon", "book.fill"),
            "accent": u.get("accent", "sky"),
        }
        if u.get("subtitle"):
            unit["subtitle"] = bil(u["subtitle"])
        if u.get("grammar"):
            notes = []
            for g in u["grammar"]:
                title, body, examples = g
                check_text(f"{u['id']} grammar", title[0], title[1])
                notes.append({
                    "title": bil(title),
                    "body": bil(body),
                    "examples": [pair(e) for e in examples],
                })
                for e in examples:
                    check_text(f"{u['id']} grammar example", e[0], e[1])
            unit["grammar"] = notes
        lessons_src = list(u["lessons"])
        for i, pack in enumerate(extra.get(u["id"], []), start=1):
            title_it, title_uz, words = pack[0], pack[1], pack[2]
            sentences = pack[3] if len(pack) > 3 else []
            lessons_src.append((f"{u['id']}x{i}", (title_it, title_uz), words, sentences))

        ls = []
        for l in lessons_src:
            lid, title, vocab, phrases = l
            lexicon = "x" in lid.split("u")[-1]
            if lid in ids:
                problems.append(f"duplicate lesson id {lid}")
            ids.add(lid)
            for v in vocab: check_text(f"{lid} vocab", v[0], v[1])
            for p in phrases: check_text(f"{lid} phrase", p[0], p[1])
            if len(vocab) < 6: problems.append(f"{lid}: only {len(vocab)} vocab items")
            min_phrases = 2 if lexicon else 4
            if len(phrases) < min_phrases:
                problems.append(f"{lid}: only {len(phrases)} phrases")
            ls.append({
                "id": lid,
                "title": bil(title),
                "vocab": [pair(v) for v in vocab],
                "phrases": [pair(p) for p in phrases],
            })
            pairs += len(vocab) + len(phrases)
            lessons += 1
        unit["lessons"] = ls
        if u.get("dialogue"):
            dtitle, lines = u["dialogue"]
            for who, it, uz in lines: check_text(f"{u['id']} dialogue", it, uz)
            unit["dialogue"] = {
                "title": bil(dtitle),
                "lines": [{"who": w, "it": i, "uz": z} for (w, i, z) in lines],
            }
        units.append(unit)
    stats[level] = dict(units=len(units), lessons=lessons, pairs=pairs,
                        nodes=sum(len(u["lessons"]) + (1 if "dialogue" in u else 0) + 1 for u in units))
    return {"level": level, "units": units}

def build_questions():
    """The open questions Anorcha draws on during a video call."""
    spec = importlib.util.spec_from_file_location("questions", os.path.join(HERE, "questions.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    generic = {}
    for level, groups in mod.GENERIC.items():
        generic[level] = {}
        for slot, items in groups.items():
            for q in items:
                check_text(f"generic {level}.{slot}", *q)
            if len(items) < 2:
                problems.append(f"generic {level}.{slot}: needs at least two variants")
            generic[level][slot] = [bil(q) for q in items]

    units = {}
    total = 0
    for unit_id, items in mod.QUESTIONS.items():
        if unit_id not in unit_ids:
            problems.append(f"questions: unknown unit '{unit_id}'")
        if len(items) < 6:
            problems.append(f"questions {unit_id}: only {len(items)} questions")
        seen = set()
        for q in items:
            check_text(f"question {unit_id}", *q)
            if q[1] in seen:
                problems.append(f"questions {unit_id}: duplicate '{q[1]}'")
            seen.add(q[1])
        units[unit_id] = [bil(q) for q in items]
        total += len(items)

    missing = unit_ids - set(units)
    if missing:
        problems.append(f"units without call questions: {sorted(missing)[:5]}")
    print(f"DOMANDE: {len(units)} bo'lim · {total} domande contestuali")
    return {"generic": generic, "units": units}


os.makedirs(OUT, exist_ok=True)
for level in ("a1", "a2", "b1", "b2"):
    data = build(level)
    with open(os.path.join(OUT, f"{level}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

with open(os.path.join(OUT, "questions.json"), "w", encoding="utf-8") as f:
    json.dump(build_questions(), f, ensure_ascii=False, separators=(",", ":"))

# --- CEFR vocabulary check -------------------------------------------------------
# "Words known" = distinct vocabulary entries taught up to and including a level.
CEFR_BANDS = {"a1": (500, 1000), "a2": (1000, 2000), "b1": (2000, 5000), "b2": (4000, 8000)}

def normalise_word(t):
    t = t.lower()
    for apo in ("\u2018", "\u2019", "\u02bb", "\u02bc"):
        t = t.replace(apo, "'")
    t = "".join(c for c in unicodedata.normalize("NFD", t) if unicodedata.category(c) != "Mn")
    t = re.sub(r"[^a-z0-9' ]", " ", t)
    return " ".join(t.split())

seen_uz = set()
print()
print(f"{'LIV':4} {'nuove':>7} {'totale':>8} {'banda CEFR':>14}")
for level in ("a1", "a2", "b1", "b2"):
    data = json.load(open(os.path.join(OUT, f"{level}.json"), encoding="utf-8"))
    before = len(seen_uz)
    for unit in data["units"]:
        for lesson in unit.get("lessons", []):
            for v in lesson.get("vocab", []):
                seen_uz.add(normalise_word(v[1]))
    lo, hi = CEFR_BANDS[level]
    total = len(seen_uz)
    flag = "OK" if lo <= total <= hi else ("BASSO" if total < lo else "ALTO")
    print(f"{level.upper():4} {total - before:7} {total:8} {lo}-{hi} {flag:>6}")
    if total < lo:
        problems.append(f"{level}: only {total} words known, CEFR asks for at least {lo}")

total_pairs = sum(s["pairs"] for s in stats.values())
total_lessons = sum(s["lessons"] for s in stats.values())
total_nodes = sum(s["nodes"] for s in stats.values())
for lvl, s in stats.items():
    print(f"{lvl.upper()}: {s['units']} unità · {s['lessons']} lezioni · {s['nodes']} nodi · {s['pairs']} coppie")
print(f"TOTALE: {total_lessons} lezioni · {total_nodes} nodi di percorso · {total_pairs} coppie di traduzione")

if problems:
    print("\nPROBLEMI:")
    for p in problems[:40]:
        print(" -", p)
    print(f"({len(problems)} totali)")
    sys.exit(1)
print("\nValidazione OK")
