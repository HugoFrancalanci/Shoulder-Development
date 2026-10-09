% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Rapport de contributions fonctionnelles huméro-
%                gravitationnelles (HG/GH/ST/TX), calculé depuis
%                PatientDatabase.mat plutôt qu'en repassant par les C3D.
%                Même patron que Multi/Core/ComputeClinicalContributionsFromDatabase.m
%                (voir ce fichier comme référence) : décomposition Euler.
%                Seule différence : utilise HG (huméro-
%                gravitationnel, Joint 12/13 - orientation absolue de
%                l'humérus dans le référentiel patient-ICS/gravitationnel)
%                comme référence d'amplitude globale au lieu de HT (huméro-
%                thoracique, Joint 1/6).
%
%                DOF HG (Joint 12/13, séquence YXY) : contrairement à HT,
%                la séquence n'est PAS conditionnée par la sous-tâche (le
%                bloc ComputeKinematics.m ne teste que "contains(...,
%                'ANALYTIC')", pas ANALYTIC1 vs ANALYTIC2) - DOF1 X
%                (position 1) = élévation, pour ANALYTIC1 ET ANALYTIC2.
%                Donc pas de mapping DOF par tâche pour HG (contrairement à
%                HT). GH/ST/TX restent exactement les mêmes joints et les
%                mêmes DOF (task-dépendant pour GH, fixes pour ST/TX) que
%                dans ComputeClinicalContributionsFromDatabase.m - voir les
%                commentaires de la fonction locale ComputeFunctionalContributions
%                en bas de ce fichier pour le détail.
%
%                Fonction centralisée : la décomposition HG/GH/ST/TX
%                (ComputeFunctionalContributions) et le tracé des courbes
%                PRE/POST (PlotHGContributionsCurves) sont des fonctions
%                locales, en bas du fichier - même organisation que le
%                pendant HT.
%
%                Callable à tout moment depuis la fenêtre de commande
%                (ou un script), sans rien relancer sur les C3D :
%                  ComputeFunctionalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder)
%
%                Prérequis : avoir lancé MAIN_MULTI_Protocol_01.m au moins
%                une fois avec SaveDatabase=true (voir userCommands_Multi.m)
%                pour générer PatientDatabase.mat.
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile  (char) chemin vers PatientDatabase.mat
%           OutputFile    (char) chemin de l'Excel de sortie (contributions
%                         fonctionnelles)
%           ResultsFolder (char, optionnel) dossier où se terminer (cd) une
%                         fois l'export fait ; omis = pas de cd
%           Opts          (struct, optionnel) ApplyInvCorr (true : corrige les
%                         courbes ST et TX inversées, voir
%                         ApplyInversionCorrectionSTTX.m ; false : valeurs
%                         non corrigées), CorrThresh (0),
%                         AsymptomaticSelection (cell, {} par défaut) :
%                         épaules asymptomatiques {ID, côté, 'PRE'/'POST',
%                         date} (voir userCommands_Multi.m), tracées en vert
%                         sur la figure des courbes et exportées dans la
%                         feuille 'Functional_Asymptomatic' (une ligne par
%                         épaule/tâche, colonnes <M>_ASYM_deg/_pct/_max_deg)
% Outputs : Results (struct array) une ligne par patient/côté/tâche - aussi
%           retourné pour exploitation directe sans repasser par l'Excel
%           Fichier Excel écrit sur disque + une figure par tâche (courbes
%           PRE/POST)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, AsymResults] = ComputeFunctionalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder, Opts)

if nargin < 3, ResultsFolder = ''; end
if nargin < 4, Opts = struct(); end
if ~isfield(Opts, 'ApplyInvCorr') || isempty(Opts.ApplyInvCorr), Opts.ApplyInvCorr = true; end
if ~isfield(Opts, 'CorrThresh')   || isempty(Opts.CorrThresh),   Opts.CorrThresh   = 0;    end
if ~isfield(Opts, 'AsymptomaticSelection'), Opts.AsymptomaticSelection = {}; end

% La base peut être répartie sur plusieurs fichiers .mat (voir
% NumDatabaseParts dans userCommands_Multi.m, DatabaseFile_partXofY.mat) -
% détecté automatiquement ; repli sur DatabaseFile seul si aucune partie
% trouvée (compatibilité avec un run à un seul fichier).
fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeFunctionalContributionsFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

