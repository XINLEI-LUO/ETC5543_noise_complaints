# Pre Presentation Action Plan

## Progress update

Items 1 and 2 were completed on 1 October 2026. The restored raw Noise snapshot matches the recorded SHA-256, and the canonical read-only preflight passes after refreshing the Windows spatial dependencies to `s2 1.1.13` and `sf 1.1-3` in `renv.lock`.

## Decision rule

Complete P0 work before changing any final interpretation. Complete P1 work before treating the HTML as presentation-ready. P2 work supports transparency and appendices. Do not start the optional RQ4 benchmark until the sensor-by-time and RQ3 deliverables are complete.

## P0 Required before final interpretation

| Order | Task | Reason and teacher feedback | Dependency | Expected output | Acceptance criteria | Suggested owner based on evidence | Effort | Presentation section |
|---:|---|---|---|---|---|---|---|---|
| 1 | Recover and verify `data/raw/microclimate_sensors.csv` | The canonical preflight currently fails; existing outputs cannot be regenerated from the current workspace | GitHub Release authentication and checksum in `data/README.md` | Restored raw snapshot | File exists and SHA-256 equals `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` | Current pipeline/reproducibility maintainer; team confirmation required | Small | Reproducibility |
| 2 | Rerun read-only preflight | Confirms environment, inputs, versions and checksums before analytical edits | Task 1 | Logged `analysis/run_pipeline.py --check` result | All Python, R, package, script, input and checksum checks pass | Current pipeline/reproducibility maintainer | Small | Reproducibility |
| 3 | Freeze final analysis definitions | Prevent outcome/window/threshold choices from changing after results are viewed | Current teacher feedback and existing data dictionaries | Short analysis specification in the new script or project management record | States outcome, night definition, 500 m primary buffer, 250/1000 m sensitivities, zero handling, coverage rule and contextual feature year | Team decision; Cindy role evidence for Noise definitions, Sandhya role evidence for amenities | Small | Methodology |
| 4 | Build sensor x hour summary and heatmap | Teacher's first analytical priority; needed to show whether the daily pattern is shared | Existing raw snapshot or `data/processed/noise_sensor_hour.csv`; frozen aggregation rule | New CSV and figure | Exactly 11 usable sensors x 24 hours where data exist; equal-sensor logic documented; readable IDs; no record-count weighting ambiguity | Cindy according to meeting records; identity mapping requires team confirmation | Medium | Sensor by time results |
| 5 | Build individual sensor hourly profiles | Shows whether pooled daily pattern is broadly shared and identifies exceptions | Task 4 | Small-multiple figure | Same scale where practical; coverage/sample-size annotation; all 11 usable sensors included | Cindy according to meeting records; confirm | Medium | Sensor by time results |
| 6 | Reconcile seasonal wording with final story | Seasonal ranking changes with sensor composition and threshold | Existing seasonal outputs | Final text block and figure decision | No stable causal/seasonal-effect claim; states two-sensor 75% result and composition sensitivity | Noise-analysis owner; confirm | Small | Temporal results / appendix |

## P1 Required for the main HTML story

