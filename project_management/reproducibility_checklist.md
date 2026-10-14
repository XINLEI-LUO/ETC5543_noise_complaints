# Reproducibility Checklist

## Current status

**Overall status: the analysis and self-contained HTML presentation have reproducible source, but the final clean-clone gate is still open.** Six required inputs are checksum-controlled, the canonical pipeline orders the analysis, the Quarto source exists, and the HTML can be rebuilt from repository-relative assets. The remaining submission checks are the pinned Python version mismatch, a clean-clone regeneration, offline classroom inspection and an independent rerun.

## Environment

| Check | Status | Evidence or action |
|---|---|---|
| R version recorded | PASS | `renv.lock` records R 4.5.2. |
| R dependency lock present | PASS | `renv.lock`, `.Rprofile`, `renv/activate.R` and `renv/settings.json` exist. |
| Python version pinned | PASS | `analysis/run_pipeline.py` requires Python 3.12.14. |
| Python packages pinned | PARTIAL | Exact versions are in `requirements.txt`; the bundled runtime has `tzdata 2026.5` while the file pins 2026.4. |
| Random process fixed | PASS | Statistical scripts use seed 5543 and 99,999 permutation draws. |
| Project-relative analysis paths | PASS | Inspected scripts derive paths from the repository or script root. |
| Quarto identified | PASS | Quarto 1.8.25 is available through the RStudio installation even when `quarto` is not on PATH. |

## Inputs and provenance

| Check | Status | Evidence or action |
|---|---|---|
| Required inputs enumerated | PASS | `analysis/run_pipeline.py` lists six inputs and expected SHA-256 hashes. |
| Raw Noise snapshot verified | PASS | `data/raw/microclimate_sensors.csv` matches SHA-256 `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01`. |
| Other required inputs present | PASS | The five additional pipeline inputs are included. |
| Snapshot dates known | PARTIAL | The Noise snapshot date is recorded; exact download dates for some other sources need team confirmation. |
| Dynamic-source risk documented | PASS | `data/README.md` distinguishes retained snapshots from current portal exports. |
| Per-file licence evidence | PARTIAL | Providers and links are documented; final per-file licence/download evidence is incomplete. |
| Sensor photograph provenance | MANUAL CHECK | Confirm source, permission and whether `figures/sensor_2.jpg` is the exact dataset model or representative equipment. |

## Pipeline and output lineage

| Check | Status | Evidence or action |
|---|---|---|
| Canonical runner | PASS | `analysis/run_pipeline.py` checks environments, inputs, hashes and required scripts, then orders the analysis. |
| Full preflight | PARTIAL | Data, scripts, hashes and R environment pass; the bundled Python check reports only the `tzdata` pin mismatch. |
| Full regeneration | PENDING FINAL GATE | Run `--run --overwrite` in a disposable clean clone before submission. |
| Processed output mapping | PASS | `data/README.md` maps current processed files to their producing scripts. |
| Figures code-generated | PASS | Displayed analytical figures have producing scripts. |
| Presentation source | PASS | `presentation/final_presentation.qmd` and `presentation/styles.css` define the deck. |
| One-command final render | PASS | `quarto render presentation/final_presentation.qmd` from the repository root. |

## Analytical safeguards

| Check | Status | Evidence or action |
|---|---|---|
| Primary spatial distance | PASS | 500 m is primary; 250 m and 1,000 m are sensitivity specifications. |
| Analysis key | PASS | `device_id + buffer_m`; validation expects 33 unique rows. |
| Zero versus missing rules | PASS | Context zeros mean confirmed absence; Noise zeros are retained with a separate sensitivity analysis. |
| Physical unit verified | FAIL — external metadata | Use “recorded Noise in dataset units” only. |
| Calibration, mounting and siting metadata | FAIL — external metadata | Site differences cannot be interpreted as pure location effects. |
| Time zone | PASS | Australia/Melbourne is documented in the analysis. |
| Mixed context years | PASS if wording preserved | 2024 hospitality fields are lagged context for 2025 comparisons. |
| Small-sample robustness | PASS | Spearman, permutation, leave-one-site-out and buffer checks are reported. |
| Permutation unit and null | PASS | One aggregated sensor site is shuffled; context ranks stay fixed while Noise ranks are permuted. |
| Uncertainty labels | PASS | Pedestrian shading is an OLS fitted-mean confidence band; hospitality bars are leave-one-site-out ranges. |
| Seasonal claim | PASS if backup wording preserved | Only two sensors pass the strict 75% coverage rule; seasonal order is composition-sensitive. |

## Final HTML reproducibility requirements

| Requirement | Status | Acceptance test |
|---|---|---|
| English Quarto source | PASS | Main and backup slides are in `presentation/final_presentation.qmd`. |
| RevealJS format | PASS | The QMD declares a 1600 by 900 RevealJS deck. |
| Relative paths | PASS | QMD and CSS contain repository-relative assets, not user-specific paths. |
| Self-contained output | PASS after each render | `embed-resources: true`; verify no external image or stylesheet dependency. |
| Deterministic tables and figures | PASS | Displayed values trace to generated tables and figures. |
| HTML resource audit | TO RECHECK AFTER FINAL RENDER | Verify every image is embedded and all slide assets resolve. |
| Headline-value check | TO RECHECK AFTER FINAL RENDER | Confirm hourly, sensor, pedestrian and hospitality values against source outputs. |
| Visual classroom check | MANUAL | Open offline, use full-screen mode and inspect every main and backup slide. |
| Independent rerun | PENDING | A second person restores environments, runs the pipeline and confirms outputs. |

## Required clean-clone sequence before submission

1. Clone the exact submission revision.
2. Recover `data/raw/microclimate_sensors.csv` from the authenticated release asset if it is not present.
3. Verify all six input checksums.
4. Restore R 4.5.2 packages from `renv.lock`.
5. Create the pinned Python 3.12.14 environment from `requirements.txt` and resolve or document the `tzdata` mismatch.
6. Run `python analysis/run_pipeline.py --check`.
7. Run `python analysis/run_pipeline.py --run --overwrite` in the disposable clean clone.
8. Render `presentation/final_presentation.qmd` with Quarto.
9. Run numerical, visual, resource and offline-open checks.
10. Record the final commit, environment versions, input hashes, render command and independent reviewer.

## Submission record

| Field | Value |
|---|---|
| Git revision | To record |
| Working-tree state | Must be clean or explicitly justified |
| Render date and time zone | To record; Australia/Sydney |
| R version | Expected 4.5.2 |
| Python version | Expected 3.12.14 |
| `requirements.txt` SHA-256 | `7e3d6215db05c74d9347ce6b23c13e7cc8830995dd12b49dd0703bddaeccd09e` |
| Microclimate SHA-256 | `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` |
| Quarto version | 1.8.25 in the current RStudio installation; record clean-clone version |
| Main HTML | `presentation/final_presentation.html` |
| Render command | `quarto render presentation/final_presentation.qmd` |
| Offline HTML check | To record |
| Independent reviewer | To record |

## Final gate

Do not call the project fully reproducible until a second person can start from the submission revision, recover the exact inputs, restore R and Python environments, regenerate the analyses, render the self-contained HTML and reproduce the headline values without manual edits to generated files.
