# -*- coding: utf-8 -*-
"""Compile every course in content/courses/<code>/ into the JSON the app bundles.

    python3 content/build.py            # every course
    python3 content/build.py uz th      # just these

Each course becomes Resources/Curriculum/<code>-a1.json … <code>-b2.json,
<code>-questions.json and <code>-phrases.json. The format is described in
content/courses/FORMAT.md. Nothing is written for a course that fails its checks.
"""
import glob, importlib.util, json, os, re, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
COURSES = os.path.join(HERE, "courses")
OUT = os.path.join(HERE, "..", "Resources", "Curriculum")
LEVELS = ("a1", "a2", "b1", "b2")

CYRILLIC = re.compile(r"[Ѐ-ӿ]")
LATIN = re.compile(r"[A-Za-z]")
BAD_APOSTROPHES = ("‘", "’", "ʻ", "ʼ", "`", "´")

# How many distinct vocabulary entries a learner knows by the end of each level.
CEFR_BANDS = {"a1": (500, 1000), "a2": (1000, 2000), "b1": (2000, 5000), "b2": (4000, 8000)}
MIN_DRILLS_PER_LESSON = 10


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Course:
    """One course folder, its checks and its output."""

    def __init__(self, code):
        self.code = code
        self.dir = os.path.join(COURSES, code)
        meta = load_module(os.path.join(self.dir, "course.py"), f"{code}_course")
        self.name = meta.NAME
        self.romanised = getattr(meta, "ROMANISED", False)
        self.latin = getattr(meta, "LATIN", True)
        self.problems = []
        self.stats = {}
        self.drill_count = 0
        self.unit_ids = set()
        self.drills = self.load_drills()

    # --- checks -----------------------------------------------------------------

    def check_pair(self, where, p):
        if not isinstance(p, (tuple, list)):
            self.problems.append(f"{where}: not a pair: {p!r}")
            return
        expected = 3 if self.romanised else 2
        if len(p) != expected:
            self.problems.append(f"{where}: expected {expected} parts, got {len(p)}: {p!r}")
            return
        en, tx = p[0], p[1]
        if not en.strip() or not tx.strip():
            self.problems.append(f"{where}: empty side in {p!r}")
        if CYRILLIC.search(en):
            self.problems.append(f"{where}: Cyrillic in the English '{en}'")
        if self.latin and CYRILLIC.search(tx):
            self.problems.append(f"{where}: Cyrillic in '{tx}'")
        if not self.latin:
            letters = [c for c in tx if c.isalpha()]
            latin = [c for c in letters if c.isascii()]
            # a brand or "OK" inside a sentence is fine; a sentence in Latin is not
            if letters and len(latin) > len(letters) / 2:
                self.problems.append(f"{where}: written in Latin letters, not the target script: '{tx}'")
            # ɛ, ɔ, ʉ, ə are Latin letters too: "ɛɛ" (แอร์) is a fine romanisation
            if self.romanised and len(p) > 2 and not any(
                    c.isalpha() and "LATIN" in unicodedata.name(c, "") for c in p[2]):
                self.problems.append(f"{where}: the romanisation is not in Latin letters: '{p[2]}'")
        if self.code == "uz":
            for bad in BAD_APOSTROPHES:
                if bad in tx:
                    self.problems.append(f"{where}: non-ASCII apostrophe in '{tx}'")
        if self.romanised and not p[2].strip():
            self.problems.append(f"{where}: missing romanisation for '{tx}'")

    def pair(self, where, p):
        self.check_pair(where, p)
        return list(p[:3] if self.romanised else p[:2])

    def bil(self, where, t):
        if not isinstance(t, (tuple, list)) or len(t) != 2 or not t[0].strip() or not t[1].strip():
            self.problems.append(f"{where}: a title needs (english, target): {t!r}")
            return {"en": str(t), "tx": str(t)}
        return {"en": t[0], "tx": t[1]}

    # --- sources ----------------------------------------------------------------

    def load_drills(self):
        out = {}
        for path in sorted(glob.glob(os.path.join(self.dir, "drills", "*.py"))):
            unit_id = os.path.splitext(os.path.basename(path))[0]
            if unit_id.startswith("_"):
                continue
            out[unit_id] = getattr(load_module(path, f"{self.code}_drills_{unit_id}"), "DRILLS", {})
        return out

    def load_extra(self, level):
        merged = {}
        for path in sorted(glob.glob(os.path.join(self.dir, f"extra_{level}*.py"))):
            name = os.path.splitext(os.path.basename(path))[0]
            for unit, packs in getattr(load_module(path, f"{self.code}_{name}"), "EXTRA", {}).items():
                merged.setdefault(unit, []).extend(packs)
        return merged

    # --- levels -----------------------------------------------------------------

    def build_level(self, level):
        path = os.path.join(self.dir, f"{level}.py")
        if not os.path.exists(path):
            return None
        mod = load_module(path, f"{self.code}_{level}")
        extra = self.load_extra(level)
        units, ids = [], set()
        pairs = lessons = 0
        for u in mod.UNITS:
            uid = u["id"]
            if uid in ids:
                self.problems.append(f"duplicate unit id {uid}")
            ids.add(uid)
            self.unit_ids.add(uid)
            unit = {"id": uid, "title": self.bil(f"{uid} title", u["title"]),
                    "icon": u.get("icon", "book.fill"), "accent": u.get("accent", "sky")}
            if u.get("subtitle"):
                unit["subtitle"] = self.bil(f"{uid} subtitle", u["subtitle"])
            notes = []
            for g in u.get("grammar", []):
                if len(g) != 3 or not isinstance(g[0], str) or not isinstance(g[1], str):
                    self.problems.append(f"{uid} grammar: expected (title, body, examples), got {str(g)[:80]}")
                    continue
                title, body, examples = g
                notes.append({"title": {"en": title}, "body": {"en": body},
                              "examples": [self.pair(f"{uid} grammar example", e) for e in examples]})
            if notes:
                unit["grammar"] = notes

            source = list(u["lessons"])
            for i, pack in enumerate(extra.get(uid, []), start=1):
                sentences = pack[3] if len(pack) > 3 else []
                source.append((f"{uid}x{i}", (pack[0], pack[1]), pack[2], sentences))

            out_lessons = []
            for lid, title, vocab, phrases in source:
                lexicon = "x" in lid.split("u")[-1]
                if lid in ids:
                    self.problems.append(f"duplicate lesson id {lid}")
                ids.add(lid)
                if len(vocab) < 6:
                    self.problems.append(f"{lid}: only {len(vocab)} vocabulary items")
                if len(phrases) < (2 if lexicon else 4):
                    self.problems.append(f"{lid}: only {len(phrases)} phrases")
                lesson = {"id": lid, "title": self.bil(f"{lid} title", title),
                          "vocab": [self.pair(f"{lid} vocab", v) for v in vocab],
                          "phrases": [self.pair(f"{lid} phrase", p) for p in phrases]}
                drills = self.drills.get(uid, {}).get(lid, [])
                if drills:
                    lesson["drills"] = [self.pair(f"{lid} drill", d) for d in drills]
                    if len(drills) < MIN_DRILLS_PER_LESSON:
                        self.problems.append(f"{lid}: only {len(drills)} drills")
                out_lessons.append(lesson)
                pairs += len(vocab) + len(phrases)
                self.drill_count += len(drills)
                lessons += 1
            unit["lessons"] = out_lessons

            if u.get("dialogue"):
                dtitle, lines = u["dialogue"]
                out_lines = []
                for line in lines:
                    who, rest = line[0], tuple(line[1:])
                    p = self.pair(f"{uid} dialogue", rest)
                    entry = {"who": who, "en": p[0], "tx": p[1]}
                    if self.romanised and len(p) > 2:
                        entry["rom"] = p[2]
                    out_lines.append(entry)
                unit["dialogue"] = {"title": self.bil(f"{uid} dialogue title", dtitle), "lines": out_lines}
            units.append(unit)
        self.stats[level] = dict(units=len(units), lessons=lessons, pairs=pairs)
        return {"level": level, "units": units}

    # --- the call ---------------------------------------------------------------

    def build_questions(self):
        path = os.path.join(self.dir, "questions.py")
        if not os.path.exists(path):
            return None
        mod = load_module(path, f"{self.code}_questions")
        generic = {}
        for level, groups in mod.GENERIC.items():
            generic[level] = {}
            for slot, items in groups.items():
                if len(items) < 2:
                    self.problems.append(f"generic {level}.{slot}: needs at least two variants")
                generic[level][slot] = [self.bil(f"generic {level}.{slot}", q[:2]) for q in items]
                for q in items:
                    self.check_pair(f"generic {level}.{slot}", q)
        units, follow = {}, {}
        for uid, items in mod.QUESTIONS.items():
            if len(items) < 6:
                self.problems.append(f"questions {uid}: only {len(items)}")
            for q in items:
                self.check_pair(f"question {uid}", q)
            units[uid] = [{"en": q[0], "tx": q[1]} for q in items]
            entries = getattr(mod, "FOLLOWUPS", {}).get(uid)
            if entries is None:
                self.problems.append(f"follow-ups {uid}: missing")
                continue
            if len(entries) != len(items):
                self.problems.append(f"follow-ups {uid}: {len(entries)} entries for {len(items)} questions")
            for i, pair_ in enumerate(entries):
                if len(pair_) != 2:
                    self.problems.append(f"follow-ups {uid} #{i + 1}: needs exactly two")
                for f in pair_:
                    self.check_pair(f"follow-up {uid} #{i + 1}", f)
            follow[uid] = [[{"en": f[0], "tx": f[1]} for f in pair_] for pair_ in entries]
        missing = self.unit_ids - set(units)
        if missing:
            self.problems.append(f"units without call questions: {sorted(missing)[:5]}")
        return {"generic": generic, "units": units, "follow": follow}

    def build_phrases(self):
        path = os.path.join(self.dir, "phrases.py")
        if not os.path.exists(path):
            self.problems.append("phrases.py is missing")
            return None
        table = load_module(path, f"{self.code}_phrases").PHRASES
        out = {}
        for key, items in table.items():
            for p in items:
                self.check_pair(f"phrase {key}", p)
            out[key] = [{"en": p[0], "tx": p[1]} for p in items]
        return out

    # --- the whole course -------------------------------------------------------

    def build(self):
        outputs = {}
        for level in LEVELS:
            data = self.build_level(level)
            if data is not None:
                outputs[f"{self.code}-{level}"] = data
        questions = self.build_questions()
        if questions is not None:
            outputs[f"{self.code}-questions"] = questions
        phrases = self.build_phrases()
        if phrases is not None:
            outputs[f"{self.code}-phrases"] = phrases
        self.check_vocabulary(outputs)

        print(f"\n== {self.name} ({self.code}) ==")
        for lvl, st in self.stats.items():
            print(f"  {lvl.upper()}: {st['units']} units · {st['lessons']} lessons · {st['pairs']} pairs")
        print(f"  drills: {self.drill_count}")
        if self.problems:
            print(f"  PROBLEMS ({len(self.problems)}):")
            for p in self.problems[:40]:
                print("   -", p)
            return False
        os.makedirs(OUT, exist_ok=True)
        for name, data in outputs.items():
            with open(os.path.join(OUT, f"{name}.json"), "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        print("  OK")
        return True

    def check_vocabulary(self, outputs):
        """The promise "by the end of A1 you know N words", checked rather than declared."""
        seen = set()
        for level in LEVELS:
            data = outputs.get(f"{self.code}-{level}")
            if not data:
                continue
            for unit in data["units"]:
                for lesson in unit["lessons"]:
                    for v in lesson["vocab"]:
                        seen.add(unicodedata.normalize("NFC", v[1]).lower().strip())
            lo, _ = CEFR_BANDS[level]
            if len(seen) < lo:
                self.problems.append(f"{level}: only {len(seen)} words known, CEFR asks for at least {lo}")
            self.stats.setdefault(level, {})["known"] = len(seen)


def main(codes):
    codes = codes or sorted(d for d in os.listdir(COURSES)
                            if os.path.isfile(os.path.join(COURSES, d, "course.py")))
    ok = True
    for code in codes:
        ok = Course(code).build() and ok
    if not ok:
        sys.exit(1)
    print("\nValidation OK")


if __name__ == "__main__":
    main(sys.argv[1:])
