"""
Export REDCap - tableau Opération / Prothèse / Planning / Simulation
-----------------------------------------------------------------
Combine en un seul script + un seul Excel ce qui était avant 2 tableaux
séparés (PostOP_operation_prothese + PostOP_planning) : mêmes variables,
mêmes règles, une seule ligne par patient avec les 4 blocs à la suite.
Tout le reste (lecture CSV, résolution des ID, lignes vides/"R",
conversion numérique) vient de redcap_common.py.

  Bloc "Opération" : Date, Durée séjour, Durée intervention, Opérateur
  Bloc "Prothèse"  : Type, Naviguation, Marque
  Bloc "Planning"  : valeur définitive (_def) des 10 variables ; si le
                     champ définitif REDCap vaut "-" (= identique au
                     plan), on prend la valeur planifiée (_prim) à la
                     place ; si les deux sont vides, la cellule affiche
                     "R". Pas de flag de modification peropératoire.
  Bloc "Simulation": 5 variables simples (pas de paire plan/def) -
                     déplacement du centre de rotation huméral simulé
                     et amplitudes max avant impingement
  Bloc "CMS"       : 11 variables (Constant-Murley Score, 10 sous-scores
                     + Total), lues sur l'event REDCap "fuy1_arm_1"
                     (suivi à 1 an) via val_for_event (le champ n'est
                     pas dédoublé en colonnes, il est répété sur
                     plusieurs events REDCap selon la visite)
"""

import datetime
import os
import sys

# redcap_common.py vit dans le dossier parent (Export/), partagé par toutes
# les tables - on l'ajoute au path pour pouvoir l'importer depuis ce dossier
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from redcap_common import val, to_number, export_table, load_csv, check_columns, get_patient_row, val_for_event

# CSV : partagé, à la racine de Export/. Excel de sortie : propre à ce dossier.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.dirname(BASE_DIR)
INPUT_CSV = os.path.join(EXPORT_DIR, "BASESDEDONNEESEPAULE_DATA_2026-07-13_1134.csv")
OUTPUT_XLSX = os.path.join(BASE_DIR, "REDCap_Extraction.xlsx")

# -------------------------------------------------------------------------
# VARIABLES
# -------------------------------------------------------------------------
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
PLANNING_FIELDS = [
    ("Inclinaison coupe humérale", "mys_hum_plan_incl_prim", "mys_hum_plan_incl_def"),
    ("Retrotorsion humérale", "mys_hum_plan_retro_prim", "mys_hum_plan_retro_def"),
    ("liner inclinaison", "mys_hum_plan_rev_liner_incl_prim", "mys_hum_plan_rev_liner_incl_def"),
    ("Taille de stem", "mys_hum_plan_stem_size_prim", "mys_hum_plan_stem_size_def"),
    ("Type de stem", "mys_hum_plan_imp_type_prim", "mys_hum_plan_imp_type_def"),
    ("Inclinaison glénoïdienne", "mys_glen_plan_sup_incl_prim", "mys_glen_plan_sup_incl_def"),
    ("Version glénoïdienne", "mys_glen_plan_retrov_prim", "mys_glen_plan_retrov_def"),
    ("Offset médial glénoïde", "mys_glen_plan_med_off_prim", "mys_glen_plan_med_off_def"),
    ("Taille glénosphère", "mys_glen_imp_gs_size_prim", "mys_glen_imp_gs_size_def"),
    ("Type de glenosphère", "mys_glen_imp_gs_type_prim", "mys_glen_imp_gs_type_def"),
]
SIMULATION_FIELDS = [
    ("Distalisation CoR", "my3d_humeral_dist"),
    ("Antériorisation CoR", "my3d_humeral_ant"),
    ("Latéralisation CoR", "my3d_humeral_lat"),
    ("Flexion", "my3d_max_flex"),
    ("Abduction", "my3d_max_abd"),
]

EVENT_POST = "fuy1_arm_1"
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

# Codes REDCap -> libellé affiché, pour les champs qui en ont besoin.
# Un code absent de ce dictionnaire est affiché tel quel.
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
    """Applique le formatage/libellé propre à un champ Opération/Prothèse."""
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


