# Part 2 — Feature QA Summary

Generated: 2026-09-02 22:21:13.123289

## Output file
- `data/processed/urban_features_250_500_1000m.csv`
- 11 rows (one per noise sensor)
- 25 columns

## Sensors
- 11 usable noise sensors included
- Sensor aws5-0999 excluded — no valid Noise readings

## Venue counts (2024 source data)
- Bars/pubs: 304
- Café indoor rows: 2175
- Café outdoor rows: 1074

## Zero vs NA treatment
- n_bars_*: 0 when no bars in buffer; never NA.
- total_patron_cap_*: 0 when n_bars == 0; NA when any matched bar has missing capacity.
- indoor_seats_* / outdoor_seats_*: 0 when no cafes; NA when seat values missing.
- Flag columns (n_bars_missing_cap_*, n_indoor_missing_seats_*, n_outdoor_missing_seats_*)
  count how many venues had missing values.

## Monotonicity check

PASS: All feature counts non-decreasing with buffer size.

## Pedestrian activity
- Not included. Raw counts file (~82 MB) not summarised inline.
- Sensor locations: data/processed/pedestrian_sensors_clean.csv
- Limitation: pedestrian sensors capture all foot traffic, not nightlife-specific activity.

## Spatial CRS
- Input: WGS84 (EPSG:4326). Buffers: GDA2020 / MGA Zone 55 (EPSG:7855).

## Data year
- All venue data from 2024 CLUE census.

## Limitations
- No liquor licence data; patron capacity used as nightlife proxy.
- No trading hours data; late-night venues cannot be identified.
- CLUE is annual; within-year seasonal variation not captured.
- Venues near buffer edges may be partially included or excluded.
- Overlapping buffers: same venue counted once per sensor buffer (intentional).
