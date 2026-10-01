# Melbourne Monitored Noise and Urban Context

## Project overview

This project analyses recorded Noise values at monitored locations and their relationships with temporal patterns and nearby urban-activity characteristics. The repository contains data-quality checks, time-based summaries, zero-value and duplicate-timestamp sensitivity analyses, spatial buffer integration and validation.

The repository and RStudio project retain a historical `noise_complaints` name. That name does not describe the current research scope. Results describe monitored sensors and their surrounding urban context; they do not represent a complete City-wide surface.

## Research questions

The main research question is:

> How do monitored urban Noise values vary across time and space in the City of Melbourne, and what characteristics of the surrounding urban environment are associated with these patterns?

Supporting questions are:

- How do recorded Noise values vary by time of day, day of week and season at the monitored locations?
- Which monitored locations have the highest and lowest recorded Noise values, and how do those patterns vary over time?
- Are areas with heavy nightlife always associated with higher recorded Noise values, or are there monitored areas with lower recorded values that still have good access to restaurants and entertainment?

An originally proposed fourth question asked whether any monitored locations had relatively high or low recorded Noise values given their surrounding urban characteristics. This question is deferred as future work rather than treated as a completed result. With only 11 usable locations, a multivariable contextual benchmark would be highly sensitive to predictor choice and individual sites. A future version would require a pre-specified outcome, no more than one or two well-justified contextual variables, an all-site deviation table and leave-one-sensor-out sensitivity analysis. The current pedestrian association analysis does not answer this deferred question.

## Scope

- The temporal coverage of the local microclimate snapshot is 31 May 2022 to 17 August 2026.
- The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.
- The spatial unit is a monitored sensor location. Eleven sensors have usable noise observations.
- The primary urban-context distance is 500 m; 250 m and 1,000 m are sensitivity distances.
- Spatial coverage is limited to monitored locations and should not be interpreted as continuous or complete coverage of the City of Melbourne.

## Repository structure

| Path | Purpose |
|---|---|
| `analysis/` | R scripts, validation code, data dictionaries and analysis notes |
| `data/raw/` | Source snapshots; do not edit these files manually |
| `data/reference/` | Municipal boundary files used for mapping and spatial checks |
| `data/processed/` | Regenerable analysis outputs |
| `figures/` | Regenerable plots and integration maps |
| `meetings/` | Meeting agendas, weekly reports and contribution records |
| `project_management/` | Audit, action-plan and reproducibility records |
| `renv/` and `renv.lock` | Reproducible R package environment |
| `requirements.txt` | Exact Python package versions for the current analysis pipeline |

## Software requirements

- R 4.5.2 is the version recorded in `renv.lock`.
- `renv` 1.2.4 restores the project package library.
- Core direct R dependencies are `dplyr`, `tidyr`, `readr`, `sf` and `ggplot2`.
- Python 3.12.14 is the verified interpreter for the current pedestrian integration and statistical stages.
- Direct and transitive Python runtime package versions are pinned in `requirements.txt`.
- Quarto is required only to render the final presentation source at `presentation/final_presentation.qmd`; it is not required to regenerate the analysis outputs.
- `analysis/convert_reference_boundary.py` remains an optional standard-library-only boundary conversion utility.

On Windows, CRAN binary packages normally include the compiled spatial libraries needed by `sf`. On Linux or macOS, installing `sf` may require GDAL, GEOS, PROJ and udunits2 development libraries; consult the `sf` installation documentation for the operating system in use.

## Environment setup

Clone the repository, open a terminal in the repository root and run:

```r
install.packages("renv", repos = "https://cloud.r-project.org")
renv::restore()
```

The project-local package library under `renv/library/` is ignored by Git. Commit `renv.lock`, `.Rprofile`, `renv/activate.R`, `renv/settings.json` and `renv/.gitignore` so another user can restore the same package versions.

To check the environment after restoration:

```r
renv::status()
```

Create a Python 3.12.14 virtual environment and install the pinned analysis packages:

```sh
python -m venv .venv
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

The repository does not track `.venv`. Use the same Python interpreter for the environment check and the full pipeline.

## Data availability and provenance

The full file inventory, exact byte sizes, SHA-256 checksums, source pages, acquisition instructions and snapshot limitations are in [`data/README.md`](data/README.md).

`data/raw/microclimate_sensors.csv` is 163,912,284 bytes and exceeds GitHub's normal 100 MB file limit. The verified project snapshot is stored as a GitHub Release asset:

- Release: <https://github.com/XINLEI-LUO/ETC5543_noise_complaints/releases/tag/microclimate_sensors_data_snapshot_2026_08>
- Direct asset: <https://github.com/XINLEI-LUO/ETC5543_noise_complaints/releases/download/microclimate_sensors_data_snapshot_2026_08/microclimate_sensors.csv>
- Expected SHA-256: `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01`

The repository is private at the time of this audit, so the direct asset URL returns 404 without GitHub authentication. After authenticating with GitHub CLI, recover it with `gh release download microclimate_sensors_data_snapshot_2026_08 --repo XINLEI-LUO/ETC5543_noise_complaints --pattern microclimate_sensors.csv --dir data/raw`. The City of Melbourne portal is dynamic. A current export can differ from the retained project snapshot even when its dataset identifier is unchanged. Use the Release asset when reproducing this repository's recorded results and verify its checksum before running the pipeline.

## Check and run the complete pipeline

From the repository root, first run the read-only preflight check:

```sh
python analysis/run_pipeline.py --check
```

The check verifies R 4.5.2, locked R package versions, Python 3.12.14 and all pinned direct/transitive Python runtime packages, required scripts, required inputs and their SHA-256 checksums. On Windows it also removes an inherited Unix-only `C.UTF-8` locale before launching R and places temporary `renv` runtime state under the ignored `renv/runtime/` directory. This prevents non-ASCII project paths from being mis-encoded by Windows R.

To regenerate all current outputs, explicitly authorise replacement of generated files:

```sh
python analysis/run_pipeline.py --run --overwrite
```

The complete order is:

1. R core: Noise EDA, season, outcomes, duplicate sensitivity, sensor buffers, 2024 CLUE features and validation through `analysis/run_all.R`.
2. 2025 Noise/pedestrian alignment and multiyear pedestrian QA through `analysis/pedestrian_activity_integration_multiyear.py`.
3. Zero-value sensitivity after the 2025 integrated file exists.
4. Primary 2025 pedestrian statistics, leave-one-sensor-out checks, figures and report.
5. Final sensor-level, spatial-context and RQ3 presentation outputs.

The sensitivity script retains `Noise == 0` in the primary estimates and excludes those records only in the parallel sensitivity estimates. It does not alter the raw snapshot or overwrite the primary analysis outputs.

`analysis/run_all.R` remains the R-core entry point. Direct R execution is supported for development, but the cross-language runner is the canonical complete workflow and provides the Windows locale/runtime safeguards. All commands stop on the first error. Do not use `--run --overwrite` when local generated-output changes need to be preserved.

The legacy scripts `analysis/urban_activity_eda.R` and `analysis/part3_spatial_integration.R` are not part of the validated main pipeline. They require the `tidyverse` meta-package; `urban_activity_eda.R` also loads `leaflet`, although no `leaflet` function is currently used. These legacy-only packages are intentionally not included in the core lockfile.

## Expected outputs

The main pipeline produces:

- noise EDA summaries and `noise_eda_results.rds`;
- seasonal noise summaries, sensor-season coverage diagnostics and two seasonal figures;
- sensor audit, location, hourly, daily and integration-ready noise tables;
- repeated-timestamp diagnostics and sensitivity comparisons;
- zero-value distributions and parallel primary versus zero-excluded estimates;
- 250 m, 500 m and 1,000 m sensor integration tables and join diagnostics;
- CLUE business features, sensitivity and QA outputs;
- the sensor-buffer integration map and noise EDA figures;
- 2025-aligned Noise and pedestrian integration, multiyear pedestrian QA and coverage diagnostics;
- 2025 pedestrian association, influence and leave-one-out tables plus two statistical figures and a report.
- final sensor-hour, spatial-context and RQ3 tables and figures for the presentation.

## Render the presentation

After the analysis preflight passes and the final contribution table has been confirmed, render the self-contained HTML document from the repository root:

```sh
quarto render presentation/final_presentation.qmd
```

The source uses repository-relative figure paths and embeds its resources in `presentation/final_presentation.html`.

See [`data/README.md`](data/README.md) for the complete processed-file inventory.

## Validation

The R-core pipeline runs `analysis/validate_sensor_integration.R`. It checks sensor and buffer key uniqueness, coordinate bounds, coverage semantics, duplicate-timestamp diagnostics, sensitivity bounds, feature counts, monotonicity and the optional CLUE extension when all CLUE outputs exist. The Python integration also writes `pedestrian_multiyear_qa.csv` and stops before output if any of its checks fail.

It can also be run independently after all prior outputs exist:

```sh
python analysis/run_pipeline.py --check
```

## Reproducibility limitations

- The GitHub Release preserves the exact microclimate snapshot; the live City of Melbourne export does not guarantee the same historical file.
- Exact download dates for the other retained raw and reference files were not recorded and require project-member confirmation.
- The retained file named `pedestrian_counts_2019_2024.csv` actually contains dates from 19 August 2024 to 15 August 2026. The current pipeline reads it, validates the observed year counts, uses 2025 for the primary aligned analysis, treats 2024 as a partial comparison period and excludes 2026 from formal activity analysis.
- Daily noise coverage uses a fixed expectation of 96 readings and does not adjust to 92 or 100 readings on daylight-saving transition dates.
- The primary seasonal comparison uses complete season-years 2023-2025 and a 75% active-day coverage rule in every pooled season; only two sensors qualify, so the identity of the highest season is sensitive to sensor composition and the coverage threshold.
- Repeated timestamps are retained in the primary data; duplicate-resistant coverage and sensitivity outputs document their effect.
- CLUE and venue features use the 2024 Census snapshot. In 2025 Noise/pedestrian outputs they are labelled as a **lagged 2024 contextual baseline, not a contemporaneous 2025 measurement**.
- Venue counts can legitimately overlap between sensor buffers.
- The physical unit, sensor model, calibration, mounting height, noise-specific quality flags and interpretation of zero readings remain unresolved.

## Contributions

Use the Git history for code and data contributions. Meeting agendas and weekly contribution records are stored in `meetings/`.
