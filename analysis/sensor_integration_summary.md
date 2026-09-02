# Sensor integration summary

## Status

The workflow is complete for the available 2024 CLUE bar/pub and cafe/restaurant sources. It produces noise outcomes for 11 usable sensors, three distance-specific integration tables, the 33-row combined table, join diagnostics and a faceted integration map. Automated validation passes.

## Methods

- Analysis unit: one sensor by one buffer distance, uniquely identified by `device_id + buffer_m`.
- Usable network: 11 sensors with valid noise observations. `aws5-0999` is excluded because it has no valid Noise values; the exclusion remains in `data/processed/noise_sensor_audit.csv`.
- Time zone: `Australia/Melbourne`.
- Daytime: 06:00 to before 18:00. Night-time: 18:00 to before 06:00.
- Weekday: Monday-Friday. Weekend: Saturday-Sunday.
- Coverage ratio: valid noise observations divided by the number of expected 15-minute slots from the sensor's first through last observation, inclusive. This is a visibility measure and does not eliminate outages, duplicate timestamps or daylight-saving limitations.
- Noise unit: dataset units; no authoritative metadata in the repository confirm decibels.
- Zero Noise readings are retained and counted separately.
- Spatial CRS: inputs are verified as plausible WGS84 longitude/latitude before conversion. All buffers and spatial joins use GDA2020 / MGA Zone 55 (EPSG:7855), whose metre-based coordinates are appropriate for Melbourne distance operations.
- Buffers: 250 m and 1,000 m are sensitivity distances; 500 m is the primary distance.
- Venue deduplication: the integration script uses block ID, trading name and coordinates as the venue identifier. Exact duplicate cafe records are removed within venue and seating type. A venue may belong to more than one sensor when buffers overlap.
- Zero versus NA: zero is assigned only after a successful source load and join finds no matching venue. Missing fields, failed inputs/joins, or wholly missing capacity/seating among matched venues remain NA.

## Outputs

- `data/processed/noise_outcomes_for_integration.csv`
- `data/processed/integrated_sensor_250m.csv`
- `data/processed/integrated_sensor_500m.csv`
- `data/processed/integrated_sensor_1000m.csv`
- `data/processed/integrated_sensor_all_buffers.csv`
- `data/processed/integration_join_diagnostics.csv`
- `figures/sensor_buffer_integration_map.png`

The available business-establishment, floor-space and pedestrian files are not added because the requested core feature set is defensibly supplied by the venue-level CLUE bar/pub and cafe/restaurant sources. This avoids adding proxies that were not required for the validated integration.

## Join diagnostics

- Source year: 2024.
- Bars/pubs: 304 unique venues with valid coordinates; 249 (81.91%) fall inside at least one sensor buffer.
- Cafes/restaurants: 2,248 unique venues with valid coordinates; 1,628 (72.42%) fall inside at least one sensor buffer.
- No invalid coordinates, coordinate-order problems, join failures, or missing capacity/seating values were found in the selected 2024 records.
- Two sensors have no bars/pubs within 250 m. All sensors have at least one bar/pub within 500 m and 1,000 m, and at least one cafe/restaurant at every distance.
- Feature counts and seating totals are non-decreasing as buffer size increases.

## Reproduction

Run from the project root in RStudio or a terminal:

```r
source("analysis/prepare_noise_outcomes.R")
source("analysis/duplicate_timestamp_sensitivity.R")
source("analysis/build_sensor_integration.R")
source("analysis/validate_sensor_integration.R")
```

The spatial steps require `dplyr`, `tidyr`, `readr`, `sf`, and `ggplot2`. These were installed in the user R library without modifying `renv`.

## Limitations

Sensor coverage represents monitored locations only and must not be interpreted as Melbourne-wide coverage. Sensor operating periods and outages differ, zero meaning is unresolved, duplicate timestamp rows are retained, and the physical unit of Noise is unverified. Venue counts can legitimately include the same venue for more than one sensor when buffers overlap. The 2024 urban features are cross-sectional and do not represent conditions throughout every sensor's observation period.

## Duplicate-timestamp QA and sensitivity decision

The raw data contain 5,496 rows in 2,745 repeated `device_id + timestamp` groups, representing 2,751 excess rows. None are exact duplicate rows. Only 59 groups have identical Noise values; 2,686 have conflicting Noise states, including three groups that mix a recorded value with missing Noise. The largest difference between finite Noise values at one sensor/timestamp is 40.0 dataset units.

Sensor location and coordinates are stable within every repeated key, while Noise and multiple meteorological measurements frequently differ. The records therefore appear to be distinct source observations assigned the same timestamp rather than duplicated file rows. The precise cause cannot be determined because the source has no ingestion ID, sequence number, or update metadata.

`analysis/duplicate_timestamp_sensitivity.R` creates no deduplicated raw file and does not delete records. It constructs an in-memory sensitivity dataset: one value is retained when repeated Noise values are identical; conflicting finite values are replaced by their within-sensor/timestamp median; all-missing groups remain missing. It writes:

- `data/processed/noise_duplicate_timestamp_diagnostics.csv`
- `data/processed/noise_deduplication_sensitivity_comparison.csv`

Across 55 sensor/outcome comparisons, 53 are exactly unchanged. `ICTMicroclimate-08` changes by 0.1 dataset units for the weekend median only, and `ICTMicroclimate-09` changes by 0.1 for the overall median only. Every other absolute difference is zero:

| Sensor | Overall | Daytime | Night-time | Weekday | Weekend |
|---|---:|---:|---:|---:|---:|
| ICTMicroclimate-01 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-02 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-03 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-04 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-05 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-06 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-07 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-08 | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 |
| ICTMicroclimate-09 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-10 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| ICTMicroclimate-11 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |

The maximum change is therefore 0.1 dataset units, one source precision step and small relative to sensor medians of approximately 52-81. Deduplication is not necessary for the primary median outcomes, so the main outcomes remain based on the original records and no raw records are removed. The sensitivity result remains an explicit robustness check.

Hourly and daily `coverage_ratio` uses unique valid timestamps divided by expected observations and is capped at 1, matching `unique_coverage_ratio`. `unique_timestamp_coverage_ratio` retains the uncapped unique-timestamp diagnostic because irregular sampling can yield more than the nominal 4/96 distinct timestamps, while `raw_row_coverage_ratio` retains the former row-count calculation. This prevents operational coverage from exceeding 1 without silently removing records or hiding sampling irregularity.
