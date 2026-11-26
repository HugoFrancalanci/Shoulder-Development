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
%           Opts          (struct, optionnel) AsymptomaticSelection (cell, {} par défaut) :
%                         épaules asymptomatiques {ID, côté, 'PRE'/'POST',
%                         date} (voir userCommands_Multi.m), tracées en vert
%                         sur la figure des courbes et exportées dans la
%                         feuille 'Functional_Asymptomatic' (une ligne par
%                         épaule/tâche, colonnes <M>_ASYM_deg/_max_deg)
% Outputs : Results (struct array) une ligne par patient/côté/tâche - aussi
%           retourné pour exploitation directe sans repasser par l'Excel
%           AsymResults (struct array) épaules asymptomatiques
%           Curves (struct array, même indexation que Results) courbes
%           HG/GH/ST/TX_<PRE|POST> du cycle retenu (101 points), signées
%           dans la convention anatomique du côté droit (Orientation.m :
%           jamais repliées par abs ; HG élévation négative, ST rotation
%           latérale négative), pour ExportRegistre
%           AsymCurves (struct array, même indexation que AsymResults)
%           courbes HG/GH/ST/TX_ASYM des épaules asymptomatiques, avec
%           Numero et Condition (export vers le registre)
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

function [Results, AsymResults, Curves, AsymCurves] = ComputeFunctionalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder, Opts)

if nargin < 3, ResultsFolder = ''; end
if nargin < 4, Opts = struct(); end
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
    'HG_PRE_deg', {}, 'GH_PRE_deg', {}, ...
    'ST_PRE_deg', {}, 'TX_PRE_deg', {}, ...
    'HG_POST_deg', {}, 'GH_POST_deg', {}, ...
    'ST_POST_deg', {}, 'TX_POST_deg', {}, ...
    'HG_PRE_max_deg', {}, 'GH_PRE_max_deg', {}, 'ST_PRE_max_deg', {}, ...
    'HG_POST_max_deg', {}, 'GH_POST_max_deg', {}, 'ST_POST_max_deg', {}, ...
    'TXlat_PRE_deg', {}, 'TXlat_POST_deg', {}, ...
    'Cycle_PRE', {}, 'Cycle_POST', {}, 'CycleAlert_PRE', {}, 'CycleAlert_POST', {});
% Pas de pic pour le thorax : max |angle| n'a pas de sens quand la flexion
% passe par zéro (il mélange la flexion au repos et l'extension au pic) ;
% le thorax est décrit par son ROM (signal signé) et la flexion signée
% (ComputePostureFromDatabase.m)
% TXlat : ROM de l'inclinaison latérale du thorax (Joint 11, DOF1 X), en
% plus de TX (flexion / extension) : en scaption, c'est surtout par
% l'inclinaison latérale que le tronc compense. Hors pourcentages
% (amplitude du signal signé, indépendante du sens).

% Courbes angle vs % cycle
Curves = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'HG_PRE', {}, 'HG_POST', {}, 'GH_PRE', {}, 'GH_POST', {}, 'ST_PRE', {}, 'ST_POST', {}, ...
    'TX_PRE', {}, 'TX_POST', {});

