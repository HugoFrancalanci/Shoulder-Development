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
  patients à traiter (`PatientSelection`) et les épaules asymptomatiques
  tracées en vert (`AsymptomaticSelection`, voir plus bas). Jamais touché
  par le script lui-même.
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
  `FunctionalContributions_Summary.xlsx`, `Posture_Summary.xlsx`, `CoRQuality_Summary.xlsx`,
  `CurveQuality_Summary.xlsx`, `PatientInfos_Summary.xlsx`, `DataAvailability_Summary.xlsx`,
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
(TX), pour ANALYTIC1, ANALYTIC2 (élévations uniplanaires), ANALYTIC3
(rotation externe) et ANALYTIC4 (rotation interne). Le DOF Euler retenu
dépend de la tâche (le mouvement dominant n'est pas stocké au même
DOF selon le plan : Z/DOF3 = flexion/extension pour ANALYTIC1 sagittal,
X/DOF1 = élévation/abduction pour ANALYTIC2 coronal, Y/DOF2 = rotation
axiale pour ANALYTIC3/4 — voir Protocol01/Core/ComputeKinematics.m et les
commentaires de la fonction locale `ComputeClinicalContributions` en bas
du fichier). ST/TX : DOF fixes pour ANALYTIC1/2 (ST upward rotation X, TX
flexion Z), DOF2 Y pour ANALYTIC3/4 (ST protraction/rétraction, TX rotation
axiale). Même convention que `ComputeContralateralEligibilityFromDatabase.m`
pour ANALYTIC1/2.
Callable à tout moment depuis la fenêtre de commande, sans repasser par les
C3D ni par `MAIN_MULTI_Protocol_01.m`.

Le résultat est accumulé dans le struct `Results` (une ligne par
patient/côté/tâche — ANALYTIC1 à ANALYTIC4 sur des lignes séparées), avec
les colonnes PRE et POST côte à côte, plus le pic d'angle atteint
(`*_max_deg`, distinct du range) pour chaque DOF :
`PatientID, Side, Task, HT_PRE_deg, GH_PRE_deg, GH_PRE_pct, ST_PRE_deg,
ST_PRE_pct, TX_PRE_deg, TX_PRE_pct, HT_POST_deg, GH_POST_deg, ...,
HT_PRE_max_deg, GH_PRE_max_deg, ST_PRE_max_deg, TX_PRE_max_deg,
HT_POST_max_deg, ...`

Elle extrait aussi `HT_curve`/`GH_curve`/`ST_curve`/`TX_curve` (angle vs % cycle),
accumulées à part dans `Curves` (avec le `Task` d'origine) et tracées par la
fonction locale `PlotHTContributionsCurves` (aussi fusionnée dans
`ComputeClinicalContributionsFromDatabase.m`) — une figure séparée par
tâche (les tâches ne sont jamais moyennées ensemble, ce sont
des mouvements différents), PRE en rouge, POST en bleu, courbes
individuelles transparentes + moyenne en gras.

## Autre reporting : contributions fonctionnelles huméro-gravitationnelles (GH/ST/TX)

`Multi/Core/ComputeFunctionalContributionsFromDatabase.m` — même patron que
`ComputeClinicalContributionsFromDatabase.m` ci-dessus, même décomposition
**Euler** (pas quaternion), même struct `Results`/`Curves`, même export
Excel, une figure PRE/POST par tâche. Seule différence : utilise **HG**
(huméro-gravitationnel, Joint 12/13 — orientation absolue de l'humérus
dans le référentiel patient-ICS/gravitationnel, séquence YXY, Wu et al.
2005) comme référence d'amplitude globale au lieu de **HT** (huméro-
thoracique, Joint 1/6).

