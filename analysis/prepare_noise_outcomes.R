options(stringsAsFactors = FALSE, scipen = 999)

# Prepare integration-ready noise outcomes from the existing microclimate data.
# Run from the project root with:
#   Rscript analysis/prepare_noise_outcomes.R

raw_path <- "data/raw/microclimate_sensors.csv"
processed_dir <- "data/processed"
melbourne_tz <- "Australia/Melbourne"
expected_hourly_obs <- 4L
expected_daily_obs <- 96L

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

message("Reading raw sensor data...")
noise_raw <- read.csv(
  raw_path,
  check.names = FALSE,
  na.strings = c("", "NA", "null")
)
names(noise_raw)[1] <- sub("^\\ufeff|^\\xef\\xbb\\xbf", "", names(noise_raw)[1])

required_fields <- c("Device_id", "Time", "SensorLocation", "LatLong", "Noise")
missing_fields <- setdiff(required_fields, names(noise_raw))
if (length(missing_fields) > 0L) {
  stop("Required raw fields are missing: ", paste(missing_fields, collapse = ", "))
}

# Reuse the parsing rules established in analysis/noise_eda.R.
time_normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", noise_raw$Time)
noise_raw$timestamp <- as.POSIXct(
  time_normalized,
  format = "%Y-%m-%dT%H:%M:%S%z",
  tz = melbourne_tz
)

latlong_parts <- strsplit(as.character(noise_raw$LatLong), ",", fixed = TRUE)
noise_raw$latitude <- suppressWarnings(as.numeric(vapply(
  latlong_parts,
  function(x) if (length(x) >= 1L) trimws(x[1L]) else NA_character_,
  character(1)
)))
noise_raw$longitude <- suppressWarnings(as.numeric(vapply(
  latlong_parts,
  function(x) if (length(x) >= 2L) trimws(x[2L]) else NA_character_,
  character(1)
)))
noise_raw$Noise <- suppressWarnings(as.numeric(noise_raw$Noise))
noise_raw$valid_noise <- is.finite(noise_raw$Noise)

if (any(is.na(noise_raw$Device_id) | !nzchar(trimws(noise_raw$Device_id)))) {
  stop("Missing device IDs are present; review the raw data before aggregation.")
}

safe_min_time <- function(x) {
  x <- x[!is.na(x)]
  if (length(x)) min(x) else as.POSIXct(NA, tz = melbourne_tz)
}

safe_max_time <- function(x) {
  x <- x[!is.na(x)]
  if (length(x)) max(x) else as.POSIXct(NA, tz = melbourne_tz)
}

collapse_values <- function(x) {
  x <- unique(trimws(as.character(x[!is.na(x)])))
  x <- x[nzchar(x)]
  paste(sort(x), collapse = " / ")
}

format_timestamp <- function(x) {
  format(x, "%Y-%m-%dT%H:%M:%S%z", tz = melbourne_tz)
}

sensor_indices <- split(seq_len(nrow(noise_raw)), noise_raw$Device_id)

sensor_audit <- do.call(rbind, lapply(names(sensor_indices), function(device_id) {
  z <- noise_raw[sensor_indices[[device_id]], , drop = FALSE]
  valid_n <- sum(z$valid_noise)
  coordinate_pairs <- unique(z[c("latitude", "longitude")])
  coordinate_pairs <- coordinate_pairs[complete.cases(coordinate_pairs), , drop = FALSE]
  location_labels <- unique(trimws(as.character(z$SensorLocation)))
  location_labels <- location_labels[!is.na(location_labels) & nzchar(location_labels)]

  data.frame(
    device_id = device_id,
    sensor_location = collapse_values(z$SensorLocation),
    latitude = if (nrow(coordinate_pairs) == 1L) coordinate_pairs$latitude else NA_real_,
    longitude = if (nrow(coordinate_pairs) == 1L) coordinate_pairs$longitude else NA_real_,
    first_observation = format_timestamp(safe_min_time(z$timestamp)),
    last_observation = format_timestamp(safe_max_time(z$timestamp)),
    n_total_observations = nrow(z),
    n_valid_noise = valid_n,
    n_missing_noise = nrow(z) - valid_n,
    pct_missing_noise = 100 * (nrow(z) - valid_n) / nrow(z),
    n_missing_coordinate_rows = sum(is.na(z$latitude) | is.na(z$longitude)),
    n_coordinate_pairs = nrow(coordinate_pairs),
    n_location_labels = length(location_labels),
    is_usable_noise_sensor = valid_n > 0L,
    exclusion_reason = if (valid_n > 0L) NA_character_ else "No valid Noise observations",
    stringsAsFactors = FALSE
  )
}))
rownames(sensor_audit) <- NULL
sensor_audit <- sensor_audit[order(sensor_audit$device_id), ]

usable_ids <- sensor_audit$device_id[sensor_audit$is_usable_noise_sensor]
noise_data <- noise_raw[noise_raw$Device_id %in% usable_ids & !is.na(noise_raw$timestamp), , drop = FALSE]

