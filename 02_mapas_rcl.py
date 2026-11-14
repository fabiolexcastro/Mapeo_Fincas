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

