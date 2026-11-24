
# Libraries ---------------------------------------------------------------
require(pacman)
pacman::p_load(tidyverse, readxl, sf, glue, stringi)

g <- gc(reset = T)
rm(list = ls())
options(scipen = 999, warn = -1)

# Paths -------------------------------------------------------------------
path <- './Bdatos_DF_Automatizacion_v3.xlsx'
shpe <- './data/DeliaFrancia_Shapefile/DeliaFrancia_UM_Limpio.shp'
dout <- './output'
dir.create(dout, showWarnings = F)

# Functions ---------------------------------------------------------------

## Normalize names (accents, spaces, case)
nrml.name <- function(text){
  # text <- 'Raíces Vivas totales'
  rsl <- text %>% stringi::stri_trans_general('Latin-ASCII') %>% str_squish() %>% str_replace_all(' ', '_') %>% tolower()
  return(rsl)
}

## Join key: the Excel writes '1A,1B' and the shapefile '1A_1B'
nrml.keyy <- function(text){
  # text <- c('1A,1B', '22,23,24', '14')
  rsl <- text %>% as.character() %>% str_squish() %>% str_replace_all('\\s*,\\s*', '_') %>% toupper()
  return(rsl)
}

## Reclassify one variable: each class starts at its lower limit
rcls.vctr <- function(vctr, vrbl){
  # vctr <- c(2.1, 2.6, NA) ; vrbl <- 'N'
  tbl <- rnge[rnge$keyy == nrml.name(vrbl), ]
  rsl <- tbl$ctgr[findInterval(vctr, tbl$lwr)]
  return(rsl)
}

## Delia Francia: lab values (foliar, soil, roots, nematodes) come from the Excel;
## the shapefile only brings the geometry (NameUM, ID10)
make.rcls.dfrn <- function(name, shpe, shet){
  # name <- 'DeliaFrancia' ; shpe <- './data/DeliaFrancia_Shapefile/DeliaFrancia_UM_Limpio.shp' ; shet <- 'Datos_DF'
  cat('Processing: ', name, '\n')

  ### Excel table
  tbl <- readxl::read_excel(path, sheet = shet, .name_repair = 'minimal')
  names(tbl) <- make.unique(str_squish(names(tbl)), sep = '_')
  tbl <- tbl %>%
    drop_na(UM) %>%
    mutate(Hacienda = str_squish(as.character(Hacienda)),
           Lote = str_squish(as.character(Lote)),
           UM = str_squish(as.character(UM)),
           keyy = nrml.keyy(UM),
           ordn = row_number())
  dpl <- tbl$keyy[duplicated(tbl$keyy)]
  if(length(dpl) > 0){stop('Duplicated UM in the Excel: ', paste(dpl, collapse = ', '))}

  ### Shapefile + join
  shp <- sf::st_read(shpe, quiet = T) %>%
    sf::st_zm() %>%
    dplyr::select(NameUM, ID10) %>%
    mutate(keyy = nrml.keyy(NameUM)) %>%
    left_join(tbl, by = 'keyy')

  ### Checks: polygons without data, Excel rows without polygon, order (ID10 vs Excel row)
  mss <- shp$NameUM[is.na(shp$UM)]
  if(length(mss) > 0){cat('UM in the shapefile without data in the Excel: ', paste(mss, collapse = ', '), '\n')}
  nsh <- setdiff(tbl$keyy, shp$keyy)
  if(length(nsh) > 0){cat('UM in the Excel without polygon: ', paste(nsh, collapse = ', '), '\n')}
  odr <- shp %>% sf::st_drop_geometry() %>% filter(!is.na(ordn), ID10 != ordn)
  if(nrow(odr) > 0){cat('Warning: ID10 does not follow the Excel order in: ', paste(odr$NameUM, collapse = ', '), '\n')}

  ### Reclassify
  vrs <- names(tbl)[nrml.name(names(tbl)) %in% rnge$keyy]
  cat('Variables to reclassify: ', length(vrs), '\n')
  for(v in vrs){shp[[paste0(v, '_rcl')]] <- rcls.vctr(vctr = shp[[v]], vrbl = v)}
  shp <- shp %>%
    dplyr::select(Hacienda, Lote, UM, all_of(as.vector(rbind(vrs, paste0(vrs, '_rcl')))), everything(), -keyy, -ordn) %>%
    arrange(ID10)
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
dfrn <- make.rcls.dfrn(name = 'DeliaFrancia', shpe = shpe, shet = 'Datos_DF')

# Check -------------------------------------------------------------------

## Values with no category (should be empty)
dfrn %>%
  sf::st_drop_geometry() %>%
  dplyr::select(UM, ends_with('_rcl')) %>%
  pivot_longer(-UM, names_to = 'vrbl', values_to = 'ctgr') %>%
  filter(is.na(ctgr))

## Categories per variable
dfrn %>%
  sf::st_drop_geometry() %>%
  dplyr::select(ends_with('_rcl')) %>%
  pivot_longer(everything(), names_to = 'vrbl', values_to = 'ctgr') %>%
  count(vrbl, ctgr) %>%
  print(n = Inf)
