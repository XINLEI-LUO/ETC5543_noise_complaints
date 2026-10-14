# Final Presentation Manual Review

Complete these checks before submission and again before presenting.

## Content and evidence

- [ ] Confirm whether `figures/sensor_2.jpg` shows the exact model used in the source dataset or only representative fixed monitoring equipment.
- [ ] Confirm the photograph's source, permission and required attribution.
- [ ] If authoritative metadata becomes available, update the sensor model, physical unit, calibration, mounting and zero-value wording consistently.
- [ ] Keep the hospitality follow-up labelled post-screen, exploratory and non-causal.
- [ ] Keep the 2024 hospitality records labelled as lagged context for 2025 Noise.
- [ ] Keep the pedestrian shaded region labelled as a confidence band for the fitted OLS mean, not an individual prediction interval or a Spearman interval.
- [ ] Keep hospitality error bars labelled as leave-one-site-out ranges, not confidence intervals.

## Visual and classroom checks

- [ ] Open `presentation/final_presentation.html` on the classroom computer with Wi-Fi disabled.
- [ ] Use the intended browser in full-screen presentation mode and click through every main and backup slide.
- [ ] Check that no title, bullet, footnote, axis label or image is clipped at the classroom resolution.
- [ ] Check that slide 5's map labels, slide 8's pedestrian chart and slide 10's hospitality annotations are readable from the back of the room.
- [ ] Confirm that arrow-key navigation, slide numbers and the progress bar work.
- [ ] Keep a local backup copy of the self-contained HTML on a second device or drive.

## Rehearsal

- [ ] Rehearse once with the actual HTML, not a PDF or screenshots.
- [ ] Target about 13 minutes and finish before 14 minutes to preserve a safety margin.
- [ ] Practise both handovers: Sandhya to Xinlei and Xinlei to Chen.
- [ ] Do not read every chart label; point to the one pattern the audience should notice.
- [ ] Practise the short spoken answers in `Q&A2.md`, especially permutation logic, confidence bands, causality and the small sample.

## Reproducibility gate

- [ ] Run the pipeline environment check and record any version mismatch.
- [ ] Run the full pipeline from a clean clone before submission.
- [ ] Confirm all source checksums and processed outputs match the intended submission state.
- [ ] Render the final QMD with Quarto and confirm that the HTML contains no external asset dependency.
- [ ] Verify the committed HTML is the same file used for the classroom rehearsal.
- [ ] Confirm the final commit contains no raw-data changes or unintended temporary files.

## Known item requiring attention

- The bundled Python environment currently has `tzdata 2026.5`, while `requirements.txt` pins `tzdata 2026.4`. Resolve or deliberately document this version mismatch before the clean-clone submission record is signed off.

