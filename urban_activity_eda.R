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
