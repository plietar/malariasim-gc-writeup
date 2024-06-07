set -eux
latexmk -pdf fig.tex
pdf2svg fig.pdf fig.svg
