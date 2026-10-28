# Teacher Feedback Gap Audit

## Audit conclusion

The repository supports a defensible central story: the monitored network shows a clear daily pattern, monitored sites differ substantially, those site differences cannot be separated from sensor and siting differences, and the available pedestrian comparison does not identify a stable simple association. The frozen RQ3 screen remains visible, while a separately labelled exploratory follow-up uses the continuous site-level information.

As of 6 October 2026, the teacher-prioritised sensor-by-time figures, revised 500 m context map, RQ3 outputs, self-contained reveal.js HTML slide deck, and three-person rehearsal script have been produced. The main remaining release tasks are a timed team rehearsal, an offline-open check on the presentation laptop, headline-number verification after the final pipeline run, and a clean-clone reproduction tied to the submission commit.

This was a read-only analytical audit. No existing code, data, report, README or figure was changed. The only files created or updated are the five internal review records requested in `1.docx`.

## Teacher feedback status

| Teacher feedback | Status | Repository evidence | Gap or action |
|---|---|---|---|
| Temporal analysis is the strongest component | Met | `analysis/noise_eda.R`, `analysis/noise_eda_summary.md`, `data/processed/hourly_pooled_vs_sensor_standardised.csv`, `figures/fig2_noise_by_hour.png`, `figures/fig8_hourly_sensor_standardised.png` | Use as the opening result in the final HTML. |
| Daily pattern remains after accounting for sensors | Met | Pooled and equal-sensor summaries both have their minimum at 03:00 and maximum at 16:00; `figures/fig8_hourly_sensor_standardised.png` shows the comparison | State this as the main finding, limited to monitored locations. |
| Weekday differences are small | Met | `data/processed/weekday_pooled_vs_sensor_standardised.csv`; pooled Friday-Sunday difference is 1.0 dataset unit | Keep brief and subordinate to hourly and between-sensor variation. |
| Seasonal interpretation must be cautious | Met in analysis; presentation not built | `analysis/seasonal_noise_analysis.md`, `data/processed/seasonal_noise_summary.csv`, `data/processed/sensor_season_coverage.csv`; only two sensors meet the 75% rule and the top-ranked season changes with composition | Use one compact sensitivity figure or appendix panel, not a strong headline. |
| Do not say the pedestrian analysis found no relationship | Met | `analysis/pedestrian_noise_statistical_report_2025.md` uses the recommended wording | Preserve that exact cautious conclusion. |
| Prioritise sensor-by-time comparison | Partial | Availability is present in `figures/fig6_active_noise_sensors_over_time.png`; pooled versus equal-sensor hourly results are present | Missing sensor-by-hour heatmap, a presentation-ready sensor x hour table and individual-sensor hourly profiles. |
| Map sensors, pedestrian counters and 500 m buffers | Not met | `figures/sensor_buffer_integration_map.png` maps Noise sensors, venue points and 250/500/1000 m buffers | Add pedestrian counter points, sensor identifiers, a single clearly emphasised 500 m boundary and a readable legend. |
| Lower Noise with stronger amenity access may be descriptive only | Not yet implemented | Candidate variables exist in `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv` | Pre-specify a selection rule, show all 11 sites and give selected/not-selected reasons. Do not claim amenities lower Noise. |
| Avoid a large unexpected-high/low model | Met by omission | No large RQ4 model is present | If retained, use one outcome and at most two contextual variables, show every site's deviation and run leave-one-sensor-out sensitivity; otherwise move to future work. |
| Influential sites remain in the primary analysis | Met for pedestrian analysis | `data/processed/pedestrian_noise_leave_one_out_2025.csv`; primary model retains all 10 matched sites | Show the full primary result, then summarise the leave-one-out range. |
| Final story should be narrow and credible | Ready to implement | Evidence spans `analysis/noise_eda_summary.md`, `analysis/seasonal_noise_analysis.md`, `analysis/pedestrian_noise_statistical_report_2025.md` | Build the final HTML around the four-sentence teacher story rather than around every completed analysis. |

## Repository inventory

