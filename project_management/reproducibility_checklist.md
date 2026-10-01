# Reproducibility Checklist

## Current status

**Overall status: the canonical read-only preflight passes, but final-presentation reproducibility is still incomplete.** The restored `data/raw/microclimate_sensors.csv` matches the recorded SHA-256, all six inputs pass checksum verification, Python 3.12.14 matches all 23 pinned requirements, R 4.5.2 is consistent with `renv.lock`, and existing processed outputs pass the repository validation script. The final Quarto source, render command and HTML do not yet exist.

## Audit commands and results through 1 October 2026

| Check | Command or method | Result |
|---|---|---|
| Git state | `git status -sb` | `main` at `72b4893`, tracking `origin/main`; pre-existing user changes: modified `meetings/Meeting_Agenda.docx`, untracked `1.docx` |
| Canonical read-only preflight | Bundled Python 3.12.14 running `analysis/run_pipeline.py --check` with R 4.5.2 on PATH | PASS: Python and 23 pinned packages, five pipeline scripts, six inputs and hashes, R 4.5.2, `renv` and core package versions |
| R syntax | Parse every `analysis/*.R` with R 4.5.2 | 12 of 12 PASS |
| Python syntax | Parse every `analysis/*.py` with Python AST | 4 of 4 PASS |
| Existing-output validation | `Rscript --vanilla analysis/validate_sensor_integration.R` | PASS: 11 sensors, 33 unique sensor-buffer rows, valid coverage/count semantics, duplicate sensitivity maximum 0.1 and CLUE checks |
| Presentation source search | Search for `.qmd`, `.Rmd`, `_quarto.yml`, HTML and CSS outside dependencies | None found |
| Quarto availability | `quarto --version` | Not available on PATH in this environment |
| Spatial dependency refresh | `renv::record(c("s2@1.1.13", "sf@1.1-3"))` | `renv.lock` updated because the prior Windows binary versions were no longer available from current CRAN; current Windows binaries install and validate |

## Environment

| Check | Status | Evidence or action |
|---|---|---|
| R version recorded | PASS | `renv.lock` records R 4.5.2 |
| R dependency lock present | PASS | `renv.lock`, `.Rprofile`, `renv/activate.R` and `renv/settings.json` exist |
| Python version pinned | PASS | `analysis/run_pipeline.py` requires Python 3.12.14 |
| Python packages pinned | PASS | `requirements.txt` has exact versions; bundled environment matched all 23 |
| Random process fixed | PASS | `analysis/pedestrian_noise_statistical_analysis_2025.py` uses seed 5543 and 99,999 permutation draws |
| Absolute analysis paths | PASS in inspected scripts | Project files use relative paths or script-root derivation |
| Quarto installed and version recorded | FAIL | Install/identify Quarto before final render and record its version |

## Inputs and provenance

| Check | Status | Evidence or action |
|---|---|---|
| Required inputs enumerated | PASS | `analysis/run_pipeline.py` lists six inputs and expected SHA-256 hashes |
| Raw Noise snapshot present | PASS | `data/raw/microclimate_sensors.csv` is present at 163,912,284 bytes |
| Raw Noise snapshot verified | PASS | SHA-256 is `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` |
| Other raw inputs present | PASS | Eight tracked raw CSVs are present; the five non-Noise inputs required by the complete pipeline are included |
| Snapshot dates known | PARTIAL | Noise snapshot date is recorded; exact download dates for most other sources require team confirmation |
| Dynamic-source risk documented | PASS | `data/README.md` distinguishes current portal exports from retained snapshots |
| Licence evidence retained per file | PARTIAL | Providers/links are documented; per-file licence/download evidence is incomplete |

## Pipeline and output lineage

| Check | Status | Evidence or action |
|---|---|---|
| Canonical complete runner | PASS | `analysis/run_pipeline.py` orders R core, multiyear pedestrian integration, zero sensitivity and pedestrian statistics |
| Full current preflight | PASS | `analysis/run_pipeline.py --check` validates both language environments, scripts, inputs and checksums |
| Full current regeneration | NOT ATTEMPTED | `--run --overwrite` would replace generated outputs and belongs in a disposable clean clone or an explicitly approved regeneration stage |
| Existing R integration validation | PASS | Read-only validation passed during this audit |
| Processed output-to-script mapping | PASS for current tables | `data/README.md` maps processed files to producing scripts |
| Legacy/current distinction | PARTIAL | README identifies two legacy scripts, but `analysis/variable_dictionary.md` still presents absent legacy outputs without a strong obsolete label |
| Intermediate files rebuildable | PREVIOUSLY VERIFIED / NOT RERUN IN THIS STAGE | Earlier clean-clone records report success; this stage intentionally stopped after the read-only preflight |
| Figures code-generated | MOSTLY PASS | Current figures have producing scripts; the final HTML has no build source yet |
| One-command final render | FAIL | No presentation source or render command exists |