% Courbes des épaules asymptomatiques (côté controlatéral, une seule
% session par épaule - voir AsymptomaticSelection dans userCommands_Multi.m).
% Condition 'ASYM' : mêmes champs que Curves.
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
                Results(ri).ST_PRE_deg   = NaN; Results(ri).ST_POST_deg  = NaN;
                Results(ri).TX_PRE_deg   = NaN; Results(ri).TX_POST_deg  = NaN;
                Results(ri).HG_PRE_max_deg = NaN; Results(ri).HG_POST_max_deg = NaN;
                Results(ri).GH_PRE_max_deg = NaN; Results(ri).GH_POST_max_deg = NaN;
                Results(ri).ST_PRE_max_deg = NaN; Results(ri).ST_POST_max_deg = NaN;
                Results(ri).TXlat_PRE_deg  = NaN; Results(ri).TXlat_POST_deg  = NaN;
                Results(ri).Cycle_PRE      = NaN; Results(ri).Cycle_POST      = NaN;
                Results(ri).CycleAlert_PRE = '';  Results(ri).CycleAlert_POST = '';
            end

            Results(ri).(['HG_', condition, '_deg']) = c.HG_range;
            Results(ri).(['GH_', condition, '_deg']) = c.GH_range;
            Results(ri).(['ST_', condition, '_deg']) = c.ST_range;
            Results(ri).(['TX_', condition, '_deg']) = c.TX_range;

            Results(ri).(['HG_', condition, '_max_deg']) = c.HG_max;
            Results(ri).(['GH_', condition, '_max_deg']) = c.GH_max;
            Results(ri).(['ST_', condition, '_max_deg']) = c.ST_max;
            Results(ri).(['TXlat_', condition, '_deg'])  = c.TXlat_range;
            Results(ri).(['Cycle_', condition])      = c.cycleIdx;
            Results(ri).(['CycleAlert_', condition]) = c.cycleAlert;
            if ~isempty(c.cycleAlert)
                fprintf('Alerte cycle (%s) : n°%d %s %s %s : %s\n', 'fonctionnel', d.Numero, c.side, c.task, condition, c.cycleAlert);
            end

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
            AsymResults(ai).ST_ASYM_deg     = c.ST_range;
            AsymResults(ai).TX_ASYM_deg     = c.TX_range;
            AsymResults(ai).HG_ASYM_max_deg = c.HG_max;
            AsymResults(ai).GH_ASYM_max_deg = c.GH_max;
            AsymResults(ai).ST_ASYM_max_deg = c.ST_max;
            AsymResults(ai).TXlat_ASYM_deg  = c.TXlat_range;
            AsymResults(ai).Cycle_ASYM      = c.cycleIdx;
            AsymResults(ai).CycleAlert_ASYM = c.cycleAlert;
            if ~isempty(c.cycleAlert)
                fprintf('Alerte cycle (%s) : n°%d %s %s ASYM (%s) : %s\n', 'fonctionnel', d.Numero, c.side, c.task, condition, c.cycleAlert);
            end
            AsymCurves(ai).PatientID = d.PatientID;
            AsymCurves(ai).Side      = c.side;
            AsymCurves(ai).Task      = c.task;
            AsymCurves(ai).Numero    = d.Numero;
            AsymCurves(ai).Condition = condition;
            AsymCurves(ai).HG_ASYM   = c.HG_curve;
            AsymCurves(ai).GH_ASYM   = c.GH_curve;
            AsymCurves(ai).ST_ASYM   = c.ST_curve;
            AsymCurves(ai).TX_ASYM   = c.TX_curve;
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
% Stockage par projet : DatabaseFile est le dossier Patients\ du projet, un
% .mat par épaule dans Patients\<n°>_<ID>_<côté>\ (ordre des numéros)
if isfolder(DatabaseFile)
    f = dir(fullfile(DatabaseFile, '*', '*.mat'));
    fileList = {};
    if ~isempty(f), fileList = sort(fullfile({f.folder}, {f.name})); end
    return;
end
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
%   TXlat Joint(11) all tasks: DOF1 X — lateral tilt (+ = toward the right),
%                   middle angle of ZXY (small, no gimbal lock) ; range on the
%                   SIGNED angle like TX, not part of the percentages
%
% Sign convention (Orientation.m, November 2026) : no abs(). Every curve is
% the SIGNED angle in the right-side anatomical convention ; values are
% computed on the curve oriented in the direction of motion
% (Orientation.sens), so they are positive and never folded.
% *_range : amplitude, max - min on the selected cycle (BestCycle.range).
% HG_max/GH_max/ST_max : peak reached in the direction of motion
% (BestCycle.peak) - NOT the same as *_range. No thorax peak ; TX_range on
% the signed angle.
%
% HG_curve/GH_curve/ST_curve/TX_curve : signed anatomical curve on the
% selected cycle (BestCycle.curve) vs % cycle (0-100%), used for the
% PRE/POST plot in PlotHGContributionsCurves. The thorax (joint 11, shared)
% uses the R/L cycField fallback of BestCycle.raw.
%
% Inputs  : Trial (struct array) all trials from runProtocol01/MAIN_Protocol_01
% Outputs : Contrib (struct array, one row per task found x side 'R'/'L')
%           with fields task ('ANALYTIC1'-'ANALYTIC4'), side, HG_range,
%           GH_range, ST_range, TX_range, HG_max,
%           GH_max, ST_max, HG_curve, GH_curve, ST_curve, TX_curve
%           Empty (0x0) struct array if neither task is found in Trial.
function Contrib = ComputeFunctionalContributions(Trial)

