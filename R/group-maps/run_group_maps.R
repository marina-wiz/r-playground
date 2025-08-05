# --------------------------------------------------------
# Script: run_group_maps.R
# Author: Marina M. Wizentier
# Date: 2025-08-04
#
# Description:
#   This script generates choropleth maps using ACS 2017–2021 race/ethnicity 
#   data (table B03002) at the U.S. metropolitan level. 
#
#   It produces:
#
#     - Population percentage maps for:
#         • Non-Hispanic White
#         • Non-Hispanic Black
#         • Total Hispanic
#
#     - Dissimilarity index maps for:
#         • Non-Hispanic White vs. Non-Hispanic Black
#         • Non-Hispanic White vs. Total Hispanic
#         • Non-Hispanic Black vs. Total Hispanic
#
# Data sources:
#   - ACS 2017–2021 5-year estimates (table B03002)
#       Retrieved via the {tidycensus} R package
#
#   - Tract-to-CBSA crosswalk: 
#       Based on 2020 census tracts with population by race since 1990.
#       Compiled by The Washington Post.
#       License: Creative Commons BY-NC-SA 4.0
# --------------------------------------------------------

library(tidycensus)
library(tidyverse)
library(tigris)
library(sf)
library(ggspatial)
library(rnaturalearth)
library(rnaturalearthdata)
library(tidygeocoder)
library(maps)
library(ggrepel)

# --------------------------------------------------------
# Download ACS race/ethnicity data (B03002) at the tract level 
# --------------------------------------------------------
census <- get_acs(
  geography = "tract",
  state = c("AL","AZ","AR","CA","CO","CT","DE","DC","FL","GA","ID",
            "IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS",
            "MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK",
            "OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV",
            "WI","WY"),
  year = 2021,
  geometry = FALSE,
  output = "wide",
  table = "B03002",
  cache_table = TRUE
)

# --------------------------------------------------------
# Merge with tract-to-CBSA crosswalk
# --------------------------------------------------------
censustract <- read.csv("data/enclave_tract1.csv")
tract.cbsa <- censustract[, c("geoid", "cbsa")]

census$geoid <- as.numeric(census$GEOID)
census1 <- merge(x = census, y = tract.cbsa, by = "geoid", all.x = TRUE)
census1 <- census1[!is.na(census1$cbsa), ]

# --------------------------------------------------------
# Calculate metro-level totals for each group
# --------------------------------------------------------
metro_totals <- census1 %>%
  group_by(cbsa) %>%
  summarise(
    metro_total = sum(B03002_001E),  # Total population
    metro_nhw   = sum(B03002_003E),  # Non-Hispanic White
    metro_nhb   = sum(B03002_004E),  # Non-Hispanic Black
    metro_whisp = sum(B03002_013E),  # Hispanic White
    metro_bhisp = sum(B03002_014E),  # Hispanic Black
    metro_hhisp = sum(B03002_018E),   # Hispanic Other
    metro_hisp  = sum(B03002_012E)   # Total Hispanic
  )

# --------------------------------------------------------
# Merge metro-level totals back to tract-level data
# --------------------------------------------------------
metro_tracts <- left_join(census1, metro_totals, by = "cbsa")

# --------------------------------------------------------
# Get CBSA geometries and merge
# --------------------------------------------------------
metro_shapes <- core_based_statistical_areas(year = 2021)

filter_metros <- function(df) {
  df %>%
    filter(grepl('Metro', NAMELSAD)) %>%
    filter(!grepl('PR Metro Area|AK Metro Area', NAMELSAD))
}


# --------------------------------------------------------
# Load background map data
# --------------------------------------------------------
world_map_data <- ne_countries(scale = "medium", returnclass = "sf")
state_map_data <- map("state", fill = TRUE, plot = FALSE) %>% st_as_sf()

# --------------------------------------------------------
# Define plotting theme
# --------------------------------------------------------
mytheme <- theme(
  text = element_text(family = 'Avenir'),
  panel.grid.major = element_line(color = '#cccccc', 
                                  linetype = 'dashed', size = 0.3),
  panel.background = element_rect(fill = 'aliceblue'),
  plot.title = element_text(size = 13),
  plot.subtitle = element_text(size = 10),
  axis.title = element_blank(),
  axis.text = element_text(size = 9)
)

# --------------------------------------------------------
# Map Group Percentage Function 
# --------------------------------------------------------
map_pctg <- function(data, group_col, denom_col, title, subtitle, filename) {
  data <- data %>%
    mutate(share = get(group_col) / get(denom_col))
  
  p <- ggplot() +
    geom_sf(data = world_map_data, fill = 'antiquewhite1', size = 0.4) +
    geom_sf(data = state_map_data, fill = NA, size = 0.4) +
    geom_sf(data = data, aes(fill = share)) +
    scale_fill_viridis_c(name = "% of Population", option = "G", 
                         labels = scales::percent) +
    scale_color_viridis_c(option = "magma") +
    xlim(c(125, 65)) + ylim(c(25, 50)) +
    ggtitle(title, subtitle = subtitle) +
    mytheme
  
  ggsave(filename, plot = p, width = 10, height = 7, dpi = 300)
}

