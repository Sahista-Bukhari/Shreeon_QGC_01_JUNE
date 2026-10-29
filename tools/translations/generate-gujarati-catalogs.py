#!/usr/bin/env python3
"""Generate complete Gujarati Qt Linguist catalogs from English TS files.

The generated catalogs are build inputs. This helper is only needed when the
English source strings change. It uses Google Translate's public web endpoint,
so a native Gujarati speaker should review wording before a release.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


TRANSLATE_URL = "https://translate.googleapis.com/translate_a/t"
MANUAL_TRANSLATIONS = {
    "Analyze": "વિશ્લેષણ",
    "Arm": "આર્મ",
    "Armed": "આર્મ્ડ",
    "Disarm": "ડિસઆર્મ",
    "Disarmed": "ડિસઆર્મ્ડ",
    "Fly": "ઉડાન",
    "General": "સામાન્ય",
    "Heading": "દિશા",
    "Hold": "સ્થિર રહો",
    "Land": "લેન્ડ",
    "Yaw": "યૉ",
    " deg": " ડિગ્રી",
    'UTM projection is not in supported format. Must be PROJCS["WGS_1984_UTM_Zone_##N/S':
        'UTM પ્રોજેક્શન સમર્થિત ફોર્મેટમાં નથી. તે PROJCS["WGS_1984_UTM_Zone_##N/S ફોર્મેટમાં હોવું આવશ્યક છે',
}
TOKEN_PATTERN = re.compile(
    r"<(?:pre|code)\b[^>]*>.*?</(?:pre|code)>|"
    r"%L?\d+|%n|"
    r"\{[A-Za-z][A-Za-z0-9_]*\}|"
    r"&(?:#\d+|#x[0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]+);|"
    r"(?:https?|ftp)://[^\s<]+|"
    r"\b[A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+\b|"
    r"\b[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+_?(?![A-Za-z0-9_])|"
    r"_[A-Za-z][A-Za-z0-9]*|"
    r"\$[A-Za-z_][A-Za-z0-9_]*|"
    r"\r?\n+|\t+",
    re.DOTALL | re.IGNORECASE,
)


def _token_name(index: int) -> str:
    letters = ""
    value = index
    while True:
        value, remainder = divmod(value, 26)
        letters = chr(ord("A") + remainder) + letters
        if value == 0:
            break
        value -= 1
    return f"ZXQPH{letters}QXZ"


def protect_tokens(text: str) -> tuple[str, dict[str, str]]:
    replacements: dict[str, str] = {}

    def replace(match: re.Match[str]) -> str:
        token = _token_name(len(replacements))
        original = match.group(0)
        replacements[token] = original
        if re.fullmatch(r"\r?\n+", original):
            return f'<br data-qgc-newline="{token}">'
        return f'<span class="notranslate">{token}</span>'

    return TOKEN_PATTERN.sub(replace, text), replacements


def restore_tokens(text: str, replacements: dict[str, str]) -> str:
    text = html.unescape(text)
    for token, original in replacements.items():
        if re.fullmatch(r"\r?\n+", original):
            newline = re.compile(
                rf' *<br\b[^>]*data-qgc-newline=["\']{re.escape(token)}["\'][^>]*> *',
                re.IGNORECASE,
            )
            text, replaced = newline.subn(lambda _: original, text, count=1)
            if not replaced:
                raise RuntimeError(f"translator corrupted protected newline {token}: {text}")
            continue
        wrapper = re.compile(
            rf'<span\b[^>]*>\s*{re.escape(token)}\s*</span>',
            re.IGNORECASE,
        )
        text, replaced = wrapper.subn(lambda _: original, text, count=1)
        if not replaced and token in text:
            text = text.replace(token, original, 1)
            replaced = 1
        if not replaced:
            raise RuntimeError(f"translator corrupted protected token {token}: {text}")
    return text


def translate_batch(strings: list[str]) -> list[str]:
    params: list[tuple[str, str]] = [
        ("client", "gtx"),
        ("sl", "en"),
        ("tl", "gu"),
        ("format", "html"),
    ]
    params.extend(("q", value) for value in strings)
    url = f"{TRANSLATE_URL}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    last_error: Exception | None = None
    for attempt in range(7):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                result = json.loads(response.read().decode("utf-8"))
            if not isinstance(result, list) or len(result) != len(strings):
                raise RuntimeError(
                    f"translator returned {len(result) if isinstance(result, list) else 'invalid'} "
                    f"items for a {len(strings)} item batch"
                )
            return [str(value) for value in result]
        except Exception as error:  # Network/rate-limit failures are transient.
            last_error = error
            time.sleep(min(2**attempt, 30))

    raise RuntimeError("Gujarati translation request failed after retries") from last_error


def collect_sources(paths: list[Path]) -> list[str]:
    unique: dict[str, None] = {}
    for path in paths:
        root = ET.parse(path).getroot()
        for source in root.iter("source"):
            text = source.text or ""
            if text and re.search(r"[A-Za-z]", text):
                unique.setdefault(text, None)
    return list(unique)


def build_batches(values: list[str]) -> list[list[str]]:
    batches: list[list[str]] = []
    current: list[str] = []
    encoded_size = 0

    for value in values:
        value_size = len(urllib.parse.quote_plus(value.encode("utf-8"))) + 3
        if current and (len(current) >= 50 or encoded_size + value_size > 12_000):
            batches.append(current)
            current = []
            encoded_size = 0
        current.append(value)
        encoded_size += value_size

    if current:
        batches.append(current)
    return batches


def translate_sources(sources: list[str], cache_path: Path) -> dict[str, str]:
    if cache_path.exists():
        translations = json.loads(cache_path.read_text(encoding="utf-8"))
    else:
        translations = {}

    protected: dict[str, tuple[str, dict[str, str]]] = {}
    pending: list[str] = []
    for source in sources:
        if "ZXQPH" in translations.get(source, ""):
            translations[source] = source
        if source not in translations:
            protected_text, replacements = protect_tokens(source)
            if len(replacements) > 20:
                translations[source] = source
                continue
            protected[source] = (protected_text, replacements)
            pending.append(source)

    batches = build_batches([protected[source][0] for source in pending])
    offset = 0
    for batch_number, batch in enumerate(batches, start=1):
        translated_batch = translate_batch(batch)
        for translated in translated_batch:
            source = pending[offset]
            replacements = protected[source][1]
            try:
                translations[source] = restore_tokens(translated, replacements)
            except RuntimeError:
                retry = translate_batch([protected[source][0]])[0]
                translations[source] = restore_tokens(retry, replacements)
            offset += 1
        cache_path.write_text(
            json.dumps(translations, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"Translated batch {batch_number}/{len(batches)} ({offset}/{len(pending)})")
        time.sleep(0.15)

    return translations


def write_catalog(source_path: Path, output_path: Path, translations: dict[str, str]) -> None:
    tree = ET.parse(source_path)
    root = tree.getroot()
    root.set("language", "gu_IN")
    root.set("sourcelanguage", "en_US")

    for message in root.iter("message"):
        source_element = message.find("source")
        if source_element is None:
            continue
        source = source_element.text or ""
        translation = message.find("translation")
        if translation is None:
            translation = ET.SubElement(message, "translation")
        translation.attrib.pop("type", None)
        translated = MANUAL_TRANSLATIONS.get(source, translations.get(source, source))
        if "ZXQPH" in translated:
            translated = source
        leading_spaces = source[: len(source) - len(source.lstrip(" "))]
        trailing_spaces = source[len(source.rstrip(" ")) :]
        translation.text = leading_spaces + translated.strip(" ") + trailing_spaces

    ET.indent(tree, space="    ")
    xml_body = ET.tostring(root, encoding="utf-8")
    output_path.write_bytes(
        b'<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + xml_body + b"\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-ts", type=Path, required=True)
    parser.add_argument("--json-ts", type=Path, required=True)
    parser.add_argument("--source-output", type=Path, required=True)
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument(
        "--cache",
        type=Path,
        default=Path("/tmp/qgc-gujarati-translation-cache.json"),
    )
    args = parser.parse_args()

    inputs = [args.source_ts, args.json_ts]
    sources = collect_sources(inputs)
    translations = translate_sources(sources, args.cache)
    write_catalog(args.source_ts, args.source_output, translations)
    write_catalog(args.json_ts, args.json_output, translations)


if __name__ == "__main__":
    main()