sensor_locations <- sensor_audit[
  sensor_audit$is_usable_noise_sensor,
  c(
    "device_id", "sensor_location", "latitude", "longitude",
    "first_observation", "last_observation", "n_total_observations",
    "n_valid_noise", "n_missing_noise", "pct_missing_noise"
  )
]

# UTC-aligned elapsed-hour keys preserve repeated local clock hours at daylight-
# saving transitions; the formatted timestamp includes its UTC offset.
noise_data$hour_epoch <- floor(as.numeric(noise_data$timestamp) / 3600) * 3600
noise_data$hour_timestamp <- as.POSIXct(noise_data$hour_epoch, origin = "1970-01-01", tz = melbourne_tz)
noise_data$date <- as.Date(noise_data$timestamp, tz = melbourne_tz)

summarise_groups <- function(data, group_key, expected_obs) {
  group_indices <- split(seq_len(nrow(data)), group_key)

  do.call(rbind, lapply(group_indices, function(idx) {
    values <- data$Noise[idx]
    valid_values <- values[is.finite(values)]
    valid_n <- length(valid_values)
    total_n <- length(values)
    unique_timestamp_n <- length(unique(data$timestamp[idx]))
    unique_valid_timestamp_n <- length(unique(data$timestamp[idx][is.finite(values)]))

    data.frame(
      noise_mean = if (valid_n) mean(valid_values) else NA_real_,
      noise_median = if (valid_n) median(valid_values) else NA_real_,
      noise_min = if (valid_n) min(valid_values) else NA_real_,
      noise_max = if (valid_n) max(valid_values) else NA_real_,
      noise_sd = if (valid_n > 1L) sd(valid_values) else NA_real_,
      n_observations = total_n,
      n_valid_noise = valid_n,
      n_missing_noise = total_n - valid_n,
      n_unique_timestamps = unique_timestamp_n,
      n_unique_valid_timestamps = unique_valid_timestamp_n,
      n_zero_noise = sum(valid_values == 0),
      expected_obs = expected_obs,
      coverage_ratio = valid_n / expected_obs,
      unique_coverage_ratio = unique_valid_timestamp_n / expected_obs,
      is_complete = unique_valid_timestamp_n >= expected_obs,
      stringsAsFactors = FALSE
    )
  }))
}

message("Aggregating sensor-hour outcomes...")
hour_key <- paste(noise_data$Device_id, noise_data$hour_epoch, sep = "\r")
hour_indices <- split(seq_len(nrow(noise_data)), hour_key)
hour_first <- vapply(hour_indices, `[`, integer(1), 1L)
hour_summary <- summarise_groups(noise_data, hour_key, expected_hourly_obs)
hour_meta <- noise_data[hour_first, c("Device_id", "hour_timestamp"), drop = FALSE]

noise_sensor_hour <- cbind(
  data.frame(
    device_id = hour_meta$Device_id,
    hourly_timestamp = format_timestamp(hour_meta$hour_timestamp),
    date = format(as.Date(hour_meta$hour_timestamp, tz = melbourne_tz), "%Y-%m-%d"),
    year = as.integer(format(hour_meta$hour_timestamp, "%Y", tz = melbourne_tz)),
    month = as.integer(format(hour_meta$hour_timestamp, "%m", tz = melbourne_tz)),
    day = as.integer(format(hour_meta$hour_timestamp, "%d", tz = melbourne_tz)),
    hour = as.integer(format(hour_meta$hour_timestamp, "%H", tz = melbourne_tz)),
    weekday = weekdays(hour_meta$hour_timestamp),
    is_weekend = as.integer(format(hour_meta$hour_timestamp, "%u", tz = melbourne_tz)) >= 6L,
    stringsAsFactors = FALSE
  ),
  hour_summary
)
names(noise_sensor_hour)[names(noise_sensor_hour) == "is_complete"] <- "is_complete_hour"
noise_sensor_hour <- merge(
  noise_sensor_hour,
  sensor_locations[c("device_id", "sensor_location", "latitude", "longitude")],
  by = "device_id",
  all.x = TRUE,
  sort = FALSE
)
noise_sensor_hour <- noise_sensor_hour[order(noise_sensor_hour$device_id, noise_sensor_hour$hourly_timestamp), ]

message("Aggregating sensor-day outcomes...")
day_key <- paste(noise_data$Device_id, noise_data$date, sep = "\r")
day_indices <- split(seq_len(nrow(noise_data)), day_key)
day_first <- vapply(day_indices, `[`, integer(1), 1L)
day_summary <- summarise_groups(noise_data, day_key, expected_daily_obs)
day_meta <- noise_data[day_first, c("Device_id", "date"), drop = FALSE]

