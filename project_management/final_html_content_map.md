# Final HTML Content Map

## Format decision

The repository contains no course template, `.qmd`, `_quarto.yml`, CSS or existing HTML. Use a Quarto HTML document, not PowerPoint and not an assumed reveal.js deck. The default target should be a self-contained file that opens locally. A suitable initial configuration is a standard HTML document with embedded resources, a concise table of contents or section navigation, code folding/hidden code in the main narrative and an appendix for technical detail.

Proposed paths:

- Source: `presentation/final_presentation.qmd`
- Optional style: `presentation/styles.css`
- Rendered deliverable: `presentation/final_presentation.html`

The central story is:

1. The available monitoring network shows a clear daily pattern.
2. Recorded values vary substantially between monitored sites.
3. Site variation cannot be separated from sensor and siting differences with the available metadata.
4. The available pedestrian comparison does not identify a stable simple association.

## Main document structure

| Section | Why needed | Existing source files | Existing figures/tables | Missing content | Recommended length | Placement |
|---|---|---|---|---|---|---|
| Title and project team | Identifies the project and authors | `README.md`; confirmed team details still required | None | Final title, names and roles | One opening screen | Main |
| Goals and research questions | Defines the scoped, monitored-location questions | `README.md` | None | Reduce four RQs to concise audience-facing wording | 120-180 words | Main |
| Background and motivation | Explains why temporal and contextual variation matter without making health claims | `README.md`; meeting records | Optional municipal context map | Short English context paragraph | 120-180 words | Main |
| Data sources | Makes Noise, CLUE and pedestrian inputs understandable | `data/README.md`; `analysis/urban_activity_summary.md`; `analysis/pedestrian_activity_multiyear_summary.md` | Compact source table | Simplified audience-facing data diagram/table | 150-220 words plus one table | Main |
| Data limitations and scope | Prevents unit, calibration and city-wide overreach | `README.md`; `analysis/noise_eda_summary.md`; `analysis/seasonal_noise_analysis.md` | `figures/fig6_active_noise_sensors_over_time.png` | Condense unresolved metadata and unequal coverage into 4-6 points | One figure plus 120-180 words | Main |
| Methodology | Explains why aggregation, 500 m and sensitivity rules were used | `analysis/noise_eda.R`; `analysis/seasonal_noise_analysis.R`; `analysis/build_sensor_integration.R`; `analysis/pedestrian_activity_integration_multiyear.py` | Existing pipeline tables | One simple flow diagram or ordered method summary; frozen RQ3 rule | 180-260 words | Main |
| Temporal results | Leads with the strongest evidence | `analysis/noise_eda_summary.md` | `figures/fig8_hourly_sensor_standardised.png`; optionally `figures/fig3_noise_by_weekday.png` | Presentation caption and one-sentence takeaway | One main figure, 150-220 words | Main |
| Sensor by time results | Direct response to teacher priority | `data/processed/noise_sensor_hour.csv`; `data/processed/active_noise_sensors_by_month.csv` | `figures/fig6_active_noise_sensors_over_time.png` | Sensor x hour heatmap and individual profile small multiples | Two figures, 180-260 words | Main |
| Spatial design and monitored sites | Shows what locations and buffers represent | `analysis/sensor_integration_summary.md`; `data/processed/noise_sensor_locations.csv`; pedestrian location source | Existing integration map is not sufficient | Revised map with Noise sensors, pedestrian counters and 500 m buffers | One map, 100-160 words | Main |
| Spatial and pedestrian results | Presents a valid but unstable exploratory comparison | `analysis/pedestrian_noise_statistical_report_2025.md`; CSV outputs | `figures/pedestrian_nighttime_noise_500m_2025.png` | Compact sensitivity sentence or appendix link | One figure, 160-230 words | Main |
| Descriptive location profiles | Addresses lower values with amenity access without causal language | `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv` | None currently | All-site table with pre-specified selection rule and reasons; optional dot plot | One compact table/figure, 150-220 words | Main if completed; otherwise omit |
| Simple benchmark analysis | Addresses RQ4 only if defensible | No dedicated source | None | One-outcome, one/two-predictor all-site deviation table and leave-one-out sensitivity | Maximum one figure and 120 words | Appendix or omit |
| Conclusions | States what is supported | All current reports | Reuse no more than one small visual | Four evidence-matched conclusions | 120-180 words | Main |
| Contributions | Required by assessment | `meetings/Catherine_weekly_report.docx`; `meetings/Meeting_Agenda.docx`; Git history; contribution register | Contribution table | Team confirmation | One table | Main |
| Reflection | Required by assessment | Meeting records; audit findings | None | Successes, weaker analyses, how limitations changed scope and credibility gains | 220-320 words | Main |
| Next steps | Shows proportionate future work | Action plan | None | Separate immediate reproducibility tasks from scientific future work | 120-180 words | Main |
| Reproducibility | Required by assessment | `README.md`; `data/README.md`; `analysis/run_pipeline.py`; `renv.lock`; `requirements.txt` | Compact checklist | Final commit, render command, offline check and independent rerun status | 150-220 words | Main |
| Technical appendix | Preserves detail without breaking the story | Seasonal, zero, duplicate, CLUE and pedestrian QA reports | Figures 9, 15, 16, pedestrian buffer sensitivity; diagnostic tables | Curated links/anchors and captions | As needed | Appendix |

