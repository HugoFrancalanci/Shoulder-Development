% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Screens the CONTRALATERAL shoulder (opposite to the side
%                analysed/operated - Database(i).Side, from PatientSelection
%                in userCommands_Multi.m) of every patient in
%                PatientDatabase.mat against 3 eligibility criteria for use
%                as an "asymptomatic" reference shoulder in the cohort:
%
%                1) ROM_Criterion: humero-thoracic (HT) range of motion on
%                   ANALYTIC1 (sagittal elevation/flexion) OR ANALYTIC2
%                   (coronal elevation) > 120 deg. Euler-based (Joint(1)
%                   right / Joint(6) left, same joints/convention as
%                   ComputeClinicalContributionsFromDatabase.m's HT). The
%                   Euler DOF that carries flexion/extension is
%                   task-dependent (Protocol01/Core/ComputeKinematics.m,
%                   ISB comment blocks) - NOT the same DOF index as
%                   ComputeClinicalContributions' ANALYTIC2 (dofHT=1, X):
%                     ANALYTIC1 (sequence ZXY) : DOF index 3 (Z) = flexion/extension
%                     ANALYTIC2 (sequence XZY) : DOF index 1 (X) = elevation/abduction
%                   (same indices for Joint 1 and Joint 6 - only the sign
%                   is flipped on the left side for ISB symmetry, which
%                   does not affect a max-min range).
%                2) EVA_Criterion: mean pain score (Session.Pain) across
%                   the 4 ANALYTIC tasks, taken directly for the
%                   CONTRALATERAL side (unlike ComputePatientInfos.m's
%                   EVA_PRE/POST, which targets the affected side with a
%                   fallback - here the side is fixed to the contralateral
%                   one, no fallback) == 0.
%                3) Antecedents_Criterion: none of Pathology.Diagnosis.d1-d5,
%                   Pathology.PlanedSurgery.i1-i5, Pathology.PreviousSurgery.i1-i5
%                   mention the contralateral side in their free text.
%                   Confirmed on real data that the side is always spelled
%                   out there (e.g. Barbaglia_Nury_739322: analysed side
%                   Gauche, but PreviousSurgery lists "Arthoplastie totale
%                   inversee d'epaule (droite, 2017)" - a prior RTSA on the
%                   CONTRALATERAL side) - detected with a "droit"/"gauche"
%                   keyword search (case-insensitive substring, matches
%                   both "droit"/"droite" and "gauche"), plus a "bilat"
%                   keyword search on the SAME entries (e.g. "Luxation
%                   bilaterale" - real case, Gokay_Bora_97867893 - names no
%                   side explicitly but clearly involves both). Pathology.
%                   Diagnosis.side itself is also checked for a bilateral
%                   marker ("D&G"/"bilat...").
%
%                ROM/EVA use PRE session data by default (baseline, before
%                the analysed side's surgery), falling back to POST only if
%                PRE is unavailable for that patient - each flagged in
%                ROM_Condition/EVA_Condition. Antecedents are checked across
%                BOTH PRE and POST (POST text is a superset of PRE in
%                practice - new lines are only appended at POST, see
%                Antich_Jaime_617113/Abreu_Serafim_301190 in the raw data),
%                so as not to miss anything.
%
%                Patients whose PatientSelection side is "RL" (both sides
%                analysed) have no contralateral side: all criteria and
%                Eligible_Overall are left blank, ContralateralSide =
%                'N/A (deux cotes analyses)'.
%
%                A criterion left blank ('') means the underlying data is
%                missing (not "non") - Eligible_Overall is then also left
%                blank rather than defaulting to Non, so missing-data rows
%                are distinguishable from genuine failures at a glance.
%
%                Antecedents_Details lists which field(s) triggered
%                Antecedents_Criterion='Non', so a manual double-check
%                stays easy (free-text medical fields, keyword search only).
%
%                Callable at any time from the command window, once
%                PatientDatabase.mat exists (SaveDatabase=true) - same usage
%                as ComputeClinicalContributionsFromDatabase.m:
%                  ComputeContralateralEligibilityFromDatabase(DatabaseFile, OutputFile, ResultsFolder)
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile  (char) path to PatientDatabase.mat (or its
%                         _partXofY.mat siblings, see NumDatabaseParts)
%           OutputFile    (char) output Excel path
%           ResultsFolder (char, optional) folder to cd() into once done;
%                         omitted = no cd
% Outputs : Results (struct array), one row per patient - also returned for
%           direct use without going through the Excel. Excel file written
%           to disk.
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Results = ComputeContralateralEligibilityFromDatabase(DatabaseFile, OutputFile, ResultsFolder)

if nargin < 3, ResultsFolder = ''; end

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeContralateralEligibilityFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

Results = struct('Numero', {}, 'PatientID', {}, 'AnalysedSide', {}, 'ContralateralSide', {}, ...
    'ROM_ANALYTIC1_deg', {}, 'ROM_ANALYTIC2_deg', {}, 'ROM_Condition', {}, 'ROM_Criterion', {}, ...
    'EVA_Contralateral', {}, 'EVA_Condition', {}, 'EVA_Criterion', {}, ...
    'Antecedents_Details', {}, 'Antecedents_Criterion', {}, ...
    'Eligible_Overall', {});

conditions = {'PRE', 'POST'};
analyticPainMap = {'Elevation_sagittal', 'Elevation_coronal', 'Rotation_external', 'Rotation_internal'};

totalPatients = 0;
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    % Chargement en bloc de la partie (voir
    % ComputeClinicalContributionsFromDatabase.m) - bien plus rapide qu'un
    % accès matfile indexé patient par patient ; chaque partie est
    % dimensionnée pour tenir en RAM d'un coup (voir NumDatabaseParts dans
    % userCommands_Multi.m).
    S       = load(fileList{iFile}, 'Database');
    nInFile = numel(S.Database);
    totalPatients = totalPatients + nInFile;

    for iP = 1:nInFile
        d = S.Database(iP);
        if isempty(d.Numero)
            continue; % ligne pré-allouée jamais remplie
        end

        ri = length(Results) + 1;
        Results(ri).Numero       = d.Numero;
        Results(ri).PatientID    = d.PatientID;
        Results(ri).AnalysedSide = strjoin(d.Side, '/');

        if numel(d.Side) ~= 1
            % 'RL' : les deux côtés sont analysés, pas de côté controlatéral
            Results(ri).ContralateralSide     = 'N/A (deux côtés analysés)';
            Results(ri).ROM_ANALYTIC1_deg      = NaN;
            Results(ri).ROM_ANALYTIC2_deg      = NaN;
            Results(ri).ROM_Condition          = '';
            Results(ri).ROM_Criterion          = '';
            Results(ri).EVA_Contralateral      = NaN;
            Results(ri).EVA_Condition          = '';
            Results(ri).EVA_Criterion          = '';
            Results(ri).Antecedents_Details    = '';
            Results(ri).Antecedents_Criterion  = '';
            Results(ri).Eligible_Overall       = '';
            continue;
        end

        if strcmp(d.Side{1}, 'R'), contraSide = 'L'; else, contraSide = 'R'; end
        Results(ri).ContralateralSide = contraSide;

        if strcmp(contraSide, 'R')
            ji = 1; cycField = 'rcycle';
        else
            ji = 6; cycField = 'lcycle';
        end

        % ---- 1) ROM HT (Euler), ANALYTIC1 (dof 3, flexion/extension) et
        % ANALYTIC2 (dof 1, elevation/abduction), PRE puis POST ----
        rom1 = NaN; rom2 = NaN; romCond = '';
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Trial'), continue; end
            Trial = d.(condition).Trial;
            r1 = getEulerRangeCycleTask(Trial, 'ANALYTIC1', ji, 3, cycField);
            r2 = getEulerRangeCycleTask(Trial, 'ANALYTIC2', ji, 1, cycField);
            if ~isnan(r1) || ~isnan(r2)
                rom1 = r1; rom2 = r2; romCond = condition;
                break; % PRE prioritaire, POST seulement si PRE indisponible
            end
        end
        Results(ri).ROM_ANALYTIC1_deg = rom1;
        Results(ri).ROM_ANALYTIC2_deg = rom2;
        Results(ri).ROM_Condition     = romCond;
        romMax = max([rom1, rom2], [], 'omitnan');
        if isnan(romMax)
            Results(ri).ROM_Criterion = '';
        elseif romMax > 120
            Results(ri).ROM_Criterion = 'Oui';
        else
            Results(ri).ROM_Criterion = 'Non';
        end

        % ---- 2) EVA = 0, côté controlatéral, PRE puis POST ----
        evaVal = NaN; evaCond = '';
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Session'), continue; end
            Session = d.(condition).Session;
            vals = collectPainValsSide(Session, analyticPainMap, contraSide);
            if ~isempty(vals)
                evaVal  = mean(vals);
                evaCond = condition;
                break;
            end
        end
        Results(ri).EVA_Contralateral = evaVal;
        Results(ri).EVA_Condition     = evaCond;
        if isnan(evaVal)
            Results(ri).EVA_Criterion = '';
        elseif evaVal == 0
            Results(ri).EVA_Criterion = 'Oui';
        else
            Results(ri).EVA_Criterion = 'Non';
        end

        % ---- 3) Pas d'antécédents, côté controlatéral (union PRE+POST) ----
        details = {};
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Pathology'), continue; end
            details = [details, findSideMentions(d.(condition).Pathology, contraSide)]; %#ok<AGROW>
        end
        details = unique(details, 'stable');
        Results(ri).Antecedents_Details = strjoin(details, ' / ');
        if isempty(details)
            Results(ri).Antecedents_Criterion = 'Oui';
        else
            Results(ri).Antecedents_Criterion = 'Non';
        end

        % ---- Overall : Oui seulement si les 3 critères sont Oui ----
        crit = {Results(ri).ROM_Criterion, Results(ri).EVA_Criterion, Results(ri).Antecedents_Criterion};
        if any(cellfun(@isempty, crit))
            Results(ri).Eligible_Overall = ''; % au moins un critère non calculable (données manquantes)
        elseif all(strcmp(crit, 'Oui'))
            Results(ri).Eligible_Overall = 'Oui';
        else
            Results(ri).Eligible_Overall = 'Non';
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
    writetable(T, OutputFile, 'Sheet', 'Contralateral_Eligibility');
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
else
    disp(' ');
    disp('Aucune donnée à exporter.');
