"""Name similarity for matching guests to real users on join."""

from __future__ import annotations

import re
import unicodedata


def normalize_person_name(name: str | None) -> str:
    """Lowercase, strip, collapse whitespace, remove extra punctuation."""
    if not name:
        return ''
    text = unicodedata.normalize('NFKC', name).strip().lower()
    text = re.sub(r'[^\w\sא-ת]', ' ', text, flags=re.UNICODE)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def names_similar(a: str | None, b: str | None) -> bool:
    """
    True when names likely refer to the same person.

    Examples that match:
      - "אור שחר" / "אור שחר"
      - "אור" / "אור שחר"
      - "שחר" / "אור שחר"
    Examples that do not:
      - "דן" / "ירדן" (substring inside a token, not a whole token)
    """
    na = normalize_person_name(a)
    nb = normalize_person_name(b)
    if not na or not nb:
        return False
    if na == nb:
        return True

    shorter, longer = (na, nb) if len(na) <= len(nb) else (nb, na)
    if longer.startswith(shorter + ' ') or longer.endswith(' ' + shorter):
        return True

    short_tokens = [t for t in shorter.split(' ') if t]
    long_tokens = set(longer.split(' '))
    if short_tokens and all(t in long_tokens for t in short_tokens):
        return True

    return False