## Evidence allocation

### Main figures

1. `figures/fig8_hourly_sensor_standardised.png` - pooled versus equal-sensor daily profile.
2. New sensor-by-hour heatmap - shared and heterogeneous hourly patterns.
3. `figures/fig6_active_noise_sensors_over_time.png` - changing network availability.
4. New 500 m map - Noise sensors, pedestrian counters and buffers.
5. `figures/pedestrian_nighttime_noise_500m_2025.png` - primary exploratory pedestrian comparison.
6. New all-site RQ3 profile - only if the rule is frozen and all sites are shown.

### Appendix figures

- `figures/fig9_weekday_sensor_standardised.png`
- `figures/fig15_seasonal_noise_boxplot.png`
- `figures/fig16_sensor_season_heatmap.png`
- `figures/pedestrian_noise_buffer_sensitivity_2025.png`
- Duplicate-timestamp and zero-value sensitivity tables from `data/processed/`

### Figures not recommended for the main story

- `figures/fig11_bars_by_area_2024.png` to `figures/fig14_cbd_patron_capacity_trend.png`: city-area context is not directly tied to the monitored-site inference.
- `figures/sensor_buffer_integration_map.png`: retain as the canonical generated legacy integration map, but do not use it for the main story because the revised 500 m map provides the required sensor identifiers and pedestrian counters. Its former duplicate, `figures/fig10_sensor_buffer_integration_map.png`, was deleted on 6 October 2026.

## Required wording controls

Use:

- recorded Noise values
- sensor-recorded values
- dataset units
- monitored locations
- exploratory association
- higher or lower than a simple exploratory benchmark
- the analysis did not identify a stable simple association

Do not use:

- dB or decibels
- sound pressure level
- safe, unsafe, harmful or health risk
- exceeds a guideline
- objectively louder
- Melbourne-wide hotspot
- no relationship or no association
- amenities lower Noise
- confirmed anomaly
- statistically proves or causes

## Assessment requirement mapping

| Requirement | HTML location | Primary repository evidence | Completion status |
|---|---|---|---|
| Goals | Goals and research questions | `README.md` | Ready to adapt |
| Background | Background and motivation | `README.md`, meeting records | Needs concise final prose |
| Methodology | Data sources; Methodology; Spatial design | Analysis scripts and summaries | Mostly ready; RQ3 rule and new map missing |
| Results | Temporal; Sensor by time; Spatial/pedestrian; Profiles | Processed tables and figures | Temporal/pedestrian ready; sensor-by-time/RQ3 incomplete |
| Conclusions | Conclusions | Current cautious reports | Ready after missing analyses |
| What we did | Methodology and results | Scripts/output lineage | Ready to map |
| Why we did it | Methodology introductions and reflection | Teacher feedback and meeting records | Needs explicit audience-facing prose |
| Individual contributions | Contributions | Git, meetings, contribution register | Requires team confirmation |
| Reflection | Reflection | Audit and meeting history | Missing final prose |
| Possible next steps | Next steps | Action plan | Ready to adapt |
| Reproducibility | Reproducibility and appendix | Runner, lockfiles, data inventory | Blocked by missing raw Noise snapshot and absent Quarto/render source |

