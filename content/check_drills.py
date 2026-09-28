# -*- coding: utf-8 -*-
"""Checks the practice sentences in content/drills/ before they reach the app.

    python3 content/check_drills.py            # every unit
    python3 content/check_drills.py a1u3 b2u7  # just these

A drill file is content/drills/<unit id>.py and defines

    DRILLS = {
        "<lesson id>": [("frase italiana.", "o'zbekcha jumla."), ...],
        ...
    }

build.py runs the same checks, so a file that passes here also builds.
"""
import importlib.util, json, os, re, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
DRILLS_DIR = os.path.join(HERE, "drills")
CURRICULUM = os.path.join(HERE, "..", "Resources", "Curriculum")

# Minimum sentences per lesson, and how long a sentence may be at each level
# (words on either side). Lenient on purpose: Italian runs a word or two longer
# than Uzbek, which has no articles and glues its prepositions on as suffixes.
MIN_PER_LESSON = 10
LENGTH = {"a1": (2, 8), "a2": (3, 11), "b1": (4, 15), "b2": (5, 20)}

CYRILLIC = re.compile(r"[Ѐ-ӿ]")
BAD_APOSTROPHES = ("‘", "’", "ʻ", "ʼ", "`", "´")


def normalise(t):
    t = t.lower()
    for apo in BAD_APOSTROPHES:
        t = t.replace(apo, "'")
    t = "".join(c for c in unicodedata.normalize("NFD", t) if unicodedata.category(c) != "Mn")
    t = re.sub(r"[^a-z0-9' ]", " ", t)
    return " ".join(t.split())


def words(t):
    return [w for w in re.split(r"\s+", t.strip()) if re.search(r"\w", w)]


def load_file(path):
    name = os.path.splitext(os.path.basename(path))[0]
    spec = importlib.util.spec_from_file_location(f"drills_{name}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, "DRILLS", None)


def curriculum_units():
    """unit id -> (level, [lesson ids], set of normalised texts already in the course)"""
    out = {}
    for level in ("a1", "a2", "b1", "b2"):
        path = os.path.join(CURRICULUM, f"{level}.json")
        data = json.load(open(path, encoding="utf-8"))
        for unit in data["units"]:
            taken = set()
            for lesson in unit.get("lessons", []):
                for it, uz, *_ in lesson.get("vocab", []) + lesson.get("phrases", []):
                    taken.add(normalise(uz))
            out[unit["id"]] = (level, [l["id"] for l in unit.get("lessons", [])], taken)
    return out


def check_unit(unit_id, drills, units, problems):
    if unit_id not in units:
        problems.append(f"{unit_id}: not a unit of the course")
        return 0
    level, lesson_ids, taken = units[unit_id]
    lo, hi = LENGTH[level]
    if not isinstance(drills, dict):
        problems.append(f"{unit_id}: DRILLS must be a dict of lesson id -> list of (it, uz)")
        return 0
    for lid in drills:
        if lid not in lesson_ids:
            problems.append(f"{unit_id}: '{lid}' is not a lesson of this unit")
    seen = {}
    total = 0
    for lid in lesson_ids:
        items = drills.get(lid)
        if not items:
            problems.append(f"{lid}: no sentences")
            continue
        if len(items) < MIN_PER_LESSON:
            problems.append(f"{lid}: only {len(items)} sentences (at least {MIN_PER_LESSON})")
        for n, item in enumerate(items, 1):
            where = f"{lid} #{n}"
            if not (isinstance(item, tuple) and len(item) == 2 and all(isinstance(x, str) for x in item)):
                problems.append(f"{where}: must be a tuple (italiano, o'zbekcha)")
                continue
            it, uz = item
            if not it.strip() or not uz.strip():
                problems.append(f"{where}: empty side")
                continue
            if CYRILLIC.search(it) or CYRILLIC.search(uz):
                problems.append(f"{where}: cyrillic in '{it}' / '{uz}'")
            for bad in BAD_APOSTROPHES:
                if bad in uz:
                    problems.append(f"{where}: use a straight apostrophe (') in '{uz}'")
                    break
            if "  " in it or "  " in uz or it != it.strip() or uz != uz.strip():
                problems.append(f"{where}: stray spaces in '{it}' / '{uz}'")
            if normalise(it) == normalise(uz):
                problems.append(f"{where}: the two sides are identical: '{it}'")
            for side, text in (("it", it), ("uz", uz)):
                n_words = len(words(text))
                if not lo <= n_words <= hi:
                    problems.append(f"{where}: {side} has {n_words} words, {level.upper()} wants {lo}-{hi}: '{text}'")
                if not text[0].isupper() and not text[0].isdigit():
                    problems.append(f"{where}: {side} should start with a capital: '{text}'")
                if text[-1] not in ".?!":
                    problems.append(f"{where}: {side} should end with . ? or !: '{text}'")
            key = normalise(uz)
            if key in taken:
                problems.append(f"{where}: already in the course: '{uz}'")
            if key in seen:
                problems.append(f"{where}: duplicate of {seen[key]}: '{uz}'")
            seen[key] = where
            total += 1
    return total


def main(argv):
    units = curriculum_units()
    wanted = argv[1:]
    files = sorted(f for f in os.listdir(DRILLS_DIR) if f.endswith(".py") and not f.startswith("_")) \
        if os.path.isdir(DRILLS_DIR) else []
    if wanted:
        files = [f"{u}.py" for u in wanted]
    problems = []
    total = 0
    for f in files:
        path = os.path.join(DRILLS_DIR, f)
        unit_id = os.path.splitext(f)[0]
        if not os.path.exists(path):
            problems.append(f"{unit_id}: {path} does not exist")
            continue
        try:
            drills = load_file(path)
        except Exception as e:  # a syntax error is a problem like any other
            problems.append(f"{unit_id}: cannot load: {e}")
            continue
        if drills is None:
            problems.append(f"{unit_id}: no DRILLS in {f}")
            continue
        count = check_unit(unit_id, drills, units, problems)
        total += count
        print(f"{unit_id}: {count} frasi")
    print(f"TOTALE: {total} frasi in {len(files)} unità")
    if problems:
        print("\nPROBLEMI:")
        for p in problems[:80]:
            print(" -", p)
        print(f"({len(problems)} totali)")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
