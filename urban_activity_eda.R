library(tidyverse)
library(sf)
library(leaflet)

data_path <- "data/raw/"
fig_path  <- "figures/"
dir.create(fig_path, showWarnings = FALSE)

bars <- read_csv(paste0(data_path, "bars-and-pubs-with-patron-capacity.csv"))
cafes <- read_csv(paste0(data_path, "cafes-and-restaurants-with-seating-capacity.csv"))
biz_block <- read_csv(paste0(data_path, "business-establishments-per-block-by-anzsic.csv"))
floor_space <- read_csv(paste0(data_path, "floor-space-by-block-by-anzsic.csv"))
ped_sensors <- read_csv(paste0(data_path, "pedestrian-counting-system-sensor-locations.csv"))

glimpse(bars)
glimpse(cafes)
glimpse(biz_block)

# FIGURE 1: Top 10 small areas by number of bars/pubs (2024)
bars_2024 <- bars |>
  filter(`Census year` == 2024) |>
  group_by(`CLUE small area`) |>
  summarise(n_venues = n(), total_capacity = sum(`Number of patrons`, na.rm = TRUE)) |>
  arrange(desc(n_venues)) |>
  slice_head(n = 10)

fig1 <- ggplot(bars_2024, aes(x = reorder(`CLUE small area`, n_venues), y = n_venues)) +
  geom_col(fill = "#2166ac") +
  coord_flip() +
  labs(
    title = "Top 10 Areas by Number of Bars & Pubs (2024)",
    x = "CLUE Small Area",
    y = "Number of Venues"
  ) +
  theme_minimal()

print(fig1)
ggsave(paste0(fig_path, "fig1_bars_by_area_2024.png"), fig1, width = 8, height = 5, dpi = 150)


# FIGURE 2: Total patron capacity by small area (2024) 
fig2 <- ggplot(bars_2024, aes(x = reorder(`CLUE small area`, total_capacity), y = total_capacity)) +
  geom_col(fill = "#d6604d") +
  coord_flip() +
  labs(
    title = "Total Bar/Pub Patron Capacity by Area (2024)",
    x = "CLUE Small Area",
    y = "Total Patron Capacity"
  ) +
  theme_minimal()

print(fig2)
ggsave(paste0(fig_path, "fig2_patron_capacity_by_area_2024.png"), fig2, width = 8, height = 5, dpi = 150)


# FIGURE 3: Outdoor café seats by small area (2024) 
cafes_outdoor <- cafes |>
  filter(`Census year` == 2024, `Seating type` == "Seats - Outdoor") |>
  group_by(`CLUE small area`) |>
  summarise(total_outdoor_seats = sum(`Number of seats`, na.rm = TRUE)) |>
  arrange(desc(total_outdoor_seats)) |>
  slice_head(n = 10)

fig3 <- ggplot(cafes_outdoor, aes(x = reorder(`CLUE small area`, total_outdoor_seats), y = total_outdoor_seats)) +
  geom_col(fill = "#4dac26") +
  coord_flip() +
  labs(
    title = "Top 10 Areas by Outdoor Café/Restaurant Seats (2024)",
    x = "CLUE Small Area",
    y = "Total Outdoor Seats"
  ) +
  theme_minimal()

print(fig3)
ggsave(paste0(fig_path, "fig3_outdoor_cafe_seats_2024.png"), fig3, width = 8, height = 5, dpi = 150)


# FIGURE 4: Bar/pub patron capacity over time in Melbourne CBD 
bars_trend <- bars |>
  filter(`CLUE small area` == "Melbourne (CBD)") |>
  group_by(`Census year`) |>
  summarise(total_capacity = sum(`Number of patrons`, na.rm = TRUE))

fig4 <- ggplot(bars_trend, aes(x = `Census year`, y = total_capacity)) +
  geom_line(colour = "#d6604d", linewidth = 1.2) +
  geom_point(colour = "#d6604d", size = 2.5) +
  labs(
    title = "Total Bar/Pub Patron Capacity in Melbourne CBD (2002–2024)",
    x = "Year",
    y = "Total Patron Capacity"
  ) +
  theme_minimal()

print(fig4)
ggsave(paste0(fig_path, "fig4_cbd_patron_capacity_trend.png"), fig4, width = 8, height = 5, dpi = 150)

# PART 2: DATA CLEANING AND FEATURE PREPARATION


# Clean bars/pubs 
bars_clean <- bars |>
  rename(
    year       = `Census year`,
    block_id   = `Block ID`,
    area       = `CLUE small area`,
    venue_name = `Trading name`,
    n_patrons  = `Number of patrons`,
    lat        = Latitude,
    lon        = Longitude
  ) |>
  filter(!is.na(lat), !is.na(lon), !is.na(block_id)) |>
  select(year, block_id, area, venue_name, n_patrons, lat, lon)

glimpse(bars_clean)

# Clean cafes/restaurants 
cafes_clean <- cafes |>
  rename(
    year         = `Census year`,
    block_id     = `Block ID`,
    area         = `CLUE small area`,
    venue_name   = `Trading name`,
    seating_type = `Seating type`,
    n_seats      = `Number of seats`,
    lat          = Latitude,
    lon          = Longitude
  ) |>
  filter(!is.na(lat), !is.na(lon), !is.na(block_id)) |>
  select(year, block_id, area, venue_name, seating_type, n_seats, lat, lon)

glimpse(cafes_clean)

# Block-level feature table (2024)
bar_features <- bars_clean |>
  filter(year == 2024) |>
  group_by(block_id) |>
  summarise(
    n_bars         = n(),
    total_patrons  = sum(n_patrons, na.rm = TRUE),
    median_patrons = median(n_patrons, na.rm = TRUE)
  )

cafe_features <- cafes_clean |>
  filter(year == 2024) |>
  group_by(block_id, seating_type) |>
  summarise(n_seats = sum(n_seats, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = seating_type, values_from = n_seats, values_fill = 0) |>
  rename_with(~str_replace_all(tolower(.), "[^a-z0-9]", "_"))

block_features <- bar_features |>
  full_join(cafe_features, by = "block_id") |>
  replace_na(list(n_bars = 0, total_patrons = 0))

glimpse(block_features)

# Check pedestrian sensors
glimpse(ped_sensors)
ped_sensors |> count(Status)

# Save cleaned datasets
dir.create("data/processed", showWarnings = FALSE)

write_csv(bars_clean,     "data/processed/bars_clean.csv")
write_csv(cafes_clean,    "data/processed/cafes_clean.csv")
write_csv(block_features, "data/processed/block_nightlife_features_2024.csv")
write_csv(ped_sensors, "data/processed/pedestrian_sensors_clean.csv")

message("✅ Cleaned datasets saved to data/processed/")

