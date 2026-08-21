% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Rapport de contributions cliniques humérothoraciques
%                (HT/GH/ST/TX), calculé depuis PatientDatabase.mat plutôt
%                qu'en repassant par les C3D. Remplace le calcul qui vivait
%                auparavant dans MAIN_MULTI_Protocol_01.m (retiré de là -
%                voir son en-tête).
%                Fonction centralisée : la décomposition HT/GH/ST/TX
%                (anciennement Multi/Core/ComputeHTContributions.m,
%                renommée ComputeClinicalContributions) et le
%                tracé des courbes PRE/POST (anciennement
%                Multi/Plot/PlotHTContributionsCurves.m) sont fusionnés ici
%                comme fonctions locales, en bas du fichier - inchangées,
%                pas de fichiers séparés.
%
%                Callable à tout moment depuis la fenêtre de commande
%                (ou un script), sans rien relancer sur les C3D :
%                  ComputeClinicalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder)
%
%                Prérequis : avoir lancé MAIN_MULTI_Protocol_01.m au moins
%                une fois avec SaveDatabase=true (voir userCommands_Multi.m)
%                pour générer PatientDatabase.mat.
%
%                Comme Trial est déjà entièrement calculé (Segment/Joint/
%                Euler/cycles), cette fonction tourne en quelques secondes
%                sur toute la cohorte, même à 182 patients - contrairement
%                à MAIN_MULTI_Protocol_01.m qui doit relire chaque C3D.
%
%                Pour ajouter une AUTRE analyse depuis le .mat (posture,
%                Moroder...) : même patron - un fichier .m séparé dans
%                Multi/Core/, avec sa propre fonction ComputeXxx(Trial)
%                (locale ou non), appelée pour Database(i).PRE.Trial et
%                Database(i).POST.Trial.
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile  (char) chemin vers PatientDatabase.mat
%           OutputFile    (char) chemin de l'Excel de sortie (contributions
%                         cliniques)
%           ResultsFolder (char, optionnel) dossier où se terminer (cd) une
%                         fois l'export fait ; omis = pas de cd
% Outputs : Results (struct array) une ligne par patient/côté - aussi
%           retourné pour exploitation directe sans repasser par l'Excel
%           Fichier Excel écrit sur disque + figure des courbes PRE/POST
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Results = ComputeClinicalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder)

if nargin < 3, ResultsFolder = ''; end

% La base peut être répartie sur plusieurs fichiers .mat (voir
% NumDatabaseParts dans userCommands_Multi.m, DatabaseFile_partXofY.mat) -
% détecté automatiquement ; repli sur DatabaseFile seul si aucune partie
% trouvée (compatibilité avec un run à un seul fichier).
fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeClinicalContributionsFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

% -------------------------------------------------------------------------
% BOUCLE PATIENTS (depuis Database, pas depuis PatientSelection/C3D)
% -------------------------------------------------------------------------
Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'HT_PRE_deg', {}, 'GH_PRE_deg', {}, 'GH_PRE_pct', {}, ...
    'ST_PRE_deg', {}, 'ST_PRE_pct', {}, 'TX_PRE_deg', {}, 'TX_PRE_pct', {}, ...
    'HT_POST_deg', {}, 'GH_POST_deg', {}, 'GH_POST_pct', {}, ...
    'ST_POST_deg', {}, 'ST_POST_pct', {}, 'TX_POST_deg', {}, 'TX_POST_pct', {});