% -------------------------------------------------------------------------
% BOUCLE PATIENTS (depuis Database, pas depuis PatientSelection/C3D)
% -------------------------------------------------------------------------
Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'HG_PRE_deg', {}, 'GH_PRE_deg', {}, 'GH_PRE_pct', {}, ...
    'ST_PRE_deg', {}, 'ST_PRE_pct', {}, 'TX_PRE_deg', {}, 'TX_PRE_pct', {}, ...
    'HG_POST_deg', {}, 'GH_POST_deg', {}, 'GH_POST_pct', {}, ...
    'ST_POST_deg', {}, 'ST_POST_pct', {}, 'TX_POST_deg', {}, 'TX_POST_pct', {}, ...
    'HG_PRE_max_deg', {}, 'GH_PRE_max_deg', {}, 'ST_PRE_max_deg', {}, ...
    'HG_POST_max_deg', {}, 'GH_POST_max_deg', {}, 'ST_POST_max_deg', {});
% Pas de pic pour le thorax : max |angle| n'a pas de sens quand la flexion
% passe par zéro (il mélange la flexion au repos et l'extension au pic) ;
% le thorax est décrit par son ROM (signal signé) et la flexion signée
% (ComputePostureFromDatabase.m)

% Courbes angle vs % cycle
Curves = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'HG_PRE', {}, 'HG_POST', {}, 'GH_PRE', {}, 'GH_POST', {}, 'ST_PRE', {}, 'ST_POST', {}, ...
    'TX_PRE', {}, 'TX_POST', {});

% Courbes des épaules asymptomatiques (côté controlatéral, une seule
% session par épaule - voir AsymptomaticSelection dans userCommands_Multi.m).
% Condition 'ASYM' : mêmes champs que Curves pour réutiliser
% ApplyInversionCorrectionSTTX.
AsymResults = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, 'Condition', {});
AsymCurves  = struct('PatientID', {}, 'Side', {}, 'Task', {});

conditions = {'PRE', 'POST'};

totalPatients = 0;
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    % Chargement en bloc de la partie : bien plus rapide qu'un accès
    % matfile indexé patient par patient (chaque accès partiel à un struct
    % array imbriqué stocké en -v7.3/HDF5 a un coût fixe élevé, indépendant
    % du volume réel lu - voir NumDatabaseParts dans userCommands_Multi.m).
    % Chaque partie est justement dimensionnée pour tenir en RAM d'un coup,
    % contrairement à l'ancien fichier unique (d'où matfile à l'origine).
    S       = load(fileList{iFile}, 'Database');
    nInFile = numel(S.Database);
    totalPatients = totalPatients + nInFile;

