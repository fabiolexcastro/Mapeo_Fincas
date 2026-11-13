

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

## Ranges
pars.rnge <- function(text){
  
  # text <- c('< 2.3', '-150.0 - 100', '> 32.0', '70% - 80%')
  txt <- str_remove_all(text, ' ')
  pct <- str_detect(txt, '%')
  txt <- str_remove_all(txt, '%')
  mtc <- str_match(txt, '^(<|>)?(-?[0-9.]+)(?:-(-?[0-9.]+))?$')
  if(any(is.na(mtc[, 1]))) stop(glue('Rango no interpretable: {paste(text[is.na(mtc[, 1])], collapse = " | ")}'))
  opr <- mtc[, 2]
  vl1 <- as.numeric(mtc[, 3])
  vl2 <- as.numeric(mtc[, 4])
  lwr <- case_when(opr %in% '<' ~ -Inf, T ~ vl1)
  upr <- case_when(opr %in% '>' ~ Inf, opr %in% '<' ~ vl1, T ~ vl2)
  fct <- ifelse(pct, 100, 1)
  rsl <- tibble(lwr = lwr / fct, upr = upr / fct)
  return(rsl)

}

# Read the blocks [ranges] ------------------------------------------------
read.rnge <- function(path){
  # path <- './Bdatos_Automatizacion.xlsx'
  cat('Reading ranges\n')
  mtx <- readxl::read_excel(path, sheet = 'Rangos', col_names = F, col_types = 'text', .name_repair = 'minimal') %>% as.matrix()
  mtx[] <- str_squish(mtx)
  nmx <- mtx
  nmx[] <- nrml.name(mtx)
  hdr <- which(nmx == 'categorias', arr.ind = T)
  
  rsl <- map_dfr(.x = 1:nrow(hdr), .f = function(i){
    row <- hdr[i, 1]
    col <- hdr[i, 2]
    ### Variables
    vrs <- c()
    j <- col + 3
    while(j <= ncol(mtx) && !is.na(mtx[row, j])){vrs <- c(vrs, j); j <- j + 1}
    ### Categories
    rws <- c()
    k <- row + 1
    while(k <= nrow(mtx) && !is.na(mtx[k, col]) && any(!is.na(mtx[k, vrs]))){rws <- c(rws, k); k <- k + 1}
    ### Long table
    map_dfr(.x = vrs, .f = function(v){
      tibble(blck = i, ordr = seq_along(rws), ctgr = mtx[rws, col], colr = mtx[rws, col + 1], rgbc = mtx[rws, col + 2], vrbl = mtx[row, v], rnge = mtx[rws, v], fol = col == 1)
    })
  })
  
  ## Key to match the columns of the data tables
  rsl <- rsl %>%
    mutate(rot = str_detect(nrml.name(vrbl), '^raices|^radopholus'),
           keyy = case_when(fol ~ vrbl, rot ~ vrbl, T ~ paste0(vrbl, '_sue')),
           keyy = nrml.name(keyy)) %>%
    bind_cols(., pars.rnge(.$rnge)) %>%
    dplyr::select(-fol, -rot)
  
  ## Check: the upper limit of one class must be the lower limit of the next one
  chk <- rsl %>% group_by(keyy) %>% arrange(ordr, .by_group = T) %>%
    mutate(nxt = lead(lwr)) %>% ungroup() %>%
    filter(!is.na(nxt), abs(upr - nxt) > 1e-9) %>%
    dplyr::select(vrbl, keyy, ctgr, rnge, upr, nxt)
  if(nrow(chk) > 0){
    cat('Inconsistent limits (the lower limit of the next class is used):\n')
    print(chk)
  }
  return(rsl)
  
}

## Reclassify a numeric vector with the ranges of one variable -----------
rcls.vctr <- function(vctr, tble){
  # vctr <- tble$N ; tble <- filter(rnge, keyy == 'n')
  tbl <- arrange(tble, ordr)
  brk <- c(tbl$lwr[1], tbl$lwr[-1], tbl$upr[nrow(tbl)])
  if(is.unsorted(brk)) stop(glue('Non increasing limits for {tbl$vrbl[1]}'))
  idx <- findInterval(round(vctr, 6), brk, rightmost.closed = T)
  rsl <- ifelse(idx %in% 1:nrow(tbl), tbl$ctgr[pmax(idx, 1)], NA_character_)
  return(rsl)
}

## Short names for the Shapefile (DBF limit: 10 characters) -----------
shrt.name <- function(nmes){
  # nmes <- c('PSI_sue_rcl', 'Raices_Vivas_totales_rcl')
  rsl <- nmes %>%
    str_replace('^Raices_Vivas_totales', 'RVT') %>%
    str_replace('^Raices_totales', 'RT') %>%
    str_replace('^Raices_vivas', 'RV') %>%
    str_replace('^Radopholus_Similis', 'RS')
  lng <- nchar(rsl) > 10
  rsl[lng] <- str_replace(rsl[lng], '_sue', '_s')
  if(any(nchar(rsl) > 10) | any(duplicated(rsl))) stop(glue('Shapefile names still invalid: {paste(rsl[nchar(rsl) > 10 | duplicated(rsl)], collapse = ", ")}'))
  return(rsl)
}

## Read one data sheet (duplicated columns are flagged with '_ray') -------
read.tble <- function(path, shet, keys){
  # shet <- 'Datos_SolyAgua' ; keys <- c('Hacienda', 'Lote', 'UM')
  tbl <- readxl::read_excel(path, sheet = shet, .name_repair = 'minimal')
  nms <- str_squish(names(tbl))
  dpl <- duplicated(nms)
  if(any(dpl)) cat(glue('{shet}: -> {paste0(nms[dpl], "_ray", collapse = ", ")}'), '\n')
  nms[dpl] <- paste0(nms[dpl], '_ray')
  names(tbl) <- nms
  tbl <- mutate(tbl, across(all_of(keys), ~ str_squish(as.character(.x))))
  dup <- tbl %>% count(across(all_of(keys))) %>% filter(n > 1)
  if(nrow(dup) > 0){print(dup); stop(glue('{shet}: duplicated keys'))}
  return(tbl)
}

## Main function: join + reclassify + write -------------------------------
name <- 'SolyAgua' ; shpe <- './data/SolyAgua_Shapefile/SolAgua_UM.shp' ; shet <- 'Datos_SolyAgua' ; keys <- c('Hacienda', 'Lote', 'UM') ; kpcl <- c('ID1', 'ID2')

make.rcls <- function(name, shpe, shet, keys, kpcl){
 
  cat('Processing: ', name, '\n')
  
  ### Shapefile (Z dropped, not needed for the maps) and table
  shp <- sf::st_read(shpe, quiet = T) %>%
    sf::st_zm(drop = T) %>%
    dplyr::select(any_of(kpcl), all_of(keys)) %>%
    mutate(across(all_of(keys), ~ str_squish(as.character(.x))))
  tbl <- read.tble(path = path, shet = shet, keys = keys)
  
  
   
}