end

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
end

end

% =========================================================================
%  DECOUVERTE DES FICHIERS DE PARTIES (identique à
%  ComputeClinicalContributionsFromDatabase.m - voir NumDatabaseParts,
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
%  HELPERS
% =========================================================================
function tf = hasField(d, condition, fieldName)
tf = isfield(d, condition) && isstruct(d.(condition)) && isfield(d.(condition), fieldName) ...
    && ~isempty(d.(condition).(fieldName));
end

% HT Euler range of motion for one task/DOF/side - identical pattern to
% getRangeCycle in ComputeClinicalContributionsFromDatabase.m /
% Protocol01/IO/ExportKinematicsSummary.m. dof is task-dependent (see file
% header) : 3 (Z, flexion/extension) for ANALYTIC1, 1 (X, elevation/
% abduction) for ANALYTIC2 - same Joint index (1 right / 6 left) for both.
function r = getEulerRangeCycleTask(Trial, task, ji, dof, cycField)
r = NaN;
tidx = [];
for k = 1:length(Trial)
    if ischar(Trial(k).task) && contains(Trial(k).task, task)
        tidx = k;
        break;
    end
end
if isempty(tidx), return; end
t = Trial(tidx);
if length(t.Joint) < ji || ~isfield(t.Joint(ji), 'Euler') || ~isfield(t.Joint(ji).Euler, cycField) ...
        || isempty(t.Joint(ji).Euler.(cycField))
    return;
end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

% Pain values for a FIXED side (no affected-side/fallback logic, unlike
% ComputePatientInfos.m's painEvaFormula - here we always want the
% contralateral side specifically).
function vals = collectPainValsSide(Session, analyticPainMap, side)
vals = [];
if ~isfield(Session, 'Pain') || ~isfield(Session.Pain, 'label'), return; end
for ip = 1:length(analyticPainMap)
    idx = find(strcmpi(Session.Pain.label, analyticPainMap{ip}), 1);
    if isempty(idx), continue; end
    if strcmp(side, 'L')
        v = Session.Pain.Lvalue(idx);
    else
        v = Session.Pain.Rvalue(idx);
    end
    if ~isnan(v)
        vals(end+1) = v; %#ok<AGROW>
    end
end
end

% Free-text keyword search for the contralateral side across
% Diagnosis.d1-d5, PlanedSurgery.i1-i5, PreviousSurgery.i1-i5 - confirmed
% on real data that the side is always spelled out there (e.g. "droite" /
% "gauche" in parentheses next to the date). Also flags a bilateral marker
% ("D&G"/"bilat...") on Diagnosis.side itself.
function mentions = findSideMentions(Pathology, side)
mentions = {};
fieldsToCheck = { ...
    'Diagnosis',       {'d1','d2','d3','d4','d5'}; ...
    'PlanedSurgery',   {'i1','i2','i3','i4','i5'}; ...
    'PreviousSurgery', {'i1','i2','i3','i4','i5'}; ...
    };
if strcmp(side, 'R')
    sideWord = 'droit';
else
    sideWord = 'gauche';
end
for f = 1:size(fieldsToCheck, 1)
    grp = fieldsToCheck{f, 1};
    if ~isfield(Pathology, grp), continue; end
    keys = fieldsToCheck{f, 2};
    for k = 1:numel(keys)
        if ~isfield(Pathology.(grp), keys{k}), continue; end
        txt = Pathology.(grp).(keys{k});
        if ~ischar(txt), continue; end
        txt = strtrim(txt);
        if isempty(txt) || strcmp(txt, '-'), continue; end
        if ~isempty(regexpi(txt, sideWord, 'once')) || ~isempty(regexpi(txt, 'bilat', 'once'))
            mentions{end+1} = [grp, ': ', txt]; %#ok<AGROW>
        end
    end
end
if isfield(Pathology, 'Diagnosis') && isfield(Pathology.Diagnosis, 'side') && ischar(Pathology.Diagnosis.side)
    s = lower(strtrim(Pathology.Diagnosis.side));
    if contains(s, 'd&g') || contains(s, 'bilat')
        mentions{end+1} = ['Diagnosis.side: ', Pathology.Diagnosis.side];
    end
end
end
