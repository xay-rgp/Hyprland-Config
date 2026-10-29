# Vendored data

## `emoji.tsv`

5 042 unique emoji, tab separated:

```
<glyph>	<group>	<name>	<keyword | keyword | ...>
```

Derived from the `all_emojis.txt` data file shipped by
[rofi-emoji](https://github.com/Mange/rofi-emoji) (MIT), reduced to the four
fields `EmojiService` actually uses and de-duplicated by glyph (the upstream
file repeats some glyphs for alternate renderings: 6 000+ lines → 5 042 rows).

It is vendored rather than read from `/usr/share/rofi-emoji/` because
`rofi-emoji` **depends on `rofi`**, and `rofi` is removed with the rest of the
old shell stack. Reading it from the system path would have made the Quickshell
emoji picker silently empty the moment `rofi` was uninstalled — a dependency the
new shell should not have on the software it replaces.

Emoji names and keywords originate from Unicode's CLDR annotations
(Unicode licence). Regenerate with:

```bash
python3 - <<'PY'
rows, seen = [], set()
for line in open('/usr/share/rofi-emoji/all_emojis.txt', encoding='utf-8'):
    f = line.rstrip('\n').split('\t')
    if len(f) < 4 or f[0] in seen:
        continue
    seen.add(f[0])
    rows.append((f[0], f[1], f[3], f[4].lower() if len(f) > 4 else ""))
open('emoji.tsv', 'w', encoding='utf-8').write(
    "".join("\t".join(r) + "\n" for r in rows))
PY
```
