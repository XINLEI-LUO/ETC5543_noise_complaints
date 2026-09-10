options(stringsAsFactors = FALSE, scipen = 999)

project_library <- normalizePath(".r-library", winslash = "/", mustWork = FALSE)
if (dir.exists(project_library)) .libPaths(c(project_library, .libPaths()))

# Purpose: prepare 2024 CLUE business-environment features for the validated
# noise-sensor buffers without altering any existing integrated output.
# Run from the project root:
#   Rscript analysis/prepare_clue_business_features.R

required_packages <- c("dplyr", "tidyr", "readr", "sf")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Required R packages are not installed: ", paste(missing_packages, collapse = ", "))
}

library(dplyr)
library(tidyr)
library(readr)
library(sf)

raw_path <- file.path("data", "raw", "business-establishments-with-address-and-industry-classification.csv")
sensor_path <- file.path("data", "processed", "noise_sensor_locations.csv")
existing_path <- file.path("data", "processed", "integrated_sensor_all_buffers.csv")
processed_dir <- file.path("data", "processed")
feature_year <- 2024L
buffer_distances <- c(250L, 500L, 1000L)
crs_wgs84 <- 4326L
crs_mga55 <- 7855L
anzsic_division_count <- 19L

required_inputs <- c(raw_path, sensor_path, existing_path)
if (any(!file.exists(required_inputs))) {
  stop("Missing required input(s): ", paste(required_inputs[!file.exists(required_inputs)], collapse = ", "))
}

assert_columns <- function(data, fields, source_name) {
  missing <- setdiff(fields, names(data))
  if (length(missing)) stop(source_name, " is missing required fields: ", paste(missing, collapse = ", "))
}

business_raw <- read_csv(raw_path, show_col_types = FALSE)
sensors <- read_csv(sensor_path, show_col_types = FALSE)
existing <- read_csv(existing_path, show_col_types = FALSE)

business_fields <- c(
  "Census year", "Block ID", "Property ID", "Base property ID", "CLUE small area",
  "Trading name", "Business address", "Industry (ANZSIC4) code",
  "Industry (ANZSIC4) description", "Longitude", "Latitude", "Point"
)
assert_columns(business_raw, business_fields, "CLUE business data")
assert_columns(sensors, c("device_id", "longitude", "latitude"), "noise sensor locations")
assert_columns(existing, c("device_id", "buffer_m"), "existing integrated data")

if (nrow(sensors) != 11L || anyDuplicated(sensors$device_id)) stop("Expected 11 unique validated noise sensors.")
if (nrow(existing) != 33L || anyDuplicated(existing[c("device_id", "buffer_m")])) {
  stop("Existing integration must contain 33 unique device_id + buffer_m rows.")
}

division_from_code <- function(code) {
  division <- suppressWarnings(as.integer(code) %/% 100L)
  case_when(
    division >= 1L & division <= 5L ~ "A_Agriculture_Forestry_Fishing",
    division >= 6L & division <= 10L ~ "B_Mining",
    division >= 11L & division <= 25L ~ "C_Manufacturing",
    division == 26L ~ "D_Electricity_Gas_Water_Waste",
    division >= 27L & division <= 29L ~ "E_Construction",
    division >= 30L & division <= 38L ~ "F_Wholesale_Trade",
    division >= 39L & division <= 43L ~ "G_Retail_Trade",
    division >= 44L & division <= 45L ~ "H_Accommodation_Food_Services",
    division >= 46L & division <= 53L ~ "I_Transport_Postal_Warehousing",
    division >= 54L & division <= 60L ~ "J_Information_Media_Telecommunications",
    division >= 62L & division <= 64L ~ "K_Financial_Insurance_Services",
    division >= 66L & division <= 67L ~ "L_Rental_Hiring_Real_Estate",
    division >= 69L & division <= 70L ~ "M_Professional_Scientific_Technical",
    division >= 72L & division <= 73L ~ "N_Administrative_Support",
    division >= 75L & division <= 77L ~ "O_Public_Administration_Safety",
    division >= 80L & division <= 82L ~ "P_Education_Training",
    division >= 84L & division <= 87L ~ "Q_Health_Care_Social_Assistance",
    division >= 89L & division <= 92L ~ "R_Arts_Recreation_Services",
    division >= 94L & division <= 96L ~ "S_Other_Services",
    TRUE ~ NA_character_
  )
}