for iP = 1:nInFile
    d = S.Database(iP);
    if isempty(d.Numero)
        continue; % ligne pré-allouée jamais remplie (patient introuvable/erreur aux deux conditions)
    end

    for iC = 1:numel(conditions)
        condition = conditions{iC};
        if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Trial')
            continue; % cette condition n'a pas été traitée avec succès pour ce patient
        end
        Trial = d.(condition).Trial;

        Contrib = ComputeFunctionalContributions(Trial);

        for iS = 1:length(Contrib)
            c = Contrib(iS);
            if ~ismember(c.side, d.Side), continue; end

            % Cle Numero+Side+Task : ANALYTIC1 et ANALYTIC2 sur des lignes
            % separees (meme convention que ComputeClinicalContributionsFromDatabase.m).
            ri = find([Results.Numero] == d.Numero & strcmp({Results.Side}, c.side) & strcmp({Results.Task}, c.task), 1);
            if isempty(ri)
                ri = length(Results) + 1;
                Results(ri).Numero       = d.Numero;
                Results(ri).PatientID    = d.PatientID;
                Results(ri).Side         = c.side;
                Results(ri).Task         = c.task;
                Results(ri).HG_PRE_deg   = NaN; Results(ri).HG_POST_deg  = NaN;
                Results(ri).GH_PRE_deg   = NaN; Results(ri).GH_POST_deg  = NaN;
                Results(ri).GH_PRE_pct   = NaN; Results(ri).GH_POST_pct  = NaN;
                Results(ri).ST_PRE_deg   = NaN; Results(ri).ST_POST_deg  = NaN;
                Results(ri).ST_PRE_pct   = NaN; Results(ri).ST_POST_pct  = NaN;
                Results(ri).TX_PRE_deg   = NaN; Results(ri).TX_POST_deg  = NaN;
                Results(ri).TX_PRE_pct   = NaN; Results(ri).TX_POST_pct  = NaN;
                Results(ri).HG_PRE_max_deg = NaN; Results(ri).HG_POST_max_deg = NaN;
                Results(ri).GH_PRE_max_deg = NaN; Results(ri).GH_POST_max_deg = NaN;
                Results(ri).ST_PRE_max_deg = NaN; Results(ri).ST_POST_max_deg = NaN;
            end

            Results(ri).(['HG_', condition, '_deg']) = c.HG_range;
            Results(ri).(['GH_', condition, '_deg']) = c.GH_range;
            Results(ri).(['GH_', condition, '_pct']) = c.GH_pct;
            Results(ri).(['ST_', condition, '_deg']) = c.ST_range;
            Results(ri).(['ST_', condition, '_pct']) = c.ST_pct;
            Results(ri).(['TX_', condition, '_deg']) = c.TX_range;
            Results(ri).(['TX_', condition, '_pct']) = c.TX_pct;

            Results(ri).(['HG_', condition, '_max_deg']) = c.HG_max;
            Results(ri).(['GH_', condition, '_max_deg']) = c.GH_max;
            Results(ri).(['ST_', condition, '_max_deg']) = c.ST_max;

            if length(Curves) < ri
                Curves(ri).Numero    = d.Numero;
                Curves(ri).PatientID = d.PatientID;
                Curves(ri).Side      = c.side;
                Curves(ri).Task      = c.task;
            end
            Curves(ri).(['HG_', condition]) = c.HG_curve;
            Curves(ri).(['GH_', condition]) = c.GH_curve;
            Curves(ri).(['ST_', condition]) = c.ST_curve;
            Curves(ri).(['TX_', condition]) = c.TX_curve;

            % Données brutes signées pour la correction ST/TX inversées
            % (voir ApplyInversionCorrectionSTTX.m)
            Curves(ri).(['ST_', condition, '_raw'])      = c.ST_raw;
            Curves(ri).(['ST_', condition, '_rangeRaw']) = c.ST_rangeRaw;
            Curves(ri).(['ST_', condition, '_peakExc'])  = c.ST_peakExc;
            Curves(ri).(['ST_', condition, '_excSign'])  = c.ST_excSign;
            Curves(ri).(['TX_', condition, '_raw'])      = c.TX_raw;
            Curves(ri).(['TX_', condition, '_rangeRaw']) = c.TX_rangeRaw;
            Curves(ri).(['TX_', condition, '_peakExc'])  = c.TX_peakExc;
            Curves(ri).(['TX_', condition, '_excSign'])  = c.TX_excSign;
        end

        % Épaule asymptomatique de ce patient à cette condition ?
        asymSide = findAsymptomaticSide(Opts.AsymptomaticSelection, d, condition);
        for iS = 1:length(Contrib)
            c = Contrib(iS);
            if ~strcmp(c.side, asymSide), continue; end
            ai = length(AsymCurves) + 1;
            AsymResults(ai).Numero    = d.Numero;
            AsymResults(ai).PatientID = d.PatientID;
            AsymResults(ai).Side      = c.side;
            AsymResults(ai).Task      = c.task;
            AsymResults(ai).Condition = condition;
            AsymResults(ai).HG_ASYM_deg     = c.HG_range;
            AsymResults(ai).GH_ASYM_deg     = c.GH_range;
            AsymResults(ai).GH_ASYM_pct     = c.GH_pct;
            AsymResults(ai).ST_ASYM_deg     = c.ST_range;
            AsymResults(ai).ST_ASYM_pct     = c.ST_pct;
            AsymResults(ai).TX_ASYM_deg     = c.TX_range;
            AsymResults(ai).TX_ASYM_pct     = c.TX_pct;
            AsymResults(ai).HG_ASYM_max_deg = c.HG_max;
            AsymResults(ai).GH_ASYM_max_deg = c.GH_max;
            AsymResults(ai).ST_ASYM_max_deg = c.ST_max;
            AsymCurves(ai).PatientID = d.PatientID;
            AsymCurves(ai).Side      = c.side;
            AsymCurves(ai).Task      = c.task;
            AsymCurves(ai).HG_ASYM   = c.HG_curve;
            AsymCurves(ai).GH_ASYM   = c.GH_curve;
            AsymCurves(ai).ST_ASYM   = c.ST_curve;
            AsymCurves(ai).TX_ASYM   = c.TX_curve;
            AsymCurves(ai).ST_ASYM_raw      = c.ST_raw;
            AsymCurves(ai).ST_ASYM_rangeRaw = c.ST_rangeRaw;
            AsymCurves(ai).ST_ASYM_peakExc  = c.ST_peakExc;
            AsymCurves(ai).ST_ASYM_excSign  = c.ST_excSign;
            AsymCurves(ai).TX_ASYM_raw      = c.TX_raw;
            AsymCurves(ai).TX_ASYM_rangeRaw = c.TX_rangeRaw;
            AsymCurves(ai).TX_ASYM_peakExc  = c.TX_peakExc;
            AsymCurves(ai).TX_ASYM_excSign  = c.TX_excSign;
        end
    end
