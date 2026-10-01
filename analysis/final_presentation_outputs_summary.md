# Final Presentation Output Summary

## Sensor-level outputs

The heatmap and small-multiple profiles cover 11 usable Noise sensors. All panels use a common scale, and all summaries retain finite recorded zero values. The overall site medians range from 52.3 to 81.1 dataset units.

Observed site differences cannot be separated from sensor calibration, mounting, placement, or local exposure differences with the available metadata.

## Spatial context map

The map contains 11 usable Noise sensors, labelled 500 m buffers, and 92 pedestrian counters with valid coordinates in the 2025 activity file. Of those counters, 53 fall within at least one primary buffer. Buffers are descriptive proximity summaries, not neighbourhood boundaries or causal exposure zones.

## RQ3 hospitality screen

The primary 500 m screen contains 11 eligible sites. Its strict thresholds are a 2025 night-time median recorded Noise value below 64.2 and a lagged 2024 hospitality venue count above 206. No 500 m site meets both conditions. The thresholds were not changed after this result was observed.

Sensitivity counts using the identical rule are:

- 250 m: 0 candidate(s)
- 500 m: 0 candidate(s)
- 1,000 m: 1 candidate(s) (ICTMicroclimate-01)

This screen is a transparent descriptive prioritisation exercise. It is not a statistical test, a causal comparison, a measure of realised amenity access, or a residential recommendation.

## Generated outputs

- `data/processed/final_sensor_hour_profiles.csv`
- `data/processed/final_sensor_site_summary.csv`
- `data/processed/rq3_hospitality_screen_all_buffers.csv`
- `data/processed/rq3_hospitality_screen_summary.csv`
- `figures/final_sensor_hour_heatmap.png`
- `figures/final_sensor_hour_profiles.png`
- `figures/final_noise_pedestrian_context_map_500m.png`
- `figures/final_rq3_hospitality_screen_500m.png`
