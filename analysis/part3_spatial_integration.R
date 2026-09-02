# =====================================================================
# Part 3

library(tidyverse)
library(sf)

proc <- "data/processed/"
out  <- "data/processed/integrated/"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

crs_wgs    <- 4326   # raw lat/lon
crs_metric <- 7855   # GDA2020 / MGA zone 55 — metres, covers Melbourne.
                     # Any metre-based projected CRS is fine at this scale (28355 works too).
BUFFER_M   <- 500

# ---------------------------------------------------------------------
# 1. Sensors -> points -> 500 m buffers
# ---------------------------------------------------------------------
sensors <- read_csv(paste0(proc, "sensor_coverage_summary.csv")) |>
  filter(!is.na(latitude), !is.na(longitude))

sensors_sf <- sensors |>
  st_as_sf(coords = c("longitude", "latitude"), crs = crs_wgs) |>
  st_transform(crs_metric)

sensor_buffers <- st_buffer(sensors_sf, BUFFER_M)   # 500 m disc per sensor

# ---------------------------------------------------------------------
# 2. Point-level nightlife -> count inside each buffer

# ---------------------------------------------------------------------
read_points <- function(file) {
  read_csv(paste0(proc, file)) |>
    filter(!is.na(lat), !is.na(lon)) |>
    st_as_sf(coords = c("lon", "lat"), crs = crs_wgs) |>
    st_transform(crs_metric)
}

bars_sf  <- read_points("bars_clean.csv")  |> filter(year == 2024)
cafes_sf <- read_points("cafes_clean.csv") |> filter(year == 2024)

# a point can fall in several overlapping buffers -> that's fine, each sensor
# is its own unit, so it should be counted once per sensor it belongs to.
join_count <- function(points_sf, value) {
  st_join(points_sf, sensor_buffers["Device_id"], join = st_within) |>
    st_drop_geometry() |>
    filter(!is.na(Device_id)) |>
    group_by(Device_id) |>
    summarise(n = n(), total = sum(.data[[value]], na.rm = TRUE), .groups = "drop")
}

bar_hits  <- join_count(bars_sf,  "n_patrons") |> rename(n_bars = n,  bar_patrons = total)
cafe_hits <- join_count(cafes_sf, "n_seats")   |> rename(n_cafes = n, cafe_seats  = total)

# ---------------------------------------------------------------------
# 3. Assemble the pilot integrated table
# ---------------------------------------------------------------------
pilot <- sensors |>
  select(Device_id, SensorLocation, latitude, longitude,
         median_noise, mean_noise, valid_noise) |>
  left_join(bar_hits,  by = "Device_id") |>
  left_join(cafe_hits, by = "Device_id") |>
  mutate(across(c(n_bars, bar_patrons, n_cafes, cafe_seats), ~replace_na(., 0)))

write_csv(pilot, paste0(out, "pilot_sensor_integrated.csv"))


message(sprintf("Bars 2024 inside any buffer:  %d / %d",
                sum(bar_hits$n_bars),  nrow(bars_sf)))
message(sprintf("Cafés 2024 inside any buffer: %d / %d",
                sum(cafe_hits$n_cafes), nrow(cafes_sf)))
print(pilot)

# ---------------------------------------------------------------------
# 4. Block-level CLUE features — NEEDS BLOCK GEOMETRY
# ---------------------------------------------------------------------

block_xy <- bind_rows(
  read_csv(paste0(proc, "bars_clean.csv"))  |> select(block_id, lat, lon),
  read_csv(paste0(proc, "cafes_clean.csv")) |> select(block_id, lat, lon)
) |>
  filter(!is.na(lat), !is.na(lon)) |>
  group_by(block_id) |>
  summarise(lat = mean(lat), lon = mean(lon), .groups = "drop")

block_sf <- read_csv(paste0(proc, "block_nightlife_features_2024.csv")) |>
  left_join(block_xy, by = "block_id") |>
  filter(!is.na(lat), !is.na(lon)) |>
  st_as_sf(coords = c("lon", "lat"), crs = crs_wgs) |>
  st_transform(crs_metric)



# ---------------------------------------------------------------------
# 5. Population — STUB, fill in once you know the file's spatial unit
# ---------------------------------------------------------------------

