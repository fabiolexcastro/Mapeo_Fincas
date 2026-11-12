

# Libraries ---------------------------------------------------------------
library(pacman)
pacman::p_load(terra, tidyverse, sf, fs, glue, RColorBrewer, ggspatial)

g <- gc(reset = T)
rm(list = ls())


# Sol y agua --------------------------------------------------------------
sola <- st_read('./data/SolyAgua_Shapefile/SolAgua_UM.shp')
plot(st_geometry(sola))



