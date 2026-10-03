# mokuro-cbz

Runs [mokuro](https://github.com/kha-white/mokuro) OCR on folders of manga
pages and packs each volume into a CBZ that is laid out exactly like the
[mokuro reader](https://reader.mokuro.app)'s own CBZ export, so it can be
imported into the reader directly.

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

### Options

| Option | Description |
| --- | --- |
| `-o`, `--output-dir DIR` | Where all output goes (default: `./mokuro-out`) |
| `--force-cpu` | Run OCR on the CPU even if CUDA is available |
| `--no-cache` | Ignore cached OCR results and OCR every page again |
| `--model NAME` | manga-ocr model name or path (default: `kha-white/manga-ocr-base`) |

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
