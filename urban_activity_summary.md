# Urban Activity / Nightlife: EDA Summary

\
**Data sources:** CLUE Bars & Pubs, Cafes & Restaurants, Pedestrian Sensors

## Key Findings

-   **Melbourne CBD dominates nightlife:** The CBD has the highest concentration of bars/pubs and the largest total patron capacity of any CLUE small area (2024).
-   **Patron capacity trends:** CBD bar/pub capacity grew steadily from 2002 to \~2015, plateaued, dipped noticeably around 2020–2021 (COVID), then partially recovered by 2024.
-   **Outdoor dining:** The CBD and Southbank have the most outdoor café/restaurant seats: both high foot-traffic, noise-sensitive areas.

## Datasets Used

| File | Description |
|-----------------------|-------------------------------------------------|
| bars-and-pubs-with-patron-capacity.csv | Venue count and patron capacity by area/year |
| cafes-and-restaurants-with-seating-capacity.csv | Indoor/outdoor seating by area/year |
| pedestrian-counting-system-sensor-locations.csv | Sensor lat/lon for spatial join |
| business-establishments-per-block-by-anzsic.csv | Block-level business counts |
| floor-space-by-block-by-anzsic.csv | Block-level floor space by industry |

## Limitations

-   No liquor licence data available for bulk download (VCGLR has no open API). Bars & pubs dataset used as proxy.
-   No trading hours data: cannot directly identify late-night venues.
-   Spatial join to noise sensors needed to connect nightlife density to complaint patterns.

## Next Steps

-   Spatial join: map each noise sensor to its nearest CLUE block
-   Correlate block-level bar/pub density with noise complaint frequency
