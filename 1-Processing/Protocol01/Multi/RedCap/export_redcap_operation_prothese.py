"""
Export REDCap - tableau Opération / Prothèse
-----------------------------------------------------------------
Table spécifique : liste des variables, mise en page de l'en-tête, et
construction d'une ligne à partir d'une ligne REDCap. Tout le reste
(lecture CSV, résolution des ID, lignes vides/"R", conversion numérique)
vient de redcap_common.py.

  Bloc "Opération" : Date, Durée séjour, Durée intervention, Opérateur
  Bloc "Prothèse"  : Type, Naviguation, Marque
"""

import datetime
import os
import sys

# redcap_common.py vit dans le dossier parent (Export/), partagé par toutes
# les tables - on l'ajoute au path pour pouvoir l'importer depuis ce dossier
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from redcap_common import val, to_number, export_table, load_csv, check_columns, get_patient_row

# CSV et Excel de sortie : propres à ce dossier de table
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV = os.path.join(BASE_DIR, "BASESDEDONNEESEPAULE_DATA_2026-07-09_0915.csv")
OUTPUT_XLSX = os.path.join(BASE_DIR, "REDCap_Extraction.xlsx")

# Variables, dans l'ordre voulu : (libellé affiché, champ REDCap)
OPERATION_FIELDS = [
    ("Date", "jourinterv"),
    ("Durée séjour", "dureesejourjour"),
    ("Durée intervention", "dureeintervmin"),
    ("Opérateur", "nomoperateur1"),
]
PROTHESE_FIELDS = [
    ("Type", "art_implant_type"),
    ("Naviguation", "nxtar_syst_impl"),
    ("Marque", "ortho_croarthro_model"),
]
ALL_FIELDS = OPERATION_FIELDS + PROTHESE_FIELDS

# Codes REDCap -> libellé affiché, pour les champs qui en ont besoin.
# Un code absent de ce dictionnaire est affiché tel quel (ex: autres
# opérateurs que "nsho").
FIELD_LABELS = {
    "nomoperateur1": {
        "nsho": "Nicolas Holzer",
    },
    "art_implant_type": {
        "1": "Anatomic",
        "2": "Anatomic Total",
        "3": "Reverse",
    },
    "ortho_croarthro_model": {
        "1": "Medacta Shoulder System",
        "2": "Tornier Aequalis Reverse FX",
        "3": "Tornier Ascend Flex",
        "4": "Tornier Aequalis Reverse",
        "5": "Biomet Comprehensive",
        "6": "Depuy Xtend",
        "7": "Smith & Nephew Neer III",
    },
}


def parse_yyyymmdd(s):
    """'20260527' -> date(2026, 5, 27) pour un vrai formatage date Excel."""
    s = s.strip()
    if len(s) == 8 and s.isdigit():
        try:
            return datetime.date(int(s[0:4]), int(s[4:6]), int(s[6:8]))
        except ValueError:
            return s
    return s


def transform(field, raw):
    """Applique le formatage/libellé propre à un champ REDCap donné."""
    if raw == "":
        return ""
    if field == "jourinterv":
        return parse_yyyymmdd(raw)
    if field == "nxtar_syst_impl":
        # Système de navigation toujours "NextAR Camera" dès que renseigné
        return "NextAR Camera"
    if field in FIELD_LABELS:
        return FIELD_LABELS[field].get(str(raw).strip(), raw)
    return to_number(raw)

# -------------------------------------------------------------------------
# EN-TÊTE (2 lignes)
# -------------------------------------------------------------------------
n_op, n_pr = len(OPERATION_FIELDS), len(PROTHESE_FIELDS)

header1 = (
    [""]
    + ["Opération"] + [""] * (n_op - 1)
    + [""]
    + ["Prothèse"] + [""] * (n_pr - 1)
)
header2 = (
    ["ID REDCap"]
    + [label for label, _ in OPERATION_FIELDS]
    + [""]
    + [label for label, _ in PROTHESE_FIELDS]
)

merges = [
    (2, n_op + 1),
    (n_op + 3, n_op + 2 + n_pr),
]

check_columns(load_csv(INPUT_CSV), [f for _, f in ALL_FIELDS])


# -------------------------------------------------------------------------
# CONSTRUCTION D'UNE LIGNE
# -------------------------------------------------------------------------
def build_row(df, rid):
    row = get_patient_row(df, rid)

    has_data = row is not None and any(val(row, f) != "" for _, f in ALL_FIELDS)
    if not has_data:
        return False, None

    line = (
        [transform(f, val(row, f)) for _, f in OPERATION_FIELDS]
        + [""]
        + [transform(f, val(row, f)) for _, f in PROTHESE_FIELDS]
    )
    return True, line


# -------------------------------------------------------------------------
# EXPORT
# -------------------------------------------------------------------------
export_table(OUTPUT_XLSX, "Operation_Prothese", header1, header2, merges, build_row, input_csv=INPUT_CSV)
