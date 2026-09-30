% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Rapport de qualité de la reconstruction du centre de
%                rotation (CoR) glénohuméral (SCoRE, Ehrig et al. 2006),
%                calculé depuis PatientDatabase.mat plutôt qu'en repassant
%                par les C3D. Même patron que Multi/Core/
%                ComputeClinicalContributionsFromDatabase.m.
%
%                IMPORTANT - contrairement aux rapports HT/HG : la
%                calibration SCoRE est faite UNE SEULE FOIS par
%                patient/côté/condition (PRE ou POST), en poolant un jeu
%                fixe d'essais de calibration (ANALYTIC2, ANALYTIC4,
%                FUNCTIONAL1, FUNCTIONAL3 par défaut - voir Core/CoR/
%                ComputeSCoRE.m), PAS par tâche ANALYTIC1/ANALYTIC2. Le CoR
%                ainsi calibré est ensuite réutilisé pour reconstruire tous
%                les essais de la session, ANALYTIC1 inclus. Donc une seule
%                valeur de qualité par patient/côté/condition ici, pas une
%                par tâche.
%
%                Stockage dans la base : Session.SCoRE (calculé dans
%                Core/CoR/ComputeSCoRE.m) est sauvegardé tel quel dans
%                Database(i).PRE.Session / Database(i).POST.Session (voir
%                MAIN_MULTI_Protocol_01.m, BatchDatabase(k).(condition).Session
%                = Session). Champs utilisés ici :
%                  Session.SCoRE.R/.L.residual_mm        [1xN] mm - agrément
%                    CoR estimé via Ti vs via Tj, par frame de calibration
%                    pooled (N = nb de frames valides pooled ; quality metric)
%                  Session.SCoRE.R/.L.clusterRMS.scapula_mm / .humerus_mm
%                    scalaire, mm - RMS du fit rigide (Soder) du cluster
%
%                Pas de seuil "officiel" validé dans le code pour flaguer un
%                résidu comme mauvais (ComputeCTGoldStandardCoR.m /
%                ExploreSCoRECombos.m mesurent une distance à un CT gold
%                standard, ~20-28mm, ce qui n'est PAS la même métrique que
%                ce résidu d'auto-cohérence Ti/Tj). Le seuil ThresholdMM ici
%                est donc un paramètre ajustable (défaut 30mm) - regarder la
%                distribution sur le graphe produit avant de se fier au
%                flag Excel.
%
%                Callable à tout moment depuis la fenêtre de commande
%                (ou un script), sans rien relancer sur les C3D :
%                  ComputeCoRQualityFromDatabase(DatabaseFile, OutputFile, ResultsFolder)
%                  ComputeCoRQualityFromDatabase(DatabaseFile, OutputFile, ResultsFolder, ThresholdMM)
%
%                Prérequis : avoir lancé MAIN_MULTI_Protocol_01.m au moins
%                une fois avec SaveDatabase=true (voir userCommands_Multi.m)
%                pour générer PatientDatabase.mat.
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile  (char) chemin vers PatientDatabase.mat
%           OutputFile    (char) chemin de l'Excel de sortie (qualité CoR)
%           ResultsFolder (char, optionnel) dossier où se terminer (cd) une
%                         fois l'export fait ; omis = pas de cd
%           ThresholdMM   (double, optionnel) seuil de résidu moyen (mm) au-
%                         delà duquel une ligne est flaguée 'A verifier'
%                         dans Flag_PRE/Flag_POST. Défaut 15.
%           Opts          (struct, optionnel) AsymptomaticSelection (cell,
%                         {} par défaut) : épaules asymptomatiques {ID, côté,
%                         'PRE'/'POST', date} (voir userCommands_Multi.m),
%                         exportées dans la feuille 'CoR_Asymptomatic' (une
%                         ligne par épaule, condition retenue seulement ; pas
%                         sur la figure)
% Outputs : Results (struct array) une ligne par patient/côté - aussi
%           retourné pour exploitation directe sans repasser par l'Excel
%           AsymResults (struct array) une ligne par épaule asymptomatique
%           Fichier Excel écrit sur disque + 1 figure diagnostique (résidu
%           SCoRE trié, PRE vs POST, patients au-dessus du seuil étiquetés)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, AsymResults] = ComputeCoRQualityFromDatabase(DatabaseFile, OutputFile, ResultsFolder, ThresholdMM, Opts)

