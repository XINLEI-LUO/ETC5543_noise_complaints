# Part 2: Urban-activity buffer features
# analysis/part2_buffer_features.R
#
# Output: data/processed/urban_features_250_500_1000m.csv
#         data/processed/part2_feature_qa_summary.md


library(tidyverse)
library(sf)

proc  <- "data/processed/"
raw   <- "data/raw/"

crs_wgs    <- 4326L   # WGS84 lat/lon
crs_metric <- 7855L   # GDA2020 / MGA Zone 55 — metres, Melbourne

BUFFER_DISTANCES <- c(250L, 500L, 1000L)


# 1. Loading sensors (Cindy's output: 11 usable sensors)

sensors <- read_csv(
  paste0(proc, "noise_sensor_locations.csv"),
  col_types = cols(
    device_id       = col_character(),
    sensor_location = col_character(),
    latitude        = col_double(),
    longitude       = col_double(),
    .default        = col_guess()
  )
) |>
  filter(!is.na(latitude), !is.na(longitude))

stopifnot("Expected 11 usable sensors" = nrow(sensors) == 11L)

sensors_sf <- sensors |>
  st_as_sf(coords = c("longitude", "latitude"), crs = crs_wgs) |>
  st_transform(crs_metric)

# 2. Loading 2024 venue data

bars_clean <- read_csv(paste0(proc, "bars_clean.csv"),
                       col_types = cols(year = col_double(), block_id = col_double(),
                                        area = col_character(), venue_name = col_character(),
                                        n_patrons = col_double(), lat = col_double(), lon = col_double()))

cafes_clean <- read_csv(paste0(proc, "cafes_clean.csv"),
                        col_types = cols(year = col_double(), block_id = col_double(),
                                         area = col_character(), venue_name = col_character(),
                                         seating_type = col_character(), n_seats = col_double(),
                                         lat = col_double(), lon = col_double()))

bars_2024  <- bars_clean  |> filter(year == 2024, !is.na(lat), !is.na(lon))
cafes_2024 <- cafes_clean |> filter(year == 2024, !is.na(lat), !is.na(lon))

cafes_indoor  <- cafes_2024 |> filter(str_detect(seating_type, regex("indoor",  ignore_case = TRUE)))
cafes_outdoor <- cafes_2024 |> filter(str_detect(seating_type, regex("outdoor", ignore_case = TRUE)))

message(sprintf("2024 venues — bars: %d, indoor rows: %d, outdoor rows: %d",
                nrow(bars_2024), nrow(cafes_indoor), nrow(cafes_outdoor)))

to_sf <- function(df, lon_col = "lon", lat_col = "lat") {
  df |>
    st_as_sf(coords = c(lon_col, lat_col), crs = crs_wgs) |>
    st_transform(crs_metric)
}

bars_sf    <- to_sf(bars_2024)
indoor_sf  <- to_sf(cafes_indoor)
outdoor_sf <- to_sf(cafes_outdoor)


# 3. Buffer features per distance
# Zero vs NA: n_bars is always 0+ (0 = none found). total_patron_cap and
# seats are 0 when no venues exist; NA when venues exist but values are missing.

