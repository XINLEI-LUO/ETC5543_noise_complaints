options(stringsAsFactors = FALSE, scipen = 999)

# Run from the project root:
#   Rscript analysis/build_sensor_integration.R

required_packages <- c("dplyr", "tidyr", "readr", "sf", "ggplot2")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop(
    "Required R packages are not installed: ", paste(missing_packages, collapse = ", "),
    ". Install them explicitly before running; this script does not modify the package environment."
  )
}

library(dplyr)
library(tidyr)
library(readr)
library(sf)
library(ggplot2)

processed_dir <- file.path("data", "processed")
raw_dir <- file.path("data", "raw")
reference_dir <- file.path("data", "reference")
figure_dir <- "figures"
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

crs_wgs84 <- 4326L
crs_mga55 <- 7855L
buffer_distances <- c(250L, 500L, 1000L)
feature_year <- 2024L

inputs <- c(
  noise = file.path(processed_dir, "noise_outcomes_for_integration.csv"),
  bars = file.path(raw_dir, "bars-and-pubs-with-patron-capacity.csv"),
  cafes = file.path(raw_dir, "cafes-and-restaurants-with-seating-capacity.csv")
)
missing_inputs <- inputs[!file.exists(inputs)]
if (length(missing_inputs)) {
  stop(
    "Required integration inputs are missing: ",
    paste(unname(missing_inputs), collapse = ", "),
    ". No urban feature values or integrated outputs were fabricated."
  )
}

assert_columns <- function(data, fields, source_name) {
  missing <- setdiff(fields, names(data))
  if (length(missing)) stop(source_name, " is missing required fields: ", paste(missing, collapse = ", "))
}

noise <- read_csv(inputs[["noise"]], show_col_types = FALSE)
assert_columns(noise, c("device_id", "longitude", "latitude"), "noise outcomes")
if (nrow(noise) != 11L || anyDuplicated(noise$device_id) || "aws5-0999" %in% noise$device_id) {
  stop("Noise outcomes must contain 11 unique usable sensors and exclude aws5-0999.")
}
if (any(!is.finite(noise$longitude) | !is.finite(noise$latitude)) ||
    any(noise$longitude < 144 | noise$longitude > 146 | noise$latitude < -39 | noise$latitude > -37)) {
  stop("Sensor coordinates are missing or outside the plausible Melbourne WGS84 range.")
}

sensors_wgs <- st_as_sf(noise, coords = c("longitude", "latitude"), crs = crs_wgs84, remove = FALSE)
sensors_mga <- st_transform(sensors_wgs, crs_mga55)
buffers <- lapply(buffer_distances, function(distance) {
  st_buffer(sensors_mga, distance) |>
    select(device_id) |>
    mutate(buffer_m = distance)
}) |>
  do.call(what = rbind)

bars_raw <- read_csv(inputs[["bars"]], show_col_types = FALSE)
cafes_raw <- read_csv(inputs[["cafes"]], show_col_types = FALSE)
assert_columns(bars_raw, c("Census year", "Block ID", "Trading name", "Number of patrons", "Latitude", "Longitude"), "bars")
assert_columns(cafes_raw, c("Census year", "Block ID", "Trading name", "Seating type", "Number of seats", "Latitude", "Longitude"), "cafes")

prepare_points <- function(data, source_name) {
  data |>
    mutate(
      source_row = row_number(),
      latitude = suppressWarnings(as.numeric(.data[["Latitude"]])),
      longitude = suppressWarnings(as.numeric(.data[["Longitude"]])),
      valid_coordinates = is.finite(latitude) & is.finite(longitude) &
        longitude >= 144 & longitude <= 146 & latitude >= -39 & latitude <= -37
    )
}

bars_stage <- prepare_points(bars_raw, "bars") |>
  filter(.data[["Census year"]] == feature_year) |>
  mutate(
    venue_id = paste(.data[["Block ID"]], trimws(.data[["Trading name"]]), latitude, longitude, sep = "|"),
    capacity = suppressWarnings(as.numeric(.data[["Number of patrons"]]))
  )
bars_unique <- bars_stage |> filter(valid_coordinates) |> distinct(venue_id, .keep_all = TRUE)

