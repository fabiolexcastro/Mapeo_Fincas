

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
  

}




