"""
Export REDCap - tableau Planning / Paramètres prothèse / Simulation
-----------------------------------------------------------------
Table spécifique : liste des variables, mise en page de l'en-tête, et
construction d'une ligne à partir d'une ligne REDCap. Tout le reste
(lecture CSV, résolution des ID, lignes vides/"R", conversion numérique)
vient de redcap_common.py.

  Bloc "Planning"           : valeur planifiée (_prim) des 10 variables
  Bloc "Paramètres prothèse": pour chaque variable, [Modification
                              peropératoire] puis la valeur définitive
                              (_def), + colonne finale "Total modification
                              peropératoire"
  Bloc "Simulation"         : 5 variables simples (pas de paire plan/def) -
                              déplacement du centre de rotation huméral
                              simulé et amplitudes max avant impingement
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

# Variables, dans l'ordre voulu : (libellé affiché, champ REDCap planifié, champ REDCap définitif)
VARIABLES = [
    ("Inclinaison coupe humérale", "mys_hum_plan_incl_prim", "mys_hum_plan_incl_def"),
    ("Retroversion humérale", "mys_hum_plan_retro_prim", "mys_hum_plan_retro_def"),
    ("liner inclinaison", "mys_hum_plan_rev_liner_incl_prim", "mys_hum_plan_rev_liner_incl_def"),
    ("Taille stem", "mys_hum_plan_stem_size_prim", "mys_hum_plan_stem_size_def"),
    ("Type stem", "mys_hum_plan_imp_type_prim", "mys_hum_plan_imp_type_def"),
    ("Inclinaison glénoïdienne", "mys_glen_plan_sup_incl_prim", "mys_glen_plan_sup_incl_def"),
    ("Version glénoïdienne", "mys_glen_plan_retrov_prim", "mys_glen_plan_retrov_def"),
    ("Offset médial glénoïde", "mys_glen_plan_med_off_prim", "mys_glen_plan_med_off_def"),
    ("Taille glénosphère", "mys_glen_imp_gs_size_prim", "mys_glen_imp_gs_size_def"),
    ("Type de glenosphère", "mys_glen_imp_gs_type_prim", "mys_glen_imp_gs_type_def"),
]

# Bloc "Simulation" : pas de paire plan/définitif, une seule valeur par variable
SIMULATION_FIELDS = [
    ("Distalisation CoR", "my3d_humeral_dist"),
    ("Antériorisation CoR", "my3d_humeral_ant"),
    ("Latéralisation CoR", "my3d_humeral_lat"),
    ("Flexion", "my3d_max_flex"),
    ("Abduction", "my3d_max_abd"),
]

# -------------------------------------------------------------------------
# EN-TÊTE (2 lignes)
# -------------------------------------------------------------------------
n_vars = len(VARIABLES)

header1 = (
    [""]
    + ["Planning"] + [""] * (n_vars - 1)
    + [""]
    + ["Paramètres prothèse"] + [""] * (2 * n_vars - 1)
    + [""]
)
header2 = ["ID REDCap"] + [label for label, _, _ in VARIABLES] + [""]
for label, _, _ in VARIABLES:
    header2 += ["Modification peropératoire", label]
header2 += ["Total modification peropératoire"]

merges = [
    (2, n_vars + 1),
    (n_vars + 3, n_vars + 2 + 2 * n_vars),
]

# Bloc "Simulation" ajouté à la suite, avec une colonne vide de séparation
n_sim = len(SIMULATION_FIELDS)
sep_col = len(header2) + 1
sim_start = sep_col + 1
sim_end = sim_start + n_sim - 1

header1 += [""] + ["Simulation"] + [""] * (n_sim - 1)
header2 += [""] + [label for label, _ in SIMULATION_FIELDS]
merges.append((sim_start, sim_end))

check_columns(
    load_csv(INPUT_CSV),
    [f for _, prim, deff in VARIABLES for f in (prim, deff)] + [f for _, f in SIMULATION_FIELDS],
)


# -------------------------------------------------------------------------
# CONSTRUCTION D'UNE LIGNE
# -------------------------------------------------------------------------
def build_row(df, rid):
    row = get_patient_row(df, rid)

    has_data = row is not None and (
        any(val(row, prim) != "" or val(row, deff) != "" for _, prim, deff in VARIABLES)
        or any(val(row, f) != "" for _, f in SIMULATION_FIELDS)
    )
    if not has_data:
        return False, None

    planning_vals = [to_number(val(row, prim)) for _, prim, _ in VARIABLES]

    modif_flags, def_vals = [], []
    for _, prim, deff in VARIABLES:
        p, d = val(row, prim), val(row, deff)
        if str(d).strip() == "-":
            # "-" REDCap = valeur définitive identique au plan
            d = p
        modif_flags.append(1 if p != d else 0)
        def_vals.append(to_number(d))
    total_modif = sum(modif_flags)

    simulation_vals = [to_number(val(row, f)) for _, f in SIMULATION_FIELDS]

    line = planning_vals + [""]
    for flag, d in zip(modif_flags, def_vals):
        line += [flag, d]
    line += [total_modif]
    line += [""] + simulation_vals

    return True, line


# -------------------------------------------------------------------------
# EXPORT
# -------------------------------------------------------------------------
export_table(OUTPUT_XLSX, "Planning_Parametres", header1, header2, merges, build_row, input_csv=INPUT_CSV)