No `.qmd`, `.Rmd`, `_quarto.yml`, `.html` or `.css` file exists outside ignored dependency and IDE directories. There is no `reports/` or `presentation/` directory. Therefore there is no course template, no existing Quarto format decision and no final HTML source to preserve. A self-contained Quarto HTML document is the appropriate default; reveal.js should not be assumed.

| Exact path | Purpose and RQ | Current status / run evidence | Current or obsolete | Final HTML use | Important issues |
|---|---|---|---|---|---|
| `README.md` | Project scope, research questions, setup and pipeline | Current and detailed | Current | Source for scope, limitations and reproducibility | Says Quarto is not required, which is true for the current pipeline but will need revision when a final HTML source is added. |
| `data/README.md` | Input provenance, checksums and output lineage | Current | Current | Technical appendix / reproducibility | Exact download dates are unknown for most retained sources. |
| `analysis/run_pipeline.py` | Canonical R/Python preflight and run order | Full read-only preflight passed after restoring and verifying `data/raw/microclimate_sensors.csv` | Current | Reproducibility method | Full regeneration was not run because it overwrites generated outputs. |
| `analysis/run_all.R` | R core pipeline order | Parsed successfully; not executed because a full run would overwrite outputs and the raw Noise file is missing | Current | Technical appendix | Warns that outputs may be overwritten; use the Python runner as canonical. |
| `analysis/noise_eda.R` | RQ1 hourly, weekday, sensor and availability EDA | Parsed successfully; outputs exist | Current | Main results | Does not produce the requested sensor-by-hour heatmap or individual sensor small multiples. |
| `analysis/noise_eda_summary.md` | Narrative RQ1 summary | Current values align with processed tables | Current | Main narrative source | YAML says PDF/HTML but it is not a reproducible report source; it is Markdown generated/maintained alongside scripts. |
| `data/processed/hourly_pooled_vs_sensor_standardised.csv` | Pooled and equal-sensor hourly comparison | 24 rows; 11 sensors represented | Current | Main result | Presentation should explain what equal-sensor aggregation means. |
| `data/processed/weekday_pooled_vs_sensor_standardised.csv` | Weekday comparison | 7 rows | Current | Supporting result | Keep short; avoid implying large weekday variation. |
| `figures/fig2_noise_by_hour.png` | Pooled hourly profile | Visually readable | Current | Main, preferably beside equal-sensor result | Pooled result alone is vulnerable to unequal sensor contribution. |
| `figures/fig8_hourly_sensor_standardised.png` | Pooled versus equal-sensor hourly profile | Visually readable | Current | Main | This is the strongest existing presentation figure. |
| `figures/fig6_active_noise_sensors_over_time.png` | Network availability by month and active count | Visually readable | Current | Main methodology/limitations | Meets the availability requirement but should be described as monthly availability, not continuous uptime. |
| `figures/fig3_noise_by_weekday.png`, `figures/fig9_weekday_sensor_standardised.png` | RQ1 weekday patterns | Outputs exist | Current | Appendix or one small supporting panel | The difference is modest relative to hourly and sensor variation. |
| `analysis/seasonal_noise_analysis.R` | Seasonal definitions, coverage and sensitivity | Parsed successfully; outputs exist | Current | Supporting / appendix | Interpretation is highly composition-sensitive. |
| `analysis/seasonal_noise_analysis.md` | Seasonal narrative | Current and cautious | Current | Supporting / appendix | Do not present the all-available Winter maximum as a stable seasonal effect. |
| `figures/fig15_seasonal_noise_boxplot.png` | Balanced seasonal distribution | Output exists | Current | Appendix | Primary 75% analysis includes only two sensors. |
| `figures/fig16_sensor_season_heatmap.png` | Sensor-season eligibility and values | Visually readable | Current | Appendix | Many X cells correctly expose sparse coverage; not a sensor-by-hour heatmap. |
| `analysis/prepare_noise_outcomes.R` | Sensor-level outcomes for spatial work | Parsed successfully; outputs exist | Current | Methodology | Different operating windows remain a core limitation. |
| `data/processed/noise_outcomes_for_integration.csv` | 11 usable sensor outcomes | Unique 11-row table | Current | Sensor comparison table / source | `aws5-0999` is excluded because all Noise values are missing. |
| `analysis/build_sensor_integration.R` | 250/500/1000 m venue integration | Parsed successfully; validation passed | Current | Spatial methodology | Site context is 2024 while Noise spans different periods. |
| `analysis/validate_sensor_integration.R` | Output validation | Executed read-only during this audit and passed for 11 sensors and 33 keys | Current | Reproducibility evidence | Validates existing outputs, not regeneration from the missing raw input. |
| `data/processed/integrated_sensor_all_buffers.csv` | Noise plus bars/cafes at three buffers | 33 unique sensor-buffer rows; validated | Current | RQ3 candidate source | All three buffers must not be treated as 33 independent sites. |
| `analysis/prepare_clue_business_features.R` | 2024 broader business features | Parsed successfully; outputs exist | Current | RQ3/RQ4 candidate source | With only 11 sites, predictor selection must be narrow. |
| `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv` | Noise plus CLUE context | 33 unique keys; CLUE checks pass | Current | RQ3 descriptive table; optional RQ4 benchmark | Features are a 2024 contextual snapshot and buffers overlap. |
| `figures/sensor_buffer_integration_map.png` | Sensors, venues and all buffer distances | Visually readable | Current | Replace or revise | Does not show pedestrian counters or sensor IDs; three panels dilute the teacher-requested 500 m map. |
| `figures/fig10_sensor_buffer_integration_map.png` | Former duplicate copy of the integration map | SHA-256 matched `figures/sensor_buffer_integration_map.png` before deletion | Removed 6 October 2026 | None | Duplicate deleted after approval; `figures/sensor_buffer_integration_map.png` remains the canonical output generated by `analysis/build_sensor_integration.R`. |
| `analysis/pedestrian_activity_integration_multiyear.py` | 2025 primary pedestrian integration and QA | Python parsed; outputs exist; QA report says 22/22 pass | Current | Methodology / spatial-pedestrian results | 2024 is partial; 2026 has only 166 rows and is excluded. |
| `data/processed/noise_pedestrian_integrated_2025.csv` | 33 sensor-buffer rows with aligned 2025 outcomes | Present; 10 matched sites at 500 m | Current | Pedestrian analysis source | 2024 business fields are lagged baselines, not 2025 measurements. |
| `analysis/pedestrian_noise_statistical_analysis_2025.py` | Correlation, OLS, permutation and leave-one-out analysis | Python parsed; outputs exist | Current | Main supporting result | The optional two-predictor adjusted model is exploratory and should not be a headline. |
| `analysis/pedestrian_noise_statistical_report_2025.md` | Statistical narrative | Current and appropriately cautious | Current | Main supporting narrative | Use effect estimates and instability, not significance-only language. |
| `figures/pedestrian_nighttime_noise_500m_2025.png` | Primary 500 m scatter and OLS fit | Visually readable | Current | Main supporting result | Very wide confidence band and influential sites should be discussed. |
| `figures/pedestrian_noise_buffer_sensitivity_2025.png` | 250/500/1000 m sensitivity | Visually readable | Current | Appendix / sensitivity | Spearman direction changes across distances; 1000 m p-value alone is not a stable result. |
| `analysis/noise_zero_value_sensitivity.R` | Zero exclusion sensitivity | Parsed successfully; outputs exist | Current | Technical appendix | Zero meaning is unresolved; sensitivity does not justify recoding zeros. |
| `analysis/duplicate_timestamp_sensitivity.R` | Repeated timestamp sensitivity | Parsed successfully; outputs exist | Current | Technical appendix | Cause of repeated timestamps remains unknown. |
| `analysis/urban_activity_eda.R` | Early urban activity EDA | Parses but is not in the validated pipeline | Legacy | Do not source final results from it | Requires legacy packages and refers to outputs no longer present. |
| `analysis/part3_spatial_integration.R` | Early spatial integration scaffold | Parses but is not in the validated pipeline | Legacy | Do not use | Superseded by validated sensor-buffer scripts. |
| `analysis/variable_dictionary.md` | Dictionary for current Noise, spatial, pedestrian and presentation outputs | Rewritten against the files present in `data/processed/` | Current | Supporting documentation | Records shared conventions, current output grain, key fields and interpretation limits. |
| `figures/fig11_bars_by_area_2024.png` through `figures/fig14_cbd_patron_capacity_trend.png` | Early city-area urban activity context | Images exist | Legacy/supporting | Appendix only if needed for background | Not directly linked to the monitored-site research questions. |
| `project_management/clean_clone_reproduction_record.md` | Earlier clean-clone test | Historically useful | Partly stale | Reproducibility appendix source | It says GitHub `main` lacked files, but current `main`/`origin/main` is `72b4893` and now tracks the runner, lockfiles and expanded docs. |
| `meetings/Catherine_weekly_report.docx` | Early progress and allocation record | Read during audit | Historical | Contribution evidence only | Contains early claims now superseded; explicitly says allocations require confirmation. |
| `meetings/Meeting_Agenda.docx` | Meeting history and teacher priorities | Read during audit; locally modified before this audit | Historical/current evidence | Contribution and reflection sources | Preserve the user's uncommitted change; do not treat every agenda statement as completed work. |
| Earlier top-level population/biodiversity CSVs | Early possible project inputs | Removed from the current tree; original addition remains recoverable from Git commit `95ecafd` | Out of current scope | Excluded | Population and biodiversity are not part of the current central story. |

