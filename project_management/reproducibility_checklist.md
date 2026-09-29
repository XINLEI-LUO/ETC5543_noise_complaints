# Reproducibility Checklist

## Current reproducibility status

**Overall status: the reviewed candidate sources pass a temporary clean-clone full run, but GitHub `main` cannot yet run the documented workflow because those sources are not committed there.**

The repository now has a canonical read-only preflight and an explicit cross-language regeneration entry point in `analysis/run_pipeline.py`. The preflight verifies R, Python, packages, scripts, inputs and checksums. The current working copy passes all of those checks. Remaining limitations are independent clean-clone verification, uncommitted critical assets and the absence of a final HTML source.

## Environment

| Check | Status | Evidence / required action |
|---|---|---|
| R version recorded | PASS | `renv.lock` records R 4.5.2 |
| R dependency lockfile present | PASS | `renv.lock` exists |
| `renv` activation files present | PASS | `.Rprofile`, `renv/activate.R`, and settings exist |
| Current working-copy R environment verified | PASS | `analysis/run_pipeline.py --check` reports R 4.5.2, `renv` 1.2.4 and core package versions consistent with `renv.lock` |
| Independent clean-clone restore demonstrated | PASS for temporary candidate / FAIL for GitHub `main` | Temporary candidate `423b1f61b8b513cebc4daf139004e56f25175f22` completed restore, preflight and full pipeline; GitHub `main` commit `b6a118649b52643c2e11bdb5983647ed67dc7196` lacks the required runner and lockfiles; see `clean_clone_reproduction_record.md` |
| Python version/dependencies pinned | PASS | `requirements.txt` pins the complete direct/transitive runtime set; the preflight verifies Python 3.12.14 and every exact version |
| Locale robustness | PASS in canonical runner | On Windows the runner removes inherited Unix-only `C.UTF-8` variables before R starts, preserving non-ASCII project paths; direct R execution fails with an actionable message if the bad locale remains |
| Random process fixed | PASS | `analysis/pedestrian_noise_statistical_analysis_2025.py` uses `RANDOM_SEED = 5543` and records per-specification seeds for 99,999 permutations |
| Absolute user paths in project analysis | PASS | No hard-coded user/home path or project `setwd()` was found in inspected analysis scripts; paths are repository-relative or derived from the script location |

## Inputs and provenance

| Check | Status | Evidence / required action |
|---|---|---|
| Required R-pipeline inputs enumerated | PASS | `analysis/run_all.R` checks four required raw inputs |
| Complete-pipeline inputs enumerated and verified | PASS | `analysis/run_pipeline.py` checks six R/Python inputs and their SHA-256 values |
| Raw/reference inventory and SHA-256 values recorded | PASS | `data/README.md` lists bytes, ranges, providers, and checksums |
| Exact microclimate snapshot recoverable | PASS | GitHub Release URL and SHA-256 are recorded for `data/raw/microclimate_sensors.csv` |
| Other exact snapshots recoverable | PARTIAL | Most are Git-tracked, but download dates and fixed portal snapshot URLs are unknown |
| Pedestrian source filename matches actual range | DOCUMENTED EXCEPTION | The historical filename remains for checksum stability; `data/README.md` now identifies it as the current input, records the 2024-08-19 to 2026-08-15 range, and states the year-specific roles |
| Licence/provenance preserved | PARTIAL | Provider links and current CC BY observation are documented, but licence text/download evidence is not preserved per file |
| 2026 completeness handled | PASS analytically / document in HTML | Noise 2026 is partial; pedestrian 2026 has only 166 rows/25 sensors and is excluded from comparative analysis |

## Pipeline and output lineage

