
## Install libraries
library(pacman)
pacman::p_load(terra, tidyverse, sf, fs, glue, RColorBrewer, ggspatial)

g <- gc(reset = T)
rm(list = ls())