noise_sensor_day <- cbind(
  data.frame(
    device_id = day_meta$Device_id,
    date = format(day_meta$date, "%Y-%m-%d"),
    year = as.integer(format(day_meta$date, "%Y")),
    month = as.integer(format(day_meta$date, "%m")),
    weekday = weekdays(day_meta$date),
    is_weekend = as.integer(format(day_meta$date, "%u")) >= 6L,
    stringsAsFactors = FALSE
  ),
  day_summary
)
names(noise_sensor_day)[names(noise_sensor_day) == "is_complete"] <- "is_complete_day"
noise_sensor_day <- merge(
  noise_sensor_day,
  sensor_locations[c("device_id", "sensor_location", "latitude", "longitude")],
  by = "device_id",
  all.x = TRUE,
  sort = FALSE
)
noise_sensor_day <- noise_sensor_day[order(noise_sensor_day$device_id, noise_sensor_day$date), ]

# Validation: flag questionable records rather than silently changing them.
raw_duplicate_keys <- duplicated(noise_raw[c("Device_id", "Time")]) |
  duplicated(noise_raw[c("Device_id", "Time")], fromLast = TRUE)
raw_duplicate_excess <- sum(duplicated(noise_raw[c("Device_id", "Time")]))
raw_duplicate_groups <- length(unique(paste(
  noise_raw$Device_id[raw_duplicate_keys],
  noise_raw$Time[raw_duplicate_keys],
  sep = "\r"
)))
hour_duplicate_keys <- duplicated(noise_sensor_hour[c("device_id", "hourly_timestamp")])
day_duplicate_keys <- duplicated(noise_sensor_day[c("device_id", "date")])
malformed_timestamp_n <- sum(is.na(noise_raw$timestamp))
usable_missing_coordinates <- sensor_locations$device_id[
  is.na(sensor_locations$latitude) | is.na(sensor_locations$longitude)
]
coordinate_issue_ids <- sensor_audit$device_id[sensor_audit$n_coordinate_pairs != 1L]

location_devices <- split(sensor_audit$device_id, sensor_audit$sensor_location)
shared_location_labels <- names(location_devices)[vapply(location_devices, length, integer(1)) > 1L]

timestamp_gaps <- unlist(lapply(sensor_indices, function(idx) {
  times <- sort(unique(noise_raw$timestamp[idx]))
  as.numeric(diff(times), units = "mins")
}), use.names = FALSE)
timestamp_gaps <- timestamp_gaps[is.finite(timestamp_gaps) & timestamp_gaps > 0]
median_gap_minutes <- median(timestamp_gaps)
pct_near_15_minutes <- 100 * mean(timestamp_gaps >= 12 & timestamp_gaps <= 18)

write.csv(sensor_audit, file.path(processed_dir, "noise_sensor_audit.csv"), row.names = FALSE, na = "")
write.csv(sensor_locations, file.path(processed_dir, "noise_sensor_locations.csv"), row.names = FALSE, na = "")
write.csv(noise_sensor_hour, file.path(processed_dir, "noise_sensor_hour.csv"), row.names = FALSE, na = "")
write.csv(noise_sensor_day, file.path(processed_dir, "noise_sensor_day.csv"), row.names = FALSE, na = "")

complete_hour_pct <- 100 * mean(noise_sensor_hour$is_complete_hour)
complete_day_pct <- 100 * mean(noise_sensor_day$is_complete_day)

message("Noise outcome preparation complete.")
message("Raw devices: ", nrow(sensor_audit), "; usable noise sensors: ", length(usable_ids))
message("Rows written - locations: ", nrow(sensor_locations),
        "; sensor-hour: ", nrow(noise_sensor_hour),
        "; sensor-day: ", nrow(noise_sensor_day))
message("Outcome date range: ", min(noise_sensor_day$date), " to ", max(noise_sensor_day$date))
message(sprintf("Complete sensor-hours: %.2f%%; incomplete: %.2f%%", complete_hour_pct, 100 - complete_hour_pct))
message(sprintf("Complete sensor-days: %.2f%%; incomplete: %.2f%%", complete_day_pct, 100 - complete_day_pct))
message("Duplicate raw device/timestamp rows: ", sum(raw_duplicate_keys))
message("Duplicate sensor-hour keys: ", sum(hour_duplicate_keys),
        "; duplicate sensor-day keys: ", sum(day_duplicate_keys))
message("Malformed timestamps: ", malformed_timestamp_n)
message("Raw duplicate device/timestamp groups: ", raw_duplicate_groups,
        "; excess rows beyond one per key: ", raw_duplicate_excess,
        " (retained and flagged, not silently removed)")
message("Coverage ratios above 1 - sensor-hours: ", sum(noise_sensor_hour$coverage_ratio > 1),
        "; sensor-days: ", sum(noise_sensor_day$coverage_ratio > 1))
message("Usable sensors with missing coordinates: ",
        if (length(usable_missing_coordinates)) paste(usable_missing_coordinates, collapse = ", ") else "none")
message("Sensors without exactly one coordinate pair: ",
        if (length(coordinate_issue_ids)) paste(coordinate_issue_ids, collapse = ", ") else "none")
message("Shared location labels: ",
        if (length(shared_location_labels)) paste(shared_location_labels, collapse = " | ") else "none")
message(sprintf("Median positive timestamp gap: %.2f minutes; gaps within 12-18 minutes: %.2f%%",
                median_gap_minutes, pct_near_15_minutes))
