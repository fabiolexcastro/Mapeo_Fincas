

# Libraries ---------------------------------------------------------------
library(pacman)
pacman::p_load(terra, tidyverse, hablar, readxl, sf, fs, glue, RColorBrewer, ggspatial)

g <- gc(reset = T)
rm(list = ls())

# Functions ---------------------------------------------------------------

## Normalize names
nrml.name <- function(text){
  # text <- 'Raíces Vivas totales'
  rsl <- text %>% stringi::stri_trans_general('Latin-ASCII') %>% str_squish() %>% str_replace_all(' ', '_') %>% tolower()
  return(rsl)
}



# Table (main) ------------------------------------------------------------
path <- './Bdatos_Automatizacion.xlsx'
shts <- readxl::excel_sheets(path)
shts
tbls <- map(.x = shts, .f = ~ readxl::read_excel(path = path, sheet = .x)) %>% set_names(shts)
tbls

# Sol y agua --------------------------------------------------------------
sola <- st_read('./data/SolyAgua_Shapefile/SolAgua_UM.shp')
plot(st_geometry(sola))

## Clean shapefile 
sola <- dplyr::select(sola, ID1, ID2, Hacienda, Lote, UM, geometry)

## Join shapefile and table
sola <- inner_join(sola, tbls$Datos_SolyAgua, by = c('Hacienda', 'Lote', 'UM'))

## To reclassify 
rngs <- tbls$Rangos
cols <- rngs[1,] |> as.vector() |> as.character()
rngs <- rngs[-1,]
colnames(rngs) <- cols
rngs <- rngs[1:5,]
colnames(rngs)[3] <- 'rgb'
rngs <- dplyr::select(rngs, 1:15)


