# Course content format

The app is in English and teaches one *target* language per course. Every course
lives in its own folder, `content/courses/<code>/`, and `content/build.py` compiles
each folder into `Resources/Courses/<code>/*.json`.

All courses share one skeleton: the same 32 units (8 per CEFR level, A1–B2), the
same unit/lesson ids, the same topics. What changes is the target-language side,
the cultural details (names, places, food), and the grammar notes, which are written
for each language.

## Files in a course folder

| File | What it holds |
|---|---|
| `course.py` | metadata: code, English name, endonym, script, romanisation, direction |
| `a1.py` `a2.py` `b1.py` `b2.py` | `LEVEL` and `UNITS`: units, grammar notes, lessons, dialogue |
| `extra_<level>*.py` | `EXTRA`: extra vocabulary lessons appended to units |
| `drills/<unit>.py` | `DRILLS`: practice sentences, ~12 per lesson |
| `questions.py` | `GENERIC`, `QUESTIONS`, `FOLLOWUPS`: what Anorcha asks on the video call |
| `phrases.py` | short lines the app itself says in the target language (reactions, openers…) |

## The pair

Every piece of language is a tuple whose **first element is English** and whose
second is the **target language**:

```python
("good morning", "xayrli tong")
```

Courses whose script is not Latin add a **romanisation** as a third element, always:

```python
("good morning", "สวัสดีตอนเช้า", "sà-wàt-dii tɔɔn-cháo")
```

Nothing else goes in a pair. English is what the learner reads and types; keep it
natural, simple and unambiguous (US spelling).

### Making English unambiguous

The learner translates *from* English, so English must say what the target says:

- **Formal vs informal "you"** — when the target distinguishes them (Uzbek sen/siz,
  Persian to/shomâ, Tagalog with/without po…), mark the polite or plural form in
  English: "How are you, sir?", "How are you? (formal)", "Are you (all) ready?".
- **Speaker gender** that changes the target (Thai ครับ/ค่ะ) — pick one and keep it
  consistent within a sentence; the app accepts both particles.
- Avoid English that has two equally good target translations with different
  meanings.

## Units — `a1.py` … `b2.py`

```python
LEVEL = "a1"

UNITS = [
 dict(id="a1u1", icon="hand.wave.fill", accent="sky",
  title=("First steps", "Ilk qadamlar"),                 # (en, target)
  subtitle=("Greetings, introductions, how you are", "…"),
  grammar=[                                              # notes in English only
    ("“To be” has no word in the present",               # title
     "In Uzbek the present tense of “to be” …",          # body, for an English speaker
     [("I am Italian.", "Men italiyalikman."), …]),      # examples: pairs
  ],
  lessons=[
   ("a1u1l1", ("Greetings", "Salomlashish"),
    [("hello", "salom"), …],                             # vocabulary (≥ 6)
    [("Hello, how are you?", "Salom, qalaysan?"), …]),   # phrases (≥ 4)
  ],
  dialogue=(("The first meeting", "Ilk tanishuv"), [
    ("Aziz", "Hello! My name is Aziz.", "Salom! Mening ismim Aziz."),   # (who, en, target[, rom])
  ]),
 ),
]
```

Grammar notes are **written for this language**, in English, for an English speaker:
what the learner needs to know to understand the unit's sentences in *this* language.

## Extra lessons — `extra_<level>*.py`

```python
EXTRA = {
 "a1u1": [
   ("Useful words", "Foydali so'zlar",        # title (en, target)
    [("yes", "ha"), …],                        # words
    [("Yes, please.", "Ha, iltimos."), …]),    # sentences (optional)
 ],
}
```

## Drills — `drills/<unit>.py`

```python
DRILLS = {
 "a1u1l1": [("Good morning, Aziz!", "Xayrli tong, Aziz!"), …],
}
```

## Call questions — `questions.py`

```python
GENERIC = {"a1": {"open": [pair, …], "follow": [...], "close": [...]}, …}
QUESTIONS = {"a1u1": [pair × 8], …}
FOLLOWUPS = {"a1u1": [[pair, pair] × 8], …}     # two per question, same order
```

## Ids

Unit, lesson and drill ids are the same in every course (`a1u1`, `a1u1l1`,
`a1u1x1`…). Never rename, add or drop one: progress, tests and the app's planners
rely on the skeleton being identical.
