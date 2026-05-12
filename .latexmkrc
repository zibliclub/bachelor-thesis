# Build with LuaLaTeX, output into ./out next to main.tex.
$pdf_mode   = 4;            # 4 = lualatex
$lualatex   = 'lualatex -interaction=nonstopmode -file-line-error -synctex=1 %O %S';
$out_dir    = 'out';
$bibtex_use = 2;
$clean_ext  = 'synctex.gz run.xml bbl bcf fdb_latexmk fls';
