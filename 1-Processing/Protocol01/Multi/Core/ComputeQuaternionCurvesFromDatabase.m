% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Angles 3D pour le registre (Registre_Epaule) : angle de
%                rotation total issu des quaternions (Joint(i).QuatAngle,
%                Protocol01/Core/ComputeQuaternionKinematics.m), sur le
%                cycle retenu de chaque tâche, depuis la base du projet.
%                Angle total de l'orientation relative des deux segments
%                (0 à 180 deg), sans séquence d'Euler : pas de blocage de
%                cardan, pas de signe (c'est une grandeur), un seul nombre
%                par instant au lieu de trois angles. Complément des
%                décompositions Clinique et Fonctionnel (angles d'Euler).
%                Articulations : HT (Joint 1 / 6), GH (2 / 7), ST (3 / 8),
%                thorax (11, partagé, repli sur l'autre champ de cycles
%                comme BestCycle.raw) et HG (12 / 13). Correction du côté
%                gauche déjà faite dans ComputeKinematics.m (HT, ST, HG).
%                Cycle retenu : BestCycle.select (le même que les
%                décompositions), 101 points.
%                Valeurs : amplitude <ART>_<C>_deg = max - min sur le cycle
%                retenu (BestCycle.range) ; pic <ART>_<C>_max_deg = angle
%                total atteint (BestCycle.peak).
%
%                Callable à tout moment depuis la fenêtre de commande :
%                  [QuatRes, QuatCurves] = ComputeQuaternionCurvesFromDatabase(DatabaseFile)
%                puis RegTables.Quaternion / RegCourbes.Quaternion avant
%                ExportRegistre (section « Registre » de MAIN_MULTI_Protocol_01.m).
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile (char) dossier Patients\ du projet (un .mat par
%                        épaule) ou PatientDatabase.mat et ses parties
% Outputs : Results (struct array) une ligne par épaule et par tâche :
%           Numero, PatientID, Side, Task, <ART>_<PRE|POST>_deg et
%           <ART>_<PRE|POST>_max_deg (ART = HT, GH, ST, TX, HG)
%           Curves  (struct array, même indexation) : <ART>_<PRE|POST>,
%           101 points
% -------------------------------------------------------------------------
% Dependencies : BestCycle.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, Curves] = ComputeQuaternionCurvesFromDatabase(DatabaseFile)

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeQuaternionCurvesFromDatabase:noDatabase', 'Base introuvable : %s', DatabaseFile);
end

tasks      = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'};
conditions = {'PRE', 'POST'};
arts       = {'HT', 'GH', 'ST', 'TX', 'HG'};
sideDef = struct('side', {'R', 'L'}, 'HT', {1, 6}, 'GH', {2, 7}, 'ST', {3, 8}, 'TX', {11, 11}, 'HG', {12, 13}, ...
                 'cycField', {'rcycle', 'lcycle'});

Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {});
Curves  = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {});

for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S = load(fileList{iFile}, 'Database');
    for iP = 1:numel(S.Database)
        d = S.Database(iP);
        if isempty(d.Numero), continue; end
        for iC = 1:numel(conditions)
            c = conditions{iC};
            if ~isfield(d, c) || ~isstruct(d.(c)) || ~isfield(d.(c), 'Trial'), continue; end
            Trial = d.(c).Trial;
            for iT = 1:numel(tasks)
                task = tasks{iT};
                tidx = find(arrayfun(@(x) contains(x.task, task), Trial), 1);
                if isempty(tidx), continue; end
                t = Trial(tidx);
                for iS = 1:numel(sideDef)
                    s = sideDef(iS);
                    if ~ismember(s.side, d.Side), continue; end   % côté de l'épaule seulement
                    sel = BestCycle.select(t, task, s.side);
                    ri = find([Results.Numero] == d.Numero & strcmp({Results.Side}, s.side) & strcmp({Results.Task}, task), 1);
                    if isempty(ri)
                        ri = numel(Results) + 1;
                        Results(ri).Numero = d.Numero; Results(ri).PatientID = d.PatientID;
                        Results(ri).Side = s.side;     Results(ri).Task = task;
                        Curves(ri).Numero  = d.Numero; Curves(ri).PatientID  = d.PatientID;
                        Curves(ri).Side    = s.side;   Curves(ri).Task       = task;
                    end
                    for iA = 1:numel(arts)
                        a = arts{iA};
                        x = quatCycles(t, s.(a), s.cycField, strcmp(a, 'TX'));
                        cur = BestCycle.curve(x, sel.idx);
                        if numel(cur) ~= 101, cur = NaN(101, 1); end
                        Curves(ri).([a, '_', c]) = cur(:)';
                        Results(ri).([a, '_', c, '_deg'])     = BestCycle.range(x, sel.idx);
                        Results(ri).([a, '_', c, '_max_deg']) = BestCycle.peak(x, sel.idx);
                    end
                end
            end
        end
    end
    clear S
end
disp(['Angles 3D (quaternions) : ', num2str(numel(Curves)), ' lignes épaule x tâche']);
end

% Angle total par cycle [101 x nCycles] d'une articulation ; shared = thorax
% (Joint 11), repli sur l'autre champ de cycles si vide (comme BestCycle.raw)
function x = quatCycles(t, ji, cf, shared)
x = [];
if length(t.Joint) < ji || ~isfield(t.Joint(ji), 'QuatAngle'), return; end
if shared && isempty(t.Joint(ji).QuatAngle.(cf))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if ~isfield(t.Joint(ji).QuatAngle, cf) || isempty(t.Joint(ji).QuatAngle.(cf)), return; end
x = squeeze(t.Joint(ji).QuatAngle.(cf));
if isvector(x), x = x(:); end
end

% Parties de la base (même fonction locale que les autres ...FromDatabase.m)
function fileList = discoverDatabaseFiles(DatabaseFile)
if isfolder(DatabaseFile)
    f = dir(fullfile(DatabaseFile, '*', '*.mat'));
    fileList = {};
    if ~isempty(f), fileList = sort(fullfile({f.folder}, {f.name})); end
    return;
end
[dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
parts = dir(fullfile(dbFolder, [dbName, '_part*of*', dbExt]));
if isempty(parts)
    if isfile(DatabaseFile), fileList = {DatabaseFile}; else, fileList = {}; end
    return;
end
partNum = zeros(numel(parts), 1);
for i = 1:numel(parts)
    tok = regexp(parts(i).name, '_part(\d+)of\d+', 'tokens', 'once');
    partNum(i) = str2double(tok{1});
end
[~, order] = sort(partNum);
fileList = fullfile({parts(order).folder}, {parts(order).name});
end