buffer_features_one_distance <- function(buf_m, sensors_sf,
                                         bars_sf, indoor_sf, outdoor_sf) {
  buffers <- st_buffer(sensors_sf, buf_m)
  
  bar_join <- st_join(bars_sf, buffers["device_id"], join = st_within) |>
    st_drop_geometry() |> filter(!is.na(device_id))
  
  bar_summary <- bar_join |>
    group_by(device_id) |>
    summarise(n_bars = n(),
              total_patron_cap   = sum(n_patrons),
              n_bars_missing_cap = sum(is.na(n_patrons)),
              .groups = "drop")
  
  indoor_join <- st_join(indoor_sf, buffers["device_id"], join = st_within) |>
    st_drop_geometry() |> filter(!is.na(device_id))
  
  indoor_summary <- indoor_join |>
    group_by(device_id) |>
    summarise(indoor_seats           = sum(n_seats),
              n_indoor_missing_seats = sum(is.na(n_seats)),
              .groups = "drop")
  
  outdoor_join <- st_join(outdoor_sf, buffers["device_id"], join = st_within) |>
    st_drop_geometry() |> filter(!is.na(device_id))
  
  outdoor_summary <- outdoor_join |>
    group_by(device_id) |>
    summarise(outdoor_seats           = sum(n_seats),
              n_outdoor_missing_seats = sum(is.na(n_seats)),
              .groups = "drop")
  
  sensors_sf |>
    st_drop_geometry() |>
    select(device_id) |>
    left_join(bar_summary,     by = "device_id") |>
    left_join(indoor_summary,  by = "device_id") |>
    left_join(outdoor_summary, by = "device_id") |>
    mutate(
      n_bars                  = replace_na(n_bars, 0L),
      n_bars_missing_cap      = replace_na(n_bars_missing_cap, 0L),
      n_indoor_missing_seats  = replace_na(n_indoor_missing_seats, 0L),
      n_outdoor_missing_seats = replace_na(n_outdoor_missing_seats, 0L),
      total_patron_cap = if_else(n_bars == 0L & is.na(total_patron_cap), 0, total_patron_cap),
      indoor_seats     = if_else(n_indoor_missing_seats == 0L & is.na(indoor_seats), 0, indoor_seats),
      outdoor_seats    = if_else(n_outdoor_missing_seats == 0L & is.na(outdoor_seats), 0, outdoor_seats),
      buffer_m = buf_m
    )
}

all_distances <- map_dfr(BUFFER_DISTANCES, buffer_features_one_distance,
                         sensors_sf = sensors_sf,
                         bars_sf    = bars_sf,
                         indoor_sf  = indoor_sf,
                         outdoor_sf = outdoor_sf)


# 4. Reshaped to wide format : one row per sensor

features_wide <- all_distances |>
  pivot_wider(
    id_cols     = device_id,
    names_from  = buffer_m,
    values_from = c(n_bars, total_patron_cap, indoor_seats, outdoor_seats,
                    n_bars_missing_cap, n_indoor_missing_seats, n_outdoor_missing_seats),
    names_glue  = "{.value}_{buffer_m}m"
  ) |>
  left_join(sensors |> select(device_id, sensor_location, latitude, longitude),
            by = "device_id") |>
  select(device_id, sensor_location, latitude, longitude, everything())


# 5. Pedestrian activity
# Locations: data/raw/pedestrian-counting-system-sensor-locations.csv
# Counts:    data/raw/pedestrian_counts_2019_2024.csv (~82 MB, hourly 2019-2024)
# To add: pre-aggregate to pedestrian_daily_avg_2024.csv and set ped_included <- TRUE

ped_included <- FALSE

if (ped_included) {
  ped_locs <- read_csv(paste0(raw, "pedestrian-counting-system-sensor-locations.csv")) |>
    filter(!is.na(Latitude), !is.na(Longitude)) |>
    rename(ped_id = Location_ID, ped_lat = Latitude, ped_lon = Longitude)
  
  ped_avg <- read_csv(paste0(proc, "pedestrian_daily_avg_2024.csv"))
  
  ped_sf <- ped_locs |>
    left_join(ped_avg, by = c("ped_id" = "Location_ID")) |>
    filter(!is.na(avg_daily_count_2024)) |>
    st_as_sf(coords = c("ped_lon", "ped_lat"), crs = crs_wgs) |>
    st_transform(crs_metric)
  
  for (buf_m in BUFFER_DISTANCES) {
    ped_join <- st_join(ped_sf, st_buffer(sensors_sf, buf_m)["device_id"], join = st_within) |>
      st_drop_geometry() |>
      filter(!is.na(device_id)) |>
      group_by(device_id) |>
      summarise(n_ped_sensors = n(),
                avg_daily_pedestrians = mean(avg_daily_count_2024, na.rm = TRUE),
                .groups = "drop") |>
      rename_with(~ paste0(., sprintf("_%dm", buf_m)), -device_id)
    features_wide <- features_wide |> left_join(ped_join, by = "device_id")
  }
}


