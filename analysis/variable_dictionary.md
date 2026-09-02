# Variable Dictionary

## File: `data/processed/bars_clean.csv`

One row per bar/pub venue per year (2002–2024).

| Variable   | Type      | Description                                   |
|------------|-----------|-----------------------------------------------|
| year       | numeric   | Census year of observation                    |
| block_id   | numeric   | CLUE block identifier, key for spatial join   |
| area       | character | CLUE small area name (e.g. "Melbourne (CBD)") |
| venue_name | character | Trading name of the venue                     |
| n_patrons  | numeric   | Licensed patron capacity of the venue         |
| lat        | numeric   | Venue latitude (WGS84)                        |
| lon        | numeric   | Venue longitude (WGS84)                       |

------------------------------------------------------------------------

## File: `data/processed/cafes_clean.csv`

One row per café/restaurant seating type per venue per year (2007–2024).

| Variable     | Type      | Description                                 |
|--------------|-----------|---------------------------------------------|
| year         | numeric   | Census year of observation                  |
| block_id     | numeric   | CLUE block identifier, key for spatial join |
| area         | character | CLUE small area name                        |
| venue_name   | character | Trading name of the venue                   |
| seating_type | character | "Seats - Indoor" or "Seats - Outdoor"       |
| n_seats      | numeric   | Number of seats of that type                |
| lat          | numeric   | Venue latitude (WGS84)                      |
| lon          | numeric   | Venue longitude (WGS84)                     |

------------------------------------------------------------------------

## File: `data/processed/block_nightlife_features_2024.csv`

One row per CLUE block. **This is the main file for Chen's spatial integration.**

| Variable           | Type    | Description                                  |
|--------------------|---------|----------------------------------------------|
| block_id           | numeric | CLUE block identifier, join key              |
| n_bars             | numeric | Number of bars/pubs in block (2024)          |
| total_patrons      | numeric | Sum of licensed patron capacity in block     |
| median_patrons     | numeric | Median patron capacity per venue in block    |
| seats\_\_\_indoor  | numeric | Total indoor café/restaurant seats in block  |
| seats\_\_\_outdoor | numeric | Total outdoor café/restaurant seats in block |

**Note:** Blocks with no bars/pubs have `n_bars = 0`. Blocks with no cafés have NA for seating columns.

------------------------------------------------------------------------

## File: `data/processed/pedestrian_sensors_clean.csv`

One row per pedestrian counting sensor (all 134 active).

| Variable           | Type      | Description                         |
|--------------------|-----------|-------------------------------------|
| Location_ID        | numeric   | Unique sensor identifier            |
| Sensor_Description | character | Human-readable sensor location name |
| Sensor_Name        | character | Short sensor code                   |
| Installation_Date  | date      | Date sensor was installed           |
| Location_Type      | character | All "Outdoor"                       |
| Status             | character | All "A" (active)                    |
| Latitude           | numeric   | Sensor latitude (WGS84)             |
| Longitude          | numeric   | Sensor longitude (WGS84)            |

**Note:** All 134 sensors are active. Can be used as a foot-traffic proxy variable in the 500m buffer analysis.

------------------------------------------------------------------------

## Limitations

-   No liquor licence data available (VCGLR has no bulk download). Bars & pubs patron capacity used as proxy.
-   No trading hours data, late-night venues cannot be identified directly.
-   CLUE data is annual, does not capture within-year seasonal variation.