| Order | Task | Reason and teacher feedback | Dependency | Expected output | Acceptance criteria | Suggested owner based on evidence | Effort | Presentation section |
|---:|---|---|---|---|---|---|---|---|
| 7 | Create the requested 500 m integration map | Current map omits pedestrian counters and sensor identifiers | Valid sensor and pedestrian locations | One new map | Shows Noise sensors, pedestrian counters, 500 m boundaries, sensor IDs, municipal context and legible legend; says monitored locations only | Chen is associated with spatial validation in meeting records; current production scripts are largely committed by Xinlei; confirm owner | Medium | Data and spatial design |
| 8 | Create the RQ3 descriptive location profile | Teacher permits this if selection is transparent and non-causal | Frozen outcome and one amenity/access measure; distribution review | All-site CSV/table and one compact figure if useful | Shows all 11 sites, raw values, thresholds, selected flag and reason; thresholds are parameters; no reverse-engineered rule | Sandhya role evidence for amenity features plus Cindy role evidence for outcome; confirm | Medium | Descriptive location profiles |
| 9 | Package pedestrian analysis for presentation | Existing result is valid but must emphasise instability | Existing 2025 tables and figures | Short result block and main/appendix figure allocation | Reports n=10 at 500 m, Spearman 0.248, permutation p=0.494, leave-one-out range 0.067 to 0.583 and buffer-direction instability; uses approved cautious sentence | Current statistical-analysis maintainer; confirm | Small | Spatial and pedestrian results |
| 10 | Create `presentation/final_presentation.qmd` | No final report source exists | Tasks 3-9 | English Quarto source | Follows `project_management/final_html_content_map.md`; relative paths only; no unsupported claims; sources figures and tables reproducibly | Team lead/editor; confirm | Large | Entire presentation |
| 11 | Add a minimal presentation style | A live HTML needs clear hierarchy without assuming reveal.js | Task 10 | `presentation/styles.css` only if necessary | Readable at projected size; responsive; restrained; print and offline view checked | HTML editor | Medium | Entire presentation |
| 12 | Render a self-contained HTML document | Teacher requires HTML, not PowerPoint | Quarto installation and Tasks 10-11 | `presentation/final_presentation.html` | Opens locally without a server; resources embedded; no broken images/links; English throughout | HTML editor / reproducibility reviewer | Medium | Deliverable |
| 13 | Confirm contribution evidence with every member | Git authorship is not equivalent to contribution | Contribution register and team responses | Confirmed contribution table | Each member approves responsibility, files, presentation and validation entries; unresolved identities remain labelled | All members | Small | Contributions |
| 14 | Write project reflection | Assessment requires more than a limitation list | Final findings and contribution confirmation | 4-6 concise reflection paragraphs or structured section | Covers successes, weaker analyses, effect of metadata/coverage limits, credibility decisions and next steps | Whole team | Small | Reflection |

## P2 Useful supporting material

| Order | Task | Reason | Dependency | Expected output | Acceptance criteria | Suggested owner | Effort | Presentation section |
|---:|---|---|---|---|---|---|---|---|
| 15 | Curate appendix sensitivity panels | Keeps the main story focused while preserving auditability | Final result selection | Appendix panels/tables | Includes zero, duplicate, buffer and seasonal coverage sensitivities without repeating main text | Analysis owners | Medium | Technical appendix |
| 16 | Resolve duplicate/legacy naming | Avoids accidental use of obsolete outputs | Final file manifest | Canonical figure/output list | One canonical integration-map path; legacy scripts and `analysis/variable_dictionary.md` clearly marked or archived after approval | Repository maintainer | Small | Reproducibility |
| 17 | Refresh clean-clone record | Existing record contains a stale statement about current `origin/main` | Tasks 1, 2, 10-12 | Updated reproduction record | Tests the actual submission commit, not a temporary candidate; records exact commands and warnings | Independent reviewer preferred | Medium | Reproducibility |
| 18 | Run final numerical and visual QA | Prevents drift between source, text and figures | Rendered HTML | QA log | Headline numbers match CSVs; figures readable; no forbidden unit/causal/city-wide language; offline open passes | Someone other than the primary HTML author if possible | Medium | Entire presentation |
| 19 | Add a one-command render entry | Makes the final artifact reproducible | Quarto source complete | Documented command or small wrapper | Clean session can run analysis check then render HTML with no manual file editing | Reproducibility maintainer | Small | Reproducibility |

## Future work rather than current-scope work

| Task | Why defer | Conditions for later use |
|---|---|---|
| Large multivariable “unexpectedly high or low” model | Eleven sites cannot support many correlated urban-context predictors; coefficients and residuals would be unstable | More monitored locations, sensor metadata, aligned context periods and a pre-registered model specification |
| City-wide hotspot surface | The network is sparse and centrally concentrated | A substantially denser, calibrated monitoring network and spatial validation |
| Health, safety or guideline interpretation | Physical unit, calibration and quality metadata are unresolved | Authoritative sensor metadata and an appropriate regulatory framework |
| Causal claims about amenities or pedestrian activity | Current data are observational, spatially selected and partly temporally lagged | Stronger design, aligned exposure measures and defensible confounding control |

## Recommended execution sequence

1. Recover the missing raw Noise snapshot and pass the preflight.
2. Freeze the final definitions and wording rules.
3. Complete sensor-by-hour heatmap and individual profiles.
4. Build the revised 500 m sensor/pedestrian map.
5. Complete the transparent RQ3 all-site profile.
6. Decide whether RQ4 is omitted, future work, or a minimal appendix-only benchmark.
7. Assemble the English Quarto HTML around the central story.
8. Confirm contributions and write the reflection.
9. Render self-contained HTML, perform numerical/visual/offline QA and refresh the clean-clone record.

