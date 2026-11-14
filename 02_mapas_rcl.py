"""
02_mapas_rcl.py
-------------------------------------------------------------------------------
Mapas por categorías (análisis foliar, suelo y raíces) en ArcGIS Pro a partir
de los shapefiles *_rcl.shp que genera 01_cleanShapefile_v2.R.
-------------------------------------------------------------------------------
"""

import os
import re
import unicodedata

import openpyxl

try:
    import arcpy
except ImportError:  
    arcpy = None

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
ROOT = r"C:\Users\chern\OneDrive\ALIA2\Proyectos\Banano\GIS_Automatizacion_Mapas"
EXCEL = os.path.join(ROOT, "Bdatos_Automatizacion_v2.xlsx")
SALIDA = os.path.join(ROOT, "maps")
APRX = "CURRENT"          # proyecto abierto en ArcGIS Pro

FECHA = "Octubre 2026"  
FECHA_CORTA = "Oct2026"   
PNG = False               
RESOLUCION = 300

# Una fila por hacienda: (prefijo del archivo, nombre del layout, nombre de la capa _rcl)
HACIENDAS = [
    ("SA", "Layout", "Categorías"),
    # ("Raq", "Layout_Raquelita", "Categorías"),
    # ("DF",  "Layout_DF",        "Categorías"),
]

# Campo numérico del shapefile: (título sin fecha, código para el nombre del archivo)
VARIABLES = {
    # Foliar
    "N":  ("N (%) foliar",   "Nfol"),
    "P":  ("P (%) foliar",   "Pfol"),
    "K":  ("K (%) foliar",   "Kfol"),
    "Ca": ("Ca (%) foliar",  "Cafol"),
    "Mg": ("Mg (%) foliar",  "Mgfol"),
    "S":  ("S (%) foliar",   "Sfol"),
    "Zn": ("Zn (ppm) foliar", "Znfol"),
    "Cu": ("Cu (ppm) foliar", "Cufol"),
    "Fe": ("Fe (ppm) foliar", "Fefol"),
    "Mn": ("Mn (ppm) foliar", "Mnfol"),
    "B":  ("B (ppm) foliar",  "Bfol"),
     # Suelo
    "pH_sue":  ("pH suelo",                  "pHsue"),
    "CE_sue":  ("CE (dS/m) suelo",           "CEsue"),
    "K_sue":   ("K (meq/100g ss) suelo",     "Ksue"),
    "Ca_sue":  ("Ca (meq/100g ss) suelo",    "Casue"),
    "Mg_sue":  ("Mg (meq/100g ss) suelo",    "Mgsue"),
    "P_sue":   ("P (ppm) suelo",             "Psue"),
    "S_sue":   ("S (ppm) suelo",             "Ssue"),
    "Zn_sue":  ("Zn (ppm) suelo",            "Znsue"),
    "Cu_sue":  ("Cu (ppm) suelo",            "Cusue"),
    "Fe_sue":  ("Fe (ppm) suelo",            "Fesue"),
    "Mn_sue":  ("Mn (ppm) suelo",            "Mnsue"),
    "B_sue":   ("B (ppm) suelo",             "Bsue"),
    "MO_sue":  ("Materia Orgánica (%)",      "MO"),
    "PSI_sue": ("PSI (%) suelo",             "PSIsue"),
    # Raíces y nematodos (solo Delia Francia)
    "RT":  ("Raíces totales (g/planta)",        "RT"),
    "RVT": ("Raíces Vivas totales (g/planta)",  "RVT"),
    "RV":  ("Raíces Vivas (%)",                 "RV"),
    "RS":  ("Radopholus similis/100g raíces",   "RS"),
}