# 6. Save output

write_csv(features_wide, paste0(proc, "urban_features_250_500_1000m.csv"))
message("✅ Saved: data/processed/urban_features_250_500_1000m.csv")
message(sprintf("   Rows: %d  |  Columns: %d", nrow(features_wide), ncol(features_wide)))


# 7. QA summary

qa_lines <- c(
  "# Part 2 — Feature QA Summary",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Output file",
  paste0("- `data/processed/urban_features_250_500_1000m.csv`"),
  paste0("- ", nrow(features_wide), " rows (one per noise sensor)"),
  paste0("- ", ncol(features_wide), " columns"),
  "",
  "## Sensors",
  paste0("- ", nrow(sensors), " usable noise sensors included"),
  "- Sensor aws5-0999 excluded — no valid Noise readings",
  "",
  "## Venue counts (2024 source data)",
  paste0("- Bars/pubs: ", nrow(bars_2024)),
  paste0("- Café indoor rows: ", nrow(cafes_indoor)),
  paste0("- Café outdoor rows: ", nrow(cafes_outdoor)),
  "",
  "## Zero vs NA treatment",
  "- n_bars_*: 0 when no bars in buffer; never NA.",
  "- total_patron_cap_*: 0 when n_bars == 0; NA when any matched bar has missing capacity.",
  "- indoor_seats_* / outdoor_seats_*: 0 when no cafes; NA when seat values missing.",
  "- Flag columns (n_bars_missing_cap_*, n_indoor_missing_seats_*, n_outdoor_missing_seats_*)",
  "  count how many venues had missing values.",
  "",
  "## Monotonicity check",
  ""
)

mono_fields <- c("n_bars", "total_patron_cap", "indoor_seats", "outdoor_seats")
mono_ok <- TRUE
for (fld in mono_fields) {
  cols <- paste0(fld, "_", BUFFER_DISTANCES, "m")
  if (!all(cols %in% names(features_wide))) next
  for (i in seq_len(nrow(features_wide))) {
    vals <- unlist(features_wide[i, cols])
    if (any(!is.na(vals) & diff(vals[!is.na(vals)]) < 0)) {
      qa_lines <- c(qa_lines, paste0("WARNING: ", features_wide$device_id[i], " / ", fld))
      mono_ok  <- FALSE
    }
  }
}
if (mono_ok) qa_lines <- c(qa_lines, "PASS: All feature counts non-decreasing with buffer size.")

qa_lines <- c(
  qa_lines,
  "",
  "## Pedestrian activity",
  "- Not included. Raw counts file (~82 MB) not summarised inline.",
  "- Sensor locations: data/processed/pedestrian_sensors_clean.csv",
  "- Limitation: pedestrian sensors capture all foot traffic, not nightlife-specific activity.",
  "",
  "## Spatial CRS",
  "- Input: WGS84 (EPSG:4326). Buffers: GDA2020 / MGA Zone 55 (EPSG:7855).",
  "",
  "## Data year",
  "- All venue data from 2024 CLUE census.",
  "",
  "## Limitations",
  "- No liquor licence data; patron capacity used as nightlife proxy.",
  "- No trading hours data; late-night venues cannot be identified.",
  "- CLUE is annual; within-year seasonal variation not captured.",
  "- Venues near buffer edges may be partially included or excluded.",
  "- Overlapping buffers: same venue counted once per sensor buffer (intentional)."
)

writeLines(qa_lines, paste0(proc, "feature_qa_summary.md"))
message("Saved: analysis/feature_qa_summary.md")