if nargin < 3, ResultsFolder = ''; end
if nargin < 4 || isempty(ThresholdMM), ThresholdMM = 30; end
if nargin < 5, Opts = struct(); end
if ~isfield(Opts, 'AsymptomaticSelection'), Opts.AsymptomaticSelection = {}; end

% La base peut être répartie sur plusieurs fichiers .mat (voir
% NumDatabaseParts dans userCommands_Multi.m, DatabaseFile_partXofY.mat) -
% détecté automatiquement ; repli sur DatabaseFile seul si aucune partie
% trouvée (compatibilité avec un run à un seul fichier).
fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeCoRQualityFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

% -------------------------------------------------------------------------
% BOUCLE PATIENTS (depuis Database, pas depuis PatientSelection/C3D)
% -------------------------------------------------------------------------
Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, ...
    'SCoRE_Residual_PRE_mean_mm', {}, 'SCoRE_Residual_PRE_max_mm', {}, 'SCoRE_Residual_PRE_nFrames', {}, ...
    'SCoRE_Residual_POST_mean_mm', {}, 'SCoRE_Residual_POST_max_mm', {}, 'SCoRE_Residual_POST_nFrames', {}, ...
    'ClusterRMS_Scapula_PRE_mm', {}, 'ClusterRMS_Humerus_PRE_mm', {}, ...
    'ClusterRMS_Scapula_POST_mm', {}, 'ClusterRMS_Humerus_POST_mm', {}, ...
    'Flag_PRE', {}, 'Flag_POST', {});

% Épaules asymptomatiques (côté controlatéral, une seule session) - même
% correspondance que ComputeClinicalContributionsFromDatabase.m
AsymResults = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Condition', {}, ...
    'SCoRE_Residual_mean_mm', {}, 'SCoRE_Residual_max_mm', {}, 'SCoRE_Residual_nFrames', {}, ...
    'ClusterRMS_Scapula_mm', {}, 'ClusterRMS_Humerus_mm', {}, 'Flag', {});

conditions = {'PRE', 'POST'};
sides      = {'R', 'L'};

totalPatients = 0;
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    % Chargement en bloc de la partie : bien plus rapide qu'un accès
    % matfile indexé patient par patient (voir NumDatabaseParts dans
    % userCommands_Multi.m).
    S       = load(fileList{iFile}, 'Database');
    nInFile = numel(S.Database);
    totalPatients = totalPatients + nInFile;