cafes_stage <- prepare_points(cafes_raw, "cafes") |>
  filter(.data[["Census year"]] == feature_year) |>
  mutate(
    venue_id = paste(.data[["Block ID"]], trimws(.data[["Trading name"]]), latitude, longitude, sep = "|"),
    seating_type = trimws(.data[["Seating type"]]),
    seats = suppressWarnings(as.numeric(.data[["Number of seats"]]))
  )
# Retain one record per venue and seating type; exact duplicate source rows do not inflate totals.
cafes_unique <- cafes_stage |>
  filter(valid_coordinates) |>
  distinct(venue_id, seating_type, seats, .keep_all = TRUE)

to_mga <- function(data) {
  st_as_sf(data, coords = c("longitude", "latitude"), crs = crs_wgs84, remove = FALSE) |>
    st_transform(crs_mga55)
}
bars_sf <- to_mga(bars_unique)
cafes_sf <- to_mga(cafes_unique)

bar_join <- st_join(buffers, bars_sf, join = st_contains, left = TRUE) |>
  st_drop_geometry() |>
  group_by(device_id, buffer_m) |>
  summarise(
    n_bars = n_distinct(venue_id, na.rm = TRUE),
    total_bar_capacity = if (all(is.na(venue_id))) 0 else if (all(is.na(capacity))) NA_real_ else sum(capacity, na.rm = TRUE),
    median_bar_capacity = if (all(is.na(capacity))) NA_real_ else median(capacity, na.rm = TRUE),
    bars_missing_capacity = sum(!is.na(venue_id) & is.na(capacity)),
    .groups = "drop"
  )

cafe_join <- st_join(buffers, cafes_sf, join = st_contains, left = TRUE) |>
  st_drop_geometry() |>
  group_by(device_id, buffer_m) |>
  summarise(
    n_cafes = n_distinct(venue_id, na.rm = TRUE),
    indoor_seats = if (all(is.na(venue_id))) 0 else if (all(is.na(seats[seating_type == "Seats - Indoor"]))) NA_real_ else sum(seats[seating_type == "Seats - Indoor"], na.rm = TRUE),
    outdoor_seats = if (all(is.na(venue_id))) 0 else if (all(is.na(seats[seating_type == "Seats - Outdoor"]))) NA_real_ else sum(seats[seating_type == "Seats - Outdoor"], na.rm = TRUE),
    cafes_missing_seats = sum(!is.na(venue_id) & is.na(seats)),
    .groups = "drop"
  )

base_grid <- tidyr::crossing(device_id = noise$device_id, buffer_m = buffer_distances)
integrated <- base_grid |>
  left_join(noise, by = "device_id") |>
  left_join(bar_join, by = c("device_id", "buffer_m")) |>
  left_join(cafe_join, by = c("device_id", "buffer_m")) |>
  mutate(
    feature_data_year = feature_year,
    join_status = "bars_and_cafes_joined",
    notes = if_else(bars_missing_capacity > 0 | cafes_missing_seats > 0, "Matched venues include missing capacity/seating", NA_character_)
  ) |>
  select(
    device_id, buffer_m, sensor_location, longitude, latitude,
    overall_median_noise, daytime_median_noise, nighttime_median_noise,
    weekday_median_noise, weekend_median_noise,
    n_overall_noise, n_daytime_noise, n_nighttime_noise, n_weekday_noise, n_weekend_noise,
    first_observation, last_observation, coverage_days, coverage_ratio, n_zero_noise,
    n_bars, total_bar_capacity, median_bar_capacity, n_cafes, indoor_seats, outdoor_seats,
    feature_data_year, join_status, notes
  )

write_csv(integrated, file.path(processed_dir, "integrated_sensor_all_buffers.csv"), na = "")
for (distance in buffer_distances) {
  write_csv(
    filter(integrated, buffer_m == distance),
    file.path(processed_dir, paste0("integrated_sensor_", distance, "m.csv")),
    na = ""
  )
}

