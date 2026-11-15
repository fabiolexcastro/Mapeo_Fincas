
# Libraries ---------------------------------------------------------------
require(pacman)
pacman::p_load(tidyverse, readxl, sf, glue, stringi)

g <- gc(reset = T)
rm(list = ls())
options(scipen = 999, warn = -1)

# Paths -------------------------------------------------------------------
path <- './Bdatos_Automatizacion_v2.xlsx'
shpe <- './data/Raquelita_Shapefile/Raquelita_UM_SueFol_Octubre2026.shp'
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

## Raquelita: the October shapefile already carries the lab values;
## from the Excel only Hacienda and Lote are taken (lookup by UM)
make.rcls.raqt <- function(name, shpe, shet){
  # name <- 'Raquelita' ; shpe <- './data/Raquelita_Shapefile/Raquelita_UM_SueFol_Octubre2026.shp' ; shet <- 'Datos_Raquelita'
  cat('Processing: ', name, '\n')
  lkp <- readxl::read_excel(path, sheet = shet, .name_repair = 'minimal')
  names(lkp) <- make.unique(str_squish(names(lkp)), sep = '_')
  lkp <- lkp %>%
    dplyr::select(Hacienda, Lote, UM) %>%
    mutate(across(everything(), ~ str_squish(as.character(.x)))) %>%
    drop_na(UM) %>%
    distinct()
  shp <- sf::st_read(shpe, quiet = T) %>%
    sf::st_zm() %>%
    mutate(UM = str_squish(as.character(UM))) %>%
    left_join(lkp, by = 'UM')
  mss <- shp$UM[is.na(shp$Lote)]
  if(length(mss) > 0){cat('UM without Lote in the Excel: ', paste(mss, collapse = ', '), '\n')}
  vrs <- names(shp)[nrml.name(names(shp)) %in% rnge$keyy]
  cat('Variables to reclassify: ', length(vrs), '\n')
  for(v in vrs){shp[[paste0(v, '_rcl')]] <- rcls.vctr(vctr = shp[[v]], vrbl = v)}
  shp <- dplyr::select(shp, Hacienda, Lote, UM, all_of(as.vector(rbind(vrs, paste0(vrs, '_rcl')))), everything())
  names(shp) <- str_replace_all(names(shp), c('PSI_sue_rcl' = 'PSI_s_rcl'))
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
rqlt <- make.rcls.raqt(name = 'Raquelita', shpe = shpe, shet = 'Datos_Raquelita')

# Check -------------------------------------------------------------------

## Values with no category (should be empty)
rqlt %>%
  sf::st_drop_geometry() %>%
  dplyr::select(UM, ends_with('_rcl')) %>%
  pivot_longer(-UM, names_to = 'vrbl', values_to = 'ctgr') %>%
  filter(is.na(ctgr))

## Categories per variable
rqlt %>%
  sf::st_drop_geometry() %>%
  dplyr::select(ends_with('_rcl')) %>%
  pivot_longer(everything(), names_to = 'vrbl', values_to = 'ctgr') %>%
  count(vrbl, ctgr)