for iP = 1:nInFile
    d = S.Database(iP);
    if isempty(d.Numero)
        continue; % ligne pré-allouée jamais remplie (patient introuvable/erreur aux deux conditions)
    end

    for iS = 1:numel(sides)
        side = sides{iS};
        if ~ismember(side, d.Side), continue; end % côté non analysé pour ce patient

        ri = find([Results.Numero] == d.Numero & strcmp({Results.Side}, side), 1);
        if isempty(ri)
            ri = length(Results) + 1;
            Results(ri).Numero       = d.Numero;
            Results(ri).PatientID    = d.PatientID;
            Results(ri).Side         = side;
            Results(ri).SCoRE_Residual_PRE_mean_mm  = NaN; Results(ri).SCoRE_Residual_POST_mean_mm = NaN;
            Results(ri).SCoRE_Residual_PRE_max_mm   = NaN; Results(ri).SCoRE_Residual_POST_max_mm  = NaN;
            Results(ri).SCoRE_Residual_PRE_nFrames  = NaN; Results(ri).SCoRE_Residual_POST_nFrames = NaN;
            Results(ri).ClusterRMS_Scapula_PRE_mm   = NaN; Results(ri).ClusterRMS_Scapula_POST_mm  = NaN;
            Results(ri).ClusterRMS_Humerus_PRE_mm   = NaN; Results(ri).ClusterRMS_Humerus_POST_mm  = NaN;
            Results(ri).Flag_PRE  = '';
            Results(ri).Flag_POST = '';
        end

        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Session')
                continue; % cette condition n'a pas été traitée avec succès pour ce patient
            end
            Session = d.(condition).Session;
            if ~isstruct(Session) || ~isfield(Session, 'SCoRE') || ~isstruct(Session.SCoRE) || ~isfield(Session.SCoRE, side)
                continue;
            end
            [residual_mm, residual_max, nFrames, scapulaRMS, humerusRMS, flag] = ...
                readSCoRE(Session.SCoRE.(side), ThresholdMM);

            Results(ri).(['SCoRE_Residual_', condition, '_mean_mm'])    = residual_mm;
            Results(ri).(['SCoRE_Residual_', condition, '_max_mm'])     = residual_max;
            Results(ri).(['SCoRE_Residual_', condition, '_nFrames'])    = nFrames;
            Results(ri).(['ClusterRMS_Scapula_', condition, '_mm'])     = scapulaRMS;
            Results(ri).(['ClusterRMS_Humerus_', condition, '_mm'])     = humerusRMS;
            Results(ri).(['Flag_', condition]) = flag;
        end
    end

    % Épaule asymptomatique de ce patient (condition retenue seulement)
    for iC = 1:numel(conditions)
        condition = conditions{iC};
        if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Session')
            continue;
        end
        asymSide = findAsymptomaticSide(Opts.AsymptomaticSelection, d, condition);
        if isempty(asymSide), continue; end
        Session = d.(condition).Session;
        ai = length(AsymResults) + 1;
        AsymResults(ai).Numero    = d.Numero;
        AsymResults(ai).PatientID = d.PatientID;
        AsymResults(ai).Side      = asymSide;
        AsymResults(ai).Condition = condition;
        AsymResults(ai).SCoRE_Residual_mean_mm = NaN; AsymResults(ai).SCoRE_Residual_max_mm = NaN;
        AsymResults(ai).SCoRE_Residual_nFrames = NaN;
        AsymResults(ai).ClusterRMS_Scapula_mm  = NaN; AsymResults(ai).ClusterRMS_Humerus_mm = NaN;
        AsymResults(ai).Flag = '';
        if ~isstruct(Session) || ~isfield(Session, 'SCoRE') || ~isstruct(Session.SCoRE) || ~isfield(Session.SCoRE, asymSide)
            continue;
        end
        [AsymResults(ai).SCoRE_Residual_mean_mm, AsymResults(ai).SCoRE_Residual_max_mm, ...
         AsymResults(ai).SCoRE_Residual_nFrames, AsymResults(ai).ClusterRMS_Scapula_mm, ...
         AsymResults(ai).ClusterRMS_Humerus_mm, AsymResults(ai).Flag] = ...
            readSCoRE(Session.SCoRE.(asymSide), ThresholdMM);
    end
end
clear S
end
disp(['Patients dans la base : ', num2str(totalPatients)]);
if ~isempty(Opts.AsymptomaticSelection)
    disp(['Épaules asymptomatiques retrouvées : ', num2str(numel(AsymResults)), ...
          ' / ', num2str(size(Opts.AsymptomaticSelection, 1))]);
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if ~isempty(Results)
    T = struct2table(Results);
    if isfile(OutputFile), delete(OutputFile); end
    writetable(T, OutputFile, 'Sheet', 'CoR_Quality');
    if ~isempty(AsymResults)
        writetable(struct2table(AsymResults), OutputFile, 'Sheet', 'CoR_Asymptomatic');
    end
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
    nFlagged = sum(strcmp({Results.Flag_PRE}, 'A verifier')) + sum(strcmp({Results.Flag_POST}, 'A verifier'));
    disp([num2str(nFlagged), ' ligne(s) PRE/POST flaguee(s) au-dessus de ', num2str(ThresholdMM), 'mm (residu moyen).']);
    if ~isempty(AsymResults)
        disp([num2str(sum(strcmp({AsymResults.Flag}, 'A verifier'))), ' épaule(s) asymptomatique(s) flaguée(s) au-dessus de ', ...
              num2str(ThresholdMM), 'mm (residu moyen).']);
    end
