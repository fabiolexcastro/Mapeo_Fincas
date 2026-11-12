

# Libraries ---------------------------------------------------------------
library(pacman)
pacman::p_load(terra, tidyverse, readxl, sf, fs, glue, RColorBrewer, ggspatial)

g <- gc(reset = T)
rm(list = ls())


# Table (main) ------------------------------------------------------------
path <- './Bdatos_Automatizacion.xlsx'
shts <- readxl::excel_sheets(path)
shts
tbls <- map(.x = shts, .f = ~ readxl::read_excel(path = path, sheet = .x)) %>% set_names(shts)
tbls

# Sol y agua --------------------------------------------------------------
sola <- st_read('./data/SolyAgua_Shapefile/SolAgua_UM.shp')
plot(st_geometry(sola))



