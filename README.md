# bachelor-thesis

[![Latest release](https://img.shields.io/github/v/release/zibliclub/bachelor-thesis?label=latest&color=blue)](https://github.com/zibliclub/bachelor-thesis/releases/latest)
[![Build](https://github.com/zibliclub/bachelor-thesis/actions/workflows/build-pdf.yml/badge.svg)](https://github.com/zibliclub/bachelor-thesis/actions/workflows/build-pdf.yml)

LaTeX sources for my bachelor's thesis at the **Dostoevsky Omsk State University** (ОмГУ им. Ф.М. Достоевского).

> **Download the compiled PDF:** [**bachelor-thesis.pdf** — latest release ↓](https://github.com/zibliclub/bachelor-thesis/releases/latest/download/bachelor-thesis.pdf)
>
> Every tagged release attaches a freshly built `bachelor-thesis.pdf`. The link above always resolves to the most recent one.

This is not a template — it is the actual document. The body text is in Russian; everything else (build system, comments, this README) is in English so the repository stays readable to a wider audience.

---

## Table of contents

- [Overview](#overview)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
  - [Arch Linux](#arch-linux)
  - [macOS](#macos)
- [Building locally](#building-locally)
- [Releases](#releases)
- [Formatting rules](#formatting-rules)
- [License](#license)

---

## Overview

- **Engine:** LuaLaTeX (`fontspec` + `polyglossia`).
- **Build driver:** `latexmk` orchestrated by a small `Makefile`.
- **Document class:** `extarticle` at 14 pt for the Russian-mandated body size.
- **Body font:** CMU Serif (Computer Modern Unicode) — covers Latin and Cyrillic; satisfies the "Times or Computer Modern" requirement.
- **Output:** a single `out/main.pdf` locally; published as `bachelor-thesis.pdf` on GitHub Releases.
- **CI:** GitHub Actions builds inside the official `texlive/texlive:latest` container on every `v*` tag and uploads the PDF to the release.

The title page follows the OmSU template; all of its text is parametrised — fill in `meta.tex` and the cover regenerates automatically.

## Repository layout

```text
.
├── main.tex                        # entry point — \input's the rest
├── preamble.tex                    # packages, geometry, fonts, headings, ToC, listings, metadata API
├── meta.tex                        # student / advisor / topic / department / year
├── titlepage.tex                   # OmSU title page, driven entirely by meta.tex
├── sections/
│   ├── 00-introduction.tex         # Введение
│   ├── 01-analysis.tex             # Глава 1. Анализ предметной области и постановка задачи
│   ├── 02-design.tex               # Глава 2. Проектирование клиентской части платформы
│   ├── 03-implementation.tex       # Глава 3. Реализация клиентских приложений
│   ├── 99-conclusion.tex           # Заключение
│   └── bibliography.tex            # Список литературы (thebibliography, ГОСТ 7.0.5-2008)
├── appendices/
│   ├── _appendices.tex             # manifest, \input's А-Г in order
│   ├── a-ios.tex                   # Приложение А. Скриншоты iOS-приложения
│   ├── b-android.tex               # Приложение Б. Скриншоты Android-приложения
│   ├── v-web.tex                   # Приложение В. Скриншоты веб-составляющей
│   └── g-code.tex                  # Приложение Г. Фрагменты ключевого кода
├── images/                         # screenshots referenced by \includegraphics (filled during final stage)
├── knowledge-base/                 # source notes that feed the chapters (project context, glossary, per-client reviews)
├── bib/                            # stub for a possible biblatex-gost migration; not active in the build
├── Makefile                        # build / watch / clean / release targets
├── .latexmkrc                      # latexmk configuration (engine = lualatex, out_dir = out/)
├── .github/workflows/build-pdf.yml # CI: build on tag push, publish PDF to release
├── requirements.md                 # university formatting requirements (source of truth)
└── CLAUDE.md                       # working notes for the Claude Code assistant
```

## Prerequisites

You need a recent TeX Live distribution (≥ 2024) with `lualatex`, `latexmk`, the `cm-unicode` font package, and Cyrillic language support. GNU Make is used to drive everything.

### Arch Linux

```sh
sudo pacman -S --needed \
    texlive-basic \
    texlive-binextra \
    texlive-latex \
    texlive-latexrecommended \
    texlive-latexextra \
    texlive-fontsrecommended \
    texlive-fontsextra \
    texlive-langcyrillic \
    texlive-luatex \
    make
```

`texlive-fontsextra` is the one that ships CMU Serif — without it the build fails with "missing character" warnings on every Cyrillic glyph.

### macOS

Install MacTeX (the standard, full TeX Live distribution for macOS) — it already includes CMU Serif, `polyglossia`, and `latexmk`:

```sh
brew install --cask mactex-no-gui    # ~5 GB; full MacTeX without the GUI apps
# or, if you prefer the apps (TeXShop, BibDesk, …):
# brew install --cask mactex
```

`make` ships with the Xcode Command Line Tools:

```sh
xcode-select --install               # no-op if already installed
```

After installation, open a fresh shell so `/Library/TeX/texbin` enters `PATH`, and verify:

```sh
which lualatex latexmk
fc-list | grep -i "CMU Serif"        # should list cmunrm.otf etc.
```

## Building locally

```sh
git clone git@github.com:zibliclub/bachelor-thesis.git
cd bachelor-thesis
make                  # one-shot build -> out/main.pdf
make watch            # rebuild on every save (latexmk -pvc)
make clean            # remove out/ and stray build artefacts
make distclean        # clean + latexmk -C (remove everything latexmk knows about)
make help             # list all targets
```

The build is fully reproducible: the same Makefile and `.latexmkrc` drive both your laptop and CI.

## Releases

Releases are tagged `vYYYY.MM.DD` (with a `.2`, `.3`, … suffix on collisions within the same day). Cutting one is a single command:

```sh
make release
```

What it does:

1. Verifies the working tree is clean and `origin` is configured.
2. Runs a local sanity build.
3. Pushes the current branch to `origin`.
4. Creates an annotated tag and pushes it.

Pushing a `v*` tag triggers `.github/workflows/build-pdf.yml`, which:

1. Spins up `texlive/texlive:latest` (full TeX Live with CMU Serif preinstalled).
2. Runs `make build`.
3. Renames `out/main.pdf` to `bachelor-thesis.pdf`.
4. Publishes a GitHub Release with auto-generated release notes and the PDF attached.

You can also rebuild an existing tag manually from the **Actions → Build and release PDF → Run workflow** page.

The asset name is stable, so this URL always resolves to the most recent build:

```
https://github.com/zibliclub/bachelor-thesis/releases/latest/download/bachelor-thesis.pdf
```

## Formatting rules

The university's formatting requirements live in [`requirements.md`](./requirements.md) and are enforced project-wide via [`CLAUDE.md`](./CLAUDE.md). Highlights:

- A4, margins **2 / 2 / 3 / 1 cm** (top / bottom / left / right).
- Body: 14 pt, line spacing 1.5, paragraph indent 1.25 cm.
- Headings: bold, left-aligned with paragraph indent, no trailing period.
- Page numbers: bottom centre, continuous; not printed on the title page.
- Captions: `Рис. N. …` below figures, `Таблица N. …` above tables (12 pt), `Листинг N. …` below code listings.
- Bibliography: ГОСТ 7.0.5-2008 — native `thebibliography` in `sections/bibliography.tex` (no BibTeX/biber dependency).
- Appendices labelled with the Cyrillic letters А, Б, В, … (Ё, З, Й, О, Ч, Ь, Ы, Ъ skipped); figures, tables and listings inside an appendix carry the letter as prefix (`Рис. А.1`, `Таблица В.1`, `Листинг Г.1`).

If `requirements.md` and the `.tex` sources ever disagree, `requirements.md` wins.

## License

No formal license is granted at this time. The build setup (Makefile, GitHub Actions workflow, `.tex` packaging) is intentionally generic and may be useful as a reference; the thesis text itself is the author's original work and is not offered for redistribution or derivative use.
