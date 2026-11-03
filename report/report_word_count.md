# Report word count

Count date: 28 October 2026.

## Result

The final report complies with the required 10,000--12,000-word range under two transparent counting methods:

- **10,257 narrative words** in the Quarto source before the References heading, after excluding YAML, headings, figure captions, table cells, raw Typst instructions, URLs and code-like path fragments.
- **10,573 rendered-equivalent words** when the same source count also includes headings (126), figure captions (106) and table text (84), but still excludes the reference list.
- **10,399 words in the rendered PDF body** from the Abstract through Individual contributions, excluding the table of contents, title material, page numbers and References.

The narrative-only count is the most conservative of these measures and is already above 10,000. Differences between the source and PDF totals arise from tokenisation, line wrapping, cross-reference substitution and the treatment of hyphenated or code-styled terms. None of the three measures counts the reference list.

## Counting rule

The audit script reads `report/final_report.qmd` only up to `# References {.unnumbered}`. It removes the YAML block, raw Typst blocks, Markdown link targets, image paths and inline formatting before counting word-like English tokens. Headings, captions and table cells are counted separately so that their inclusion is explicit rather than accidental.

The rendered-PDF check extracts pages 2--23, removes the table-of-contents text that precedes the Abstract, stops before the References heading and excludes isolated page numbers. It is an independent cross-check of the content that actually reached the PDF, not the compliance total used in isolation.

The earlier `Measure-Object -Word` total of 10,260 has been withdrawn because it counted raw Quarto syntax and YAML while claiming to represent substantive English narrative. The corrected audit is based on rendered-content boundaries and reports its assumptions.