inside_any <- function(points, buffer_layer) lengths(st_intersects(points, st_union(buffer_layer))) > 0
# Count unique intersecting pairs belonging to different sensors. Nested buffers
# around the same sensor are not treated as between-sensor overlap.
intersection_matrix <- st_intersects(buffers, sparse = FALSE)
different_sensor <- outer(buffers$device_id, buffers$device_id, `!=`)
overlap_n <- sum(intersection_matrix & different_sensor & upper.tri(intersection_matrix))
diagnostics <- bind_rows(
  tibble(
    source_dataset = c("bars", "cafes"), source_data_year = feature_year,
    original_rows = c(nrow(bars_raw), nrow(cafes_raw)),
    selected_year_rows = c(nrow(bars_stage), nrow(cafes_stage)),
    unique_venues = c(n_distinct(bars_unique$venue_id), n_distinct(cafes_unique$venue_id)),
    valid_coordinates = c(nrow(bars_unique), n_distinct(cafes_unique$venue_id)),
    invalid_or_missing_coordinates = c(sum(!bars_stage$valid_coordinates), sum(!cafes_stage$valid_coordinates)),
    inside_at_least_one_buffer = c(sum(inside_any(bars_sf, buffers)), n_distinct(cafes_unique$venue_id[inside_any(cafes_sf, buffers)])),
    missing_capacity_or_seating = c(sum(is.na(bars_unique$capacity)), sum(is.na(cafes_unique$seats))),
    crs_before = "EPSG:4326", crs_after = "EPSG:7855",
    coordinate_order_issue = FALSE, join_failure = FALSE
  ) |>
    mutate(
      outside_all_buffers = valid_coordinates - inside_at_least_one_buffer,
      percentage_matched = 100 * inside_at_least_one_buffer / valid_coordinates,
      overlapping_sensor_buffer_polygon_pairs = overlap_n
    ),
  integrated |>
    group_by(buffer_m) |>
    summarise(
      source_dataset = "sensor_buffer_summary", source_data_year = feature_year,
      sensors_zero_bars = sum(n_bars == 0, na.rm = TRUE),
      sensors_zero_cafes = sum(n_cafes == 0, na.rm = TRUE), .groups = "drop"
    )
)
write_csv(diagnostics, file.path(processed_dir, "integration_join_diagnostics.csv"), na = "")

boundary_path <- file.path(reference_dir, "melbourne_municipal_boundary.geojson")
boundary <- if (file.exists(boundary_path)) st_transform(st_read(boundary_path, quiet = TRUE), crs_mga55) else NULL
map_data <- buffers
p <- ggplot() +
  {if (!is.null(boundary)) geom_sf(data = boundary, fill = "grey97", colour = "grey55", linewidth = 0.3)} +
  geom_sf(data = map_data, aes(colour = factor(buffer_m)), fill = NA, linewidth = 0.55) +
  geom_sf(data = bars_sf, aes(shape = "Bars/pubs"), colour = "#B2182B", alpha = 0.60, size = 0.75) +
  geom_sf(data = cafes_sf, aes(shape = "Cafes/restaurants"), colour = "#2166AC", alpha = 0.45, size = 0.60) +
  geom_sf(data = sensors_mga, aes(shape = "Noise sensors"), colour = "black", size = 2.2, stroke = 0.8) +
  facet_wrap(~buffer_m) +
  scale_colour_brewer(palette = "Dark2", name = "Buffer (m)") +
  scale_shape_manual(values = c("Bars/pubs" = 16, "Cafes/restaurants" = 16, "Noise sensors" = 4), name = "Mapped features") +
  labs(
    title = "Noise sensor buffers and 2024 urban activity",
    subtitle = "Monitored locations only; 500 m is the primary analysis distance",
    caption = "Projected in GDA2020 / MGA Zone 55 (EPSG:7855)"
  ) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom") +
  guides(
    colour = guide_legend(order = 1),
    shape = guide_legend(order = 2, override.aes = list(colour = c("#B2182B", "#2166AC", "black"), alpha = 1))
  )
ggsave(file.path(figure_dir, "sensor_buffer_integration_map.png"), p, width = 12, height = 7.5, dpi = 220)

message("Sensor integration outputs created successfully in data/processed and figures/.")
