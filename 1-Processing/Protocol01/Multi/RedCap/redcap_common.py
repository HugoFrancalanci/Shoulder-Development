"""
Partie commune à tous les scripts d'extraction REDCap.
-----------------------------------------------------------------
Un script d'extraction par table (planning, preop, postop, ...) importe ce
module et ne définit que ce qui lui est propre : ses variables, la mise en
page de son en-tête, et comment construire une ligne à partir d'une ligne
REDCap.

Ce module gère ce qui ne change jamais d'une table à l'autre :
  - lecture du CSV REDCap
  - la liste des patients à extraire (ID_REDCAP), partagée par toutes les
    tables puisque c'est la même cohorte
  - résolution d'un id_redcap vers sa ligne (ou None si vide/introuvable)
  - conversion en nombre pour éviter le warning Excel "stocké en texte"
  - ligne vide avant chaque patient, ligne "R" si aucune donnée, ID affiché
    même quand la ligne est vide/introuvable ("ID Recap not available" si
    id_redcap n'a pas été renseigné)
"""

import datetime

import pandas as pd
from openpyxl import Workbook
from openpyxl.utils import get_column_letter

# -------------------------------------------------------------------------
# CONFIGURATION PARTAGÉE
# -------------------------------------------------------------------------
INPUT_CSV = r"C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\02_Database\01_E02_Classification_rTSA\RedCap\Export\BASESDEDONNEESEPAULE_DATA_2026-07-08_1945.csv"

# ID REDCap des patients à extraire (même cohorte pour toutes les tables)
ID_REDCAP = [
    '20220803_104800_93',   # 1
    '20220613_094000_17',   # 2
    '20220601_112300_25',   # 3
    '20220919_113000_80',   # 4
    '20220905_114400_79',   # 5
    '20211129_100500_03',   # 6
    '20220815_123800_98',   # 7
    '20220817_122100_85',   # 8
    '20220406_083000_48',   # 9
    '20221111_082900_71',   # 10
    '20230208_084300_05',   # 11
    '20220831_104400_09',   # 12
    '20220729_103200_59',   # 13
    '20220902_081900_50',   # 14
    '20220914_083100_73',   # 15
    '20221007_084300_34',   # 16
    '20220930_105900_40',   # 17
    '20220930_135200_50',   # 18
    '20230111_112800_10',   # 19
    '20221104_083500_76',   # 20
    '20221121_131200_66',   # 21
    '20221107_094000_82',   # 22
    '20221123_105600_29',   # 23
    '20221123_082200_13',   # 24
    '',                     # 25 (vide)
    '20221130_105300_14',   # 26
    '20221128_151800_98',   # 27
    '20230111_085600_30',   # 28
    '20230113_084600_51',   # 29
    '20221214_084100_38',   # 30
    '20230329_090300_60',   # 31
    '20221130_083300_20',   # 32
    '20221205_093700_41',   # 33
    '20230109_093200_59',   # 34
    '20230125_082800_23',   # 35
    '20230118_082300_04',   # 36
    '20230116_094600_59',   # 37
    '20230123_093100_86',   # 38
    '20230227_124100_50',   # 39
    '20230125_140300_08',   # 40
    '20230213_135200_97',   # 41
    '20230320_094400_14',   # 42
    '20230322_083200_29',   # 43
    '20230310_111600_29',   # 44
    '20230403_092800_17',   # 45
    '20230510_085400_11',   # 46
    '20230522_112000_98',   # 47
]


# -------------------------------------------------------------------------
# LECTURE / RÉSOLUTION
# -------------------------------------------------------------------------
def load_csv(input_csv=INPUT_CSV):
    return pd.read_csv(input_csv, dtype=str)


def check_columns(df, fields):
    missing = [c for c in fields if c not in df.columns]
    if missing:
        raise ValueError(f"Colonnes introuvables dans le CSV : {missing}")


