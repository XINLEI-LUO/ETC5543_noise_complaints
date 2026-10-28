# Current Analysis Variable Dictionary

This dictionary covers the current Noise analysis outputs used by the analysis pipeline, final report and final presentation. File provenance and regeneration commands are listed in [`data/README.md`](../data/README.md). More detailed definitions are available in [`noise_outcome_preparation.md`](noise_outcome_preparation.md), [`clue_business_feature_dictionary.md`](clue_business_feature_dictionary.md) and [`pedestrian_activity_multiyear_summary.md`](pedestrian_activity_multiyear_summary.md).

The former entries for `bars_clean.csv`, `cafes_clean.csv`, `block_nightlife_features_2024.csv` and `pedestrian_sensors_clean.csv` are retired: those files are not present in the current repository and are not canonical project inputs or outputs.

## Shared conventions

| Variable or convention | Type | Definition |
|---|---|---|
| `device_id` | character | Noise sensor identifier and the primary key for site-level analysis. Use this rather than the location label because two devices can share a label. |
| `sensor_location` | character | Human-readable Noise sensor location supplied with the sensor metadata. |
| `longitude`, `latitude` | numeric | Sensor coordinates in WGS84 (EPSG:4326). |
| `buffer_m` | integer | Circular buffer radius in metres. The pre-specified primary radius is 500 m; 250 m and 1,000 m are sensitivity checks. Rows at different radii for the same device are not independent sites. |
| Noise values | numeric | Values from the source `Noise` field. The repository does not contain sufficient metadata to confirm a physical acoustic unit, so outputs use “Noise value” or “dataset units”, not dB/dBA. |
| Day/night | — | Daytime is 06:00–17:59 and nighttime is 18:00–05:59 in the timestamp used by the source data. |
| Missing and zero values | — | Missing values are unavailable observations. Zero Noise readings are retained and counted separately rather than being silently converted to missing. |
| Spatial distance | — | Buffer joins use projected metric coordinates (GDA2020 / MGA zone 55, EPSG:7855), unless a file's provenance field explicitly states a different distance method. |

## `data/processed/noise_outcomes_for_integration.csv`

One row per usable Noise sensor. This is the canonical site-level Noise outcome table used by the spatial integration pipeline.

| Variable | Type | Definition |
|---|---|---|
| `device_id` | character | Unique Noise sensor identifier. |
| `sensor_location` | character | Display name for the sensor location. |
| `longitude`, `latitude` | numeric | Sensor coordinates in WGS84. |
| `first_observation`, `last_observation` | datetime | First and last retained observations for the device. |
| `coverage_days` | numeric | Elapsed time between first and last retained observations, expressed in days. |
| `n_total_observations` | integer | Total source observations considered for the device. |
| `n_valid_noise` | integer | Non-missing Noise observations used in summaries. |
| `n_missing_noise` | integer | Observations with missing Noise values. |
| `n_zero_noise` | integer | Valid Noise observations equal to zero. |
| `coverage_ratio` | numeric | Observed valid readings divided by the expected readings over the device-specific observation span. |
| `overall_median_noise` | numeric | Median valid Noise value over the full device-specific period. |
| `daytime_median_noise`, `nighttime_median_noise` | numeric | Median valid Noise value in the shared day/night windows. |
| `weekday_median_noise`, `weekend_median_noise` | numeric | Median valid Noise value for weekdays and weekends. |
| `n_overall_noise`, `n_daytime_noise`, `n_nighttime_noise`, `n_weekday_noise`, `n_weekend_noise` | integer | Valid-observation counts supporting each corresponding median. |

## `data/processed/integrated_sensor_all_buffers.csv`

One row per `device_id` and `buffer_m` for the 250 m, 500 m and 1,000 m buffers. It combines the site-level Noise outcomes above with 2024 bar/pub and café/restaurant context.

| Variable | Type | Definition |
|---|---|---|
| `buffer_m` | integer | Buffer radius around the Noise sensor. |
| `n_bars` | integer | Number of 2024 bar/pub venues whose point falls within the buffer. |
| `total_bar_capacity` | numeric | Sum of licensed patron capacity for bar/pub venues in the buffer. |
| `median_bar_capacity` | numeric | Median licensed patron capacity among bar/pub venues in the buffer. |
| `n_cafes` | integer | Number of 2024 café/restaurant venues in the buffer. |
| `indoor_seats`, `outdoor_seats` | numeric | Summed 2024 indoor and outdoor café/restaurant seating in the buffer. |
| `feature_data_year` | integer | Context year for the venue features; currently 2024. |
| `join_status` | character | Whether the expected venue feature sources were successfully joined. |
| `notes` | character | Optional row-level integration note. |

All Noise and coverage fields retain the definitions in `noise_outcomes_for_integration.csv`.

## `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv`

The current extended spatial panel: one row per Noise sensor and buffer, with the venue variables above plus 2024 CLUE business-establishment context. The complete CLUE definitions are maintained in [`clue_business_feature_dictionary.md`](clue_business_feature_dictionary.md).

