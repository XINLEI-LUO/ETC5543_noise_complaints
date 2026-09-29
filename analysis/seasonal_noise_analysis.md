# Seasonal Recorded Noise Analysis

## Scope

This analysis completes the seasonal component of RQ1: How do recorded Noise values vary by time of day, day of week and season? Hour-of-day and weekday analyses are unchanged.

The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.

## Season and year definitions

Australian meteorological seasons are Summer (December-February), Autumn (March-May), Winter (June-August) and Spring (September-November), in that order. December is assigned to the following `season_year`, so Summer 2024 consists of December 2023 through February 2024.

The raw snapshot covers 2022-05-31 to 2026-08-17. Complete calendar years are 2023, 2024, 2025. Incomplete calendar years are 2022, 2026. The main comparison uses complete season-years 2023-2025, spanning December 2022 through November 2025. Data from 2026 remain partial-year descriptive context and are not included in the four-season comparison.

## Coverage rule and aggregation

The primary balanced rule requires each sensor to have valid Noise observations on at least 75% of expected calendar days in every pooled season across season-years 2023-2025. Active-day coverage was chosen because the source is approximately 15-minute data but outages, duplicate timestamps and daylight-saving transitions make strict record-count coverage less suitable for seasonal eligibility. The threshold is fixed at the top of the script and was not selected from the seasonal results.

The alternative threshold is 50%. Sensors retained at 75%: `ICTMicroclimate-01`, `ICTMicroclimate-03`. Sensors retained at 50%: `ICTMicroclimate-01`, `ICTMicroclimate-02`, `ICTMicroclimate-03`.

The primary evidence uses a hierarchy of raw records to sensor-date medians and then sensor-season-year medians. Seasonal summaries compare these final units so sensors with more raw records do not automatically receive more weight. Raw-record summaries remain in the CSV as descriptive information only.

## Main results

| Season | All available median | IQR | 75% balanced median | 50% balanced median | Zero-excluded median |
|---|---:|---:|---:|---:|---:|
| Summer | 66.80 | 16.51 | 53.41 | 67.50 | 66.80 |
| Autumn | 67.40 | 7.65 | 61.93 | 69.80 | 67.40 |
| Winter | 69.43 | 7.98 | 61.43 | 70.53 | 69.43 |
| Spring | 68.72 | 7.65 | 61.35 | 70.20 | 68.72 |

Winter has the highest all-available median (69.43), while Summer has the lowest (66.80). The difference is 2.63 dataset units among the eligible monitored locations.

The maximum absolute difference between the all-available and 75% balanced seasonal medians is 13.39 dataset units. The maximum difference after excluding zero values is 0.00 dataset units.

## Composition and sensitivity

The all-available analysis includes up to 11 sensors, while the primary balanced analysis includes 2. Differences between these summaries show the contribution of changing sensor availability and unequal temporal coverage. The 50% alternative threshold is retained in the CSV so the coverage choice can be assessed without changing the pre-specified primary rule.

The all-available seasonal order is Winter > Spring > Autumn > Summer; the 75% balanced order is Autumn > Winter > Spring > Summer; and the 50% balanced order is Winter > Spring > Autumn > Summer. The 75% ranking is therefore not identical to the all-available ranking, although Summer remains lowest in all three summaries. The identity of the highest season is sensitive to the coverage threshold and sensor composition.

The all-available zero-excluded seasonal ranking is unchanged. Zero exclusion is a sensitivity analysis only and does not establish that zero readings are faults.

## Interpretation

The reported differences describe the monitored locations represented in each eligible seasonal sample. They do not demonstrate a causal effect of weather, tourism, venue activity or any other seasonal mechanism. They also should not be interpreted as a city-wide seasonal pattern.

Figure 15 shows the balanced sensor-season-year distribution. Figure 16 shows sensor-specific seasonal medians and marks cells below the primary coverage threshold with X rather than replacing missing or ineligible values with zero.

## Outputs

- `data/processed/seasonal_noise_summary.csv`
- `data/processed/sensor_season_coverage.csv`
- `figures/fig15_seasonal_noise_boxplot.png`
- `figures/fig16_sensor_season_heatmap.png`