Contrib = struct('task', {}, 'side', {}, 'HG_range', {}, ...
                  'GH_range', {}, 'ST_range', {}, ...
                  'TX_range', {}, 'TXlat_range', {}, ...
                  'HG_max', {}, 'GH_max', {}, 'ST_max', {}, ...
                  'HG_curve', {}, 'GH_curve', {}, 'ST_curve', {}, 'TX_curve', {}, ...
                  'cycleIdx', {}, 'cycleAlert', {});

% DOF task-dependant pour GH uniquement (HG et ST/TX sont fixes quelle que
% soit la tache - sequences non conditionnees par la sous-tache dans
% ComputeKinematics.m).
% ANALYTIC3/4 (rotations) : HG DOF3 Y2 (axial), GH/ST/TX DOF2 Y (voir
% ComputeClinicalContributionsFromDatabase.m).
taskDOF = struct('name', {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'}, ...
                  'dofHG', {1, 1, 3, 3}, 'dofGH', {3, 1, 2, 2}, 'dofST', {1, 1, 2, 2}, 'dofTX', {3, 3, 2, 2}, ...
                  'dofTXlat', {1, 1, 1, 1});

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
        % Cycle retenu (meilleur des cycles valides, voir BestCycle.m),
        % le même pour tous les joints, en pic comme en amplitude
        sel = BestCycle.select(t, task, s.side);
        % Courbes anatomiques signées (convention du côté droit, sans abs,
        % voir Orientation.m) ; valeurs dans le sens du mouvement
        xHG = Orientation.anat(BestCycle.raw(t, s.jiHG, dofHG, s.cycField, false), 'HG', task, s.side);
        xGH = Orientation.anat(BestCycle.raw(t, s.jiGH, dofGH, s.cycField, false), 'GH', task, s.side);
        xST = Orientation.anat(BestCycle.raw(t, s.jiST, dofST, s.cycField, false), 'ST', task, s.side);
        xTX = Orientation.anat(BestCycle.raw(t, 11, dofTX, s.cycField, true), 'TX', task, s.side);

        i = length(Contrib) + 1;
        Contrib(i).task     = task;
        Contrib(i).side     = s.side;
        Contrib(i).cycleIdx   = sel.idx;
        Contrib(i).cycleAlert = sel.alert;
        Contrib(i).HG_range = amplitude(xHG, 'HG', task, sel.idx);
        Contrib(i).GH_range = amplitude(xGH, 'GH', task, sel.idx);
        Contrib(i).ST_range = amplitude(xST, 'ST', task, sel.idx);
        Contrib(i).TX_range = amplitude(xTX, 'TX', task, sel.idx);
        Contrib(i).TXlat_range = BestCycle.range(BestCycle.raw(t, 11, taskDOF(iT).dofTXlat, s.cycField, true), sel.idx);

        Contrib(i).HG_max = pic(xHG, 'HG', task, sel.idx);
        Contrib(i).GH_max = pic(xGH, 'GH', task, sel.idx);
        Contrib(i).ST_max = pic(xST, 'ST', task, sel.idx);

        Contrib(i).HG_curve = BestCycle.curve(xHG, sel.idx);
        Contrib(i).GH_curve = BestCycle.curve(xGH, sel.idx);
        Contrib(i).ST_curve = BestCycle.curve(xST, sel.idx);
        Contrib(i).TX_curve = BestCycle.curve(xTX, sel.idx);
    end
end

end

% Amplitude (max - min) d'une courbe anatomique dans le sens du mouvement,
% sur le cycle retenu (fenêtre autour du pic, voir BestCycle.range) ; sans
% sens fixe (thorax en rotation), sur la courbe telle quelle
function r = amplitude(x, art, task, idx)
s = Orientation.sens(art, task); if isnan(s), s = 1; end
r = BestCycle.range(s * x, idx);
end

% Pic dans le sens du mouvement, cycle retenu : élévations = valeur atteinte
% (BestCycle.peak) ; rotations (ANALYTIC3/4) = rotation réalisée depuis la
% position de départ (BestCycle.rotation), indépendante de l'angle de départ
% (ST en protraction, HG proche du blocage de cardan bras le long du corps)
function p = pic(x, art, task, idx)
s = Orientation.sens(art, task); if isnan(s), s = 1; end
if any(strcmp(task, {'ANALYTIC3', 'ANALYTIC4'}))
    p = BestCycle.rotation(s * x, idx);
else
    p = BestCycle.peak(s * x, idx);
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
