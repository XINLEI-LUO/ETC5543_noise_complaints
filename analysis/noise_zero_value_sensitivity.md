# Noise Zero Value Sensitivity Analysis

## Scope and unresolved metadata limitation

The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.

The primary analysis retains `Noise == 0` and excludes only missing or non-finite Noise values. The sensitivity analysis excludes `Noise == 0`. Neither analysis modifies the raw source file or converts zero values to missing values.

## Zero value distribution

There are 649 zero records among 893959 non-missing Noise records (0.0726%).
The highest sensor-specific zero percentage is 0.5340% at `ICTMicroclimate-08` (435 records).
The largest annual zero count is 634 in 2026; the largest hourly zero count is 57 at 05:00.

The CSV reports zero counts and percentages overall, by sensor, by year, by local hour and for daytime/night-time. Concentration is descriptive and does not establish whether zeros are measurements, faults or missing-value codes.

## Descriptive sensitivity results

The maximum absolute hourly median difference is 0.1000 dataset units.
The maximum absolute weekday median difference is 0.0000 dataset units.
The maximum absolute sensor-median difference is 0.1000 dataset units. The sensor ordering is unchanged.
The 2025 night-time median is 65.7000 with zeros retained and 65.7000 after zero exclusion (absolute difference 0.0000; n=166221/166219).

## 500 m urban activity associations

The models reproduce the existing 2025 specification: one row per monitored noise sensor, 500 m as the primary buffer, 18:00-05:59 night-time Noise median as the outcome, pedestrian activity as the main predictor, and the optional bar-capacity adjustment as a lagged 2024 contextual baseline, not a 2025 measurement.

- pearson correlation, `bivariate correlation`, `mean_nighttime_avg_hourly_pedestrian_count`: 0.204692 (primary) versus 0.204692 (excluding zero), absolute difference 0.000000, n=10/10.
- spearman correlation, `bivariate correlation`, `mean_nighttime_avg_hourly_pedestrian_count`: 0.248485 (primary) versus 0.248485 (excluding zero), absolute difference 0.000000, n=10/10.
- pearson correlation, `bivariate correlation`, `sum_sensor_means_nighttime_avg_hourly_pedestrian_count`: 0.362707 (primary) versus 0.362707 (excluding zero), absolute difference 0.000000, n=10/10.
- spearman correlation, `bivariate correlation`, `sum_sensor_means_nighttime_avg_hourly_pedestrian_count`: 0.393939 (primary) versus 0.393939 (excluding zero), absolute difference 0.000000, n=10/10.
- OLS coefficient, `simple_pedestrian_mean`, `mean_nighttime_avg_hourly_pedestrian_count`: 0.016653 (primary) versus 0.016653 (excluding zero), absolute difference 0.000000, n=10/10.
- OLS coefficient, `alternative_pedestrian_intensity`, `sum_sensor_means_nighttime_avg_hourly_pedestrian_count`: 0.000891 (primary) versus 0.000891 (excluding zero), absolute difference 0.000000, n=10/10.
- OLS coefficient, `exploratory_adjusted_2024_bar_capacity`, `mean_nighttime_avg_hourly_pedestrian_count`: -0.028896 (primary) versus -0.028896 (excluding zero), absolute difference 0.000000, n=10/10.
- OLS coefficient, `exploratory_adjusted_2024_bar_capacity`, `total_bar_capacity_2024_baseline`: 0.000783 (primary) versus 0.000783 (excluding zero), absolute difference 0.000000, n=10/10.

## Interpretation

In the observed snapshot, excluding zero records changes hourly and sensor medians by no more than 0.1000 dataset units, leaves the sensor ordering unchanged, and changes the reported 500 m association estimates by at most 0.000000. The main temporal, sensor-ranking and urban-activity conclusions are therefore robust to zero-value exclusion in this dataset.

The observed primary and zero-excluded estimates should be read side by side. Excluding zeros does not justify treating zeros as errors. Conclusions remain limited to the monitored locations and describe exploratory associations rather than causal, health, regulatory or city-wide effects.

Detailed estimates, sample sizes, absolute differences, relative differences where defined, ranks and zero distributions are in `data/processed/noise_zero_value_sensitivity.csv`.