def resolve_planning_value(row, prim, deff):
    """Définitif par défaut ; si '-' (= identique au plan), on prend le
    plan ; si les deux sont vides, la cellule affiche 'R'."""
    d = val(row, deff)
    if str(d).strip() == "-":
        d = val(row, prim)
    if d == "":
        return "R"
    return to_number(d)


# -------------------------------------------------------------------------
# EN-TÊTE (2 lignes)
# -------------------------------------------------------------------------
n_op, n_pr = len(OPERATION_FIELDS), len(PROTHESE_FIELDS)
n_plan, n_sim = len(PLANNING_FIELDS), len(SIMULATION_FIELDS)
n_cms = len(CMS_FIELDS)

header1 = (
    [""]
    + ["Opération"] + [""] * (n_op - 1)
    + [""] + ["Prothèse"] + [""] * (n_pr - 1)
    + [""] + ["Planning"] + [""] * (n_plan - 1)
    + [""] + ["Simulation"] + [""] * (n_sim - 1)
    + [""] + ["CMS"] + [""] * (n_cms - 1)
)
header2 = (
    ["ID REDCap"]
    + [label for label, _ in OPERATION_FIELDS]
    + [""]
    + [label for label, _ in PROTHESE_FIELDS]
    + [""]
    + [label for label, _, _ in PLANNING_FIELDS]
    + [""]
    + [label for label, _ in SIMULATION_FIELDS]
    + [""]
    + [label for label, _ in CMS_FIELDS]
)

merges = [
    (2, n_op + 1),
    (n_op + 3, n_op + 2 + n_pr),
    (n_op + n_pr + 4, n_op + n_pr + 3 + n_plan),
    (n_op + n_pr + n_plan + 5, n_op + n_pr + n_plan + 4 + n_sim),
    (n_op + n_pr + n_plan + n_sim + 6, n_op + n_pr + n_plan + n_sim + 5 + n_cms),
]

check_columns(
    load_csv(INPUT_CSV),
    [f for _, f in OPERATION_FIELDS]
    + [f for _, f in PROTHESE_FIELDS]
    + [f for _, prim, deff in PLANNING_FIELDS for f in (prim, deff)]
    + [f for _, f in SIMULATION_FIELDS]
    + [f for _, f in CMS_FIELDS] + ["redcap_event_name"],
)


# -------------------------------------------------------------------------
# CONSTRUCTION D'UNE LIGNE
# -------------------------------------------------------------------------
def build_row(df, rid):
    row = get_patient_row(df, rid)

    cms_raw = [val_for_event(row, f, EVENT_POST) for _, f in CMS_FIELDS]

    has_data = row is not None and (
        any(val(row, f) != "" for _, f in OPERATION_FIELDS)
        or any(val(row, f) != "" for _, f in PROTHESE_FIELDS)
        or any(val(row, prim) != "" or val(row, deff) != "" for _, prim, deff in PLANNING_FIELDS)
        or any(val(row, f) != "" for _, f in SIMULATION_FIELDS)
        or any(v != "" for v in cms_raw)
    )
    if not has_data:
        return False, None

    operation_vals = [transform(f, val(row, f)) for _, f in OPERATION_FIELDS]
    prothese_vals = [transform(f, val(row, f)) for _, f in PROTHESE_FIELDS]
    planning_vals = [resolve_planning_value(row, prim, deff) for _, prim, deff in PLANNING_FIELDS]
    simulation_vals = [to_number(val(row, f)) for _, f in SIMULATION_FIELDS]
    cms_vals = [to_number(v) for v in cms_raw]

    line = (
        operation_vals + [""]
        + prothese_vals + [""]
        + planning_vals + [""]
        + simulation_vals + [""]
        + cms_vals
    )
    return True, line


# -------------------------------------------------------------------------
# EXPORT
# -------------------------------------------------------------------------
export_table(OUTPUT_XLSX, "PostOp", header1, header2, merges, build_row, input_csv=INPUT_CSV)
