# Urban Activity Context Summary

## Scope

This analysis describes nearby urban-activity characteristics around the monitored Noise sensor locations. Venue records represent potential activity, while pedestrian counters represent observed movements past specific counters. Neither source measures individual behaviour or establishes that urban activity causes recorded Noise values.

The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.

## Data sources

| File | Role |
|---|---|
| `bars-and-pubs-with-patron-capacity.csv` | Bar/pub counts and patron capacity by location and year |
| `cafes-and-restaurants-with-seating-capacity.csv` | Cafe/restaurant counts and indoor/outdoor seating |
| `business-establishments-with-address-and-industry-classification.csv` | Address-level 2024 CLUE business features |
| `pedestrian_counts_2019_2024.csv` | Hourly pedestrian counter observations; the filename does not reflect the full actual date range |
| `pedestrian-counting-system-sensor-locations.csv` | Pedestrian counter coordinates used for spatial matching |

## Current integration design

- The analysis unit is one monitored Noise sensor and one buffer distance.
- The 500 m buffer is the primary spatial specification; 250 m and 1,000 m are sensitivity distances.
- CLUE venue and business features use the 2024 snapshot.
- The formal 2025 pedestrian analysis uses 18:00-05:59 as night-time and labels the business variables as a **lagged 2024 contextual baseline, not a 2025 measurement**.
- Buffer rows are not treated as independent replications of the same monitored sensor.

## Interpretation limits

- Spatial conclusions apply only to the monitored locations and their defined buffers.
- Pedestrian counts are movements past counters, not unique people, patrons or venue customers.
- Venue capacity is a contextual characteristic, not a direct measure of realised attendance.
- The small number of monitored Noise locations supports exploratory associations, not causal or city-wide conclusions.
- Zero Noise records remain in the primary analysis because their meaning is unresolved; a parallel sensitivity analysis reports estimates after excluding `Noise == 0`.

## Related outputs

- `data/processed/integrated_sensor_all_buffers.csv`
- `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv`
- `data/processed/noise_pedestrian_integrated_2025.csv`
- `data/processed/noise_zero_value_sensitivity.csv`