## Analytical safeguards

| Check | Status | Evidence or action |
|---|---|---|
| Primary spatial distance | PASS | 500 m primary; 250 and 1000 m sensitivity |
| Analysis key | PASS | `device_id + buffer_m`; validation confirms 33 unique rows |
| Zero versus missing rules | PASS | Zero indicates confirmed absence for context features; NA indicates missing/invalid/failed linkage; Noise zeros retained with separate sensitivity |
| Physical unit verified | FAIL external metadata | Use dataset units only |
| Calibration/mounting/siting metadata | FAIL external metadata | Prevents physical or purely spatial interpretation of site differences |
| Time zone | PASS | Australia/Melbourne is documented in analysis |
| Mixed context years | PASS if wording preserved | 2024 business fields are explicitly lagged contextual baselines for 2025 comparisons |
| Small-sample robustness | PASS for pedestrian analysis | Permutation, influence, buffer and leave-one-sensor-out outputs exist |
| Sensor-by-time evidence | PARTIAL | Availability and equal-sensor summaries exist; heatmap and individual profiles are missing |

## Final HTML reproducibility requirements

| Requirement | Current status | Acceptance test |
|---|---|---|
| English Quarto source | Missing | `presentation/final_presentation.qmd` exists and contains all main sections |
| Template/format decision | Missing | Standard HTML document selected after confirming no course template; reveal.js not assumed |
| Relative paths | To verify | No local drive/user-specific paths in QMD, CSS or generated links |
| Self-contained output | Missing | HTML opens offline with images/styles embedded or packaged predictably |
| Deterministic tables/figures | Partial | Every displayed value traces to code-generated CSV/figure; new RQ3 rule is parameterised |
| Render command | Missing | One documented command renders from a clean session |
| HTML resource/link audit | Missing | No broken images, anchors or external local assets |
| Headline-value check | Missing | Hourly, sensor, seasonal and pedestrian values match source CSVs |
| Contribution confirmation | Missing | Every member confirms final table |
| Independent rerun | Missing | A second person recovers inputs, restores environments, runs check/build and confirms outputs |

## Required clean-clone sequence before submission

1. Clone the exact submission revision.
2. Recover `data/raw/microclimate_sensors.csv` from the authenticated Release asset when it is not already available.
3. Verify all six pipeline input checksums; the current working copy passes this check.
4. Restore R 4.5.2 packages from `renv.lock`.
5. Create a Python 3.12.14 environment from `requirements.txt`.
6. Run `python analysis/run_pipeline.py --check`.
7. Run `python analysis/run_pipeline.py --run --overwrite` only in a disposable clean clone or after generated outputs are approved for replacement.
8. Run the new sensor-by-time, map and RQ3 generation steps once added to the canonical pipeline.
9. Render `presentation/final_presentation.qmd` to a self-contained HTML file.
10. Run numerical, visual, link/resource and offline-open checks.
11. Record the final commit, environment versions, hashes, render command and independent reviewer.

## Submission record

| Field | Value |
|---|---|
| Git revision | To record |
| Dirty working tree | Must be clean or explicitly justified |
| Render date and time zone | To record; Australia/Sydney |
| R version | Expected 4.5.2 |
| `renv` status | To record after clean restore |
| Python version | Expected 3.12.14 |
| `requirements.txt` SHA-256 | `7e3d6215db05c74d9347ce6b23c13e7cc8830995dd12b49dd0703bddaeccd09e` |
| Microclimate SHA-256 | `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` |
| Quarto version | To record |
| Main HTML path | Expected `presentation/final_presentation.html` |
| Render command | To record |
| Offline HTML check | To record |
| Independent rerun reviewer | To record |

## Final gate

Do not call the final project fully reproducible until a second person can start from the submission revision, recover the exact inputs, restore R and Python environments, regenerate the analyses, render the self-contained HTML and reproduce the headline values without manual edits to generated files.

