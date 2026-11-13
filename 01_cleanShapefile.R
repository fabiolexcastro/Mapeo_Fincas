

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




