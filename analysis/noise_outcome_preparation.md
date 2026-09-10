# Noise outcome preparation handover

## Purpose

These files prepare sensor-level Noise outcomes for spatial linkage with urban-environment data. This is data preparation, not modelling or a new city-wide noise analysis. `Noise` is reported in **dataset units** because no authoritative repository metadata identifies its physical unit.

## Usable sensors

The raw file contains 12 device IDs. Eleven ICT sensors have at least one valid Noise observation and are retained in the location, hourly and daily outcome files. `aws5-0999` is excluded from outcome aggregation because all 65,847 of its Noise observations are missing; it remains documented in `data/processed/noise_sensor_audit.csv`.

All 11 usable sensors have exactly one complete coordinate pair. Location labels are unique except that `ICTMicroclimate-10` and `ICTMicroclimate-11` both use `1 Treasury Place`; they have distinct device IDs and slightly different coordinates. Use `device_id`, not the location label, as the primary join key.

## Outputs

- `data/processed/noise_sensor_audit.csv`: one row for each of the 12 raw devices, including usability, coordinate/location counts, rows with missing coordinates and any exclusion reason.
- `data/processed/noise_sensor_locations.csv`: one row for each of the 11 usable noise sensors, with coordinates, observation dates and Noise completeness counts.
- `data/processed/noise_sensor_hour.csv`: 228,241 rows; one row per usable sensor and elapsed calendar hour. Local timestamps include their UTC offset so repeated daylight-saving clock hours remain distinguishable.
- `data/processed/noise_sensor_day.csv`: 9,596 rows; one row per usable sensor and Melbourne calendar day.

The hourly and daily outcomes span 2022-05-31 to 2026-08-17. Both carry `sensor_location`, latitude and longitude for direct use, although the location table remains the authoritative spatial sensor layer.

## Aggregation definitions

For every sensor-hour and sensor-day, `noise_mean`, `noise_median`, `noise_min`, `noise_max` and `noise_sd` are calculated from finite Noise values only. The median is the preferred typical-value measure because it is less sensitive to extreme values. Standard deviation is missing where fewer than two valid readings exist.

`n_observations` counts all source rows in the group, `n_valid_noise` counts finite Noise rows, and `n_missing_noise` is their difference. `n_unique_timestamps` counts distinct timestamps, while `n_unique_valid_timestamps` counts distinct timestamps having at least one finite Noise value. `n_zero_noise` counts retained zero readings. No duplicate row, zero or extreme value is automatically removed.

Hourly coverage uses `expected_obs = 4`; daily coverage uses `expected_obs = 96`. `raw_row_coverage_ratio = n_valid_noise / expected_obs` is retained as a diagnostic and can exceed 1 when repeated timestamp rows are present. `unique_timestamp_coverage_ratio = n_unique_valid_timestamps / expected_obs` is the uncapped duplicate-resistant diagnostic. The operational `coverage_ratio = pmin(unique_timestamp_coverage_ratio, 1)` is therefore restricted to [0, 1]; `unique_coverage_ratio` remains as a backward-compatible alias of this capped measure. The main hourly and daily completeness flags require the unique valid timestamp count to meet the expected count, so duplicated rows cannot make a group complete. Incomplete groups are retained.

## Validation results

- Sensor-hour keys are unique: no duplicate `device_id + hourly_timestamp` keys remain.
- Sensor-day keys are unique: no duplicate `device_id + date` keys remain.
- All raw timestamps parsed successfully; the sensor audit finds zero rows with missing parsed coordinates, and no usable sensor has missing coordinates.
- Positive timestamp gaps have a median of 15.03 minutes, and 93.85% fall between 12 and 18 minutes. This supports four-per-hour and 96-per-day as practical reference counts, not guaranteed schedules.
- 215,497 sensor-hours (94.42%) meet the unique-timestamp hourly completeness rule; 12,744 (5.58%) do not.
- 5,678 sensor-days (59.17%) meet the unique-timestamp daily completeness rule; 3,918 (40.83%) do not.
- The raw data contain 2,745 duplicated `device_id + timestamp` groups (2,751 excess rows beyond one row per key). These records are retained rather than silently deduplicated. Consequently, the diagnostic `raw_row_coverage_ratio` can exceed 1, while duplicate records do not inflate the operational `coverage_ratio`, its backward-compatible `unique_coverage_ratio` alias, or the completeness flags.
- There are 649 retained zero Noise readings.
- The number of sensors with valid observations varies by period: monthly activity ranges from 1 to 11 usable sensors. Sensor start/end dates and outages are unequal.

The 96-per-day rule also does not adjust to 92 or 100 readings on daylight-saving transition days. Treat coverage as a simple visibility flag, especially near partial first/last days, outages, duplicate timestamps and daylight-saving transitions.

## Data-quality limitations

- The Noise unit and physical interpretation remain unknown; do not label the values as dB or decibels.
- Zero readings are retained because their meaning is unresolved.
- Extreme values are retained; both mean and median are provided for later robustness checks.
- Sensors have unequal start and end dates, and gaps/outages produce incomplete hours and days.
- Duplicate raw device/timestamp records have been flagged but not silently changed.
- Spatial coverage represents monitored sensor locations, not all of Melbourne; these files do not support city-wide hotspot claims or interpolation.

## Recommendation for Chen

Use `noise_sensor_locations.csv` as the spatial sensor layer and `device_id` as the primary join key. Create the agreed 500 m buffers from its longitude/latitude coordinates, then join aggregated outcomes back by `device_id`. Start the pilot integration with `noise_sensor_day.csv`; retain `noise_sensor_hour.csv` for later time-of-day work. Review coverage fields during linkage and sensitivity analysis rather than discarding incomplete groups automatically.
