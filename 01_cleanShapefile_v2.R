
# Libraries ---------------------------------------------------------------
require(pacman)
pacman::p_load(tidyverse, readxl, sf, glue, stringi)

g <- gc(reset = T)
rm(list = ls())
options(scipen = 999, warn = -1)

# Paths -------------------------------------------------------------------
path <- './Bdatos_Automatizacion_v2.xlsx'
dout <- './output'
dir.create(dout, showWarnings = F)

# Functions ---------------------------------------------------------------

## Normalize names (accents, spaces, case)
nrml.name <- function(text){
  # text <- 'Raíces Vivas totales'
  rsl <- text %>% stringi::stri_trans_general('Latin-ASCII') %>% str_squish() %>% str_replace_all(' ', '_') %>% tolower()
  return(rsl)
}

## Reclassify one variable: each class starts at its lower limit
rcls.vctr <- function(vctr, vrbl){
  # vctr <- c(2.1, 2.6, NA) ; vrbl <- 'N'
  tbl <- rnge[rnge$keyy == nrml.name(vrbl), ]
  rsl <- tbl$ctgr[findInterval(vctr, tbl$lwr)]
  return(rsl)
}

## Join + reclassify + write
make.rcls <- function(name, shpe, shet, keys){
  # name <- 'SolyAgua' ; shpe <- './data/SolyAgua_Shapefile/SolAgua_UM.shp' ; shet <- 'Datos_SolyAgua' ; keys <- c('Hacienda', 'Lote', 'UM')
  cat('Processing: ', name, '\n')
  tbl <- readxl::read_excel(path, sheet = shet, .name_repair = 'minimal')
  names(tbl) <- make.unique(str_squish(names(tbl)), sep = '_')
  tbl <- mutate(tbl, across(all_of(keys), ~ str_squish(as.character(.x))))
  shp <- sf::st_read(shpe, quiet = T) %>%
    sf::st_zm() %>%
    dplyr::select(all_of(keys)) %>%
    mutate(across(all_of(keys), ~ str_squish(as.character(.x)))) %>%
    left_join(tbl, by = keys)
  vrs <- names(tbl)[nrml.name(names(tbl)) %in% rnge$keyy]
  for(v in vrs){shp[[paste0(v, '_rcl')]] <- rcls.vctr(vctr = shp[[v]], vrbl = v)}
  shp <- dplyr::select(shp, all_of(keys), all_of(as.vector(rbind(vrs, paste0(vrs, '_rcl')))), everything())
  names(shp) <- str_replace_all(names(shp), c('Raices_Vivas_totales' = 'RVT', 'Raices_totales' = 'RT', 'Raices_vivas' = 'RV', 'Radopholus_Similis' = 'RS', 'PSI_sue_rcl' = 'PSI_s_rcl'))
  sf::st_write(shp, glue('{dout}/{name}_rcl.shp'), append = F, quiet = T, layer_options = 'ENCODING=UTF-8')
  cat('Done!\n')
  return(shp)
}

# Ranges ------------------------------------------------------------------
shts <- grep('^Rango_', readxl::excel_sheets(path), value = T) %>% setdiff('Rango_3vbajo')
rnge <- map_dfr(.x = shts, .f = function(s){
  readxl::read_excel(path, sheet = s, col_types = 'text') %>%
    dplyr::select(ctgr = 1, 4:last_col()) %>%
    pivot_longer(-ctgr, names_to = 'vrbl', values_to = 'rnge') %>%
    drop_na() %>%
    mutate(vrbl = if(s %in% c('Rango_pH', 'Rango_CE', 'Rango_PSI')) paste0(vrbl, '_sue') else vrbl)
}) %>%
  mutate(ctgr = str_squish(ctgr),
         keyy = nrml.name(vrbl),
         lwr = ifelse(str_detect(rnge, '<'), -Inf, parse_number(rnge)) / ifelse(str_detect(rnge, '%'), 100, 1))
rnge

# To apply the function ---------------------------------------------------
sola <- make.rcls(name = 'SolyAgua', shpe = './data/SolyAgua_Shapefile/SolAgua_UM.shp', shet = 'Datos_SolyAgua', keys = c('Hacienda', 'Lote', 'UM'))
rqlt <- make.rcls(name = 'Raquelita', shpe = './data/Raquelita_Shapefile/Raquelita_UM.shp', shet = 'Datos_Raquelita', keys = c('Hacienda', 'Lote', 'UM'))
dfrn <- make.rcls(name = 'DeliaFrancia', shpe = './data/DeliaFrancia_Shapefile/DeliaFrancia_UM.shp', shet = 'Datos_DF', keys = c('UM'))

# Check -------------------------------------------------------------------

sola









