# Build with LuaLaTeX, output into ./out next to main.tex.
$pdf_mode   = 4;            # 4 = lualatex
$lualatex   = 'lualatex -interaction=nonstopmode -file-line-error -synctex=1 %O %S';
$out_dir    = 'out';
$bibtex_use = 0;  # Native thebibliography in sections/bibliography.tex (no BibTeX/biber).
$max_repeat = 8;  # Allow extra passes for cite/ref convergence with thebibliography.
$clean_ext  = 'synctex.gz run.xml bbl bcf fdb_latexmk fls';