% Courbes angle vs % cycle
Curves = struct('Numero', {}, 'PatientID', {}, 'Side', {}, ...
    'HT_PRE', {}, 'HT_POST', {}, 'GH_PRE', {}, 'GH_POST', {}, 'ST_PRE', {}, 'ST_POST', {}, ...
    'TX_PRE', {}, 'TX_POST', {});

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

        Contrib = ComputeClinicalContributions(Trial);

        for iS = 1:length(Contrib)
            c = Contrib(iS);
            if ~ismember(c.side, d.Side), continue; end

            ri = find([Results.Numero] == d.Numero & strcmp({Results.Side}, c.side), 1);
            if isempty(ri)
                ri = length(Results) + 1;
                Results(ri).Numero       = d.Numero;
                Results(ri).PatientID    = d.PatientID;
                Results(ri).Side         = c.side;
                Results(ri).Task         = c.task;
                Results(ri).HT_PRE_deg   = NaN; Results(ri).HT_POST_deg  = NaN;
                Results(ri).GH_PRE_deg   = NaN; Results(ri).GH_POST_deg  = NaN;
                Results(ri).GH_PRE_pct   = NaN; Results(ri).GH_POST_pct  = NaN;
                Results(ri).ST_PRE_deg   = NaN; Results(ri).ST_POST_deg  = NaN;
                Results(ri).ST_PRE_pct   = NaN; Results(ri).ST_POST_pct  = NaN;
                Results(ri).TX_PRE_deg   = NaN; Results(ri).TX_POST_deg  = NaN;
                Results(ri).TX_PRE_pct   = NaN; Results(ri).TX_POST_pct  = NaN;
            end

            Results(ri).(['HT_', condition, '_deg']) = c.HT_range;
            Results(ri).(['GH_', condition, '_deg']) = c.GH_range;
            Results(ri).(['GH_', condition, '_pct']) = c.GH_pct;
            Results(ri).(['ST_', condition, '_deg']) = c.ST_range;
            Results(ri).(['ST_', condition, '_pct']) = c.ST_pct;
            Results(ri).(['TX_', condition, '_deg']) = c.TX_range;
            Results(ri).(['TX_', condition, '_pct']) = c.TX_pct;

            if length(Curves) < ri
                Curves(ri).Numero    = d.Numero;
                Curves(ri).PatientID = d.PatientID;
                Curves(ri).Side      = c.side;
            end
            Curves(ri).(['HT_', condition]) = c.HT_curve;
            Curves(ri).(['GH_', condition]) = c.GH_curve;
            Curves(ri).(['ST_', condition]) = c.ST_curve;
            Curves(ri).(['TX_', condition]) = c.TX_curve;
        end
    end
end
clear S
end
disp(['Patients dans la base : ', num2str(totalPatients)]);

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if ~isempty(Results)
    T = struct2table(Results);
    if isfile(OutputFile), delete(OutputFile); end
    writetable(T, OutputFile, 'Sheet', 'Clinical_Contributions');
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
else
    disp(' ');
    disp('Aucune donnée à exporter.');
end

PlotHTContributionsCurves(Curves);

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
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
%  DECOMPOSITION HT/GH/ST/TX (ex-Multi/Core/ComputeHTContributions.m,
%  renommée ComputeClinicalContributions, fusionnée ici - pour centraliser
%  en une seule fonction)
% =========================================================================
%
% Decompose the humerothoracic (HT) range of motion into glenohumeral (GH),
% scapulothoracic (ST) and thoracic (TX) sub-contributions, in degrees and
% in % of HT range. Same DOF/joint convention as the "Clinical analysis
% (euler)" table in Protocol01/IO/ExportKinematicsSummary.m (Tableau 2) -
% checked to match exactly, on purpose (same clinical-literature reference).
%
% Only ANALYTIC2 (coronal elevation) is supported: it is a uniplanar
% movement, which ensures a coherent GH/ST/TX decomposition of the HT angle.
%
% DOF mapping (ANALYTIC2) :
%   HT Joint(1/6)  DOF1 X — abduction     (XZY)
%   GH Joint(2/7)  DOF1 X — abduction     (XZY)
%   ST Joint(3/8)  DOF1 X — upward rot.   (YXZ)
%   TX Joint(11)   DOF3 Z — flexion       (ZXY)
%
% HT_curve/GH_curve/ST_curve/TX_curve : mean curve (across cycles) of the
% angle vs % cycle (0-100%), same number of points as the cycle
% normalisation done by CutCycles.m. Used for the PRE/POST plot in
% PlotHTContributionsCurves.m. TX uses getCurveCycleTH (not getCurveCycle)
% for the same reason TX_range uses getRangeCycleTH : joint 11 (thorax) is
% a single shared joint, not duplicated per side like HT/GH/ST, so it can
% need the R/L cycField fallback.
%
% Inputs  : Trial (struct array) all trials from runProtocol01/MAIN_Protocol_01
% Outputs : Contrib (1x2 struct array, one row per side 'R'/'L') with fields
%           task, side, HT_range, GH_range, GH_pct, ST_range, ST_pct,
%           TX_range, TX_pct, HT_curve, GH_curve, ST_curve, TX_curve
%           Empty (0x0) struct array if ANALYTIC2 is not found in Trial.
function Contrib = ComputeClinicalContributions(Trial)