# --------------------------------------------------------
# Generate group percentage maps 
# --------------------------------------------------------
geo_metros <- merge(metro_shapes, metro_totals, by.x = "GEOID", 
                    by.y = "cbsa", all.x = TRUE) %>% filter_metros()

# % Non-Hispanic White
map_pctg(geo_metros, "metro_nhw", "metro_total", "% Non-Hispanic White", 
         "ACS 2017–2021, Metropolitan Areas", "output/pct_nhw.png")

# % Non-Hispanic Black
map_pctg(geo_metros, "metro_nhb", "metro_total", "% Non-Hispanic Black", 
         "ACS 2017–2021, Metropolitan Areas", "output/pct_nhb.png")

# % Hispanic
map_pctg(geo_metros, "metro_hisp", "metro_total", "% Hispanic", 
         "ACS 2017–2021, Metropolitan Areas", "output/pct_hisp.png")


# --------------------------------------------------------
# Compute Dissimilarity Indices
# --------------------------------------------------------

# Non-Hispanic White vs. Non-Hispanic Black
metro_dissim_nhw_nhb <- metro_tracts %>%
  mutate(diff_nhw_nhb = abs(
    B03002_003E / metro_nhw - B03002_004E / metro_nhb)) %>%
  group_by(cbsa) %>%
  summarise(dissim_nhw_nhb = round(0.5 * sum(diff_nhw_nhb, na.rm = TRUE), 2))

# Non-Hispanic White vs. Hispanic
metro_dissim_nhw_hisp <- metro_tracts %>%
  mutate(diff_nhw_hisp = abs(B03002_003E / metro_nhw - B03002_012E / metro_hisp)) %>%
  group_by(cbsa) %>%
  summarise(dissim_nhw_hisp = round(0.5 * sum(diff_nhw_hisp, na.rm = TRUE), 2))

# Non-Hispanic Black vs. Hispanic
metro_dissim_nhb_hisp <- metro_tracts %>%
  mutate(diff_nhb_hisp = abs(B03002_004E / metro_nhb - B03002_012E / metro_hisp)) %>%
  group_by(cbsa) %>%
  summarise(dissim_nhb_hisp = round(0.5 * sum(diff_nhb_hisp, na.rm = TRUE), 2))

# --------------------------------------------------------
# Merge geometries with dissimilarity outputs
# --------------------------------------------------------

geo_dissim_nhw_nhb  <- merge(
  metro_shapes, metro_dissim_nhw_nhb, by.x = "GEOID", by.y = "cbsa", 
  all.x = TRUE) %>% filter_metros()

geo_dissim_nhw_hisp <- merge(
  metro_shapes, metro_dissim_nhw_hisp, by.x = "GEOID", by.y = "cbsa", 
  all.x = TRUE) %>% filter_metros()

geo_dissim_nhb_hisp <- merge(
  metro_shapes, metro_dissim_nhb_hisp, by.x = "GEOID", by.y = "cbsa", 
  all.x = TRUE) %>% filter_metros()


# --------------------------------------------------------
# Map Dissimilarity Function
# --------------------------------------------------------
map_dissim <- function(data, fill_var, title, subtitle, filename) {
  p <- ggplot() +
    geom_sf(data = world_map_data, fill = 'antiquewhite1', size = 0.4) +
    geom_sf(data = state_map_data, fill = NA, size = 0.4) +
    geom_sf(data = data, aes_string(fill = fill_var)) +
    scale_fill_viridis_c(name = "Dissim.", option = "G", limits = c(0, 1)) +
    scale_color_viridis_c(option = "magma") +
    xlim(c(125, 65)) + ylim(c(25, 50)) +
    ggtitle(title, subtitle = subtitle) +
    mytheme
  
  ggsave(filename, plot = p, width = 10, height = 7, dpi = 300)
}

# --------------------------------------------------------
# Generate dissimilarity maps
# --------------------------------------------------------

map_dissim(geo_dissim_nhw_nhb, "dissim_nhw_nhb", 
            "Dissimilarity Index for Non-Hispanic White and Non-Hispanic Black", 
            "ACS 2017–2021, Metropolitan Areas", "output/dissim_nhw_nhb.png")

map_dissim(geo_dissim_nhw_hisp, "dissim_nhw_hisp", 
           "Dissimilarity Index for Non-Hispanic White and Hispanic", 
           "ACS 2017–2021, Metropolitan Areas", "output/dissim_nhw_hisp.png")

map_dissim(geo_dissim_nhb_hisp, "dissim_nhb_hisp", 
           "Dissimilarity Index for Non-Hispanic Black and Hispanic", 
           "ACS 2017–2021, Metropolitan Areas", "output/dissim_nhb_hisp.png")