business_2024 <- business_raw |>
  filter(.data[["Census year"]] == feature_year) |>
  mutate(
    source_row = row_number(),
    anzsic4_code = suppressWarnings(as.integer(.data[["Industry (ANZSIC4) code"]])),
    longitude = suppressWarnings(as.numeric(.data[["Longitude"]])),
    latitude = suppressWarnings(as.numeric(.data[["Latitude"]])),
    valid_coordinates = is.finite(longitude) & is.finite(latitude) &
      longitude >= 144 & longitude <= 146 & latitude >= -39 & latitude <= -37,
    is_vacant = anzsic4_code == 0L | .data[["Industry (ANZSIC4) description"]] == "Vacant Space",
    anzsic_division = if_else(is_vacant, NA_character_, division_from_code(anzsic4_code)),
    duplicate_candidate_key = paste(
      trimws(.data[["Trading name"]]), trimws(.data[["Business address"]]), anzsic4_code,
      format(longitude, digits = 15), format(latitude, digits = 15), sep = "|"
    )
  )

if (nrow(business_2024) == 0L) stop("No 2024 CLUE business records were found.")
if (any(!business_2024$valid_coordinates)) stop("One or more 2024 CLUE records lack plausible WGS84 coordinates.")
if (any(!business_2024$is_vacant & is.na(business_2024$anzsic_division))) {
  stop("One or more active 2024 records could not be assigned to an ANZSIC division.")
}

sensors_mga <- st_as_sf(sensors, coords = c("longitude", "latitude"), crs = crs_wgs84, remove = FALSE) |>
  st_transform(crs_mga55)
buffers <- bind_rows(lapply(buffer_distances, function(distance) {
  st_buffer(sensors_mga, distance) |>
    select(device_id) |>
    mutate(buffer_m = distance)
}))

business_sf <- st_as_sf(business_2024, coords = c("longitude", "latitude"), crs = crs_wgs84, remove = FALSE) |>
  st_transform(crs_mga55)

entropy_value <- function(categories) {
  counts <- table(categories)
  if (!length(counts)) return(0)
  proportions <- as.numeric(counts) / sum(counts)
  -sum(proportions * log(proportions))
}

summarise_join <- function(points_sf, sensitivity = FALSE) {
  joined <- st_join(buffers, points_sf, join = st_contains, left = TRUE) |>
    st_drop_geometry()

  joined |>
    group_by(device_id, buffer_m) |>
    summarise(
      total_records = sum(!is.na(source_row)),
      total_active_businesses = sum(!is.na(source_row) & !is_vacant),
      vacant_spaces = sum(!is.na(source_row) & is_vacant),
      cafes_restaurants = sum(anzsic4_code == 4511L, na.rm = TRUE),
      takeaway_food = sum(anzsic4_code == 4512L, na.rm = TRUE),
      pubs_bars_clue = sum(anzsic4_code == 4520L, na.rm = TRUE),
      other_food_beverage = sum(anzsic4_code >= 4500L & anzsic4_code <= 4599L &
                                  !anzsic4_code %in% c(4511L, 4512L, 4520L), na.rm = TRUE),
      retail_businesses = sum(anzsic4_code %/% 100L >= 39L & anzsic4_code %/% 100L <= 43L, na.rm = TRUE),
      accommodation_businesses = sum(anzsic4_code == 4400L, na.rm = TRUE),
      entertainment_recreation_businesses = sum(anzsic4_code %/% 100L >= 89L & anzsic4_code %/% 100L <= 92L, na.rm = TRUE),
      professional_scientific_technical_businesses = sum(anzsic4_code %/% 100L >= 69L & anzsic4_code %/% 100L <= 70L, na.rm = TRUE),
      financial_insurance_businesses = sum(anzsic4_code %/% 100L >= 62L & anzsic4_code %/% 100L <= 64L, na.rm = TRUE),
      rental_real_estate_businesses = sum(anzsic4_code %/% 100L >= 66L & anzsic4_code %/% 100L <= 67L, na.rm = TRUE),
      administrative_support_businesses = sum(anzsic4_code %/% 100L >= 72L & anzsic4_code %/% 100L <= 73L, na.rm = TRUE),
      business_mix_entropy = entropy_value(anzsic_division[!is_vacant & !is.na(source_row)]),
      .groups = "drop"
    ) |>
    mutate(
      buffer_area_km2 = pi * (buffer_m / 1000)^2,
      business_density_per_km2 = total_active_businesses / buffer_area_km2,
      vacancy_share = if_else(total_records == 0L, 0, vacant_spaces / total_records),
      business_mix_entropy_normalised = business_mix_entropy / log(anzsic_division_count),
      zero_business_buffer = total_active_businesses == 0L,
      low_business_count_flag = total_active_businesses < 10L,
      duplicate_treatment = if (sensitivity) "one_record_per_name_address_anzsic_coordinate" else "source_records_retained"
    )
}

