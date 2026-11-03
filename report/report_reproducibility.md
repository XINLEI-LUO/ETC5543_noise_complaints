# Reproducibility record

## Scope and repository state

This record applies to the final report regenerated on 28 October 2026 from commit `72b489315ee9d91a32c8360c1e421a45236e9be0` plus the current uncommitted analytical and report files. Repository: <https://github.com/XINLEI-LUO/ETC5543_noise_complaints>. The local working tree is the assessed snapshot; the remote repository is not yet a complete final reproduction package.

The analytical workflow is deliberately conservative. `analysis/run_pipeline.py --check` performs a non-destructive preflight; full regeneration requires `--run --overwrite`. No raw input was overwritten during report production.

## Raw inputs and checksums

| Input | Bytes | SHA-256 |
|---|---:|---|
| `data/raw/microclimate_sensors.csv` | 163,912,284 | `85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01` |
| `data/raw/pedestrian_counts_2019_2024.csv` | 85,779,406 | `c03352478451366e4469344bd404724a2cd3d4ee2f36a85ae7a5f3b044102e58` |
| `data/raw/pedestrian-counting-system-sensor-locations.csv` | 18,908 | `f191b2c8901a50750676a1fa99799c7b3cb51ff7e952198dc962871648132de2` |
| `data/raw/bars-and-pubs-with-patron-capacity.csv` | 1,068,699 | `4365cc257ccb4dc2438513d957da4f631827b990107025c608a0a0cda63ea620` |
| `data/raw/cafes-and-restaurants-with-seating-capacity.csv` | 15,995,124 | `61cb34f5ee0cf20c6b0031f252193ea94b8458d97db87b46b1a98372482c4028` |
| `data/raw/business-establishments-with-address-and-industry-classification.csv` | 80,293,067 | `0f285d4b2d9d7279f28b750ec700dd506cad60976f3767c29f06b145ecb9aa0d` |
| `data/reference/melbourne_municipal_boundary.geojson` | 24,867 | `d1bdfd78e7a6f8585e8e6a8d833e8cd53e5201be4dd9b5f67871405988d37023` |

The large microclimate snapshot is restored through the release-asset instructions in `data/README.md` when absent from a clean clone. The filename `pedestrian_counts_2019_2024.csv` is historical; the retained file extends into 2026, and 2025 is the primary complete analysis year.

## Software and commands

The report was prepared on Windows in PowerShell. The checked project uses R 4.5.2 through `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`, the repository `renv` environment, bundled Python from the Codex runtime, Quarto 1.8.25, and Quarto's bundled Typst engine.

Non-destructive validation commands:

```powershell
& 'C:\Program Files\R\R-4.5.2\bin\Rscript.exe' --vanilla analysis/check_r_environment.R
& 'C:\Program Files\R\R-4.5.2\bin\Rscript.exe' --vanilla analysis/validate_sensor_integration.R
& 'C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' analysis/run_pipeline.py --check
```

Report rendering command:

```powershell
& 'C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe' render report/final_report.qmd
```

Full regeneration, only when overwriting derived outputs is intended:

```powershell
& 'C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' analysis/run_pipeline.py --run --overwrite
```

## Validation status on 28 October 2026

- `analysis/check_r_environment.R` completed successfully. It identified the repository root and the required locked R packages; startup warnings did not prevent validation.
- `analysis/validate_sensor_integration.R` completed successfully. The 11-sensor structure, all 33 sensor-buffer keys, coverage bounds, outcome stability, cumulative-count monotonicity, duplicate-timestamp sensitivity and CLUE integration checks passed.
- The Python canonical preflight did **not** complete because the active environment contains `tzdata 2026.5` while the project manifest expects `tzdata 2026.4`. This is an exact dependency-version mismatch, not an analytical test failure. The mismatch must be resolved or the manifest deliberately updated before claiming a fully clean canonical preflight.
- `analysis/hospitality_cross_source_overlap_sensitivity.py` completed successfully. It identified 166 exact bar/cafe venue keys in common and showed that replacing the source-sum proxy with a cross-source union leaves the 500 m screen result and Spearman correlation unchanged.
- Saved figures and tables used in the report were checked against the current processed outputs and project analysis summaries. The report does not claim that every derived file was regenerated during this writing session.

## Output lineage

The main sequence is:

1. `analysis/noise_eda.R` creates the base Noise audit, coverage summaries and temporal figures.
2. `analysis/seasonal_noise_analysis.R`, `analysis/duplicate_timestamp_sensitivity.R` and `analysis/noise_zero_value_sensitivity.R` add composition and data-quality sensitivity analyses.
3. `analysis/prepare_noise_outcomes.R` creates one-row-per-device outcomes.
4. `analysis/pedestrian_activity_integration_multiyear.py`, `analysis/prepare_clue_business_features.R` and `analysis/build_sensor_integration.R` create contextual features and the 33-key spatial panel.
5. `analysis/pedestrian_noise_statistical_analysis_2025.py` and `analysis/rq3_hospitality_followup.py` create the association and stability outputs.
6. `analysis/final_presentation_outputs.py` creates the final common-scale sensor figures and map.
7. `analysis/hospitality_cross_source_overlap_sensitivity.py` audits exact bar/cafe venue overlap and creates union-count sensitivity outputs.
8. `analysis/validate_sensor_integration.R` tests the integrated outputs.
9. `report/final_report.qmd` consumes retained figures and checked numerical outputs and renders `report/final_report.pdf`.

## Known reproducibility limits

Exact download dates are unavailable for several retained source files, so checksums identify the local snapshots more precisely than a current portal export. The Noise unit and calibration metadata remain unresolved. A future portal revision may differ from these inputs. Reproduction should therefore begin from the checksummed repository snapshots, not from an assumption that a fresh download is byte-identical.

Several final-stage scripts, processed outputs, figures, the specification and the report are uncommitted. The repository also contains a zero-byte `report/REPORT.docx`. These states must be resolved before submission so that a clean clone contains the intended final deliverables and no misleading placeholder file.
