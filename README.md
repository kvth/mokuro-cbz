# mokuro-cbz

Runs [mokuro](https://github.com/kha-white/mokuro) OCR on folders of manga
pages and packs each volume into a CBZ that is laid out exactly like the
[mokuro reader](https://reader.mokuro.app)'s own CBZ export, so it can be
imported into the reader directly.

A second command, `mokuro-translate`, adds DeepL translations of every speech
bubble to CBZs that already contain a `.mokuro` file, whether made by
`mokuro-cbz`, exported from the reader or from anywhere else (see
[Translating CBZs](#translating-cbzs)).

## Requirements

- [uv](https://docs.astral.sh/uv/). Nothing else needs to be installed: the
  script declares its dependencies inline and runs through
  `#!/usr/bin/env -S uv run --script`. The first run takes about a minute
  while uv installs mokuro and PyTorch into its cache; later runs start
  right away.
- A CUDA GPU is used if available, otherwise OCR runs on the CPU (slower).

## Usage

```bash
./mokuro-cbz <volume-folder> [<volume-folder> ...] [options]
```

Each folder you pass is one volume. Its parent folder is the series, and the
folder names become the series and volume titles in the reader.

```
comics/                      ← series "comics"
├── Example Vol 1/           ← volume "Example Vol 1"
│   ├── 001.jpg
│   └── 002.jpg
└── Example Vol 2/
    └── ...
```

Process one volume:

```bash
./mokuro-cbz "comics/Example Vol 1"
```

Process every volume of a series:

```bash
./mokuro-cbz comics/*
```

Bash completion comes with the packages; from a checkout, `source
completions/mokuro-cbz.bash`, or copy it to
`~/.local/share/bash-completion/completions/mokuro-cbz`.

### Options

| Option | Description |
| --- | --- |
| `-o`, `--output-dir DIR` | Where all output goes (default: `./mokuro-out`) |
| `--force-cpu` | Run OCR on the CPU even if CUDA is available |
| `--no-cache` | Ignore cached OCR results and OCR every page again |
| `--model NAME` | manga-ocr model name or path (default: `kha-white/manga-ocr-base`) |
| `--version` | Print the version and exit |

## Output

Nothing is written into the source folders. All output goes into one
subfolder per series inside the output directory:

```
mokuro-out/
└── comics/
    ├── _ocr/
    │   ├── Example Vol 1/              ← per-page OCR cache
    │   └── Example Vol 2/
    ├── Example Vol 1.mokuro            ← mokuro's OCR data
    ├── Example Vol 2.mokuro
    ├── comics - Example Vol 1.cbz      ← import these into the reader
    └── comics - Example Vol 2.cbz
```

Each CBZ contains:

```
Example Vol 1/          ← the page images
Example Vol 1.mokuro    ← the OCR data
series.json             ← series index used by the reader
```

- The `.mokuro` inside the CBZ is mokuro's file plus the `chars` count that
  the reader adds when it exports a volume.
- `series.json` lists every volume of the series that has a `.mokuro` file
  in the output directory, not only the current one. Volumes you only have
  in the reader can't be listed.

## Re-running

Keep the `_ocr` folders and `.mokuro` files in the output directory:

- **`_ocr`** caches the OCR result of every page, so re-running a volume
  only repacks it instead of OCR-ing it again (unless `--no-cache` is given).
- **`.mokuro`** holds the volume's and series' IDs (`volume_uuid`,
  `title_uuid`). mokuro reuses them on re-runs, so a rebuilt CBZ is the same
  volume to the reader. Without that file the volume gets new IDs, and the
  reader treats the new CBZ as a different volume from one you've already
  imported.

Volumes processed into the same series folder share one series ID.

## Errors

If a volume fails (e.g. an unreadable image), no CBZ is written for it, the
remaining volumes are still processed, and the script lists the failed
volumes at the end and exits with status 1.

## Notes

- mokuro is pinned to `0.2.5`. The script calls mokuro's Python code directly
  instead of its command line, so the OCR models load only once per run and
  errors per volume are reported. That code isn't a stable API, so check the
  script still works before changing the pin.
- mokuro's legacy HTML output is not generated.

## Translating CBZs

`mokuro-translate` adds a machine translation of every speech bubble to the
`.mokuro` files inside existing CBZs, using the
[DeepL API](https://www.deepl.com/pro-api). It needs no OCR, no source
images and no GPU, only the CBZs.

```bash
export DEEPL_AUTH_KEY=your-key
./mokuro-translate "series - Vol 1.cbz"              # English (the default)
./mokuro-translate ~/manga --lang en,de              # every CBZ under ~/manga
./mokuro-translate ~/manga --lang en,de --dry-run    # only count characters
./mokuro-translate ~/manga -i "Translate as literally as possible" -s literal
```

| Option | Description |
| --- | --- |
| `-l`, `--lang LANGS` | Comma-separated DeepL target languages (default: `en`) |
| `-i`, `--instruction INSTRUCTION` | A DeepL [custom instruction](https://developers.deepl.com/docs/customize/custom-instructions); repeatable, up to 10 of at most 300 characters |
| `-s`, `--suffix SUFFIX` | Store the translations under `LANG-SUFFIX` (e.g. `en-literal`) instead of `LANG` |
| `-t`, `--timeout SECONDS` | How long to wait for each DeepL request before retrying (default: `60`) |
| `-n`, `--dry-run` | Only count the characters that would be sent to DeepL; needs no API key and changes nothing |
| `--version` | Print the version and exit |

Folders are searched recursively for `.cbz` and `.zip` files. Each CBZ is
rewritten in place with only its `.mokuro` files changed. Every text block in
them gets a `translations` object with one entry per language, under the code
you passed:

```json
{
  "box": [120, 340, 260, 610],
  "vertical": true,
  "font_size": 28,
  "lines": ["おはよう", "ございます"],
  "translations": { "en": "Good morning.", "de": "Guten Morgen." }
}
```

- Readers that don't know the key ignore it, so the CBZ still works in the
  upstream mokuro reader. CBZs made by `mokuro-cbz` itself never contain it.
- **Only missing translations are requested.** Blocks that already have one
  for a language are left alone, and a CBZ that needs nothing isn't
  rewritten, so re-running over a whole library only costs what's new, e.g.
  newly added volumes or a new language.
- **Runs add up.** Each run only adds its own keys and keeps every other
  translation in the file, so languages can be added one run at a time:
  `--lang en` and later `--lang de` leave both `en` and `de`. Existing
  translations are never overwritten.
- If DeepL stops partway (e.g. the quota is used up), everything translated
  so far is written to the CBZ, the run stops, and the next run carries on
  from there.
- Each bubble is translated with the rest of its page as context, which
  DeepL doesn't bill. Repeated text in a volume is sent only once.
- Languages are DeepL target language codes, case-insensitive: `en`, `de`,
  `fr`, `en-gb`, `zh-hant`, … Plain `en` is sent as `EN-US` and plain `pt`
  as `PT-BR`, since DeepL needs a regional variant for those. The key and
  the languages are checked before anything is translated.
- At the end it prints the characters sent and your DeepL usage for the
  billing period.

### Custom instructions

`--instruction` passes natural-language rules that steer how DeepL
translates, e.g. `"Translate as literally as possible, keeping the Japanese
sentence structure"` to get translations that map more closely onto the
Japanese. DeepL applies them to each bubble separately, so they work best as
sentence-level rules about wording and style; they don't make DeepL explain
anything, only translate differently.

Since blocks that already have a translation are skipped, use `--suffix` to
store translations made with instructions under their own key, next to the
plain ones:

```json
"translations": { "en": "…", "en-literal": "…" }
```

A run with `--suffix` only fills in its own key, here `en-literal`; it
doesn't create plain `en`. To get both, run once without and once with the
instructions, in either order:

```bash
./mokuro-translate ~/manga                                                     # en
./mokuro-translate ~/manga -i "Translate as literally as possible" -s literal  # en-literal
```

Each suffix is translated and billed separately, so it costs the same
characters again as the plain translation (`--dry-run -s literal` shows how
many). Requests with instructions use DeepL's slower `quality_optimized`
model, so expect the run to take longer. If requests time out, raise
`--timeout`.

Use the same instructions every time you run with a given suffix: blocks
that already have a translation under that key aren't redone, so changing the
instructions only affects new ones. To try different instructions, use a new
suffix.

### Getting a DeepL API key

1. Sign up for **DeepL API Free** at <https://www.deepl.com/pro-api>
   (pick the API plan, not the DeepL Translator subscription). DeepL asks
   for a credit card to verify your identity; the free plan doesn't charge
   it.
2. Log in and open **Account → API Keys & Limits**
   (<https://www.deepl.com/your-account/keys>), create a key and copy it.
   Free keys end in `:fx`.
3. Pass it in `DEEPL_AUTH_KEY`, e.g. put `export DEEPL_AUTH_KEY=...` in your
   `~/.bashrc`.

The free plan allows 500,000 characters a month. DeepL bills every character
once per target language, and a volume is very roughly 20,000–40,000
characters, so plan for about 12–25 volumes a month per language. Use
`--dry-run` to see what a library would cost; when the quota runs out, run
again next month and it continues where it stopped.

## Packaging

```
make install-deps         # nfpm v2.47.0 via go install (NFPM_VERSION=vX.Y.Z)
make packages             # deb and rpm
make deb                  # -> build/mokuro-cbz_<version>_all.deb
make rpm                  # -> build/mokuro-cbz-<version>-1.noarch.rpm
```

- the version is `__version__` in `mokuro-cbz` (override with `VERSION=x.y.z`);
  to release: bump it, commit, `git tag v<version>`
- packages install `mokuro-cbz` and `mokuro-translate` to `/usr/bin` and
  are architecture independent; both scripts carry the same `__version__`
- uv is needed at runtime but is not a package dependency, since
  distributions don't package it; install it yourself
- bash completion: `completions/<command>.bash`, installed to
  `/usr/share/bash-completion/completions/<command>`; lists the options by
  hand, so keep it in sync with the scripts
