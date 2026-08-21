# Pipeline multi-patients

Traite une liste de patients/côtés définie à l'avance et exporte un rapport
Excel, en réutilisant le traitement du protocole solo (`MAIN_Protocol_01.m`)
sans jamais écrire dans les données patients (lecture seule).

## Fichiers

- **`MAIN_MULTI_Protocol_01.m`** — script à lancer en premier. Traite les
  patients par paquets de `BatchSize` (voir `userCommands_Multi.m`), chaque
  paquet en parallèle (`parfor` - un patient par worker), appelle
  `runProtocol01()` par session (relit les C3D - c'est l'étape lente),
  exporte `PatientInfos`/`DataAvailability` en Excel. Si `SaveDatabase=true`,
  sauvegarde aussi `Trial` (sans `.btk`) + `Patient`/`Session`/`Pathology` de
  chaque patient, répartis sur `NumDatabaseParts` fichiers
  `Results/..._partXofY.mat` (`BatchSize` est aligné sur `NumDatabaseParts`
  dans `userCommands_Multi.m` - un paquet = une partie exactement).
  Chaque partie est écrite en **un seul bloc** (`save(...,'-v7.3','-nocompression')`)
  une fois tous ses patients traités, puis vidée de la RAM - pas en
  écritures partielles indexées au fil des paquets comme avant : mesuré
  ~25x plus lent, car le coût des écritures partielles dans un struct array
  imbriqué stocké en `-v7.3`/HDF5 est un coût fixe par appel, indépendant du
  volume réel écrit (la compression seule n'explique pas ce coût - testé).
  **Reprise automatique** : granularité par **partie** (pas par patient) -
  le statut (léger, `PartDone` + `PatientInfos`/`DataAvailPerPatient`, pas
  les `Trial` complets) est suivi dans `Results/PatientDatabase_progress.mat` ;
  si le script est interrompu (plantage, fermeture), les parties déjà
  écrites ne sont pas retraitées au prochain lancement, mais une partie
  interrompue en cours de traitement est retraitée entièrement (jusqu'à
  `BatchSize` patients), pas seulement les patients manquants - contrepartie
  acceptée du gain de vitesse.
- **`userCommands_Multi.m`** — le seul fichier à modifier pour choisir les
  patients à traiter. Jamais touché par le script lui-même.
- **`Core/`, `IO/`** — fonctions propres au pipeline multi, ajoutées au path
  par `MAIN_MULTI_Protocol_01.m`. Séparées des dossiers `Core/`, `IO/`,
  `Plot/` de `Protocol01/` (ceux-là restent partagés avec le
  solo, et sont ajoutés au path par `runProtocol01.m` pour le calcul
  cinématique commun) :
  - `Core/runProtocol01.m` — version "fonction" de `MAIN_Protocol_01.m` (voir
    plus bas). Ne pas supprimer : c'est le moteur de calcul utilisé par le
    script multi.
  - `Core/StripBtkFromTrial.m` — retire `.btk` (handle BTK non réutilisable)
    de `Trial` avant sauvegarde dans `PatientDatabase.mat`.
  - `Core/ComputeClinicalContributionsFromDatabase.m` — **pas appelée pendant le run C3D**,
    callable à tout moment depuis la fenêtre de commande une fois
    `PatientDatabase.mat` généré : `ComputeClinicalContributionsFromDatabase(DatabaseFile,
    OutputFile, ResultsFolder)`. Recharge le `.mat` et calcule le rapport
    HT/GH/ST/TX en quelques secondes sur toute la cohorte, sans repasser
    par les C3D. Fonction centralisée : la décomposition HT/GH/ST/TX
    (ex-`ComputeHTContributions.m`, renommée `ComputeClinicalContributions` -
    même convention DOF/joint que le Tableau 2 "Clinical analysis" de
    `Protocol01/IO/ExportKinematicsSummary.m`, vérifié identique) et le
    tracé PRE/POST (ex-`PlotHTContributionsCurves.m`), auparavant des
    fichiers séparés, sont fusionnés dedans comme fonctions locales, à la
    fin du fichier.
    Nouvelle analyse du même genre (posture, Moroder...) : même patron - un
    fichier `Multi/Core/ComputeXxxFromDatabase.m` séparé, appelée sur
    `Database(i).PRE.Trial`/`.POST.Trial`.
  - `Core/ComputePatientInfos.m`, `Core/ComputeDataAvailability.m`,
    `IO/ExportPatientInfos.m`, `IO/ExportDataAvailability.m` — reporting.
- **`RedCap/`** — copie locale du prototype Python (Spyder) d'export REDCap ;
  la version de référence à jour (avec sa notice) vit sur OneDrive, hors
  dépôt git (voir mémoire de session pour le chemin).
- **`Results/`** — tous les fichiers de sortie y sont écrits (chemins
  définis dans `userCommands_Multi.m`) : `ClinicalContributions_Summary.xlsx`,
  `PatientInfos_Summary.xlsx`, `DataAvailability_Summary.xlsx`,
  `PatientDatabase.mat` et son compagnon `PatientDatabase_progress.mat`
  (si `SaveDatabase=true` - voir reprise automatique ci-dessus ; ne pas
  supprimer l'un sans l'autre, sinon la reprise redémarre de zéro ou, pire,
  se croit à jour alors que `PatientDatabase.mat` a été effacé). Les scripts
  s'y terminent (`cd`) une fois le run fini, pour les retrouver facilement.

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
- `runProtocol01.m` (dans `Multi/Core/`) = **exactement le même calcul cinématique**
  (import session, chargement C3D, `ComputeKinematics`, `ComputeThoraxPosture`,
  `CutCycles`, `ComputeSHR`...) mais encapsulé en fonction
  `[Trial, Patient, Session, Pathology] = runProtocol01(Folder)`, sans popup
  ni plot, pour pouvoir tourner en boucle sans intervention.
- `MAIN_MULTI_Protocol_01.m` appelle `runProtocol01()` une fois par
  patient/session, puis extrait les métriques qui l'intéressent depuis le
  `Trial` retourné.

Toute évolution du calcul cinématique lui-même (nouvelle correction, nouveau
joint...) se fait dans les fichiers `Protocol01/Core/` communs aux deux
pipelines — pas besoin de dupliquer entre solo et multi. Les fonctions
propres au reporting multi-patients (Compute*/Export* listées ci-dessus),
elles, vivent dans `Multi/Core/`, `Multi/IO/`.

## Reporting actuel : contributions cliniques humérothoraciques (GH/ST/TX)

`Multi/Core/ComputeClinicalContributionsFromDatabase.m` recharge `PatientDatabase.mat` et
décompose, pour chaque patient/côté, le range humérothoracique (HT) en
contributions gléno-humérale (GH), scapulo-thoracique (ST) et thoracique
(TX), pour ANALYTIC2 (seule tâche uniplanaire, donc seule décomposition
jugée fiable — voir les commentaires de la fonction locale
`ComputeClinicalContributions` en bas du fichier pour le détail des DOF).
Callable à tout moment depuis la fenêtre de commande, sans repasser par les
C3D ni par `MAIN_MULTI_Protocol_01.m`.

Le résultat est accumulé dans le struct `Results` (une ligne par
patient/côté), avec les colonnes PRE et POST côte à côte :
`PatientID, Side, Task, HT_PRE_deg, GH_PRE_deg, GH_PRE_pct, ST_PRE_deg,
ST_PRE_pct, TX_PRE_deg, TX_PRE_pct, HT_POST_deg, GH_POST_deg, ...`

Elle extrait aussi `HT_curve`/`GH_curve`/`ST_curve`/`TX_curve` (angle vs % cycle),
accumulées à part dans `Curves` et tracées par la fonction locale
`PlotHTContributionsCurves` (aussi fusionnée dans `ComputeClinicalContributionsFromDatabase.m`)
- PRE en rouge, POST en bleu, courbes individuelles transparentes + moyenne
en gras.

## Autre reporting : éligibilité de l'épaule controlatérale

`Multi/Core/ComputeContralateralEligibilityFromDatabase.m` recharge
`PatientDatabase.mat` et évalue, pour l'épaule **controlatérale** (opposée
au côté analysé/opéré, `Database(i).Side`) de chaque patient, 3 critères
d'éligibilité comme épaule de référence asymptomatique :