## Evidence matrix by research question

| RQ | Intended question | Data and analysis unit | Window | Current code/report/outputs | Current conclusion and support | Sensitivity and limitations | Status | Required next action |
|---|---|---|---|---|---|---|---|---|
| RQ1 | How do recorded values vary by hour, weekday and season? | Raw Noise records; hourly/weekday summaries; sensor-day and sensor-season-year units | 2022-05-31 to 2026-08-17; seasonal comparison uses complete season-years 2023-2025 | `analysis/noise_eda.R`; `analysis/seasonal_noise_analysis.R`; `analysis/noise_eda_summary.md`; `analysis/seasonal_noise_analysis.md`; Figures 2, 3, 6, 8, 9, 15, 16 | Clear daily cycle: pooled 61.6 at 03:00 to 69.7 at 16:00; equal-sensor 58.9 to 70.5. Weekday differences are small. Seasonal ranking depends on composition. | Equal-sensor, balanced coverage, 50%/75% seasonal thresholds, zero exclusion and duplicate sensitivity. Physical unit and sensor comparability unresolved. | Needs revision | Add sensor-by-hour heatmap and individual profiles; package hourly as main, weekday as brief, season as cautious supporting evidence. |
| RQ2 | Which monitored sites are high/low and how do patterns vary over time? | 11 usable Noise sensors; sensor-hour or site summaries | Unequal sensor-specific periods, with aligned 2025 outcome available for pedestrian work | `analysis/prepare_noise_outcomes.R`; `data/processed/noise_sensor_hour.csv`; `data/processed/noise_outcomes_for_integration.csv`; `figures/fig4_noise_by_sensor.png`; `figures/fig5_sensor_location_map.png`; `figures/fig6_active_noise_sensors_over_time.png` | Site medians range 52.3 to 81.1 dataset units. These differences cannot be separated from sensor calibration, mounting, siting and coverage. | Availability and coverage outputs exist; no complete sensor x hour presentation summary or heatmap. | In progress; highest priority | Create sensor x hour table/heatmap, individual hourly profiles and revised 500 m map with pedestrian counters. |
| RQ3 | Are there lower-value sites with stronger amenity access? | One row per sensor at 500 m; candidate outcome is a pre-specified night-time or overall median; candidate amenities are bars/capacity/cafes/outdoor seats or one CLUE access measure | Noise period must be stated; context is 2024 | Candidate source: `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv`; no dedicated code, table or report | No defensible selection result exists yet. The table contains all inputs needed for a transparent descriptive profile. | 250 and 1000 m sensitivity available in source; selection rule not pre-specified; only 11 sites; overlapping buffers; no causal interpretation. | Missing | Inspect distributions, freeze one outcome and one amenity measure, parameterise thresholds, show all sites and record selected/not-selected reasons. |
| RQ4 | Which sites are above/below a simple contextual benchmark? | One row per sensor, preferably 500 m; one outcome and one or at most two predictors | Must use a clearly aligned or explicitly lagged window | No dedicated RQ4 script/report/table. `pedestrian_noise_models_2025.csv` is an association analysis, not an all-site benchmark table. | No current conclusion. No site should be called an anomaly. | Severe small-n risk; coefficients and residuals require leave-one-sensor-out stability. | Missing / optional | Defer unless RQ2 and RQ3 are complete. If retained, output fitted value and residual for every site plus leave-one-sensor-out ranges; otherwise place in future work. |

