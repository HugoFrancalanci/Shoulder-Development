# Pipeline multi-patients

Traite une liste de patients/côtés définie à l'avance et exporte un rapport
Excel, en réutilisant le traitement du protocole solo (`MAIN_Protocol_01.m`)
sans jamais écrire dans les données patients (lecture seule).

## Fichiers

- **`MAIN_MULTI_Protocol_01.m`** — script à lancer. Boucle sur les patients,
  appelle `runProtocol01()` par session, accumule les résultats, exporte l'Excel.
- **`runProtocol01.m`** — version "fonction" de `MAIN_Protocol_01.m` (voir
  plus bas). Ne pas supprimer : c'est le moteur de calcul utilisé par le script multi.
- **`userCommands_Multi.m`** — le seul fichier à modifier pour choisir les
  patients à traiter. Jamais touché par le script lui-même.

## Comment le script accède aux patients

1. `DataFolder` (défini dans `userCommands_Multi.m`, ou choisi via une
   fenêtre si laissé vide) est le dossier racine contenant un sous-dossier
   par patient, nommé `NomFamille_Prénom_ID` (ex: `Mottet_André_97516068`).
2. Pour chaque ligne de `PatientSelection`, le script retrouve le dossier
   patient en cherchant l'**ID** comme sous-chaîne du nom de dossier — pas
   besoin de taper le nom complet.
3. Dans ce dossier patient, chaque sous-dossier de session est nommé
   `YYYYMMDD`. Le script cherche le dossier dont le nom **commence par** la
   valeur donnée dans `PatientSelection` (date complète `'20231003'` ou
   juste l'année `'2023'`) — une colonne pour PRE, une pour POST.
4. Le côté à garder (`R`, `L`, ou `RL` pour les deux ; `1`/`0` acceptés comme
   raccourci Gauche/Droit) filtre les résultats mais pas le calcul : les
   deux côtés sont toujours traités par `runProtocol01`, seul le
   **reporting** est filtré.

Si un dossier ou une session est introuvable, le patient est loggé dans
`ErrorLog` (affiché en fin d'exécution) et le script continue avec le
patient suivant — un patient en erreur ne bloque jamais les autres.

## Lien avec le script solo

- `MAIN_Protocol_01.m` (dans `Protocol01/`) = traitement interactif d'**un**
  patient : ouvre des popups de sélection, affiche les plots, lance les
  validations (TestICS, TestHG), et les résumés console (ExportPostureSummary,
  ExportKinematicsSummary). Pensé pour inspecter les résultats à la main.
- `runProtocol01.m` (dans `Multi/`) = **exactement le même calcul cinématique**
  (import session, chargement C3D, `ComputeKinematics`, `ComputeThoraxPosture`,
  `CutCycles`, `ComputeSHR`...) mais encapsulé en fonction
  `[Trial, Patient, Session, Pathology] = runProtocol01(Folder)`, sans popup
  ni plot, pour pouvoir tourner en boucle sans intervention.
- `MAIN_MULTI_Protocol_01.m` appelle `runProtocol01()` une fois par
  patient/session, puis extrait les métriques qui l'intéressent depuis le
  `Trial` retourné.

Toute évolution du calcul cinématique lui-même (nouvelle correction, nouveau
joint...) se fait dans les fichiers `Core/` communs aux deux pipelines — pas
besoin de dupliquer entre solo et multi.

## Reporting actuel : contributions humérothoraciques (GH/ST/TX)

`Core/ComputeHTContributions.m` décompose le range humérothoracique (HT) en
contributions gléno-humérale (GH), scapulo-thoracique (ST) et thoracique
(TX), pour ANALYTIC2 (seule tâche uniplanaire, donc seule décomposition
jugée fiable — voir les commentaires du fichier pour le détail des DOF).

Le résultat est accumulé dans le struct `Results` (une ligne par
patient/côté), avec les colonnes PRE et POST côte à côte :
`PatientID, Side, Task, HT_PRE_deg, GH_PRE_deg, GH_PRE_pct, ST_PRE_deg,
ST_PRE_pct, TX_PRE_deg, TX_PRE_pct, HT_POST_deg, GH_POST_deg, ...`

## Ajouter un nouveau reporting

1. Écrire une fonction `Core/ComputeMaMetrique.m` qui prend `Trial` en
   entrée et retourne un struct/valeurs (voir `ComputeHTContributions.m`
   comme modèle : une entrée par côté, gestion des cas manquants avec `NaN`).
2. Dans `MAIN_MULTI_Protocol_01.m`, l'appeler juste après
   `ComputeHTContributions(Trial)` (même endroit, dans la boucle patient/session).
3. Ajouter les champs correspondants au struct `Results` (au début du
   script, dans les deux blocs d'initialisation NaN et de remplissage) —
   même logique PRE/POST côte à côte que pour HT/GH/ST/TX.
4. `struct2table(Results)` reprend automatiquement les nouvelles colonnes,
   rien à changer côté export Excel.

Pas besoin de toucher à `runProtocol01.m` : le `Trial` retourné contient déjà
toutes les données cinématiques (`Trial(k).Joint`, `.Euler`, `.rcycle`,
`.lcycle`...) nécessaires à n'importe quelle nouvelle métrique.