features_main <- summarise_join(business_sf, sensitivity = FALSE) |>
  mutate(feature_data_year = feature_year, feature_source = basename(raw_path))

# Sensitivity only: retain one row per name/address/ANZSIC/coordinate key.
business_sensitivity <- business_2024 |>
  distinct(duplicate_candidate_key, .keep_all = TRUE)
business_sensitivity_sf <- st_as_sf(
  business_sensitivity, coords = c("longitude", "latitude"), crs = crs_wgs84, remove = FALSE
) |>
  st_transform(crs_mga55)
features_sensitivity <- summarise_join(business_sensitivity_sf, sensitivity = TRUE)

sensitivity_comparison <- features_main |>
  select(device_id, buffer_m, main_total_active_businesses = total_active_businesses,
         main_business_mix_entropy_normalised = business_mix_entropy_normalised) |>
  left_join(
    features_sensitivity |>
      select(device_id, buffer_m, sensitivity_total_active_businesses = total_active_businesses,
             sensitivity_business_mix_entropy_normalised = business_mix_entropy_normalised),
    by = c("device_id", "buffer_m")
  ) |>
  mutate(
    active_business_absolute_difference = abs(main_total_active_businesses - sensitivity_total_active_businesses),
    entropy_absolute_difference = abs(main_business_mix_entropy_normalised - sensitivity_business_mix_entropy_normalised)
  )

integrated_with_clue <- existing |>
  left_join(features_main, by = c("device_id", "buffer_m"))
if (nrow(integrated_with_clue) != nrow(existing) || anyDuplicated(integrated_with_clue[c("device_id", "buffer_m")])) {
  stop("CLUE join changed the validated sensor-buffer key structure.")
}

count_fields <- c(
  "total_records", "total_active_businesses", "vacant_spaces", "cafes_restaurants",
  "takeaway_food", "pubs_bars_clue", "other_food_beverage", "retail_businesses",
  "accommodation_businesses", "entertainment_recreation_businesses",
  "professional_scientific_technical_businesses", "financial_insurance_businesses",
  "rental_real_estate_businesses", "administrative_support_businesses"
)

monotonic_failures <- character()
for (field in count_fields) for (id in unique(features_main$device_id)) {
  values <- features_main |>
    filter(device_id == id) |>
    arrange(buffer_m) |>
    pull(all_of(field))
  if (any(diff(values) < 0)) monotonic_failures <- c(monotonic_failures, paste(id, field, sep = ":"))
}