| Check | Status | Evidence / required action |
|---|---|---|
| Main R sequence documented | PASS | `analysis/run_all.R` runs EDA, season, outcomes, duplicate sensitivity, integration, CLUE features, and validation |
| Canonical cross-language runner present | PASS | `analysis/run_pipeline.py --run --overwrite` executes the R core, pedestrian integration, zero sensitivity and 2025 pedestrian statistics in dependency order |
| Zero-value sensitivity included in complete runner | PASS | It runs after the 2025 integrated file has been generated |
| Pedestrian integration included in complete runner | PASS | The multiyear Python stage runs after the R sensor-buffer core |
| Pedestrian statistics included in complete runner | PASS | The statistical stage runs last and requires explicit overwrite authorisation |
| Legacy/current scripts distinguished | PARTIAL | Summaries describe some superseded outputs, but filenames do not consistently mark legacy scripts |
| Output-to-script inventory complete | PASS for current processed tables | `data/README.md` now maps the current R and pedestrian/statistical processed tables to producing scripts; final HTML lineage remains future work |
| Safe overwrite controls | PASS for current Python scripts | Current Python scripts require explicit overwrite and check generation metadata; legacy scripts do not provide the same guarantees |
| Validation checks pass | PASS for sensor integration | `analysis/validate_sensor_integration.R` was run during the audit and reported 11 sensors, 33 rows, monotonic features, maximum duplicate sensitivity of 0.1, and CLUE validation passed |
| Pedestrian QA checks pass | PASS for current outputs | `data/processed/pedestrian_multiyear_qa.csv` contains 22 PASS checks |
| Source-code syntax checks | PASS | 12 R scripts parsed and 5 Python scripts compiled after the reproducibility changes |
| Final presentation build reproducible | FAIL | No presentation source or render command exists |

## Data semantics and analytical safeguards

| Check | Status | Evidence / required action |
|---|---|---|
| Primary spatial distance fixed | PASS | 500 m is primary; 250 m and 1,000 m are sensitivity specifications |
| Analysis key fixed | PASS | `device_id + buffer_m` identifies `sensor × buffer` rows |
| Zero versus missing semantics defined | PASS | Zero contextual count means confirmed absence after successful load; `NA` means missing/invalid/failed linkage |
| Exact zero Noise handling transparent | PASS | Zeros retained in primary analysis; exclusion sensitivity is separate |
| Physical Noise unit verified | FAIL / external metadata needed | Report only dataset units |
| Sensor calibration/siting metadata available | FAIL | Prevent location-only or physical-sound interpretation |
| Time zone explicit | PASS in analysis | Timestamps are converted to Melbourne local time; final HTML should repeat this |
| Mixed feature years explicit | PASS in processed metadata and current reports | 2025 pedestrian/noise analysis labels 2024 business capacity as a **lagged 2024 contextual baseline, not a 2025 measurement** |
| Small-sample robustness present | PASS | Permutation inference, influence diagnostics, buffer sensitivity, and leave-one-sensor-out checks exist |

## Required clean-clone run order

The following order should be tested on a clean clone before submission. The current repository now supports the same sequence through the canonical runner.

1. Restore tracked raw/reference files and fetch the verified microclimate release asset.
2. Verify every checksum in `data/README.md`.
3. Install R 4.5.2 and successfully restore `renv.lock`.
4. Create a Python 3.12.14 environment and install `requirements.txt`.
5. Run `python analysis/run_pipeline.py --check`.
6. Run `python analysis/run_pipeline.py --run --overwrite` only after generated outputs may be replaced. This executes the R core, pedestrian integration, zero sensitivity and pedestrian statistics in order.
7. Run the new RQ3 descriptive-selection script and new figure scripts when implemented.
8. Render `presentation/final_presentation.qmd` to HTML.
9. Run validation, syntax, link/resource, and offline-open checks.
10. Compare key numerical results and output checksums against the submission record.

## Submission record template

Complete and retain the following alongside the final HTML:

| Field | Value |
|---|---|
| Git revision | To record |
| Dirty working tree? | Must be `No` or explicitly justified |
| Render date/time zone | To record |
| R version | Expected 4.5.2 |
| `renv` status | To record after successful restore |
| Python version | To record |
| Python dependency lock/checksum | `requirements.txt`; SHA-256 `7e3d6215db05c74d9347ce6b23c13e7cc8830995dd12b49dd0703bddaeccd09e` |
| Microclimate SHA-256 | Expected `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` |
| Main HTML path | To record |
| Render command | To record |
| Offline HTML check | To record |
| Independent rerun reviewer | To record |

## Final gate

Do not describe the project as fully reproducible until a second person can start from a clean clone, recover the exact inputs, restore both language environments, run the full cross-language sequence, render the final HTML, and reproduce the key headline values without manual edits to generated files.
