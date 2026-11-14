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


# =============================================================================
# FUNCIONES PURAS (no dependen de arcpy)
# =============================================================================
def nrml(texto):
    """'Raíces Vivas totales' -> 'raices_vivas_totales'."""
    txt = unicodedata.normalize("NFKD", str(texto)).encode("ascii", "ignore").decode()
    return "_".join(txt.split()).lower()

def limpiar_rango(texto):
    """'<0.5' -> '< 0.5' ; '2.25 -  2.5' -> '2.25 - 2.5'."""
    txt = " ".join(str(texto).split())
    txt = re.sub(r"^([<>])\s*", r"\1 ", txt)
    return re.sub(r"\s*-\s*", " - ", txt)


def leer_rangos(ruta=EXCEL):
    """{clave_variable: [(categoria, (r, g, b), rango), ...]} en el orden del Excel."""
    wb = openpyxl.load_workbook(ruta, data_only=True, read_only=True)
    rangos = {}
    for hoja in wb.sheetnames:
        if not hoja.startswith("Rango_") or hoja == "Rango_3vbajo":
            continue
        filas = list(wb[hoja].iter_rows(values_only=True))
        enc = filas[0]
        for j in range(3, len(enc)):
            if enc[j] is None:
                continue
            clave = nrml(enc[j]) + ("_sue" if hoja in HOJAS_SUE else "")
            clases = []
            for f in filas[1:]:
                if f[0] is None or j >= len(f) or f[j] is None:
                    continue
                hx = str(f[2]).strip().lstrip("#")
                rgb = tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))
                clases.append((" ".join(str(f[0]).split()), rgb, limpiar_rango(f[j])))
            rangos[clave] = clases
    return rangos


def campo_rcl(campo):
    """Nombre del campo categórico en el .shp (límite de 10 caracteres)."""
    return "PSI_s_rcl" if campo == "PSI_sue" else campo + "_rcl"
  

def clave_rango(campo):
    return ALIAS.get(campo, nrml(campo))
  
  
  

