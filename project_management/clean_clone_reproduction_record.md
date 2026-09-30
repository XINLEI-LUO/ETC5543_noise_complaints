# Clean-clone Reproduction Record

## Scope

This record covers source/data recovery and the R/Python analysis pipeline only. It does not cover a final presentation HTML/QMD.

## GitHub `main` test

- Remote: `https://github.com/XINLEI-LUO/ETC5543_noise_complaints.git`
- Remote branch: `main`
- Commit tested: `b6a118649b52643c2e11bdb5983647ed67dc7196`
- Local working-copy HEAD at test time: `014512047b5d63c3f44785d4994553b9a52d612b`
- Clone command: `git clone --depth 1 --branch main https://github.com/XINLEI-LUO/ETC5543_noise_complaints.git <temporary-directory>`

Result: **FAIL before environment restoration or analysis execution.** The clean GitHub clone does not contain `analysis/run_pipeline.py`, `requirements.txt`, `renv.lock`, `.Rprofile`, or the expanded README recovery/run instructions. Therefore the current working-copy preflight result must not be described as a clean-clone reproduction result.

## Current working-copy checks

The following checks passed in the working copy on 29 September 2026 (Australia/Sydney):

- `python analysis/run_pipeline.py --check`
  - Python 3.12.14 and all 23 exact package versions matched `requirements.txt`.
  - Five pipeline entry scripts and six required inputs existed.
  - All six input SHA-256 values matched.
  - R 4.5.2, `renv` 1.2.4 and locked core R packages matched `renv.lock`.
  - `renv::status()` reported no issues.
- All 12 R scripts parsed.
- `analysis/validate_sensor_integration.R` passed for 11 sensors and 33 sensor-buffer rows, with unique keys, monotonic urban features, maximum duplicate sensitivity of 0.1 dataset units, and valid 2024 CLUE integration.
- The Python source files used by the current repository compiled after correcting an obsolete filename in the first syntax-check command.

These are **working-copy checks only** because critical source/configuration files are uncommitted and the ignored microclimate input was already present locally.

## Candidate clean-clone test

To separate the missing-commit problem from pipeline behaviour, the reviewed source/configuration files were copied into a temporary repository and committed there only. No commit was created in the team working tree and nothing was pushed.

- Temporary candidate commit: `423b1f61b8b513cebc4daf139004e56f25175f22`
- Candidate clone method: `git clone --no-local <temporary-candidate-repository> <second-temporary-directory>`
- R restore: R 4.5.2 bootstrapped `renv` 1.2.4 and `renv::restore(prompt = FALSE)` restored 48 locked packages. The packages were linked from the machine's `renv` cache, so this verifies the lockfile/project restore path but not an empty-cache source build.
- Python restore: Python 3.12.14 created a fresh `.venv`; `pip install -r requirements.txt` installed all 23 exact requirements.
- Raw snapshot recovery: the anonymous Release URL returned HTTP 404 because the repository is private. `gh release view` confirmed the tag and asset, and authenticated `gh release download` restored `microclimate_sensors.csv` (163,912,284 bytes). SHA-256 matched `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01`.
- Preflight: `.venv/Scripts/python.exe analysis/run_pipeline.py --check` passed Python, R, scripts, all six required inputs and all six SHA-256 checks.
- Full run: `.venv/Scripts/python.exe analysis/run_pipeline.py --run --overwrite` completed all seven R-core stages, 2025 pedestrian integration, zero-value sensitivity and 2025 statistical analysis.
- R warning retained: the restored Windows binaries for `dplyr`, `tidyr`, `readr`, `sf` and `ggplot2` reported that they were built under R 4.5.3 while running under R 4.5.2. Package versions matched `renv.lock`, the scripts completed, and validation passed; a second machine should confirm whether fresh R 4.5.2 binaries produce the same warning.

Key results reproduced:

- 11 usable Noise sensors and 33 unique `device_id + buffer_m` rows.
- Pedestrian multiyear QA: 22/22 PASS.
- Primary 500 m result: `n = 10`, Spearman rho `0.2484848485`, permutation p-value `0.49398`.
- Primary simple OLS slope: `0.01665286` dataset units per pedestrian count; 95% CI `[-0.04827157, 0.08157729]`.
- Leave-one-sensor-out Spearman range: `0.06666667` to `0.58333333`.
- All 33 integrated rows have `business_feature_year = 2024` and `business_temporal_status = "Lagged 2024 contextual baseline; not a 2025 measurement"`.

Seven key CSVs were compared with the working copy after excluding the intentionally variable `generated_at` column. All data columns and rows matched: correlations, models, leave-one-out results, 2025 integrated data, pedestrian QA, zero-value sensitivity and the 2024 CLUE integration table. Two of those files also matched byte-for-byte because they do not contain a changed generation timestamp.

Result: **PASS for the commit.** A passing test on this machine is strong workflow evidence but is not a second-person or empty-cache verification.