Contrib = struct('task', {}, 'side', {}, 'HT_range', {}, ...
                  'GH_range', {}, 'GH_pct', {}, 'ST_range', {}, 'ST_pct', {}, ...
                  'TX_range', {}, 'TX_pct', {}, ...
                  'HT_curve', {}, 'GH_curve', {}, 'ST_curve', {}, 'TX_curve', {});

task = 'ANALYTIC2';
tidx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task, task)
        tidx = k;
        break;
    end
end
if isempty(tidx), return; end
t = Trial(tidx);

dofHT = 1; dofGH = 1; dofST = 1; dofTX = 3;

sideDef = struct('side', {'R','L'}, 'jiHT', {1,6}, 'jiGH', {2,7}, 'jiST', {3,8}, ...
                  'cycField', {'rcycle','lcycle'});

for iS = 1:length(sideDef)
    s  = sideDef(iS);
    ht = getRangeCycle(t, s.jiHT, dofHT, s.cycField);
    gh = getRangeCycle(t, s.jiGH, dofGH, s.cycField);
    st = getRangeCycle(t, s.jiST, dofST, s.cycField);
    tx = getRangeCycleTH(t, 11, dofTX, s.cycField);

    Contrib(iS).task     = t.task;
    Contrib(iS).side     = s.side;
    Contrib(iS).HT_range = ht;
    Contrib(iS).GH_range = gh;
    Contrib(iS).GH_pct   = safePct(gh, ht);
    Contrib(iS).ST_range = st;
    Contrib(iS).ST_pct   = safePct(st, ht);
    Contrib(iS).TX_range = tx;
    Contrib(iS).TX_pct   = safePct(tx, ht);

    Contrib(iS).HT_curve = getCurveCycle(t, s.jiHT, dofHT, s.cycField);
    Contrib(iS).GH_curve = getCurveCycle(t, s.jiGH, dofGH, s.cycField);
    Contrib(iS).ST_curve = getCurveCycle(t, s.jiST, dofST, s.cycField);
    Contrib(iS).TX_curve = getCurveCycleTH(t, 11, dofTX, s.cycField);
end

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
data = abs(squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
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
% per side like HT/GH/ST).
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
%  TRACE DES COURBES PRE/POST (ex-Multi/Plot/PlotHTContributionsCurves.m,
%  fusionnée ici - inchangée - pour centraliser en une seule fonction)
% =========================================================================
%
% Plots the angle vs % cycle (0-100%) HT/GH/ST/TX curves, PRE vs POST.
%
% Layout: 1 row x 4 columns (HT, GH, ST, TX)
%   Individual curve per patient/side, transparent (red = PRE, blue = POST)
%   Bold mean curve (red = PRE, blue = POST)
%   Each curve is resampled to 101 points (0-100%) before averaging, in
%   case the number of cycle points differs from one patient to another.
%
% Inputs  : Curves (struct array) with fields HT_PRE/HT_POST, GH_PRE/
%           GH_POST, ST_PRE/ST_POST, TX_PRE/TX_POST (vectors, or [] if absent)
% Outputs : 1 figure, 4 subplots
function PlotHTContributionsCurves(Curves)

if isempty(Curves)
    disp('PlotHTContributionsCurves: no data to plot.');
    return;
end

metrics = {'HT', 'GH', 'ST', 'TX'};
titles  = {'HT (humérothoracique)', 'GH (glénohuméral)', 'ST (scapulothoracique)', 'TX (thoracique)'};
xgrid   = linspace(0, 100, 101);
colPre  = [0.8500 0.3250 0.0980]; % red
colPost = [0 0.4470 0.7410];   % blue

figure('Name', 'Courbes HT/GH/ST — PRE vs POST', 'Color', 'w');

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

    if ~isempty(preCurves)
        plot(xgrid, mean(preCurves, 2, 'omitnan'), 'Color', colPre, 'LineWidth', 3, 'DisplayName', 'PRE (moyenne)');
    end
    if ~isempty(postCurves)
        plot(xgrid, mean(postCurves, 2, 'omitnan'), 'Color', colPost, 'LineWidth', 3, 'DisplayName', 'POST (moyenne)');
    end

    hold off;
    xlim([0 100]);
    xlabel('Cycle (%)');
    ylabel([metrics{m}, ' (deg)']);
    title(titles{m});
    legend('show', 'Location', 'best');
    box on;
end

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