def get_patient_row(df, rid):
    """Lignes REDCap (DataFrame) pour un id_redcap, ou None si vide/absent.

    Un même id_redcap peut correspondre à PLUSIEURS lignes du CSV (events ou
    instruments répétés REDCap) : chaque ligne ne porte souvent qu'une
    partie des champs, le reste étant vide sur cette ligne-là. On renvoie
    donc toutes les lignes ; val() se charge d'aller chercher la bonne."""
    if rid == "":
        return None
    match = df[df["id_redcap"] == rid]
    if match.empty:
        print(f"ATTENTION - id_redcap introuvable dans le CSV : {rid}")
        return None
    return match


def val(rows, field):
    """Première valeur non vide de `field`, cherchée parmi toutes les
    lignes (events/instruments) d'un patient - le champ voulu peut être
    renseigné sur une ligne différente de celle des autres champs."""
    if rows is None:
        return ""
    for v in rows[field]:
        if not pd.isna(v) and str(v).strip() != "":
            return v
    return ""


def to_number(v):
    """Convertit en int/float si la valeur est numérique, sinon la laisse
    telle quelle (texte) - évite le warning Excel 'nombre stocké en texte'."""
    if not isinstance(v, str) or v.strip() == "":
        return v
    try:
        f = float(v.strip())
        return int(f) if f.is_integer() else f
    except ValueError:
        return v


# -------------------------------------------------------------------------
# ÉCRITURE DU TABLEAU
# -------------------------------------------------------------------------
def export_table(output_xlsx, sheet_title, header1, header2, merges, build_row,
                  id_redcap=ID_REDCAP, input_csv=INPUT_CSV, text_cols=None):
    """
    header1, header2 : lignes d'en-tête (listes), même longueur.
    merges            : liste de (start_col, end_col) 1-based à fusionner sur header1.
    build_row(df, rid): doit retourner (has_data: bool, data_cols: list | None).
                        data_cols exclut la colonne ID (longueur = len(header2) - 1).
    text_cols         : liste de colonnes (1-based) à forcer en format Texte -
                        utile pour des codes/grades qui ressemblent à des
                        nombres ("0","1","2"...) mais n'en sont pas
                        (évite le warning Excel "nombre stocké en texte").
    """
    df = load_csv(input_csv)

    n_cols = len(header2)
    blank_row = [""] * n_cols

    wb = Workbook()
    ws = wb.active
    ws.title = sheet_title
    ws.append(header1)
    ws.append(header2)
    for start_col, end_col in merges:
        ws.merge_cells(start_row=1, start_column=start_col, end_row=1, end_column=end_col)

    for rid in id_redcap:
        has_data, data_cols = build_row(df, rid)

        ws.append(blank_row)

        if not has_data:
            id_display = rid if rid != "" else "ID RedCap not available"
            ws.append([id_display] + ["R"] * (n_cols - 1))
        else:
            ws.append([rid] + data_cols)

        # Format Excel des dates (sinon Excel affiche "####" ou un format US)
        for cell in ws[ws.max_row]:
            if isinstance(cell.value, datetime.date):
                cell.number_format = "DD.MM.YYYY"

    # Colonnes forcées en Texte (codes/grades ressemblant à des nombres)
    if text_cols:
        for col_idx in text_cols:
            for cell in ws[get_column_letter(col_idx)][2:]:  # sous les 2 lignes d'en-tête
                cell.number_format = "@"

    # Largeur de colonne auto (évite les "####" sur dates/nombres, colonnes
    # trop étroites pour le contenu)
    for col_idx in range(1, n_cols + 1):
        max_len = max(
            (len(str(cell.value)) for cell in ws[get_column_letter(col_idx)] if cell.value is not None),
            default=0,
        )
        ws.column_dimensions[get_column_letter(col_idx)].width = max(10, min(max_len + 2, 40))

    wb.save(output_xlsx)
    print(f"{len(id_redcap)} ligne(s) écrite(s) -> {output_xlsx}")