1. ROM HT (Euler, DOF dépendant de la tâche : 3=Z flexion/extension pour
   ANALYTIC1, 1=X élévation/abduction pour ANALYTIC2 - voir
   Protocol01/Core/ComputeKinematics.m) > 150° sur ANALYTIC1 ou ANALYTIC2
   (PRE puis POST si PRE indisponible).
2. EVA moyen (4 tâches ANALYTIC) du côté controlatéral == 0 (PRE puis POST).
3. Aucune mention du côté controlatéral dans `Diagnosis`/`PlanedSurgery`/
   `PreviousSurgery` (recherche de mot-clé "droit"/"gauche" dans le texte
   libre - confirmé sur des données réelles que le côté y est toujours
   précisé), union PRE+POST.

Callable à tout moment, même patron que
`ComputeClinicalContributionsFromDatabase` :
`ComputeContralateralEligibilityFromDatabase(DatabaseFile, ContralateralEligibilityFile, ResultsFolder)`.
Un critère vide (`''`) signale une donnée manquante (distinct de "Non") ;
`Eligible_Overall` reste vide tant qu'un critère est vide, sinon `Oui`
seulement si les 3 critères sont `Oui`. `Antecedents_Details` liste le(s)
champ(s) ayant déclenché un `Non`, pour vérification manuelle facile.

