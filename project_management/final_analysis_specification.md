# Final Analysis Specification

## Status and change control

This document freezes the definitions for the remaining pre-presentation analysis. Any later change to an outcome, time window, aggregation level, spatial buffer, threshold, or reporting phrase must be recorded in the pull request or commit message that introduces the change.

The specification is deliberately descriptive. It does not convert the recorded `Noise` field to decibels, infer health risk, or generalise beyond the monitored locations.

## Shared conventions

- Use only the 11 sensors with usable `Noise` observations. Exclude `aws5-0999` because its `Noise` field is entirely missing.
- Parse timestamps in `Australia/Melbourne` local time.
- Use 500 m as the primary spatial buffer. Use 250 m and 1,000 m only as labelled sensitivity analyses.
- Use `device_id` plus `buffer_m` as the spatial integration key.
- Retain recorded zero `Noise` values in primary summaries. Add a clearly labelled sensitivity result that excludes zeros where relevant.
- Treat a zero contextual count as confirmed absence within the buffer. Treat `NA` as missing data or a failed join.
- Use medians for primary `Noise` summaries because the field contains outliers and its physical unit is not documented.
- Describe the field as "recorded Noise values", "sensor-recorded values", or "dataset units". Do not use "dB", "decibels", "safe", "unsafe", "harmful", or "objectively louder".
- Scope every conclusion to the monitored locations and observation period.

## RQ1: Temporal pattern

### Primary hourly summary

1. Keep finite `Noise` observations from the 11 usable sensors.
2. Derive local hour from the parsed timestamp.
3. Calculate the median `Noise` value for each `device_id` and hour.
4. Calculate the median of those sensor-specific hourly medians for each hour.

This sensor-balanced series is the primary hourly result because each sensor receives equal weight. The pooled observation-level hourly median remains a secondary comparison and must be labelled as pooled.

### Weekday summary

Apply the same two-stage, sensor-balanced aggregation by local weekday. Retain the pooled weekday median only as a secondary comparison. Order weekdays Monday through Sunday.

### Required RQ1 outputs

- A 24-hour line chart comparing the sensor-balanced and pooled hourly medians.
- A weekday chart comparing the sensor-balanced and pooled weekday medians.
- A concise text summary of the minimum, maximum, and peak-hour range without unit claims.

The existing benchmark values are:

- pooled hourly minimum: 61.6 at 03:00;
- pooled hourly maximum: 69.7 at 16:00;
- sensor-balanced hourly minimum: 58.9 at 03:00;
- sensor-balanced hourly maximum: 70.5 at 15:00-16:00; and
- pooled weekday medians: 68.3 on Friday and 67.3 on Sunday, a difference of 1.0 dataset unit.

Regenerated outputs must reconcile with these values or document why they differ.

## RQ2: Variation between monitored sites

### Sensor-by-hour heatmap

1. Calculate the median `Noise` value for every `device_id` and local hour.
2. Show sensors as rows in stable identifier order and hours 00:00-23:00 as columns.
3. Use one fixed colour scale across all sensors.
4. Display missing sensor-hour combinations as missing, not zero.

### Individual sensor profiles

Plot the 24-hour median profile for every usable sensor. Use small multiples with the same axes, or a single chart with direct labels if legibility is preserved. Do not independently rescale panels.

### Site-level summary

Provide a table with each sensor's overall median, valid observation count, active-day count, first timestamp, and last timestamp. The existing overall medians range from 52.3 at `ICTMicroclimate-01` to 81.1 at `ICTMicroclimate-10`; regenerated results must reconcile with this range or document why they differ.

The interpretation must distinguish observed spatial variation from causal spatial effects: sensor calibration, mounting, placement, and local exposure cannot be separated with the available metadata.

## Seasonal analysis

- Use Australian meteorological seasons: summer is December-February, autumn is March-May, winter is June-August, and spring is September-November.
- Assign December to the following `season_year` so that each summer is kept together.
- Use complete season years 2023-2025 for the primary comparison.
- Aggregate in this order: raw observations to sensor-day medians, sensor-day medians to sensor-season-year medians, and sensor-season-year medians to the displayed seasonal summary.
- Require at least 75% of expected active days for the primary result and use 50% as a labelled sensitivity threshold.
- State that the eligible sensor composition is limited and changes with the coverage threshold. At 75%, only sensors 01 and 03 qualify; at 50%, sensors 01, 02, and 03 qualify.

Seasonal ranking must be described as composition-sensitive and descriptive, not as a city-wide seasonal effect.

## Spatial context map

The primary map must show:

- all 11 usable Noise sensor points;
- a labelled 500 m buffer around each Noise sensor;
- pedestrian counters with valid coordinates that are present in the 2025 pedestrian observations;
- a visual distinction between counters inside at least one primary buffer and other eligible counters in the displayed extent; and
- a basemap attribution statement if a basemap is used.

The map must not imply that buffers are neighbourhood boundaries or causal exposure zones. Any coordinate-system transformation must occur before distance or buffer calculations, using a projected coordinate reference system suitable for Melbourne.

## Pedestrian activity comparison

### Primary definition

- Analysis year: 2025.
- Night-time window: 18:00-05:59 local time.
- Outcome: `nighttime_median_noise`.
- Predictor: `mean_nighttime_avg_hourly_pedestrian_count`.
- Primary buffer: 500 m.
- Sensitivity buffers: 250 m and 1,000 m.
- Association measure: Spearman rank correlation.
- Inference support: the existing permutation test and leave-one-out analysis.

The primary 500 m analysis has 10 matched sensor locations. The current benchmark is Spearman rho 0.24848 with permutation p 0.49398. The leave-one-out rho range is 0.0667-0.5833, showing that the estimate is not stable to removal of one site.

Use this conclusion: "The analysis did not identify a stable simple association between the selected pedestrian measure and night-time recorded Noise values at these monitored locations."

Do not rewrite this as evidence that pedestrian activity has no relationship with environmental sound in general.

## RQ3: Lower recorded Noise with stronger hospitality access

### Fixed variables

- Outcome: 2025 `nighttime_median_noise`, using the same 18:00-05:59 window as the pedestrian comparison.
- Amenity proxy: `hospitality_venues_2024`, defined as `n_bars_2024_baseline + n_cafes_2024_baseline`.
- Spatial buffer: 500 m primary, with 250 m and 1,000 m as sensitivity summaries.
- Eligible set: usable Noise sensors with non-missing outcome and both component venue counts. Pedestrian-counter matching is not required for RQ3.

`hospitality_venues_2024` is a lagged count of nearby source records, not a measure of venue quality, realised access, visits, or entertainment activity.

### Fixed selection rule

A site is a descriptive candidate only when both conditions are true:

1. its 2025 night-time median `Noise` value is strictly below the median across eligible sites; and
2. its 2024 hospitality venue count is strictly above the median across eligible sites.

Values equal to either median do not satisfy the corresponding condition. Do not alter the threshold direction, use inclusive comparisons, or substitute another amenity variable after inspecting which sites are selected.

At 500 m, all 11 usable sensors have the required values. The frozen thresholds are 64.2 for the night-time median `Noise` value and 206 hospitality venues. No site satisfies both strict conditions. This zero-candidate result must be retained.

### Required RQ3 outputs

- A scatter plot showing all eligible sites, both median threshold lines, direct sensor labels, and the selected quadrant.
- A complete site table with outcome, bar count, cafe count, combined hospitality count, both condition flags, and the final candidate flag.
- A short statement that no 500 m site jointly met the fixed criteria, followed by a descriptive discussion of the visible trade-off rather than a replacement selection rule.
- Separate 250 m and 1,000 m sensitivity counts and tables using the identical rule at each buffer.

RQ3 is a transparent prioritisation screen, not a statistical test or a recommendation for residential choice.

## RQ4 decision

Do not add a multivariable model to the main presentation before the temporal, sensor-level, spatial-map, pedestrian, and RQ3 outputs are complete and quality checked. Treat RQ4 as future work in the presentation. No adjusted-effect or causal claim is authorised by this specification.

If RQ4 is later implemented, it requires a separately reviewed analysis plan that fixes the outcome, no more than two contextual predictors, diagnostics, and a small-sample reporting strategy before model results are inspected.

## Reporting hierarchy

1. Lead with the sensor-balanced temporal result.
2. Show substantial variation between monitored sites.
3. State that sensor and siting differences cannot be separated from location differences.
4. Report that the pedestrian comparison does not show a stable simple association.
5. Report the RQ3 zero-candidate result under the fixed rule without moving the thresholds.
6. Place seasonal and alternative-buffer results in sensitivity or appendix material unless they directly qualify a main conclusion.

## Quality gates

Before an output is presentation-ready, confirm that:

- the canonical input hashes and pinned Python/R environments pass the read-only preflight;
- each output can be regenerated by a committed script;
- titles, axes, legends, captions, and tables are in English;
- every figure states its population, time period, aggregation, and buffer where applicable;
- no undocumented physical unit appears;
- missing values and confirmed zeros remain distinct;
- primary and sensitivity results are visibly labelled; and
- numerical text in the presentation is generated from or checked against the saved analysis tables.
