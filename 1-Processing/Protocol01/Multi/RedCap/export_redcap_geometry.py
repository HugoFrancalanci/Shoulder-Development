"""
Export REDCap - tableau Géométrie articulaire pré-opératoire
-----------------------------------------------------------------
Table spécifique : liste des variables, mise en page de l'en-tête, et
construction d'une ligne à partir d'une ligne REDCap. Tout le reste
(lecture CSV, résolution des ID, lignes vides/"R", conversion numérique)
vient de redcap_common.py.

  Bloc "Géométrie articulaire pré-opératoire" : 6 variables simples
  (pas de paire plan/définitif, une seule valeur par variable)
"""

import os
import sys

# redcap_common.py vit dans le dossier parent (Export/), partagé par toutes
# les tables - on l'ajoute au path pour pouvoir l'importer depuis ce dossier
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from redcap_common import val, to_number, export_table, load_csv, check_columns, get_patient_row

# CSV et Excel de sortie : propres à ce dossier de table
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV = os.path.join(BASE_DIR, "BASESDEDONNEESEPAULE_DATA_2026-07-08_1945.csv")
OUTPUT_XLSX = os.path.join(BASE_DIR, "REDCap_Extraction.xlsx")

# Variables, dans l'ordre voulu : (libellé affiché, champ REDCap)
GEOMETRY_FIELDS = [
    ("Diamètre tête humérale", "mys_hum_preop_head_diam"),
    ("Inclinaison humérale", "mys_hum_preop_incl"),
    ("Retroversion humérale", "mys_hum_preop_retro"),
    ("Subluxation humérale", "mys_hum_preop_sublux"),
    ("Inclinaison glénoïdienne", "mys_glen_preop_sup_incl"),
    ("Retroversion glénoïdienne", "mys_glen_preop_retrov"),
]

# -------------------------------------------------------------------------
# EN-TÊTE (2 lignes)
# -------------------------------------------------------------------------
n_fields = len(GEOMETRY_FIELDS)

header1 = [""] + ["Géométrie articulaire pré-opératoire"] + [""] * (n_fields - 1)
header2 = ["ID REDCap"] + [label for label, _ in GEOMETRY_FIELDS]

merges = [
    (2, n_fields + 1),
]

check_columns(load_csv(INPUT_CSV), [f for _, f in GEOMETRY_FIELDS])


# -------------------------------------------------------------------------
# CONSTRUCTION D'UNE LIGNE
# -------------------------------------------------------------------------
def build_row(df, rid):
    row = get_patient_row(df, rid)

    has_data = row is not None and any(val(row, f) != "" for _, f in GEOMETRY_FIELDS)
    if not has_data:
        return False, None

    line = [to_number(val(row, f)) for _, f in GEOMETRY_FIELDS]
    return True, line


# -------------------------------------------------------------------------
# EXPORT
# -------------------------------------------------------------------------
export_table(OUTPUT_XLSX, "Geometrie_PreOp", header1, header2, merges, build_row, input_csv=INPUT_CSV)