duplicate_sizes <- table(business_2024$duplicate_candidate_key)
qa <- tibble(
  check = c(
    "source_2024_rows", "source_2024_active_records", "source_2024_vacant_records",
    "source_2024_valid_coordinates", "source_2024_full_row_duplicates",
    "source_2024_candidate_duplicate_groups", "source_2024_candidate_duplicate_excess_rows",
    "sensor_buffer_rows", "unique_device_buffer_keys", "expected_buffer_distances",
    "eleven_sensors_per_buffer", "nonnegative_integer_counts", "count_monotonicity",
    "entropy_range", "density_nonnegative", "join_preserves_existing_rows",
    "sensitivity_max_active_count_difference", "sensitivity_max_entropy_difference"
  ),
  status = c(
    nrow(business_2024) == 19672L,
    sum(!business_2024$is_vacant) == 14337L,
    sum(business_2024$is_vacant) == 5335L,
    sum(business_2024$valid_coordinates) == nrow(business_2024),
    sum(duplicated(business_2024[business_fields])) == 0L,
    sum(duplicate_sizes > 1L) == 1L,
    sum(pmax(as.integer(duplicate_sizes) - 1L, 0L)) == 2L,
    nrow(features_main) == 33L,
    !anyDuplicated(features_main[c("device_id", "buffer_m")]),
    setequal(features_main$buffer_m, buffer_distances),
    all(table(features_main$buffer_m) == 11L),
    all(vapply(features_main[count_fields], function(x) all(is.finite(x) & x >= 0 & x == floor(x)), logical(1))),
    length(monotonic_failures) == 0L,
    all(features_main$business_mix_entropy_normalised >= 0 & features_main$business_mix_entropy_normalised <= 1),
    all(is.finite(features_main$business_density_per_km2) & features_main$business_density_per_km2 >= 0),
    nrow(integrated_with_clue) == nrow(existing),
    max(sensitivity_comparison$active_business_absolute_difference) >= 0,
    max(sensitivity_comparison$entropy_absolute_difference) >= 0
  ),
  evidence = c(
    as.character(nrow(business_2024)),
    as.character(sum(!business_2024$is_vacant)),
    as.character(sum(business_2024$is_vacant)),
    as.character(sum(business_2024$valid_coordinates)),
    as.character(sum(duplicated(business_2024[business_fields]))),
    as.character(sum(duplicate_sizes > 1L)),
    as.character(sum(pmax(as.integer(duplicate_sizes) - 1L, 0L))),
    as.character(nrow(features_main)),
    as.character(sum(duplicated(features_main[c("device_id", "buffer_m")]))),
    paste(sort(unique(features_main$buffer_m)), collapse = ","),
    paste(names(table(features_main$buffer_m)), table(features_main$buffer_m), sep = ":", collapse = ";"),
    "All feature counts are non-negative integers",
    if (length(monotonic_failures)) paste(monotonic_failures, collapse = ";") else "No failures",
    sprintf("%.6f to %.6f", min(features_main$business_mix_entropy_normalised), max(features_main$business_mix_entropy_normalised)),
    sprintf("%.3f to %.3f", min(features_main$business_density_per_km2), max(features_main$business_density_per_km2)),
    paste(nrow(existing), "before and", nrow(integrated_with_clue), "after"),
    as.character(max(sensitivity_comparison$active_business_absolute_difference)),
    format(max(sensitivity_comparison$entropy_absolute_difference), digits = 8)
  )
) |>
  mutate(status = if_else(status, "PASS", "FAIL"))

write_csv(features_main, file.path(processed_dir, "clue_business_features_by_buffer.csv"), na = "")
write_csv(sensitivity_comparison, file.path(processed_dir, "clue_business_duplicate_sensitivity.csv"), na = "")
write_csv(integrated_with_clue, file.path(processed_dir, "integrated_sensor_all_buffers_with_clue_2024.csv"), na = "")
write_csv(qa, file.path(processed_dir, "clue_business_integration_qa.csv"), na = "")

if (any(qa$status == "FAIL")) stop("CLUE business preparation completed with failed QA checks.")
message("CLUE business features created: 33 unique sensor-buffer rows; all automated QA checks passed.")