## Analysis and wording that can be retained

- Retain the headline daily pattern from `analysis/noise_eda_summary.md`, supported by `figures/fig8_hourly_sensor_standardised.png`.
- Retain the comparison that weekday differences are smaller than hourly and between-site differences.
- Retain the seasonal methodology and sensitivity outputs, but not as a stable four-season ranking.
- Retain the site-level spread as a monitored-location comparison, with the explicit unresolved sensor/siting limitation.
- Retain the 2025 pedestrian analysis, its permutation result, buffer sensitivity and leave-one-sensor-out results.
- Retain the reporting sentence: “The analysis did not identify a stable simple association between the selected pedestrian measure and night-time recorded Noise values at these monitored locations.”
- Retain the 500 m primary and 250/1000 m sensitivity decision, unique `device_id + buffer_m` key, and zero-versus-NA rules.

## Analysis, wording and figures requiring change

- `figures/sensor_buffer_integration_map.png` must be revised for the teacher's requested layers. It currently shows Noise sensors, venue points and three buffer distances, not pedestrian counters, sensor IDs and an emphasised 500 m design.
- Duplicate-map cleanup is complete: `figures/fig10_sensor_buffer_integration_map.png` was deleted on 6 October 2026 after its SHA-256 matched `figures/sensor_buffer_integration_map.png`. The later-named file remains the only canonical generated integration map.
- `analysis/variable_dictionary.md` now documents the current analysis outputs and can be used as supporting documentation; the final HTML should still define essential variables where they first appear.
- `project_management/clean_clone_reproduction_record.md` contains a historically correct but now stale claim about what `origin/main` contains. It should be refreshed after input recovery and a new clean-clone test.
- `README.md` says no Quarto entry point exists; after presentation implementation it should link to the new render source and command.
- Any future wording such as “no relationship”, “amenities lower Noise”, “confirmed anomaly”, “hotspot across Melbourne”, physical-unit language or health/regulatory interpretations must be excluded.

