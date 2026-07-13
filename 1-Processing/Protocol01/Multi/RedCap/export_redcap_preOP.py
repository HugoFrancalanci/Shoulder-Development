"""
Export REDCap - tableau Géométrie articulaire pré-opératoire / Classification morphologique / ASA
-----------------------------------------------------------------
Table spécifique : liste des variables, mise en page de l'en-tête, et
construction d'une ligne à partir d'une ligne REDCap. Tout le reste
(lecture CSV, résolution des ID, lignes vides/"R", conversion numérique)
vient de redcap_common.py.

  Bloc "Géométrie articulaire pré-opératoire" : 6 variables simples
  Bloc "Classification morphologique"         : 4 variables simples (codes
                                                 REDCap traduits en grade
                                                 clinique réel, ex: Walch
                                                 '4' -> 'B1', voir MORPHO_LABELS)
  Bloc "ASA"                                  : 1 variable (classeasa)
  Bloc "CMS"                                  : 11 variables (Constant-Murley
                                                 Score, 10 sous-scores + Total),
                                                 lues sur l'event REDCap
                                                 "pre_operative_arm_1" via
                                                 val_for_event (le champ n'est
                                                 pas dédoublé en colonnes, il
                                                 est répété sur plusieurs
                                                 events REDCap selon la visite)
  (pas de paire plan/définitif, une seule valeur par variable)

  classeasa vaut "3 - trois", "1 - un", etc. -> on extrait juste le
  chiffre de tête (1 à 5).
"""

import os
import re
import sys

# redcap_common.py vit dans le dossier parent (Export/), partagé par toutes
# les tables - on l'ajoute au path pour pouvoir l'importer depuis ce dossier
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from redcap_common import val, to_number, export_table, load_csv, check_columns, get_patient_row, val_for_event

# CSV : partagé, désormais à la racine de Export/ (plus une copie par dossier)
# Excel de sortie : propre à ce dossier de table
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.dirname(BASE_DIR)
INPUT_CSV = os.path.join(EXPORT_DIR, "BASESDEDONNEESEPAULE_DATA_2026-07-13_1134.csv")
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

MORPHO_FIELDS = [
    ("Kellgren et Lawrence", "rxpreop_kellgren_arthro"),
    ("Samilson Prieto", "rxpreop_samilson_arthro"),
    ("Walch", "rxpreop_walch_arthro"),
    ("Hamada", "rxpreop_hamada_arthro"),
]

ASA_FIELD = "classeasa"

EVENT_PRE = "pre_operative_arm_1"
CMS_FIELDS = [
    ("Douleur", "cms_douleur"),
    ("Activité professionnelle", "cms_prof"),
    ("Loisir", "cms_loisir"),
    ("Sommeil", "cms_sommeil"),
    ("Hauteur de main", "cms_niv_main"),
    ("Antéflexion", "cms_ante"),
    ("Abduction", "cms_abd"),
    ("Rotation externe", "cms_rotext"),
    ("Rotation interne", "cms_rotint"),
    ("Force", "cms_force"),
    ("Total", "cms_total"),
]

# Codes REDCap (bruts) -> grade clinique réel, par champ
MORPHO_LABELS = {
    "rxpreop_kellgren_arthro": {"1": "0", "2": "1", "3": "2", "4": "3", "5": "4"},
    "rxpreop_samilson_arthro": {"0": "0", "1": "1", "2": "2", "3": "3"},
    "rxpreop_walch_arthro": {"1": "A1", "2": "A2", "4": "B1", "5": "B2", "6": "B3", "7": "C", "9": "D"},
    "rxpreop_hamada_arthro": {"1": "0", "2": "1", "3": "2", "4": "3", "5": "4a", "6": "4b", "7": "5"},
}

# -------------------------------------------------------------------------
# EN-TÊTE (2 lignes)
# -------------------------------------------------------------------------
n_geo    = len(GEOMETRY_FIELDS)
n_morpho = len(MORPHO_FIELDS)
n_cms    = len(CMS_FIELDS)

header1 = (
    [""] + ["Géométrie articulaire pré-opératoire"] + [""] * (n_geo - 1)
    + [""] + ["Classification morphologique"] + [""] * (n_morpho - 1)
    + [""] + ["ASA"]
    + [""] + ["CMS"] + [""] * (n_cms - 1)
)
header2 = (
    ["ID REDCap"]
    + [label for label, _ in GEOMETRY_FIELDS]
    + [""]
    + [label for label, _ in MORPHO_FIELDS]
    + ["", "ASA"]
    + [""]
    + [label for label, _ in CMS_FIELDS]
)

merges = [
    (2, n_geo + 1),
    (n_geo + 3, n_geo + 2 + n_morpho),
    (n_geo + n_morpho + 6, n_geo + n_morpho + 5 + n_cms),
]

check_columns(
    load_csv(INPUT_CSV),
    [f for _, f in GEOMETRY_FIELDS] + [f for _, f in MORPHO_FIELDS] + [ASA_FIELD]
    + [f for _, f in CMS_FIELDS] + ["redcap_event_name"],
)


def asa_class(raw):
    """'3 - trois' -> 3 (juste le chiffre de tête, 1 à 5)."""
    if raw == "":
        return ""
    m = re.match(r"\s*(\d+)", str(raw))
    return int(m.group(1)) if m else raw


def morpho_grade(field, raw):
    """Code REDCap brut -> grade clinique réel (ex: Walch '4' -> 'B1')."""
    if raw == "":
        return ""
    return MORPHO_LABELS.get(field, {}).get(str(raw).strip(), raw)


# -------------------------------------------------------------------------
# CONSTRUCTION D'UNE LIGNE
# -------------------------------------------------------------------------
def build_row(df, rid):
    row = get_patient_row(df, rid)

    cms_raw = [val_for_event(row, f, EVENT_PRE) for _, f in CMS_FIELDS]

    has_data = row is not None and (
        any(val(row, f) != "" for _, f in GEOMETRY_FIELDS)
        or any(val(row, f) != "" for _, f in MORPHO_FIELDS)
        or val(row, ASA_FIELD) != ""
        or any(v != "" for v in cms_raw)
    )
    if not has_data:
        return False, None

    geometry_vals = [to_number(val(row, f)) for _, f in GEOMETRY_FIELDS]
    morpho_vals = [morpho_grade(f, val(row, f)) for _, f in MORPHO_FIELDS]
    asa_val = asa_class(val(row, ASA_FIELD))
    cms_vals = [to_number(v) for v in cms_raw]

    line = geometry_vals + [""] + morpho_vals + ["", asa_val] + [""] + cms_vals
    return True, line


# -------------------------------------------------------------------------
# EXPORT
# -------------------------------------------------------------------------
# Colonnes "Classification morphologique" uniquement (grades ressemblant
# à des nombres, ex: Kellgren "0".."4") : forcées en texte pour éviter le
# warning Excel "nombre stocké en texte"
morpho_cols = list(range(n_geo + 3, n_geo + 3 + n_morpho))

export_table(OUTPUT_XLSX, "PreOp", header1, header2, merges, build_row,
             input_csv=INPUT_CSV, text_cols=morpho_cols)