else
    disp(' ');
    disp('Aucune donnée à exporter.');
end

PlotCoRQuality(Results, ThresholdMM);

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
end

end

% =========================================================================
%  LECTURE SCoRE D'UN COTE (Session.SCoRE.R/.L)
% =========================================================================
function [residual_mm, residual_max, nFrames, scapulaRMS, humerusRMS, flag] = readSCoRE(SC, ThresholdMM)
residual_mm = NaN; residual_max = NaN; nFrames = 0;
if isfield(SC, 'residual_mm') && ~isempty(SC.residual_mm)
    residual_mm  = mean(SC.residual_mm, 'omitnan');
    residual_max = max(SC.residual_mm, [], 'omitnan');
    nFrames      = sum(~isnan(SC.residual_mm));
end

scapulaRMS = NaN; humerusRMS = NaN;
if isfield(SC, 'clusterRMS') && isstruct(SC.clusterRMS)
    if isfield(SC.clusterRMS, 'scapula_mm'), scapulaRMS = SC.clusterRMS.scapula_mm; end
    if isfield(SC.clusterRMS, 'humerus_mm'), humerusRMS = SC.clusterRMS.humerus_mm; end
end

if isnan(residual_mm)
    flag = '';
elseif residual_mm > ThresholdMM
    flag = 'A verifier';
else
    flag = 'OK';
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
%  GRAPHE DIAGNOSTIC (résidu SCoRE trié, PRE vs POST, seuil visible)
% =========================================================================
%
% Bar chart : une barre par ligne patient/côté, triée par résidu moyen
% décroissant (max des deux conditions PRE/POST, pour faire remonter les
% pires cas en premier peu importe la condition). PRE en rouge, POST en
% bleu, barres groupées côte à côte. Ligne pointillée horizontale au seuil
% ThresholdMM. Les patients au-dessus du seuil sont étiquetés en x
% (PatientID-Côté) pour identification directe ; les autres restent
% numériques pour ne pas surcharger l'axe.
%
% Inputs  : Results (struct array, voir ComputeCoRQualityFromDatabase)
%           ThresholdMM (double)
% Outputs : 1 figure, 1 axe
function PlotCoRQuality(Results, ThresholdMM)

if isempty(Results)
    disp('PlotCoRQuality: no data to plot.');
    return;
end

pre  = [Results.SCoRE_Residual_PRE_mean_mm];
post = [Results.SCoRE_Residual_POST_mean_mm];
worst = max(pre, post, 'omitnan');

[~, order] = sort(worst, 'descend', 'MissingPlacement', 'last');
pre  = pre(order);
post = post(order);
Results = Results(order);

labels = arrayfun(@(r) [patientIDStr(r.PatientID), '-', r.Side], Results, 'UniformOutput', false);

figure('Name', 'Qualité CoR (SCoRE) — résidu moyen PRE vs POST', 'Color', 'w');
b = bar([pre(:), post(:)], 'grouped');
b(1).FaceColor = [0.8500 0.3250 0.0980]; % red = PRE
b(2).FaceColor = [0 0.4470 0.7410];      % blue = POST

hold on;
yline(ThresholdMM, '--k', ['Seuil ', num2str(ThresholdMM), ' mm'], 'LabelHorizontalAlignment', 'left');
hold off;

set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels, 'XTickLabelRotation', 90);
ylabel('Résidu SCoRE moyen (mm)');
title('Qualité de reconstruction du CoR (SCoRE) — triée par pire cas');
legend({'PRE', 'POST'}, 'Location', 'best');
box on;

end

function s = patientIDStr(pid)
% PatientID peut être numérique ou char selon la source (PatientSelection) -
% conversion défensive pour l'étiquette du graphe.
if isnumeric(pid)
    s = num2str(pid);
else
    s = char(pid);
end
end