end
clear S
end
disp(['Patients dans la base : ', num2str(totalPatients)]);
if ~isempty(Opts.AsymptomaticSelection)
    disp(['Épaules asymptomatiques retrouvées : ', num2str(numel(unique(strcat({AsymCurves.PatientID}, {AsymCurves.Side})))), ...
          ' / ', num2str(size(Opts.AsymptomaticSelection, 1))]);
end

% Correction des courbes ST et TX inversées (angle de repos de signe opposé
% que abs() ne rend pas cohérent) - voir ApplyInversionCorrectionSTTX.m.
% Opts.ApplyInvCorr = false pour retrouver les valeurs non corrigées.
% Asymptomatiques corrigées à part (référence = moyenne des asymptomatiques),
% pour ne pas modifier la référence ni les résultats des patients.
if Opts.ApplyInvCorr
    [Results, Curves] = ApplyInversionCorrectionSTTX(Results, Curves, 'HG', Opts.CorrThresh);
    [AsymResults, AsymCurves] = ApplyInversionCorrectionSTTX(AsymResults, AsymCurves, 'HG', Opts.CorrThresh, {'ASYM'});
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if ~isempty(Results)
    T = struct2table(Results);
    if isfile(OutputFile), delete(OutputFile); end
    writetable(T, OutputFile, 'Sheet', 'Functional_Contributions');
    if ~isempty(AsymResults)
        writetable(struct2table(AsymResults), OutputFile, 'Sheet', 'Functional_Asymptomatic');
    end
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
else
    disp(' ');
    disp('Aucune donnée à exporter.');
end

PlotHGContributionsCurves(Curves, AsymCurves);

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
end

end

% =========================================================================
%  EPAULE ASYMPTOMATIQUE (voir AsymptomaticSelection, userCommands_Multi.m)
% =========================================================================
% Côté asymptomatique ('R'/'L') du patient d pour cette condition, '' si
% aucun. Même règle que dans ComputeClinicalContributionsFromDatabase.m.
function asymSide = findAsymptomaticSide(AsymSel, d, condition)
asymSide = '';
for k = 1:size(AsymSel, 1)
    if ~strcmp(num2str(AsymSel{k, 1}), num2str(d.PatientID)), continue; end
    if ~strcmp(AsymSel{k, 3}, condition), continue; end
    if ismember(AsymSel{k, 2}, d.Side), continue; end
    [~, sessName] = fileparts(d.(condition).Date);
    if ~startsWith(sessName, AsymSel{k, 4}), continue; end
    asymSide = AsymSel{k, 2};
    return;
end
end

