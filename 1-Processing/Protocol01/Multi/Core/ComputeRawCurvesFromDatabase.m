% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Données brutes pour le registre (Registre_Epaule) : les
%                trois angles d'Euler (X, Y, Z) de chaque articulation, sur
%                le cycle retenu de chaque tâche, depuis PatientDatabase.mat.
%                Articulations : HT (Joint 1 / 6), GH (Joint 2 / 7),
%                ST (Joint 3 / 8) du côté de l'épaule, et thorax (Joint 11,
%                articulation partagée, repli sur l'autre champ de cycles
%                comme BestCycle.raw).
%                Angles SIGNÉS (pas d'abs, contrairement aux décompositions
%                Clinique et Fonctionnel), rangés comme dans
%                Protocol01/Core/ComputeKinematics.m : position 1 = X,
%                2 = Y, 3 = Z, quelle que soit la séquence. Séquences :
%                HT et GH ZXY (ANALYTIC1), XZY (ANALYTIC2), YXZ (ANALYTIC3/4) ;
%                ST YXZ et thorax ZXY pour toutes les tâches.
%                Cycle retenu : BestCycle.select (le même que les
%                décompositions Clinique et Fonctionnel), 101 points ;
%                moyenne des cycles si aucun cycle n'est retenu.
%                Pas de correction des courbes inversées (données brutes).
%
%                Callable à tout moment depuis la fenêtre de commande :
%                  RawCurves = ComputeRawCurvesFromDatabase(DatabaseFile)
%                puis RegCourbes.Brut = RawCurves avant ExportRegistre
%                (section « Registre » de MAIN_MULTI_Protocol_01.m).
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile (char) chemin vers PatientDatabase.mat (ou ses
%                        parties _partXofY, détectées automatiquement)
% Outputs : Curves (struct array) une ligne par épaule et par tâche :
%           Numero, PatientID, Side, Task et les champs <ART><AXE>_<PRE|POST>
%           de 101 points (ART = HT, GH, ST, TX ; AXE = X, Y, Z), lus par
%           ExportRegistre.m (articulation « HTX », « GHY »...)
% -------------------------------------------------------------------------
% Dependencies : BestCycle.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Curves = ComputeRawCurvesFromDatabase(DatabaseFile)

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeRawCurvesFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

tasks      = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'};
conditions = {'PRE', 'POST'};
axeLib     = {'X', 'Y', 'Z'};   % position 1, 2, 3 du DOF (ComputeKinematics.m)
% Articulations du côté de l'épaule (R puis L) ; thorax partagé (Joint 11)
sideDef = struct('side', {'R', 'L'}, 'jiHT', {1, 6}, 'jiGH', {2, 7}, 'jiST', {3, 8}, ...
                 'cycField', {'rcycle', 'lcycle'});
arts = {'HT', 'GH', 'ST', 'TX'};

Curves = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {});

for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S = load(fileList{iFile}, 'Database');

    for iP = 1:numel(S.Database)
        d = S.Database(iP);
        if isempty(d.Numero), continue; end   % ligne pré-allouée jamais remplie

        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Trial')
                continue;   % condition non traitée pour ce patient
            end
            Trial = d.(condition).Trial;

            for iT = 1:numel(tasks)
                task = tasks{iT};
                tidx = find(arrayfun(@(x) contains(x.task, task), Trial), 1);
                if isempty(tidx), continue; end
                t = Trial(tidx);

                for iS = 1:numel(sideDef)
                    s = sideDef(iS);
                    if ~ismember(s.side, d.Side), continue; end   % côté de l'épaule seulement
                    sel = BestCycle.select(t, task, s.side);
                    ji  = struct('HT', s.jiHT, 'GH', s.jiGH, 'ST', s.jiST, 'TX', 11);

                    % Ligne de l'épaule et de la tâche (PRE et POST dans la même ligne)
                    ri = find([Curves.Numero] == d.Numero & strcmp({Curves.Side}, s.side) & strcmp({Curves.Task}, task), 1);
                    if isempty(ri)
                        ri = numel(Curves) + 1;
                        Curves(ri).Numero    = d.Numero;
                        Curves(ri).PatientID = d.PatientID;
                        Curves(ri).Side      = s.side;
                        Curves(ri).Task      = task;
                    end

                    for iA = 1:numel(arts)
                        art = arts{iA};
                        for dof = 1:3
                            x = BestCycle.raw(t, ji.(art), dof, s.cycField, strcmp(art, 'TX'));
                            c = BestCycle.curve(x, sel.idx);
                            if numel(c) ~= 101, c = NaN(101, 1); end   % courbe absente ou non normalisée
                            Curves(ri).([art, axeLib{dof}, '_', condition]) = c(:)';
                        end
                    end
                end
            end
        end
    end
end

disp(['Données brutes : ', num2str(numel(Curves)), ' lignes épaule x tâche']);

end

% =========================================================================
%  Parties de la base (copie de la fonction locale des autres
%  ...FromDatabase.m : NumDatabaseParts dans userCommands_Multi.m)
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
% Tri par numéro de partie (part10 après part9)
partNum = zeros(numel(parts), 1);
for i = 1:numel(parts)
    tok = regexp(parts(i).name, '_part(\d+)of\d+', 'tokens', 'once');
    partNum(i) = str2double(tok{1});
end
[~, order] = sort(partNum);
parts = parts(order);
fileList = fullfile({parts.folder}, {parts.name});
end
