
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