% =========================================================================
%  DECOUVERTE DES FICHIERS DE PARTIES (voir NumDatabaseParts,
%  userCommands_Multi.m / MAIN_MULTI_Protocol_01.m)
% =========================================================================
function fileList = discoverDatabaseFiles(DatabaseFile)
[dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
parts = dir(fullfile(dbFolder, [dbName, '_part*of*', dbExt]));
if isempty(parts)
    if isfile(DatabaseFile)
        fileList = {DatabaseFile};
    else
        fileList = {};
    end
    return;
end
% Tri par numero de partie (part1of4, part2of4...) plutot que par ordre
% alphabetique (qui casserait a partir de 10 parties : "part10" < "part2").
partNum = zeros(numel(parts), 1);
for i = 1:numel(parts)
    tok = regexp(parts(i).name, '_part(\d+)of\d+', 'tokens', 'once');
    partNum(i) = str2double(tok{1});
end
[~, order] = sort(partNum);
parts = parts(order);
fileList = fullfile({parts.folder}, {parts.name});
end

% =========================================================================
%  DECOMPOSITION HG/GH/ST/TX (pendant "fonctionnel" de ComputeClinicalContributions -
%  meme decomposition Euler, HG au lieu de HT comme reference d'amplitude)
% =========================================================================
%
% Decompose the humero-gravitational (HG) range of motion into glenohumeral
% (GH), scapulothoracic (ST) and thoracic (TX) sub-contributions, in
% degrees and in % of HG range.
%
% HG (Joint 12/13) quantifies the absolute orientation of the humerus in
% the patient-referenced gravitational frame (YXY sequence - Wu et al.
% 2005), as opposed to HT (Joint 1/6) which is humerus-relative-to-thorax.
%
% Unlike HT, the HG Euler sequence is NOT conditioned on the ANALYTIC sub-
% task in Protocol01/Core/ComputeKinematics.m (only "contains(...,
% 'ANALYTIC')" is tested, not ANALYTIC1 vs ANALYTIC2) - DOF1 X (position 1)
% = elevation for both ANALYTIC1 and ANALYTIC2, so dofHG is fixed at 1,
% no per-task mapping needed for HG itself.
%
% GH and ST/TX are the exact same joints/DOF as in ComputeClinicalContributions
% (HT version) - GH DOES remain task-dependent (its own Euler sequence
% changes with the task, same reasoning as HT - see Protocol01/Core/
% ComputeKinematics.m and ComputeClinicalContributionsFromDatabase.m) :
%
% ANALYTIC3/4 (external/internal rotation) : HG reports DOF3 Y2 (axial
% rotation, YXY). Caution - with the arm along the body (HG elevation X
% close to 0) the YXY sequence is near gimbal lock and Y1/Y2 are poorly
% separated, so HG_range for these tasks must be checked against HT before
% being trusted. GH/ST/TX : same DOF as ComputeClinicalContributions.
%
% DOF mapping :
%   HG Joint(12/13) ANALYTIC1/2: DOF1 X — elevation | ANALYTIC3/4: DOF3 Y2 — axial rotation (YXY)
%   GH Joint(2/7)   ANALYTIC1: DOF3 Z — flexion/extension | ANALYTIC2: DOF1 X — abduction | ANALYTIC3/4: DOF2 Y — axial rotation
%   ST Joint(3/8)   ANALYTIC1/2: DOF1 X — upward rot. | ANALYTIC3/4: DOF2 Y — protraction/retraction (YXZ)
%   TX Joint(11)    ANALYTIC1/2: DOF3 Z — flexion     | ANALYTIC3/4: DOF2 Y — axial rotation (ZXY)
%
% HG_max/GH_max/ST_max : peak angle reached (mean of each cycle's
% max |angle|, same cycle-averaging convention as HG_range etc., but max
% instead of max-min) - NOT the same as *_range, which is an amplitude
% (max-min). No thorax peak: the thorax flexion crosses zero during the
% movement, so max |angle| would mix rest flexion and peak extension ;
% TX_range is max - min of the SIGNED angle (getRangeCycleTH).
%
% HG_curve/GH_curve/ST_curve/TX_curve : mean curve (across cycles) of the
% angle vs % cycle (0-100%), same number of points as the cycle
% normalisation done by CutCycles.m. Used for the PRE/POST plot in
% PlotHGContributionsCurves. TX uses getCurveCycleTH (not getCurveCycle)
% for the same reason TX_range uses getRangeCycleTH : joint 11 (thorax) is
% a single shared joint, not duplicated per side like HG/GH/ST, so it can
% need the R/L cycField fallback.
%
% Inputs  : Trial (struct array) all trials from runProtocol01/MAIN_Protocol_01
% Outputs : Contrib (struct array, one row per task found x side 'R'/'L')
%           with fields task ('ANALYTIC1'-'ANALYTIC4'), side, HG_range,
%           GH_range, GH_pct, ST_range, ST_pct, TX_range, TX_pct, HG_max,
%           GH_max, ST_max, HG_curve, GH_curve, ST_curve, TX_curve
%           Empty (0x0) struct array if neither task is found in Trial.
function Contrib = ComputeFunctionalContributions(Trial)

Contrib = struct('task', {}, 'side', {}, 'HG_range', {}, ...
                  'GH_range', {}, 'GH_pct', {}, 'ST_range', {}, 'ST_pct', {}, ...
                  'TX_range', {}, 'TX_pct', {}, ...
                  'HG_max', {}, 'GH_max', {}, 'ST_max', {}, ...
                  'HG_curve', {}, 'GH_curve', {}, 'ST_curve', {}, 'TX_curve', {}, ...
                  'ST_raw', {}, 'ST_rangeRaw', {}, 'ST_peakExc', {}, 'ST_excSign', {}, ...
                  'TX_raw', {}, 'TX_rangeRaw', {}, 'TX_peakExc', {}, 'TX_excSign', {});

% DOF task-dependant pour GH uniquement (HG et ST/TX sont fixes quelle que
% soit la tache - sequences non conditionnees par la sous-tache dans
% ComputeKinematics.m).
% ANALYTIC3/4 (rotations) : HG DOF3 Y2 (axial), GH/ST/TX DOF2 Y (voir
% ComputeClinicalContributionsFromDatabase.m).
taskDOF = struct('name', {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'}, ...
                  'dofHG', {1, 1, 3, 3}, 'dofGH', {3, 1, 2, 2}, 'dofST', {1, 1, 2, 2}, 'dofTX', {3, 3, 2, 2});

sideDef = struct('side', {'R','L'}, 'jiHG', {12,13}, 'jiGH', {2,7}, 'jiST', {3,8}, ...
                  'cycField', {'rcycle','lcycle'});

for iT = 1:numel(taskDOF)
    task  = taskDOF(iT).name;
    dofHG = taskDOF(iT).dofHG;
    dofGH = taskDOF(iT).dofGH;
    dofST = taskDOF(iT).dofST;
    dofTX = taskDOF(iT).dofTX;
    tidx = [];
    for k = 1:length(Trial)
        if contains(Trial(k).task, task)
            tidx = k;
            break;
        end
    end
    if isempty(tidx), continue; end
    t = Trial(tidx);

    for iS = 1:length(sideDef)
        s  = sideDef(iS);
        hg = getRangeCycle(t, s.jiHG, dofHG, s.cycField);
        gh = getRangeCycle(t, s.jiGH, dofGH, s.cycField);
        st = getRangeCycle(t, s.jiST, dofST, s.cycField);
        tx = getRangeCycleTH(t, 11, dofTX, s.cycField);

        i = length(Contrib) + 1;
        Contrib(i).task     = task;
        Contrib(i).side     = s.side;
        Contrib(i).HG_range = hg;
        Contrib(i).GH_range = gh;
        Contrib(i).GH_pct   = safePct(gh, hg);
        Contrib(i).ST_range = st;
        Contrib(i).ST_pct   = safePct(st, hg);
        Contrib(i).TX_range = tx;
        Contrib(i).TX_pct   = safePct(tx, hg);

        Contrib(i).HG_max = getPeakCycle(t, s.jiHG, dofHG, s.cycField);
        Contrib(i).GH_max = getPeakCycle(t, s.jiGH, dofGH, s.cycField);
        Contrib(i).ST_max = getPeakCycle(t, s.jiST, dofST, s.cycField);

        Contrib(i).HG_curve = getCurveCycle(t, s.jiHG, dofHG, s.cycField);
        Contrib(i).GH_curve = getCurveCycle(t, s.jiGH, dofGH, s.cycField);
        Contrib(i).ST_curve = getCurveCycle(t, s.jiST, dofST, s.cycField);
        Contrib(i).TX_curve = getCurveCycleTH(t, 11, dofTX, s.cycField);

        [Contrib(i).ST_raw, Contrib(i).ST_rangeRaw, Contrib(i).ST_peakExc, Contrib(i).ST_excSign] = ...
            getRawInfo(t, s.jiST, dofST, s.cycField, false);
        [Contrib(i).TX_raw, Contrib(i).TX_rangeRaw, Contrib(i).TX_peakExc, Contrib(i).TX_excSign] = ...
            getRawInfo(t, 11, dofTX, s.cycField, true);
    end
end

end

% Données brutes signées (sans abs) d'un DOF, pour la correction ST/TX
% inversées (voir ApplyInversionCorrectionSTTX.m) :
%   rawMean  : moyenne des cycles du brut signé
%   rangeRaw : moyenne des cycles de (max - min) du brut (indépendant du signe
%              et de l'offset)
%   sp       : sens de l'excursion brute par rapport au repos (moyenne
%              début/fin du cycle), +1/-1
%   peakExc  : moyenne des cycles de max(sp*(brut - repos))
% shared = joint 11 (thorax), repli R/L comme getRangeCycleTH.
function [rawMean, rangeRaw, peakExc, sp] = getRawInfo(t, ji, dof, cycField, shared)
rawMean = []; rangeRaw = NaN; peakExc = NaN; sp = NaN;
if length(t.Joint) < ji, return; end
cf = cycField;
if shared && isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
cyc = squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :));
if isvector(cyc), cyc = cyc(:); end
cyc = cyc(:, any(~isnan(cyc), 1));
if isempty(cyc), return; end
rawMean  = mean(cyc, 2, 'omitnan');
rangeRaw = mean(max(cyc, [], 1) - min(cyc, [], 1), 'omitnan');
base     = mean(rawMean([1 end]));
[~, ip]  = max(abs(rawMean - base));
sp       = sign(rawMean(ip) - base);
if sp == 0, sp = 1; end
peakExc  = mean(max(sp * (cyc - base), [], 1), 'omitnan');
end

function r = getRangeCycle(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function r = getRangeCycleTH(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji, return; end
cf = cycField;
if isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf,'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
% Thorax : amplitude sur le signal SIGNÉ (max - min), pas sur abs() : la
% flexion du thorax passe souvent par zéro pendant le geste (fléchi au
% repos, redressé au pic), et abs() replie alors la courbe et sous-estime
% l'amplitude (ex. -15.5 à +6 deg : 21.5 deg réels, 15.5 deg avec abs).
data = squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function r = getPeakCycle(t, ji, dof, cycField)
% Peak angle reached (mean across cycles of each cycle's max |angle|) -
% same convention as getRangeCycle, but max instead of max-min.
r = NaN;
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
peaks = max(data, [], 1);
r = mean(peaks, 'omitnan');
end


function c = getCurveCycle(t, ji, dof, cycField)
% Mean curve (across cycles) of the angle, already normalised to % cycle
% by CutCycles.m (same number of points across all cycles/patients).
c = [];
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
c = mean(data, 2, 'omitnan');
end

function c = getCurveCycleTH(t, ji, dof, cycField)
% Same as getCurveCycle, with the R/L cycField fallback also used by
% getRangeCycleTH (joint 11 = thorax, single shared joint, not duplicated
% per side like HG/GH/ST).
c = [];
if length(t.Joint) < ji, return; end
cf = cycField;
if isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf,'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :)));
if isvector(data), data = data(:); end
c = mean(data, 2, 'omitnan');
end

function p = safePct(num, den)
if isnan(num) || isnan(den) || den == 0
    p = NaN;
else
    p = num / den * 100;
end
end

% =========================================================================
%  TRACE DES COURBES PRE/POST (pendant "fonctionnel" de PlotHTContributionsCurves)
% =========================================================================
%
% Plots the angle vs % cycle (0-100%) HG/GH/ST/TX curves, PRE vs POST.
%
% Layout: 1 figure per task found (ANALYTIC1 and ANALYTIC2 are never
% averaged together, since they are different movements), 1 row x 4
% columns (HG, GH, ST, TX) each :
%   Individual curve per patient/side, transparent (red = PRE, blue = POST)
%   Bold mean curve (red = PRE, blue = POST)
%   Each curve is resampled to 101 points (0-100%) before averaging, in
%   case the number of cycle points differs from one patient to another.
%
% Inputs  : Curves (struct array) with fields Task ('ANALYTIC1'/'ANALYTIC2'),
%           HG_PRE/HG_POST, GH_PRE/GH_POST, ST_PRE/ST_POST, TX_PRE/TX_POST
%           (vectors, or [] if absent)
%           AsymCurves (struct array, optional) asymptomatic shoulders,
%           fields Task, HG_ASYM/GH_ASYM/ST_ASYM/TX_ASYM - plotted in green
%           (individual + bold mean), same layout
% Outputs : 1 figure per task found (4 subplots each)
function PlotHGContributionsCurves(Curves, AsymCurves)

if nargin < 2, AsymCurves = struct('Task', {}); end
if isempty(Curves)
    disp('PlotHGContributionsCurves: no data to plot.');
    return;
end

tasks = unique({Curves.Task});
for iT = 1:numel(tasks)
    task = tasks{iT};
    asym = AsymCurves([]);
    if ~isempty(AsymCurves), asym = AsymCurves(strcmp({AsymCurves.Task}, task)); end
    plotTaskCurves(Curves(strcmp({Curves.Task}, task)), asym, task);
end

end

function plotTaskCurves(Curves, AsymCurves, task)

metrics = {'HG', 'GH', 'ST', 'TX'};
titles  = {'HG (huméro-gravitationnel)', 'GH (glénohuméral)', 'ST (scapulothoracique)', 'TX (thoracique)'};
xgrid   = linspace(0, 100, 101);
colPre  = [0.8500 0.3250 0.0980]; % red
colPost = [0 0.4470 0.7410];   % blue
colAsym = [0.4660 0.6740 0.1880]; % green

figure('Name', ['Courbes HG/GH/ST/TX — ', task, ' — PRE vs POST'], 'Color', 'w');

for m = 1:length(metrics)
    preField  = [metrics{m}, '_PRE'];
    postField = [metrics{m}, '_POST'];

    preCurves  = [];
    postCurves = [];

    subplot(1, length(metrics), m);
    hold on;

    for i = 1:length(Curves)
        pre = resample101(Curves(i).(preField), xgrid);
        if ~isempty(pre)
            h = plot(xgrid, pre, 'Color', colPre, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = 0.25;
            preCurves = [preCurves, pre(:)]; %#ok<AGROW>
        end

        post = resample101(Curves(i).(postField), xgrid);
        if ~isempty(post)
            h = plot(xgrid, post, 'Color', colPost, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = 0.25;
            postCurves = [postCurves, post(:)]; %#ok<AGROW>
        end
    end

    asymCurves = [];
    for i = 1:length(AsymCurves)
        asym = resample101(AsymCurves(i).([metrics{m}, '_ASYM']), xgrid);
        if ~isempty(asym)
            h = plot(xgrid, asym, 'Color', colAsym, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = 0.25;
            asymCurves = [asymCurves, asym(:)]; %#ok<AGROW>
        end
    end

    if ~isempty(preCurves)
        plot(xgrid, mean(preCurves, 2, 'omitnan'), 'Color', colPre, 'LineWidth', 3, 'DisplayName', 'PRE (moyenne)');
    end
    if ~isempty(postCurves)
        plot(xgrid, mean(postCurves, 2, 'omitnan'), 'Color', colPost, 'LineWidth', 3, 'DisplayName', 'POST (moyenne)');
    end
    if ~isempty(asymCurves)
        plot(xgrid, mean(asymCurves, 2, 'omitnan'), 'Color', colAsym, 'LineWidth', 3, ...
            'DisplayName', ['Asymptomatique (moyenne, n=', num2str(size(asymCurves, 2)), ')']);
    end

    hold off;
    xlim([0 100]);
    xlabel('Cycle (%)');
    ylabel([metrics{m}, ' (deg)']);
    title(titles{m});
    legend('show', 'Location', 'best');
    box on;
end

sgtitle([task, ' — PRE vs POST']);

end

function c = resample101(curve, xgrid)
% Resamples a vector of any length onto the 0-100% grid (101 points), so
% that cycles of different lengths can be averaged together.
c = [];
curve = curve(:);
curve = curve(~isnan(curve));
if length(curve) < 2, return; end
xOrig = linspace(0, 100, length(curve));
c = interp1(xOrig, curve, xgrid, 'linear');
end