## Missing analyses and presentation outputs

1. Presentation-ready sensor x hour summary and heatmap.
2. Individual-sensor hourly profiles or compact small multiples showing whether the daily pattern is broadly shared.
3. Revised 500 m map with Noise sensor identifiers, pedestrian counters and readable buffer boundaries.
4. One transparent RQ3 all-site table with a pre-specified selection rule and selected/not-selected reasons.
5. A final English Quarto HTML source and self-contained rendered HTML.
6. A verified contribution table confirmed by team members.
7. Optional only: minimal RQ4 benchmark and all-site residual table with leave-one-sensor-out sensitivity.

## Read-only checks performed through 1 October 2026

| Check | Result |
|---|---|
| Search for `.qmd`, `.Rmd`, `_quarto.yml`, HTML and CSS | None found outside dependencies/IDE state. |
| Git state | `main` at `72b4893`, tracking `origin/main`; pre-existing changes are `meetings/Meeting_Agenda.docx` modified and `1.docx` untracked. |
| Python source parsing | All four Python files in `analysis/` parsed successfully. |
| R source parsing | All 12 R files in `analysis/` parsed successfully. |
| Existing-output validation | `Rscript --vanilla analysis/validate_sensor_integration.R` passed for 11 sensors, 33 sensor-buffer rows, duplicate sensitivity and CLUE validation. |
| Canonical preflight | Passed after the raw Noise snapshot was restored and its SHA-256 verified. |
| Quarto availability | `quarto` is not available on PATH in the audited environment. |

