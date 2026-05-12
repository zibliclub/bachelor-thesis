# Usage:
#   make            -> build main.tex into out/main.pdf
#   make watch      -> continuous rebuild (latexmk -pvc)
#   make clean      -> remove out/ and stray build artifacts
#   make distclean  -> clean + latexmk -C (full latexmk cleanup)

SHELL := /bin/bash

LATEXMK       := latexmk
LATEXMK_FLAGS := -lualatex -interaction=nonstopmode -file-line-error -halt-on-error
MAIN          := main.tex

# Имя PDF в релизе (см. .github/workflows/build-pdf.yml).
RELEASE_NAME    := bachelor-thesis
RELEASE_REMOTE  := origin

.PHONY: build watch clean distclean release help

build:
	$(LATEXMK) $(LATEXMK_FLAGS) $(MAIN)

watch:
	$(LATEXMK) $(LATEXMK_FLAGS) -pvc $(MAIN)

clean:
	@rm -rf out
	@find . -maxdepth 2 -type f \( \
		-name '*.aux' -o -name '*.log' -o -name '*.toc' \
		-o -name '*.out' -o -name '*.synctex.gz' -o -name '*.fdb_latexmk' \
		-o -name '*.fls' -o -name '*.bbl' -o -name '*.bcf' -o -name '*.blg' \
		-o -name '*.run.xml' \) -delete
	@echo "Cleaned."

distclean: clean
	$(LATEXMK) -C $(MAIN)

# Сборка локально → пуш ветки → создание тега v<YYYY.MM.DD>[.N] → пуш тега.
# GitHub Actions подхватит тег и опубликует релиз с PDF (см. workflow).
release:
	@if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		echo "Не git-репозиторий. Сначала: git init && git remote add $(RELEASE_REMOTE) <url>"; exit 1; \
	fi
	@if ! git remote get-url $(RELEASE_REMOTE) >/dev/null 2>&1; then \
		echo "Remote '$(RELEASE_REMOTE)' не настроен. Добавь:"; \
		echo "  git remote add $(RELEASE_REMOTE) git@github.com:zibliclub/bachelor-thesis.git"; \
		exit 1; \
	fi
	@if ! git diff-index --quiet HEAD --; then \
		echo "Рабочая копия грязная — закоммить или спрячь изменения."; exit 1; \
	fi
	@base="v$$(date +%Y.%m.%d)"; tag="$$base"; n=2; \
	while git rev-parse "$$tag" >/dev/null 2>&1; do \
		tag="$$base.$$n"; n=$$((n+1)); \
	done; \
	echo "Локальная пробная сборка..."; \
	$(MAKE) --no-print-directory build || exit $$?; \
	branch=$$(git rev-parse --abbrev-ref HEAD); \
	echo "Пушу $$branch в $(RELEASE_REMOTE)..."; \
	git push $(RELEASE_REMOTE) "$$branch" && \
	git tag -a "$$tag" -m "Release $$tag" && \
	git push $(RELEASE_REMOTE) "$$tag" && \
	echo "Тег $$tag отправлен. GitHub Actions соберёт и опубликует релиз с $(RELEASE_NAME).pdf."

help:
	@echo "Targets:"
	@echo "  make           Build main.tex -> out/main.pdf"
	@echo "  make watch     Continuous rebuild on file change"
	@echo "  make clean     Remove out/ and stray build files"
	@echo "  make distclean clean + latexmk -C"
	@echo "  make release   Push branch + tag v<YYYY.MM.DD>; GitHub Actions опубликует PDF"