Différence de mapping DOF : contrairement à HT, la séquence Euler de HG
n'est PAS conditionnée par la sous-tâche dans `Protocol01/Core/
ComputeKinematics.m` (seul `contains(..., 'ANALYTIC')` est testé, pas
ANALYTIC1 vs ANALYTIC2) — DOF1 X (position 1) = élévation pour ANALYTIC1/2,
DOF3 Y2 (position 3) = rotation axiale pour ANALYTIC3/4. GH/ST/TX : mêmes
joints et DOF que dans la version HT (y compris DOF2 Y pour ANALYTIC3/4).
**Attention ANALYTIC3/4** : bras le long du corps (élévation HG X ≈ 0), la
séquence YXY est proche du gimbal lock, Y1 et Y2 sont mal séparés —
vérifier `HG_*_deg` contre `HT_*_deg` avant de s'y fier.

Colonnes : `PatientID, Side, Task, HG_PRE_deg, GH_PRE_deg, GH_PRE_pct,
ST_PRE_deg, ST_PRE_pct, TX_PRE_deg, TX_PRE_pct, HG_POST_deg, ..., HG_PRE_max_deg,
GH_PRE_max_deg, ST_PRE_max_deg, TX_PRE_max_deg, HG_POST_max_deg, ...`
(export Excel, feuille `Functional_Contributions`).

## Correction des courbes ST et TX « inversées » (clinical + functional)

`Multi/Core/ApplyInversionCorrectionSTTX.m`, appelée par
`ComputeClinicalContributionsFromDatabase` (dénominateur HT) et
`ComputeFunctionalContributionsFromDatabase` (dénominateur HG) avant l'export
Excel.

**Problème.** L'angle de repos de ST (et de TX) diffère fortement selon les
patients : par exemple environ -10° pour la majorité des ST, +20° à +50° pour
d'autres, avec un mouvement de même sens et d'amplitude proche. `abs()` retourne
les courbes négatives en cloche mais pas les positives, qui restent en U et vont
à l'opposé de la moyenne. Le range (max-min) n'est pas touché quand le brut ne
traverse pas zéro ; la courbe et le max le sont. Cause du décalage de repos ST
non identifiée (hypothèse : construction du repère scapulaire à partir des
repères IA/RS/AA, `DefineSegments.m`/`AddACMLandmarks.m`) ; non vérifiée.

**Détection.** Par tâche et par métrique (ST, TX ; PRE/POST/côtés confondus), la
courbe `abs` (moyenne des cycles, 101 points) est corrélée (Pearson signé) à la
courbe moyenne du groupe, recalculée sans les courbes inversées (2 passes).
Corrélation < `CorrThresh` (0) = inversée. Même règle que
`ComputeCurveQualityFromDatabase.m` (la rugosité n'entre pas ici dans le choix
de la référence).

**Correction** (courbes inversées uniquement), `repos` = moyenne du début et de
la fin du cycle du patient, `sp` = sens de l'excursion brute du patient (+1/-1),
`repos_cohorte` = repos de la courbe moyenne du groupe :

* courbe : `sp * (brut - repos) + repos_cohorte`
* `_deg` (range) : moyenne des cycles de (max - min) du brut (indépendant du
  signe et de l'offset)
* `_max_deg` : moyenne des cycles de `max(sp * (brut - repos))` + `repos_cohorte`
* `_pct` : range corrigé / range HT (clinical) ou HG (functional)

Colonnes `ST_PRE_corrected`, `ST_POST_corrected`, `TX_PRE_corrected`,
`TX_POST_corrected` (0/1) dans l'Excel : valeurs corrigées. Compte par tâche
affiché en console. Quatrième argument optionnel des deux fonctions :
`struct('ApplyInvCorr', false)` pour retrouver les valeurs non corrigées,
`struct('CorrThresh', ...)` pour changer le seuil.

**Réserve TX.** L'angle du thorax reflète en partie la posture réelle du
patient ; remplacer son niveau de repos par celui de la cohorte efface cette
information (le range est conservé). À interpréter avec précaution.

Cinquième argument optionnel de `ApplyInversionCorrectionSTTX` : les
conditions à traiter (`{'PRE','POST'}` par défaut ; `{'ASYM'}` pour les
épaules asymptomatiques, voir section suivante).

## Épaules asymptomatiques (courbes vertes, clinical + functional)

`AsymptomaticSelection` (dans `userCommands_Multi.m`) liste les épaules
asymptomatiques retenues parmi les patients de `PatientSelection` :
`{ID patient, côté asymptomatique, 'PRE'/'POST', date de session}`. Le côté
est le côté **opposé** à celui de `PatientSelection` (l'épaule
controlatérale) ; la date est celle de la colonne PRE (col. 3) ou POST
(col. 4) de la ligne correspondante de `PatientSelection`, selon la condition
retenue. Le commentaire `% N` renvoie au numéro de ligne dans
`PatientSelection`.

Pas de retraitement des C3D : `runProtocol01` calcule toujours les deux
côtés et `PatientDatabase.mat` les garde, donc les courbes controlatérales
sont déjà dans la base. `MAIN_MULTI_Protocol_01.m` passe la liste aux deux
fonctions via le quatrième argument :
`struct('AsymptomaticSelection', {AsymptomaticSelection})`. Si l'option est
absente ou vide, le comportement est inchangé.

**Correspondance** (fonction locale `findAsymptomaticSide`, dans les deux
fichiers) : même `PatientID`, même condition, côté différent du côté analysé
(`Database(i).Side` ; lève l'ambiguïté des patients présents sur deux lignes,
un côté chacune) et nom du dossier de session commençant par la date donnée.
La console affiche `Épaules asymptomatiques retrouvées : X / N` : si X < N,
certaines épaules n'ont pas été retrouvées dans la base.

**Tracé.** Sur les figures `PlotHTContributionsCurves` /
`PlotHGContributionsCurves`, les courbes de chaque épaule asymptomatique sont
en vert transparent et leur moyenne en vert gras (`n` en légende), à côté des
courbes PRE (rouge) et POST (bleu) des patients, par tâche. Les courbes des
patients (côté de `PatientSelection`, PRE/POST) ne changent pas.

**Correction ST/TX.** Les courbes asymptomatiques passent par
`ApplyInversionCorrectionSTTX` dans un appel **séparé** (condition `'ASYM'`,
référence = moyenne des asymptomatiques seules), pour ne pas modifier la
référence ni les résultats des patients.

**Export.** Feuille séparée dans chaque Excel (`Clinical_Asymptomatic`,
`Functional_Asymptomatic`), une ligne par épaule/tâche pour la seule condition
retenue : `Numero, PatientID, Side, Task, Condition, HT_ASYM_deg` (ou
`HG_ASYM_deg`), `GH/ST/TX_ASYM_deg`, `GH/ST/TX_ASYM_pct`, `*_ASYM_max_deg`, et
`ST/TX_ASYM_corrected` (0/1) si la correction est active. Les feuilles
principales (`Clinical_Contributions`, `Functional_Contributions`) sont
inchangées.

**Contrôle qualité.** Même option passée à
`ComputeCoRQualityFromDatabase` (5e argument) et
`ComputeCurveQualityFromDatabase` (`Opts`) :

* `CoR_Asymptomatic` (dans `CoRQuality_Summary.xlsx`) : une ligne par épaule,
  condition retenue seulement — résidu SCoRE du côté asymptomatique
  (`Session.SCoRE.R/.L`), RMS des clusters, `Flag` au même seuil. Pas sur la
  figure.
* `Curve_Quality_Asymptomatic` + `Summary_Asymptomatic` (dans
  `CurveQuality_Summary.xlsx`) : mêmes colonnes et mêmes critères
  (`Rough`, `Inversee`) que `Curve_Quality`, mais scorées **à part** (référence
  = moyenne des asymptomatiques seules, comme la correction ST/TX ci-dessus) :
  les verdicts des patients ne changent pas. Pas sur les figures. Avec ~26
  épaules par groupe, les z-scores robustes sont moins stables que sur la
  cohorte patients.

## Autre reporting : posture (inclinaison thoracique + Moroder)

`Multi/Core/ComputePostureFromDatabase.m` recharge `PatientDatabase.mat` et lit
`Trial(k).Joint(11).PostureSummary`, déjà calculé pendant le run C3D par
`Protocol01/Core/Thorax/ComputeThoraxPosture.m` (rien n'est recalculé) :

* `Inclination_<C>_deg` : `thoracic_curvature_angle`, angle 3D TV8→CV7 vs
  verticale, moyenne des 100 premières frames (0° = thorax vertical)
* `PostureType_<C>` : `Erect` (< 32°) / `Slouched` (≥ 32°), Kebaetse et al. 1999
* `SIR_<C>_deg` : `SIR_R`/`SIR_L` du côté de la ligne, |ST DOF2 Y| (Joint 3/8),
  moyenne des 100 premières frames — approximation cinématique de la SIR de
  Moroder (mesurée sur CT), **non validée**
* `Moroder_<C>` : `A` (≤ 36°) / `B` (≤ 46°) / `C` (> 46°)

(`<C>` = `PRE`/`POST`.) Une ligne par patient/côté analysé/tâche, pour
`CALIBRATION3` (`STATIC3` sur les sessions plus anciennes, reporté sous
`CALIBRATION3`), `ANALYTIC1` et `ANALYTIC2`. L'inclinaison est propre au thorax,
donc identique pour les deux côtés d'un patient `RL`.

`ComputePostureFromDatabase(DatabaseFile, PostureOutputFile, ResultsFolder, Opts)` :
Excel `Posture_Summary.xlsx`, feuille `Posture`.

**Figures** (`PlotPostureDistribution`, fonction locale) : une par tâche, 3x2,
PRE (rouge) vs POST (bleu) vs asymptomatique (vert) :

* inclinaison thoracique : points individuels + médiane/IQR, seuil 32°
  (Erect/Slouched) ; une valeur par patient (dédoublonnée pour les `RL`)
* SIR : idem, seuils 36° (A/B) et 46° (B/C) ; une valeur par côté
* % Erect / Slouched par groupe
* % Moroder A / B / C par groupe
* inclinaison par strates de 5° (5-10 … 45-50), % de chaque groupe par
  strate (barres groupées), ligne au seuil 32° ; valeurs < 5° ou > 50°
  non tracées, comptées dans le titre

**SIR > 100° = outlier** (valeurs aberrantes, à traiter plus tard) : exclu des
distributions et des pourcentages Moroder, nombre d'exclus par groupe indiqué
dans le titre. L'Excel, lui, garde toutes les valeurs telles quelles.

**Corrélation inclinaison vs SIR** (`CorrelatePosture`, fonction locale) : par
tâche et par groupe (PRE, POST, asymptomatique), paires (inclinaison, SIR) de
la même session et du même côté, **uniquement dans la plage plausible :
inclinaison ∈ [0, 50]° et SIR ∈ [10, 60]°** (hors plage exclus, comptés
par groupe dans le titre et rappelés en bas de la figure ; axes fixés sur
cette plage ; colonne `nExcluded_OutOfRange` dans l'Excel). Plage propre à
cette analyse : les graphes de distribution gardent le seuil SIR > 100°.
Pearson r (linéaire) et
Spearman ρ (monotone, rangs avec ex-aequo au rang moyen), p bilatéral par la
loi de Student (df = n-2, calculé sans Statistics Toolbox), pente/ordonnée de
la régression SIR ~ inclinaison. Feuille `Correlation_Incl_SIR` (une ligne
par tâche/groupe) + une figure par tâche (nuages 1x3, droite de régression,
lignes aux seuils 32° et 36°/46°). Un patient `RL` donne deux paires
partageant la même inclinaison (non indépendantes) ; pas de correction pour
comparaisons multiples (3 tâches x 3 groupes).

**Corrélation posture x ROM** (`Multi/Core/CorrelatePostureROM.m`) :
1) inclinaison x ROM HT et inclinaison x ROM HG ; 2) SIR (Moroder) x ROM HT et
SIR x ROM HG (ROM = valeurs des colonnes de l'Excel, telles quelles). Posture PRE x ROM PRE et posture PRE x ROM POST. Aucun `.mat`
chargé, rien n'est recalculé : lit l'Excel trié à la main `PostureDataFile`
(`Multi/Results/Data_posture.xlsx`, feuilles `Posture` et `Cinematique`),
appariement par `Numero`, aucune exclusion (le tri est fait dans l'Excel ;
lignes vides ignorées). Statistiques : Pearson, Spearman, p, régression.
Feuille `Correlation_ROM` dans `CorrelationROMOutputFile`
(`Multi/Results/Correlation_Posture_ROM.xlsx`) + 2 figures ({inclinaison,
SIR}), 2x2 (ROM HT / HG x PRE / POST). 8 tests, pas de correction pour
comparaisons multiples. Plus, sur la feuille `Posture` seule : histogramme des
types de Moroder (`Moroder_type_pre`, feuille `Moroder_Distribution`) et
corrélation inclinaison x SIR (feuille `Correlation_Incl_SIR`), 1 figure 1x2.
Axe SIR borné à 70° (`SIRAxisMax`, affichage seulement : points au-delà comptés
dans le titre, gardés dans les calculs). Section indépendante dans `MAIN_MULTI_Protocol_01.m`.

Épaules asymptomatiques : avec `Opts.AsymptomaticSelection` (passé par
`MAIN_MULTI_Protocol_01.m`, voir section « Épaules asymptomatiques »), une
feuille séparée `Posture_Asymptomatic`, une ligne par épaule/tâche pour la
seule condition retenue : `Numero, PatientID, Side, Task, Condition,
Inclination_deg, PostureType, SIR_deg, Moroder` (SIR/Moroder du côté
asymptomatique). Même correspondance que pour les courbes vertes ; la console
affiche `Épaules asymptomatiques retrouvées : X / N`. La feuille `Posture`
est inchangée. Les trajectoires
marqueurs n'étant pas gardées dans la base (`FilterTrialForDatabase.m`), toute
autre définition de l'inclinaison (fenêtre, projection, marqueurs) demande de
relancer `MAIN_MULTI_Protocol_01.m`.

## Autre reporting : qualité de la reconstruction du CoR (SCoRE)

`Multi/Core/ComputeCoRQualityFromDatabase.m` recharge `PatientDatabase.mat` et
lit, pour chaque patient/côté analysé, la qualité de la calibration du centre
de rotation glénohuméral (SCoRE, Ehrig et al. 2006) déjà calculée pendant le run
C3D (`Core/CoR/ComputeSCoRE.m`) :

* `Database(i).PRE/POST.Session.SCoRE.R/.L.residual_mm` : `[1xN]`, agrément du
  CoR estimé via la scapula (Ti) et via l'humérus (Tj), par frame de calibration
* `Database(i).PRE/POST.Session.SCoRE.R/.L.clusterRMS.scapula_mm/.humerus_mm` :
  scalaire, RMS du fit rigide des clusters

**Une seule valeur par patient/côté/condition, pas par tâche** : la calibration
SCoRE est faite une fois par session en poolant des essais fixes (`ANALYTIC2`,
`ANALYTIC4`, `FUNCTIONAL1`, `FUNCTIONAL3` par défaut), puis réutilisée pour
reconstruire tous les essais de la session (ANALYTIC1 inclus).

`ComputeCoRQualityFromDatabase(DatabaseFile, CoRQualityOutputFile, ResultsFolder, ThresholdMM)` :
Excel `CoRQuality_Summary.xlsx`, feuille `CoR_Quality`, une ligne par
patient/côté, PRE et POST côte à côte :
`SCoRE_Residual_PRE_mean_mm/_max_mm/_nFrames`, `ClusterRMS_Scapula_PRE_mm`,
`ClusterRMS_Humerus_PRE_mm`, `Flag_PRE` (idem POST). `Flag` = `OK` /
`A verifier` selon `ThresholdMM` (30 mm par défaut, appelé avec 30 depuis
`MAIN_MULTI_Protocol_01.m`) appliqué au résidu moyen. **Ce seuil n'est pas
validé** (aucune référence dans le code : les distances à un CT gold standard
de `ComputeCTGoldStandardCoR.m`, ~20-28 mm, ne sont pas la même métrique) ; à
ajuster d'après le graphe. Figure : bar chart trié par pire résidu, PRE en
rouge/POST en bleu, ligne au seuil.

## Autre reporting : validité des courbes HT/HG/GH/ST/TX

`Multi/Core/ComputeCurveQualityFromDatabase.m` détecte les courbes angulaires
cycle-normalisées anormales pour HT, HG, GH, ST et TX (ANALYTIC1/2, PRE/POST),
avec les MÊMES courbes que les sorties clinical/functional (`abs()` par cycle
puis moyenne des cycles) et les mêmes joints/DOF. Callable à tout moment :
`ComputeCurveQualityFromDatabase(DatabaseFile, CurveQualityOutputFile, ResultsFolder, Opts)`.

**Référence.** Par groupe (tâche + métrique, PRE/POST/côtés confondus), la
courbe moyenne, recalculée sans les courbes flaguées (2 passes).

**Critères d'exclusion** (colonne `Reason`, verdict `Forme aberrante`, sinon
`OK`) :

* `Rough` : forte discontinuité, z-score robuste (médiane/MAD) du log du maximum
  de la dérivée seconde > `ZThresh` (3) : sauts, pics
* `Inversee` : corrélation de Pearson signée avec la référence
  (`Corr_vsMean`) < `CorrThresh` (0) : courbe à l'opposé de la moyenne

Colonnes informatives (n'entrent pas dans le verdict) : `MaxResid_deg`,
`RMSE_fit_deg`, `Fit_scale`, `Fit_offset_deg` (ajustement `c ~ a*t + b`,
`a >= 0`) et, sur le brut signé, `Range_raw_deg`, `CrossesZero`, `Raw_ExcSign`.
TX (joint unique partagé) : une seule ligne par patient, seule l'inversion est
testée (pas la rugosité). Les seuils sont provisoires (aucune référence
validée).

**Sorties.** Excel `CurveQuality_Summary.xlsx` (feuilles `Curve_Quality`, une
ligne par courbe, et `Summary`, comptages par tâche/métrique). Figures, par
tâche : courbes `abs` avec les outliers en rouge, courbes brutes signées, et
courbes avec la « correction inversée » (ST et TX : courbes inversées
corrigées en vert, moyenne tiretée recalculée avec elles). Une figure
interactive ANALYTIC2 (un patient à la fois, `a` = suivant, `q` = précédent,
cliquer d'abord sur la figure) et sa figure « Diagnostic patient » (brut, `abs`
et 4 corrections candidates avec `r` et ROM, et sens de l'excursion brute par
rapport à la cohorte). Ces corrections ne modifient que les figures ; la même
correction est appliquée aux Excel clinical/functional par
`ApplyInversionCorrectionSTTX.m` (voir section précédente).

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
