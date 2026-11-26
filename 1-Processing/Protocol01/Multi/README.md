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

## Stockage par projet (novembre 2026)

`StockageProjet = true` (défaut, `userCommands_Multi.m`) : un dossier par projet
sur le bureau, hors OneDrive, qui devient la référence du projet une fois
terminé. `ProjectsRoot` = `Bureau\Projets_epaule`, `ProjectCode` = code du
projet dans le registre (ou la variable d'environnement `EPAULE_PROJET`) : le
registre renvoie les épaules retenues par ce projet avec leur numéro
(`PatientNumbers`), gardé comme `Numero` et dans les noms de dossiers (trous
possibles). `COHORTE` = toutes les épaules ; un autre code exige le registre
(sinon le run s'arrête). La page du projet dans le registre lit ce dossier :

```
Projets_epaule\<CODE>\
  Patients\<n°>_<ID>_<côté>\   <ID>_<côté>.mat (une base par épaule)
                               PRE\, POST\ : copie des C3D de Processed\ et de
                               Session.xlsx utilisés (IO/CopySessionInputs.m)
  Valeurs\                     tous les Excels de sortie du projet
  Valeurs\Cache\               sorties des fonctions ...FromDatabase
  Valeurs\Controle_courbes\    CheckCurvesFromDatabase (CurveCheckFolder)
  projet.json                  date, commit du code, réglages du centre de
                               rotation, replis sur Rab, épaules, erreurs
                               (IO/WriteProjectSummary.m)
  progress.mat                 reprise automatique
```

Les fonctions `...FromDatabase` acceptent le dossier `Patients\` comme
`DatabaseFile`. Dans les sections de résultats de MAIN, `Core/CachedCompute.m`
calcule une fois puis relit `Valeurs\Cache\<Nom>.mat` tant qu'aucun .mat (ni la
référence figée) n'est plus récent ; `RecomputeValues = true` force le recalcul.
`EPAULE_LIGNES` (ex. `1:3`) limite le run à quelques lignes de PatientSelection
pour un essai. `StockageProjet = false` : ancien stockage en parties.

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

**Contrôle du xiphoïde virtuel (SXS), solo et multi.**
`runProtocol01` appelle `DetectSXSCorrection` (`Protocol01/Core/`) une fois
par session : le SXS écrit dans les C3D par la toolbox K-LAB (pointage au
stylet en CALIBRATION3) est comparé à STY05 (pointe du stylet actuel) et à la
pointe de l'ancien stylet (Stylus1) au moment du pointage. S'il est
incohérent (calculé au mauvais instant ou avec le mauvais modèle de stylet,
surtout janvier à juin 2024), `ApplySXSCorrection` le reconstruit frame par
frame dans chaque essai, dans le repère technique du thorax (SJN, SME, TV5,
CV7). Les C3D ne sont pas modifiés ; la décision est affichée en console
(« Contrôle SXS : ... ») et gardée dans `Trial(k).SXSCorrection`. Testé sur
362 sessions : 53 corrigées (47 par STY05, 6 par l'ancien stylet). Même
contrôle dans `MAIN_Protocol_01.m` (solo).

## Cycle retenu : meilleur des 3 cycles (`Multi/Core/BestCycle.m`)

Depuis octobre 2026 (règle validée avec le superviseur), les valeurs ne sont
plus des moyennes des cycles mais sont lues sur **un cycle retenu**, le même
pour toutes les articulations d'une épaule et d'une tâche
(`BestCycle.select`) :

* pic d'un cycle = moyenne de 10 points (sur 101) autour du maximum ;
* cycle non valide : saut > 90° entre deux points consécutifs, ou variation
  > 120° sur 3 points (repliement à ±180° étalé par le rééchantillonnage,
  ajouté le 26.11.2026 : n°59 scaption post, seul cycle de la cohorte
  au-delà de 120°, 99,9 % des cycles sous 91°), ou pic à plus de 20° de la
  médiane des cycles (si au moins 3 cycles) ;
* cycle retenu = cycle valide au pic le plus haut (sinon le plus haut, avec
  alerte) ;
* élévations (ANALYTIC1/2) : cycle choisi sur |HG|, sauts contrôlés sur HG,
  HT, ST et thorax ;
* rotations (ANALYTIC3/4) : cycle choisi sur HT signé dans le sens du
  mouvement (HG en blocage de cardan bras le long du corps), valeur = rotation
  réalisée depuis la position de départ (`BestCycle.rotation`, pic moins
  moyenne des 3 premiers points) ;
* contrôles de forme, en alerte seulement : sens opposé au groupe, courbe
  décalée (départ du cycle retenu au-delà de 90°).

Amplitude = pic lissé moins minimum brut du cycle (le minimum, au bord du
cycle, n'est pas lissé). Le cycle retenu et les alertes sont exportés
(`Cycle_<C>`, `CycleAlert_<C>`) et affichés en console. Utilisé par
`ComputeClinicalContributionsFromDatabase`, `ComputeFunctionalContributionsFromDatabase`
(valeurs, courbes, correction ST/TX) et `ComputePostureFromDatabase` (thorax
au pic HG, feuilles `TXflex`/`TXlat`). Restent volontairement sur la moyenne
des cycles : `ComputeContralateralEligibilityFromDatabase` (sélection des
épaules asymptomatiques, inchangée), `ComputeCurveQualityFromDatabase` et
`CheckCurvesFromDatabase` (contrôle qualité), et le script solo
(`IO/ExportKinematicsSummary.m`).

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
(`*_max_deg`, distinct du range) pour HT, GH et ST :
`PatientID, Side, Task, HT_PRE_deg, GH_PRE_deg, ST_PRE_deg, TX_PRE_deg,
HT_POST_deg, GH_POST_deg, ..., HT_PRE_max_deg, GH_PRE_max_deg, ST_PRE_max_deg,
HT_POST_max_deg, ..., Cycle_PRE, CycleAlert_PRE, ...` (plus de colonnes `_pct`
depuis octobre 2026 : sans objet en rotation, et recalculables depuis les
`_deg` en élévation). Valeurs lues sur le cycle retenu par `BestCycle.m`
(choisi sur HG en élévation, sur HT en rotation) ; en rotation (ANALYTIC3/4),
`HT_*_deg` est l'amplitude du signal signé et `HT_*_max_deg` la rotation
réalisée depuis la position de départ.

**Thorax (TX)** : le range est `max - min` de l'angle **signé** (voir
« Convention de signe des courbes »), car la flexion du thorax passe souvent
par zéro pendant le geste. Pas de pic pour le thorax (`max |angle|` mélangerait la
flexion au repos et l'extension au pic) : le thorax est décrit par son range
et par la flexion signée (`ComputePostureFromDatabase.m`).

**Inclinaison latérale du thorax (TXlat)** : colonnes `TXlat_PRE_deg`,
`TXlat_POST_deg` (et `TXlat_ASYM_deg`), range sur l'angle signé du DOF1 X du
`Joint(11)` (+ = vers la droite ; angle du milieu de ZXY, petit, sans blocage
de cardan ni saut de ±180°), en plus de TX (flexion / extension). En scaption,
c'est surtout par l'inclinaison latérale que le tronc compense : r(HG moins HT,
ROM latéral) = 0.54 en POST contre 0.13 pour la flexion / extension. Hors
pourcentages.

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

Colonnes : `PatientID, Side, Task, HG_PRE_deg, GH_PRE_deg, ST_PRE_deg,
TX_PRE_deg, HG_POST_deg, ..., HG_PRE_max_deg, GH_PRE_max_deg, ST_PRE_max_deg,
HG_POST_max_deg, ..., Cycle_PRE, CycleAlert_PRE, ...` (plus de colonnes `_pct`)
(export Excel, feuille `Functional_Contributions` ; thorax : range signé, pas
de pic, comme ci-dessus).

## Convention de signe des courbes (`Multi/Core/Orientation.m`, novembre 2026)

Remplace `abs()` et la correction des courbes ST et TX « inversées »
(`ApplyInversionCorrectionSTTX.m`, `InversionReference.m` et
`InversionReference_STTX.csv`, retirés le 26.11.2026). Utilisée par les
contributions cliniques et fonctionnelles, l'éligibilité controlatérale, la
qualité des courbes, le contrôle des courbes, les courbes moyennes et l'export
SHR.

**Problème.** `abs()` replie toute courbe qui passe par zéro : thorax en
flexion qui va de −10° à +5° (forme en W), ST qui part d'un repos positif, bras
qui démarre légèrement derrière zéro. Amplitudes sous-estimées, formes
inversées, et le sens biomécanique est perdu (toutes les courbes montent, ST
compris). La correction des courbes inversées compensait en partie, avec une
référence de cohorte et un repos remplacé par celui de la cohorte.

**Constat (207 épaules, 414 courbes par tâche, cycle retenu).** Le sens du
mouvement du DOF principal est fixé par l'articulation, la tâche et le côté :

| Articulation | Flexion | Scaption | Rot. externe | Rot. interne | Courbes dans ce sens |
|---|---|---|---|---|---|
| HG | − | − | − | + | élévations 99 %, aucune ne passe par zéro |
| HT | droite +, gauche − | − | − | + | 99 à 100 % |
| GH | + | − | − | + | 96 à 99 % |
| ST | − | − | − | + | 99 à 100 % |
| TX | + | + | variable | variable | élévations 95 à 98 % |

Les exceptions sont des sauts de cardan (n°118, 177, 45, 105, 30), des
élévations quasi nulles (n°12, 84, 34, 3, 171) ou un vrai mouvement inverse
du thorax (n°4, 5, 14, 170, 203).

**Méthode.**
* Courbe anatomique `x = Miroir(côté) × brut` : convention du côté droit pour
  les deux côtés ; seul HT en flexion (DOF3 Z) change de signe à gauche.
  Jamais repliée, signe biomécanique conservé : ST < 0 = rotation latérale,
  thorax > 0 = extension, HT et GH > 0 en flexion et < 0 en abduction, HG < 0 à
  l'élévation.
* Sens du mouvement `s = Orientation.sens(articulation, tâche)` (+1, −1 ; NaN
  pour le thorax en rotation axiale).
* Amplitude `*_deg` = max − min de `s × x` sur le cycle retenu
  (`BestCycle.range`) ; pic `*_max_deg` = valeur atteinte dans le sens du
  mouvement (`BestCycle.peak` de `s × x`) : grandeurs positives, comme avant.
* Une courbe dont l'excursion va contre `s` n'est plus « corrigée » : elle est
  gardée et signalée par les contrôles (alerte de `BestCycle.shape`, verdict
  `Inversee` de la qualité des courbes, « sens opposé » du contrôle des
  courbes).

Les colonnes `ST_*_corrected` et `TX_*_corrected` disparaissent des Excels et
du registre. Toute modification de la table recalcule les sections en cache
qui l'utilisent (dépendance `OrientationFile` dans MAIN).

En rotation (ANALYTIC3/4), le pic de HT, GH, ST et HG est la rotation réalisée
depuis la position de départ (`BestCycle.rotation`, déjà la règle de HT) : la
valeur ne dépend plus de l'angle de départ (ST en protraction, HG proche du
blocage de cardan bras le long du corps).

**Validation (26.11.2026, 207 épaules, run COHORTE, avant contre après).**
* Élévations : seules les valeurs des courbes qui passent par zéro changent
  (HT amplitude : 49 examens pré et 38 post, +3,7° en médiane, jusqu'à +18° ;
  GH et ST : une centaine chacun, +3 à +6° en médiane). HG : inchangé sauf
  n°172 (excursion inverse). Thorax : amplitude inchangée (déjà signée), courbe
  dépliée (moyenne de −9° à +5° au lieu d'un W plat autour de 11°).
* Pics : HT inchangé sauf 5 courbes de sens inverse ou à saut de cardan ; les
  11 pics ST décalés par la référence de la correction (n°45, 53, 72, 75, 81,
  93, 117, 124, 142) retrouvent leur valeur propre.
* Rotations : HT inchangé ; GH, ST et HG passent de l'angle absolu au pic à la
  rotation depuis le départ. HG en rotation externe garde 52 courbes sur 411
  avec un saut de ±180° (blocage de cardan) : valeurs à ne pas utiliser.
* Data_posture (E02_01, 189 épaules) : thorax, posture et cycles identiques ;
  ROM HT en flexion plus grand pour 43 examens pré et 31 post ; HG inchangé
  sauf n°172.
* SHR (TPC2_SHR, 182 épaules) : TestSHRFormulas donne exactement les mêmes
  résultats (il orientait déjà lui-même les courbes signées).

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

**Signes.** Même convention que les patients (`Orientation.m`), côté de
l'épaule asymptomatique.

**Export.** Feuille séparée dans chaque Excel (`Clinical_Asymptomatic`,
`Functional_Asymptomatic`), une ligne par épaule/tâche pour la seule condition
retenue : `Numero, PatientID, Side, Task, Condition, HT_ASYM_deg` (ou
`HG_ASYM_deg`), `GH/ST/TX_ASYM_deg`, `*_ASYM_max_deg` (sauf
thorax). Les feuilles
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

* inclinaison thoracique : points individuels + médiane/IQR, seuils des types
  d'inclinaison ; une valeur par patient (dédoublonnée pour les `RL`)
* SIR : idem, seuils 36° (A/B) et 46° (B/C) ; une valeur par côté
* % de types d'inclinaison I-A / I-B / I-C par groupe (construits comme
  Moroder : moyenne ± 1 SD de l'inclinaison PRE de la tâche)
* % Moroder A / B / C par groupe
* inclinaison par strates de 5° (5-10 … 45-50), % de chaque groupe par
  strate (barres groupées), lignes aux seuils des types ; valeurs < 5° ou > 50°
  non tracées, comptées dans le titre

**SIR > 100° = outlier** (valeurs aberrantes, à traiter plus tard) : exclu des
distributions et des pourcentages Moroder, nombre d'exclus par groupe indiqué
dans le titre. L'Excel, lui, garde toutes les valeurs telles quelles.

**Flexion thoracique signée** (`summariseThoraxFlexion`, fonction locale de
`ComputePostureFromDatabase`, 3e sortie `ThxFlex`) : lecture seule des cycles
déjà stockés (thorax `Joint(11).Euler` DOF3 Z, négatif = flexion, positif =
extension ; pic d'élévation repéré sur HG `Joint(12/13)` DOF1), ANALYTIC1/2,
PRE et POST. Sur le cycle retenu par `BestCycle.select` (le même que les
valeurs HG/HT ; moyenne des cycles si aucun cycle retenu) : `Start` (3 premières frames), `AtPeak`
(frame du pic HG), `Change` = AtPeak moins Start (> 0 = le tronc se redresse
pendant l'élévation), `Min`/`Max`. Feuille `Thorax_Flexion_Signed` de
`Posture_Summary.xlsx`, une ligne par patient/côté, colonnes au format de
`Data_posture.xlsx` (ex. `analytic1_TXflex_Change_Post`). Même calcul pour les
épaules asymptomatiques (cycles du bras sain, session retenue) : feuille
`Thorax_Flexion_Signed_Asym`, colonnes `<tâche>_TXflex_<stat>_Asym` + `Condition`.
Même résumé pour l'inclinaison latérale du thorax (DOF1 X), après les colonnes
de flexion : `<tâche>_TXlat_<Start|AtPeak|Change|Min|Max>_<Pre|Post|Asym>`,
signe ramené au bras mesuré (> 0 = le tronc penche du côté opposé au bras).
Élévations bilatérales : en POST, le tronc penche du côté opposé au bras opéré
(vers le côté sain) ; pour le bras sain, la valeur est donc en général négative.
Ces colonnes, et `<tâche>_ROM_ThoraciqueLateral_<Pre|Post|Asym>`, sont aussi
dans `Data_posture.xlsx` (feuilles `Cinematique`, `Cinematique_thorax` et leurs
versions `_Asym`).

**Génération de `Data_posture.xlsx`** : par le registre (`Registre_Epaule`,
`data_posture.py`, bouton « Générer » de la carte Exports d'un projet), pour
les épaules retenues par le projet. Remplit toutes les feuilles (`Posture`,
`Cinematique`, `Cinematique_pics`, `Cinematique_thorax`, leurs versions `_Asym`,
`Controle_cycles` et `Cote_retenu`) à partir de `ClinicalContributions_Summary`,
`FunctionalContributions_Summary` et `Posture_Summary` du dossier `Valeurs\`
du projet. L'ancien script `build_data_posture.py` (OneDrive) est supprimé
(26.11.2026).

**Épaules asymptomatiques vs rTSA** (`Multi/Core/AsymptomaticComparison.m`,
section dédiée de `MAIN`, sortie `AsymptomaticOutputFile`) : lit les feuilles
`Posture_Asym`, `Cinematique_Asym`, `Cinematique_pics_Asym` et
`Cinematique_thorax_Asym` de `Data_posture.xlsx` (26 épaules controlatérales
saines, une session PRE ou POST chacune, suffixe `_Asym`), en plus des
feuilles patients. 1) Valeurs de référence (HG, HT, HG moins HT, thorax,
saines vs rTSA PRE et POST, Welch et g de Hedges). 2) Même patient, même
session : côté opéré moins côté sain (t apparié, % du côté sain). 3) Posture
de la session x HG / HT du côté sain (Pearson, IC 95 % de Fisher) vs rTSA
POST, et posture x déficit opéré moins sain. Les élévations ANALYTIC1/2 sont
**bilatérales** : le thorax est commun aux deux côtés, donc pas de référence
« saine » pour la compensation par le tronc (thorax apparié = contrôle,
écart attendu nul). 26 épaules : exploratoire.

**Courbes moyennes des trois populations**
(`Multi/Core/PlotMeanCurvesFromDatabase.m`, section dédiée de `MAIN`) : lit les
cycles stockés dans la base pour les patients de la feuille `Posture` (rTSA
PRE et POST, côté opéré) et les épaules de `Posture_Asym` (côté sain, session
retenue). HG, HT, GH (DOF de la tâche, valeur absolue), ST rotation latérale
(signée, sens harmonisé entre côtés) et thorax (flexion signée), moyenne ± 1 SD
par population, flexion et scaption (figure 2 x 5). Sortie `Curves` :
`Curves.<PRE|POST|ASYM>.<ANALYTIC1|ANALYTIC2>.<HG|HT|GH|ST|TX>` = [n x 101].
Deux figures de vue d'ensemble (flexion, scaption ; 3 x 5) montrent en plus la
courbe de chaque épaule (gris) sous la moyenne de chaque population, pour
repérer les courbes atypiques. `PlotMeanCurvesFromDatabase(Curves)` retrace
toutes les figures sans relire la base ; un 3e argument limite les mesures
tracées, ex. `PlotMeanCurvesFromDatabase(Curves, '', {'HG', 'HT', 'TX'})`.

**Contrôle des courbes patient par patient**
(`Multi/Core/CheckCurvesFromDatabase.m`, section dédiée de `MAIN`) : mêmes
populations, joints, DOF et conventions que `PlotMeanCurvesFromDatabase`, mais
tous les cycles, les 3 DOF et le signal signé sont gardés. Contrôles par
épaule x session x tâche x mesure : saut > 90° entre deux échantillons (angle
qui franchit ±180°), excursion de sens opposé au mouvement attendu, forme inversée ou
atypique (r avec la moyenne du groupe), ROM extrême (z robuste), cycles
dispersés, écart entre l'angle d'Euler et l'élévation 3D de HT et GH
(acos(cos DOF1 cos DOF3), indépendante de la séquence, avec l'angle du milieu
au pic pour repérer le blocage de cardan), verdict de
`ComputeCurveQualityFromDatabase` si fourni. Sorties dans `CurveCheckFolder`
(OneDrive) : `QC_courbes.xlsx` (feuilles `QC_courbes`, `Synthese`, `Sauts` avec
les valeurs de `Data_posture`), figures de contrôle par tâche et GH Euler vs
3D. Renvoie aussi `Cycles` pour relancer sans relire la
base : `CheckCurvesFromDatabase(CurveCycles, PostureDataFile, CurveCheckFolder)`. Limites connues : GH en flexion
(séquence ZXY) approche le blocage de cardan (élévation et rotation axiale
mélangées, valeurs d'Euler peu fiables au dessus d'environ 90° d'élévation) ;
quelques courbes HT franchissent ±180° et sont repliées par la valeur absolue.

**Illustrations des mesures** (`Multi/Core/PlotMeasureIllustrations.m`, section
dédiée de `MAIN`) : sur un patient réel (Numero donné, ou patient
représentatif choisi automatiquement : type B, valeurs proches de la moyenne,
session PRE non corrigée pour le SXS), retraite ses sessions PRE et POST par
`runProtocol01` (copie locale montée sur un lecteur virtuel `subst`, BTK
échouant sur les chemins accentués ou trop longs) et produit, avec une
silhouette schématique du patient : 1) l'inclinaison thoracique assis et
debout (vue sagittale, même échelle) ; 2) la SIR (vue de dessus dans le repère
du thorax, 1re rotation Y de YXZ, côté gauche avec la convention de
`ComputeKinematics`) ; 3) HG et HT au repos et au pic, en flexion (vue
sagittale) et en scaption (vue de face), avec les courbes de l'essai. Valeurs
affichées = valeurs du pipeline. Export PNG, PDF vectoriel et SVG (formes et
textes séparés, modifiables dans Inkscape) dans le dossier `Illustrations` à
côté de `Data_posture.xlsx`.

**Stratification de l'inclinaison et seuil critique**
(`Multi/Core/InclinationClassification.m`, section dédiée de `MAIN`, sortie
`InclinationOutputFile`) : lit le même `Data_posture.xlsx`. 1) Types I-A / I-B /
I-C construits comme Moroder (moyenne ± 1 SD), vérifiés par k-means 1D exact
(variance expliquée k = 2 à 5) et mélange de gaussiennes (BIC k = 1 à 4) ;
kappa vs Moroder A/B/C ; élévation POST par type (Kruskal-Wallis, epsilon²,
écart type 3 moins type 1). 2) Mauvais résultat = pic HG POST < 90° : ROC (AUC,
seuil de Youden, IC bootstrap), régression segmentée, % par tranche de 5°.
Debout et assis, SIR en comparaison ; sans Statistics Toolbox.

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
lignes aux seuils 36°/46°). Un patient `RL` donne deux paires
partageant la même inclinaison (non indépendantes) ; pas de correction pour
comparaisons multiples (3 tâches x 3 groupes).

**Analyses de l'article posture** (octobre 2026 : l'ancienne `CorrelatePostureROM.m`, trop longue, est découpée en trois fonctions et un fichier d'outils ; résultats identiques, vérifiés feuille par feuille). Les trois fonctions lisent `PostureDataFile` (`Data_posture.xlsx` du dossier OneDrive `05_Ressources/01_Data/01_Etudes/E02_01_Posture_rTSA`, généré par le registre pour les épaules du projet E02_01 ; appariement par `Numero`, aucune exclusion, rien n'est recalculé) et écrivent chacune leurs feuilles dans `CorrelationROMOutputFile` (`Multi/Results/Correlation_Posture_ROM.xlsx`). Postures, métriques et tâches sont définies une seule fois dans `PostureUtils.defs()`.

- `Multi/Core/CorrelatePostureROM.m` (**H2**) : corrélations posture PRE (inclinaison assis `Inclinaison_thoracique_Pre`, debout `Inclinaison_thoracique_Pre_Calibration3`, SIR) x élévation HT et HG, PRE et POST, flexion (ANALYTIC1) et scaption (ANALYTIC2), ROM (feuille `Cinematique`) et pic (feuille `Cinematique_pics`) : 48 tests, Pearson, Spearman, pente en °/°. Feuille `Correlation_ROM`. Pas de figure.
- `Multi/Core/AnalyseThoraxContribution.m` (**H1**) : mouvement du thorax pendant le geste (feuille `Cinematique_thorax`) : position au repos (contrôle vs inclinaison), extension au pic d'élévation HG (moyenne, IC 95 %, % qui se redressent, POST moins PRE apparié), inclinaison latérale au pic (> 0 = côté opposé au bras, % qui penchent du côté opposé), extension vs inclinaison PRE ; amplitude du thorax (ROM du signal signé, flexion / extension et inclinaison latérale) ; vérification : HG moins HT vs mouvement du thorax (pente attendue proche de 1) et dispersion de HG moins HT (la moyenne n'est pas interprétée : HT Cardan et HG YXY n'ont pas la même définition). Feuilles `Thorax_Contribution` et `Thorax_Flexion`. Pas de figure.
- `Multi/Core/PostureSecondaryAnalyses.m` (secondaire) : types de Moroder en % vs Moroder et al. 2024 (681 rTSA, 33 / 48 / 19 %, chi² 2 x 3) et inclinaison x SIR (feuilles `Moroder_Distribution`, `Correlation_Incl_SIR`) ; inclinaison assis vs debout (Bland-Altman, ICC(A,1), t apparié, % de changement de type ; feuille `Seated_vs_Standing`) ; HG moins HT vs posture (pente, IC 95 %, p vs 0 et vs -1, thorax vs posture, Meng, Rosenthal et Rubin 1992 ; feuille `HG_minus_HT`). Une figure par analyse (axe SIR borné à 70°, affichage seulement).
- `Multi/Core/PostureUtils.m` : outils communs en méthodes statiques (`defs`, `readSheet`, `getCol`, `getText`, `alignCol`, `pearsonP`, `spearmanP`, `meanCI`, `slopeTest`, `fmtP`...), sans Statistics Toolbox.

- `Multi/Core/PlotArticleFigures.m` : figures de l'article, une par fichier et par tâche (flexion, scaption), textes en anglais sans tiret, 8.5 cm de large, Arial 8 pt, palette Okabe-Ito (PRE orange, POST bleu), export PDF vectoriel, SVG et PNG 600 dpi dans `ArticleFigureFolder` (`Figures_article`, à côté de `Data_posture.xlsx`). Toutes les comparaisons portent sur l'amplitude (max moins min, colonnes `_ROM_` de la feuille `Cinematique` ; le terme ROM n'apparaît plus dans les figures) : `Fig2` amplitude du thorax (flexion / extension et inclinaison latérale), PRE et POST ; `Fig3` part du thorax dans l'amplitude HG (amplitude du thorax / amplitude HG x 100, indicatif), PRE et POST : médiane et IC 95 % bootstrap, tableau affiché dans la console (deuxième sortie `Share`, pas d'Excel) ; `Fig4` amplitude du thorax x amplitude HG ; `Fig5` contribution du thorax à épaule égale (régression HG ~ HT + thorax flexion / extension + thorax inclinaison latérale, figure de régression partielle de la composante principale, coefficient [IC 95 %] et p sur la figure, tableau `Decomp` dans la console : R² épaule seule et complet, coefficients) ; `Fig6` inclinaison debout PRE x amplitude HG, un fichier PRE et un fichier POST. Renvoie une table des n, moyennes, r, p et pentes affichés.

**SHR (scoping review, novembre 2026).** Depuis le 26.11.2026, `SHR_Curves.xlsx` est écrit par le registre (`Registre_Epaule/shr_curves.py`, projet `TPC2_SHR` : critères du projet E02_01 et aucun saut de cardan GH ni ST, bouton « Générer » SHR_Curves.xlsx) dans `SHRDataFolder` (`05_Ressources/01_Data/01_Etudes/TPC2_SHR_calculation_rTSA`), sans relire les .mat ; même fichier que la fonction ci-dessous (vérifié sur 189 épaules, écart au plus 0,00005°, arrondi du registre). MAIN ne lance plus que `TestSHRFormulas(SHRDataFolder, ...)`. `Multi/Core/ExportSHRCurvesFromDatabase.m` (contrôle) : courbes HT, GH et ST point par point (101 points, 0 à 100 % du cycle), PRE et POST, flexion (ANALYTIC1) et scaption (ANALYTIC2), pour les patients et le côté retenu de `PostureDataFile` (mêmes lignes que la feuille `Cinematique`). Aucun recalcul : ce sont les courbes de `ComputeClinicalContributionsFromDatabase` (cycle retenu `BestCycle`, angle signé, voir « Convention de signe des courbes »), obtenues avec `Opts.Export = false` et `Opts.Plot = false` (troisième sortie `Curves`). Excel `SHRCurvesOutputFile` (`SHR_Curves.xlsx`) : une feuille par tâche et articulation (`analytic1_Humerothoracique`...) et une feuille `Cycle_retenu` (cycle, alerte). Renvoie `SHR.ANALYTIC1/2` (matrices patients x 101), l'entrée des formules de SHR.
`Multi/Core/TestSHRFormulas.m` lit le `SHR_Curves.xlsx` validé dans `SHRAbstractFolder` (dossier de l'abstract ISB 2027) et calcule, sur la montée du bras (repos = 3 premiers points, pic = 10 points autour du maximum de HT, mêmes points pour HT, GH et ST), une formule par famille : A GH:ST = ΔGH / ΔST, B TH:ST = ΔHT / ΔST, C TH:GH au pic = HT_pic / GH_pic (GH mesuré directement ; ratio vide si |dénominateur| < 1°). GH est pris **signé et orienté** (feuille `*_Glenohumerale_signe` de l'export, sens fixé par tâche et par côté = sens majoritaire de la cohorte) : `abs()` repliait GH quand l'angle de repos est du côté de zéro opposé au mouvement (16 des 18 GH:ST négatifs). ST est aussi pris **signé et orienté** (feuille `*_ST_signe`, brut `ST_<C>_raw` de Clinical, non corrigé) : en scaption il diminue chez tous les patients mais part légèrement positif et traverse zéro dans 77 sessions sur 326, ce qui réduisait ΔST avec `abs()` (B négatifs à 60°). HT reste en `abs()` comme `Data_posture`. Sessions exclues si HT monte de moins de 15° (`Opts.MinElevation`). Plages d'élévation `Opts.Ranges` ([début fin] en HT, NaN = repos / maximum individuel) : rest–individual max, rest–90°, rest–120°, 20–90° et 20–120° pour A et B (colonnes `_rest_max`, `_rest_90`, `_rest_120`, `_20_90`, `_20_120`), C au pic ; à un angle, GH et ST sont pris quand HT franchit l'angle sur la montée, vide si HT part au-dessus de l'angle de début ou n'atteint pas l'angle de fin ; la figure montre une position par plage avec le nombre de patients appariés PRE / POST. Intervalles d'analyse sur la montée rest–individual max (`shrIntervals`) : pente de régression (GH sur ST, HT sur ST) et moyenne des incréments de 10° (colonnes `_reg`, `_incmean`, dans le tableau et les figures) ; fenêtre fixe 30–90° (plage `_30_90`) ; incréments de 10° (`Opts.IncEdges`), brackets de 30° (`Opts.Brackets`), cumulatif depuis le repos et courbe continue (rapport des dérivées de polynômes de degré 3 de GH(HT) et ST(HT), vide si |dST/dHT| < 0.1) aux angles `Opts.Grid` : feuilles `Intervalles` (une ligne par session, intervalle, famille et angle) et `Intervalles_resume` (n, moyenne, IC 95 %, médiane, quartiles), figure `SHR_Formulas_intervalles` (moyenne et IC 95 % en fonction de HT, n ≥ 10). PNG à 300 dpi : MATLAB R2026a superpose parfois les chiffres d'un libellé d'axe selon sa position en pixels, préférer le PDF pour le diapo. Tests (feuille `Tests`, colonnes ajoutées à `Tableau_abstract`) : PRE vs POST par Wilcoxon signé apparié (exact si n ≤ 50 sans ex aequo, sinon approximation normale, comme `scipy.stats.wilcoxon` par défaut), correction de Holm sur toutes les colonnes de la tâche ; rho de Spearman entre chaque méthode et la référence rest–individual max de sa famille, par condition (descriptif) ; méthode vs référence, statut ignoré (différence méthode − référence moyennée par patient sur ses sessions PRE et POST, différence moyenne [IC 95 %] et Wilcoxon sur les valeurs par patient, Holm sur les 14 comparaisons ; comparaison sur les mêmes patients, non biaisée par la sélection des plages à angle fixe) ; fonctions locales `wilcoxonSigned`, `avgRank`, `spearmanRho`, `holm`, sans Statistics Toolbox. Figures écrites dans `Opts.FigureFolder` (`SHRFigureFolder` = `Abstract 3/Figures` depuis MAIN ; tableaux Word dans `SHRTableFolder` = `Abstract 3/Tables`). Feuille `Resume` avec IC 95 % de la moyenne (t de Student via `betaincinv`, sans Statistics Toolbox), feuille `Tableau_abstract` (une ligne par famille et plage : moyenne [IC 95 %] et n en PRE et en POST) et figure `SHR_Formulas_moyenne_IC` (moyenne et IC 95 % par famille et plage, pour le diapo). `ComputeClinicalContributionsFromDatabase` fournit pour cela `Curves.GH_<C>_signed`, non utilisé ailleurs. Sortie `SHR_Formulas.xlsx` dans le même dossier : feuilles `SHR` (mêmes lignes que le template), `Composantes` (repos et pic) et `Resume` (médiane, quartiles, moyenne, écart-type), et figure `SHR_Formulas.png` / `.pdf` (un panneau par famille, PRE / POST, points, médiane, Q1-Q3, repère 2:1 d'Inman). Scaption (ANALYTIC2) seule par défaut pour l'abstract (`Opts.Tasks`) : la flexion est écartée (GH ZXY peu fiable) et le `SHR_Curves.xlsx` du dossier de l'abstract ne contient plus que les feuilles `analytic2`.

Épaules asymptomatiques : avec `Opts.AsymptomaticSelection` (passé par
`MAIN_MULTI_Protocol_01.m`, voir section « Épaules asymptomatiques »), une
feuille séparée `Posture_Asymptomatic`, une ligne par épaule/tâche pour la
seule condition retenue : `Numero, PatientID, Side, Task, Condition,
Inclination_deg, SIR_deg, Moroder` (SIR/Moroder du côté
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
rapport à la cohorte). Ces corrections ne modifient que les figures (diagnostic historique). Depuis
le 26.11.2026 les courbes scorées sont orientées dans le sens du mouvement
(`Orientation.oriente`, sans abs) : `Inversee` ne relève plus qu'un vrai
mouvement de sens opposé.

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