## Autre reporting : infos démographiques/cliniques patient

`Multi/Core/ComputePatientInfos.m` + `Multi/IO/ExportPatientInfos.m`
exportent, dans un 2e fichier Excel (`PatientInfosFile`), un résumé par
patient : ID (initiales), Genre/Latéralité (1/0), Age/Taille/Masse/IMC en
PRE/POST, et un score de douleur EVA (moyenne des 4 tâches ANALYTIC côté
atteint) écrit comme une vraie formule Excel cliquable. Si le côté atteint
n'a pas de donnée, la cellule se replie sur l'autre côté et est marquée en
orange + commentaire pour ne jamais être confondue avec une vraie mesure du
côté atteint.

## Ajouter un nouveau reporting

D'abord choisir où : est-ce que le calcul a besoin d'un état qui n'existe
que PENDANT le run C3D (ex: `c3dFiles`, comme `ComputeDataAvailability.m`),
ou seulement de valeurs déjà calculées dans `Trial` (`.Segment`, `.Joint`,
`.Euler`, `.rcycle`/`.lcycle`...) ? Dans le 2e cas (le plus courant),
préférer une fonction `Multi/Core/ComputeXxxFromDatabase.m` (voir
`ComputeClinicalContributionsFromDatabase.m` comme modèle) : le calcul tourne en quelques
secondes sur toute la cohorte au lieu de re-router par `runProtocol01`/C3D,
et reste callable à tout moment sans rien relancer.

1. Écrire une fonction `ComputeMaMetrique(Trial)` qui retourne un
   struct/valeurs (voir la fonction locale `ComputeClinicalContributions`
   en bas de `ComputeClinicalContributionsFromDatabase.m` comme modèle : une entrée par côté,
   gestion des cas manquants avec `NaN`).
2. L'appeler pour chaque patient/condition :
   - Depuis `PatientDatabase.mat` : une fonction `Multi/Core/ComputeMaMetriqueFromDatabase.m`
     (voir `ComputeClinicalContributionsFromDatabase.m` comme modèle) qui charge le `.mat` et
     boucle sur `Database(i).PRE.Trial`/`.POST.Trial`.
   - Depuis le run C3D live : dans `MAIN_MULTI_Protocol_01.m`, juste après
     l'appel à `runProtocol01()`.
3. Ajouter les champs correspondants au struct accumulateur (`Results` ou
   équivalent, au début du script, dans les deux blocs d'initialisation NaN
   et de remplissage) — même logique PRE/POST côte à côte que pour HT/GH/ST/TX.
4. `struct2table(...)` reprend automatiquement les nouvelles colonnes, rien
   à changer côté export Excel.

Pas besoin de toucher à `runProtocol01.m` : le `Trial` qu'il retourne (et
donc celui sauvegardé dans `PatientDatabase.mat`) contient déjà toutes les
données cinématiques nécessaires à n'importe quelle nouvelle métrique.