| Variable group | Key fields | Definition |
|---|---|---|
| Establishment totals | `total_records`, `total_active_businesses`, `vacant_spaces` | Counts of spatially matched 2024 CLUE establishment records, active businesses and vacant premises. |
| Hospitality | `cafes_restaurants`, `takeaway_food`, `pubs_bars_clue`, `other_food_beverage` | Counts of establishments in the named CLUE industry categories. |
| Other industries | `retail_businesses`, `accommodation_businesses`, `entertainment_recreation_businesses`, `professional_scientific_technical_businesses`, `financial_insurance_businesses`, `rental_real_estate_businesses`, `administrative_support_businesses` | Counts of active businesses in the named categories. |
| Diversity | `business_mix_entropy`, `business_mix_entropy_normalised` | Raw and normalised Shannon entropy of the active-business category mix. |
| Density | `buffer_area_km2`, `business_density_per_km2` | Nominal circular-buffer area and active-business density. Density does not correct for clipped land area or overlapping buffers. |
| Vacancy | `vacancy_share` | Vacant spaces divided by total matched records when the denominator is non-zero. |
| QA flags | `zero_business_buffer`, `low_business_count_flag`, `duplicate_treatment` | Flags and documentation for sparse buffers and source-record deduplication. |
| Provenance | `feature_source`, `feature_data_year.x`, `feature_data_year.y` | Source and year fields retained from the joined venue and CLUE feature tables. The `.x`/`.y` suffixes result from the join. |

## `data/processed/noise_pedestrian_integrated_2025.csv`

One row per Noise sensor and buffer, combining aligned 2025 nighttime Noise outcomes with pedestrian activity and explicitly labelled 2024 venue baselines.

| Variable or group | Type | Definition |
|---|---|---|
| `n_pedestrian_sensors` | integer | Number of pedestrian counters within the selected buffer. |
| `pedestrian_sensor_ids` | character | Semicolon-separated IDs of matched pedestrian counters. |
| `nearest_pedestrian_sensor_m` | numeric | Distance to the nearest matched pedestrian counter, in metres. |
| `mean_pedestrian_sensor_coverage_ratio` | numeric | Mean availability measure across the matched pedestrian counters. |
| `mean_*_avg_hourly_pedestrian_count` | numeric | Mean of the matched counters' average hourly pedestrian counts for the named time window. Each counter contributes equally. |
| `sum_sensor_means_*_avg_hourly_pedestrian_count` | numeric | Sum of matched counter-level average hourly counts for the named time window. This increases with both activity and the number of counters. |
| `nighttime_median_noise` | numeric | Median 2025 Noise value for 18:00–05:59, used as the aligned pedestrian-analysis outcome. |
| `nighttime_valid_observations`, `nighttime_coverage_ratio` | integer / numeric | Observation count and coverage measure supporting the nighttime outcome. |
| `n_bars_2024_baseline`, `total_bar_capacity_2024_baseline` | integer / numeric | Lagged 2024 hospitality context; these are not 2025 measurements. |
| `analysis_start_date`, `analysis_end_date`, `analysis_period` | date / character | Explicit temporal scope of the aligned analysis. |
| `feature_year`, `business_feature_year`, `business_temporal_status` | integer / character | Years and temporal relationship of the pedestrian and business features. |
| `source_files`, `generation_script`, `generated_at`, `output_purpose` | character | Input lineage, generating script, timestamp and intended use. |

The file also contains analogous pedestrian measures for all-day, daytime, nighttime, weekday, weekend and evening windows. Their suffixes identify the time window.

## Final report and presentation outputs

| File | Grain | Key variables and interpretation |
|---|---|---|
| `data/processed/final_sensor_site_summary.csv` | One row per usable Noise sensor | `overall_median_noise`, `valid_observations`, `active_days`, `first_observation`, `last_observation`; used for descriptive site comparison. |
| `data/processed/final_sensor_hour_profiles.csv` | One row per sensor and hour | `hour`, `median_noise`, `valid_observations`; used for hourly profiles and the heatmap. |
| `data/processed/rq3_hospitality_screen_all_buffers.csv` | One row per sensor and buffer | `hospitality_venues_2024`, median thresholds and Boolean screen fields. The 500 m result is primary; 250 m and 1,000 m are sensitivity checks. |
| `data/processed/rq3_hospitality_association_by_buffer.csv` | One row per buffer | Spearman `spearman_rho`, asymptotic and permutation p-values, sample size, seed and provenance for the exploratory continuous association. |

## Interpretation limits

- The Noise values have no confirmed physical acoustic unit in the retained metadata.
- Site coverage periods are unequal except where an aligned analysis period is explicitly stated.
- The 2024 business and venue fields are contextual snapshots and must not be described as concurrent 2025 measurements.
- Buffers overlap, and multiple buffer rows for one sensor are sensitivity specifications rather than additional independent observations.
- The small number of Noise sites supports descriptive and exploratory inference only; associations are not causal effects.
