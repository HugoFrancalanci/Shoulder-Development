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
%                as an "asymptomatic" reference shoulder in the cohort, on
%                TWO independent range-of-motion measures - humero-thoracic
%                (HT) and humero-gravitational (HG) - each producing its
%                own overall verdict (Eligible_Overall_HT/_HG):
%
%                1a) HT_Criterion: humero-thoracic range of motion on
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
%                1b) HG_Criterion: humero-gravitational range of motion
%                   (humerus relative to the fixed vertical/gravity frame,
%                   not the - possibly leaning - trunk) on ANALYTIC1 OR
%                   ANALYTIC2 > 120 deg. Euler-based (Joint(12) right /
%                   Joint(13) left, sequence YXY, DOF1/X = Elevation - see
%                   ComputeKinematics.m ~line 395-439). Unlike HT, the
%                   elevation DOF is DOF1 for BOTH tasks (no task-dependent
%                   switching) and is stored identically on both sides (no
%                   sign flip on DOF1, confirmed in ComputeKinematics.m -
%                   only DOF2/DOF3 get sign-flipped on the left).
%                2) EVA_Criterion: mean pain score (Session.Pain) across
%                   the 4 ANALYTIC tasks, taken directly for the
%                   CONTRALATERAL side (unlike ComputePatientInfos.m's
%                   EVA_PRE/POST, which targets the affected side with a
%                   fallback - here the side is fixed to the contralateral
%                   one, no fallback) == 0. Shared by both HT and HG verdicts.
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
%                   marker ("D&G"/"bilat..."). Shared by both verdicts.
%
%                ONE ROW PER (patient, condition) available, not one row
%                per patient: PRE and POST are two INDEPENDENT observations
%                of the same contralateral shoulder (not fused/prioritised
%                into a single value) - a patient with both PRE and POST
%                usable contributes up to 2 rows, each scored on its own
%                HT/HG/EVA (no cross-condition fallback), maximising the
%                number of usable "asymptomatic reference" observations
%                rather than collapsing to one per patient. The `Condition`
%                column ('PRE'/'POST') identifies which session each row
%                is. Antecedents are the one exception - a medical-history
%                fact, not a session measurement - so they're computed ONCE
%                per patient (union of BOTH PRE and POST text, POST being a
%                superset of PRE in practice - new lines are only appended
%                at POST, see Antich_Jaime_617113/Abreu_Serafim_301190 in
%                the raw data) and shared identically across that patient's
%                row(s), so as not to miss anything.
%
%                Patients whose PatientSelection side is "RL" (both sides
%                analysed) have no contralateral side: a single row with
%                Condition='', all criteria and both Eligible_Overall_HT/_HG
%                left blank, ContralateralSide = 'N/A (deux cotes analyses)'.
%                Same single-blank-row treatment for a patient with NEITHER
%                PRE nor POST usable (Trial or Session present) - kept
%                visible in the table rather than silently dropped, though
%                this shouldn't normally happen (every patient is expected
%                to have both PRE and POST).
%
%                A criterion left blank ('') means the underlying data is
%                missing (not "non") - the corresponding Eligible_Overall_*
%                is then also left blank rather than defaulting to Non, so
%                missing-data rows are distinguishable from genuine
%                failures at a glance.
%
%                Antecedents_Details lists which field(s) triggered
%                Antecedents_Criterion='Non', so a manual double-check
%                stays easy (free-text medical fields, keyword search only).
%
%                HT_Max_deg/HG_Max_deg = max(*_ANALYTIC1_deg, *_ANALYTIC2_deg) -
%                the same value HT_Criterion/HG_Criterion (>120) is based
%                on. Also reported at higher thresholds (HT_130/140/150/160,
%                HG_130/140/150/160) as Oui/Non/blank, same convention as
%                HT_Criterion/HG_Criterion, for stratifying how many
%                contralateral shoulders clear each bar - these do NOT feed
%                into Eligible_Overall_HT/_HG, which stay tied to the 120°
%                criterion only.
%
%                Four figures generated after the Excel export (see
%                PlotContralateralROM, local function, called once per
%                measure): for HT then for HG, (1) a bar chart of how many
%                contralateral shoulders clear each threshold
%                120/130/140/150/160°, (2) a histogram of *_Max_deg across
%                ALL contralateral shoulders with a valid measurement (not
%                just the eligible ones), to see the full distribution shape.
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
% Outputs : Results (struct array), one row per (patient, condition) - up
%           to 2 rows per patient (PRE/POST, see `Condition` column) - also
%           returned for direct use without going through the Excel. Excel
%           file written to disk.
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

Results = struct('Numero', {}, 'PatientID', {}, 'Condition', {}, 'AnalysedSide', {}, 'ContralateralSide', {}, ...
    'HT_ANALYTIC1_deg', {}, 'HT_ANALYTIC2_deg', {}, 'HT_Max_deg', {}, 'HT_Criterion', {}, ...
    'HT_130', {}, 'HT_140', {}, 'HT_150', {}, 'HT_160', {}, ...
    'HG_ANALYTIC1_deg', {}, 'HG_ANALYTIC2_deg', {}, 'HG_Max_deg', {}, 'HG_Criterion', {}, ...
    'HG_130', {}, 'HG_140', {}, 'HG_150', {}, 'HG_160', {}, ...
    'EVA_Contralateral', {}, 'EVA_Criterion', {}, ...
    'Antecedents_Details', {}, 'Antecedents_Criterion', {}, ...
    'Eligible_Overall_HT', {}, 'Eligible_Overall_HG', {});

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

        if numel(d.Side) ~= 1
            % 'RL' : les deux côtés sont analysés, pas de côté controlatéral -
            % une seule ligne (pas de distinction PRE/POST utile ici)
            ri = length(Results) + 1;
            Results(ri).Numero       = d.Numero;
            Results(ri).PatientID    = d.PatientID;
            Results(ri).Condition    = '';
            Results(ri).AnalysedSide = strjoin(d.Side, '/');
            Results(ri).ContralateralSide     = 'N/A (deux côtés analysés)';
            Results(ri).HT_ANALYTIC1_deg       = NaN;
            Results(ri).HT_ANALYTIC2_deg       = NaN;
            Results(ri).HT_Max_deg             = NaN;
            Results(ri).HT_Criterion           = '';
            Results(ri).HT_130                 = '';
            Results(ri).HT_140                 = '';
            Results(ri).HT_150                 = '';
            Results(ri).HT_160                 = '';
            Results(ri).HG_ANALYTIC1_deg       = NaN;
            Results(ri).HG_ANALYTIC2_deg       = NaN;
            Results(ri).HG_Max_deg             = NaN;
            Results(ri).HG_Criterion           = '';
            Results(ri).HG_130                 = '';
            Results(ri).HG_140                 = '';
            Results(ri).HG_150                 = '';
            Results(ri).HG_160                 = '';
            Results(ri).EVA_Contralateral      = NaN;
            Results(ri).EVA_Criterion          = '';
            Results(ri).Antecedents_Details    = '';
            Results(ri).Antecedents_Criterion  = '';
            Results(ri).Eligible_Overall_HT    = '';
            Results(ri).Eligible_Overall_HG    = '';
            continue;
        end

        if strcmp(d.Side{1}, 'R'), contraSide = 'L'; else, contraSide = 'R'; end

        if strcmp(contraSide, 'R')
            jiHT = 1; jiHG = 12; cycField = 'rcycle';
        else
            jiHT = 6; jiHG = 13; cycField = 'lcycle';
        end

        % ---- Antécédents : fait médical partagé par les deux lignes
        % (PRE/POST) de ce patient, pas une mesure de session - union
        % PRE+POST comme avant, calculé une seule fois ----
        details = {};
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Pathology'), continue; end
            details = [details, findSideMentions(d.(condition).Pathology, contraSide)]; %#ok<AGROW>
        end
        details = unique(details, 'stable');
        antecedentsDetails = strjoin(details, ' / ');
        if isempty(details)
            antecedentsCriterion = 'Oui';
        else
            antecedentsCriterion = 'Non';
        end

        % ---- Une ligne par condition disponible (PRE et/ou POST) : chaque
        % session est une observation indépendante de la même épaule
        % controlatérale, plus de fusion PRE-prioritaire/repli-POST en une
        % seule valeur par patient - ça augmente le nombre d'observations
        % exploitables (jusqu'à 2 par patient) au lieu de le réduire.
        % Antécédents partagés (ci-dessus) ; HT/HG/EVA propres à CHAQUE
        % ligne, sans repli croisé PRE<->POST.
        anyRow = false;
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Trial') && ~hasField(d, condition, 'Session')
                continue; % rien d'exploitable pour cette condition
            end
            anyRow = true;

            ri = length(Results) + 1;
            Results(ri).Numero            = d.Numero;
            Results(ri).PatientID         = d.PatientID;
            Results(ri).Condition         = condition;
            Results(ri).AnalysedSide      = strjoin(d.Side, '/');
            Results(ri).ContralateralSide = contraSide;

            % ---- HT (Euler), ANALYTIC1 (dof 3, flexion/extension) et
            % ANALYTIC2 (dof 1, elevation/abduction) ----
            [ht1, ht2] = romForCondition(d, condition, 'ANALYTIC1', 3, 'ANALYTIC2', 1, jiHT, cycField);
            Results(ri).HT_ANALYTIC1_deg = ht1;
            Results(ri).HT_ANALYTIC2_deg = ht2;
            htMax = max([ht1, ht2], [], 'omitnan');
            Results(ri).HT_Max_deg   = htMax;
            Results(ri).HT_Criterion = romCriterionAtThreshold(htMax, 120);
            % Colonnes supplémentaires, mêmes seuils que le graph stratifié
            % (PlotContralateralROM ci-dessous) - n'entrent PAS dans
            % Eligible_Overall_HT, qui reste basé sur HT_Criterion (120°) seul.
            Results(ri).HT_130 = romCriterionAtThreshold(htMax, 130);
            Results(ri).HT_140 = romCriterionAtThreshold(htMax, 140);
            Results(ri).HT_150 = romCriterionAtThreshold(htMax, 150);
            Results(ri).HT_160 = romCriterionAtThreshold(htMax, 160);

            % ---- HG (Euler YXY, dof 1 = Elevation, MEME dof pour les deux
            % taches - pas de switch task-dependant contrairement a HT) ----
            [hg1, hg2] = romForCondition(d, condition, 'ANALYTIC1', 1, 'ANALYTIC2', 1, jiHG, cycField);
            Results(ri).HG_ANALYTIC1_deg = hg1;
            Results(ri).HG_ANALYTIC2_deg = hg2;
            hgMax = max([hg1, hg2], [], 'omitnan');
            Results(ri).HG_Max_deg   = hgMax;
            Results(ri).HG_Criterion = romCriterionAtThreshold(hgMax, 120);
            Results(ri).HG_130 = romCriterionAtThreshold(hgMax, 130);
            Results(ri).HG_140 = romCriterionAtThreshold(hgMax, 140);
            Results(ri).HG_150 = romCriterionAtThreshold(hgMax, 150);
            Results(ri).HG_160 = romCriterionAtThreshold(hgMax, 160);

            % ---- EVA = 0, côté controlatéral, cette condition uniquement ----
            evaVal = evaForCondition(d, condition, analyticPainMap, contraSide);
            Results(ri).EVA_Contralateral = evaVal;
            if isnan(evaVal)
                Results(ri).EVA_Criterion = '';
            elseif evaVal == 0
                Results(ri).EVA_Criterion = 'Oui';
            else
                Results(ri).EVA_Criterion = 'Non';
            end

            Results(ri).Antecedents_Details    = antecedentsDetails;
            Results(ri).Antecedents_Criterion  = antecedentsCriterion;

            % ---- Overall (x2) : Oui seulement si les 3 critères sont Oui,
            % EVA/Antécédents partagés, ROM propre à HT et à HG ----
            Results(ri).Eligible_Overall_HT = overallVerdict(Results(ri).HT_Criterion, Results(ri).EVA_Criterion, antecedentsCriterion);
            Results(ri).Eligible_Overall_HG = overallVerdict(Results(ri).HG_Criterion, Results(ri).EVA_Criterion, antecedentsCriterion);
        end

        if ~anyRow
            % Aucune condition exploitable pour ce patient (ni PRE ni POST) -
            % garde une ligne vide plutôt que de le faire disparaître du
            % tableau (visibilité que le patient existe dans la base).
            ri = length(Results) + 1;
            Results(ri).Numero            = d.Numero;
            Results(ri).PatientID         = d.PatientID;
            Results(ri).Condition         = '';
            Results(ri).AnalysedSide      = strjoin(d.Side, '/');
            Results(ri).ContralateralSide = contraSide;
            Results(ri).HT_ANALYTIC1_deg  = NaN;
            Results(ri).HT_ANALYTIC2_deg  = NaN;
            Results(ri).HT_Max_deg        = NaN;
            Results(ri).HT_Criterion      = '';
            Results(ri).HT_130            = '';
            Results(ri).HT_140            = '';
            Results(ri).HT_150            = '';
            Results(ri).HT_160            = '';
            Results(ri).HG_ANALYTIC1_deg  = NaN;
            Results(ri).HG_ANALYTIC2_deg  = NaN;
            Results(ri).HG_Max_deg        = NaN;
            Results(ri).HG_Criterion      = '';
            Results(ri).HG_130            = '';
            Results(ri).HG_140            = '';
            Results(ri).HG_150            = '';
            Results(ri).HG_160            = '';
            Results(ri).EVA_Contralateral = NaN;
            Results(ri).EVA_Criterion     = '';
            Results(ri).Antecedents_Details   = antecedentsDetails;
            Results(ri).Antecedents_Criterion = antecedentsCriterion;
            Results(ri).Eligible_Overall_HT   = '';
            Results(ri).Eligible_Overall_HG   = '';
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

PlotContralateralROM([Results.HT_Max_deg], 'HT (huméro-thoracique)');
PlotContralateralROM([Results.HG_Max_deg], 'HG (huméro-gravitaire)');

ReportOverlap(Results);

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
% Oui/Non/'' at an arbitrary ROM threshold - same convention as
% HT_Criterion/HG_Criterion (blank = missing data, distinct from Non).
function crit = romCriterionAtThreshold(romMax, threshold)
if isnan(romMax)
    crit = '';
elseif romMax > threshold
    crit = 'Oui';
else
    crit = 'Non';
end
end

% Range-of-motion lookup for ONE specific condition (no PRE/POST fallback -
% each condition is now its own independent row, see call site). dof1/dof2
% let HT (task-dependent: 3 then 1) and HG (fixed: 1 then 1) share this.
function [v1, v2] = romForCondition(d, condition, task1, dof1, task2, dof2, ji, cycField)
v1 = NaN; v2 = NaN;
if ~hasField(d, condition, 'Trial'), return; end
Trial = d.(condition).Trial;
v1 = getEulerRangeCycleTask(Trial, task1, ji, dof1, cycField);
v2 = getEulerRangeCycleTask(Trial, task2, ji, dof2, cycField);
end

% Mean contralateral pain score for ONE specific condition (no PRE/POST
% fallback - see romForCondition).
function evaVal = evaForCondition(d, condition, analyticPainMap, side)
evaVal = NaN;
if ~hasField(d, condition, 'Session'), return; end
vals = collectPainValsSide(d.(condition).Session, analyticPainMap, side);
if ~isempty(vals)
    evaVal = mean(vals);
end
end

% Oui seulement si les 3 critères (ROM propre à la mesure + EVA +
% Antécédents, ces deux derniers partagés entre HT et HG) sont Oui ; blanc
% si au moins un est non calculable (données manquantes), jamais défaulté
% à Non.
function verdict = overallVerdict(romCriterion, evaCriterion, antecedentsCriterion)
crit = {romCriterion, evaCriterion, antecedentsCriterion};
if any(cellfun(@isempty, crit))
    verdict = '';
elseif all(strcmp(crit, 'Oui'))
    verdict = 'Oui';
else
    verdict = 'Non';
end
end

% Two figures for ONE ROM measure (called once for HT, once for HG - see
% call site): (1) bar chart - how many contralateral shoulders clear each
% ROM threshold 120/130/140/150/160deg (stratified count, decreasing by
% construction as the bar rises), (2) histogram of the same values across
% ALL contralateral shoulders with a valid measurement - not just the
% eligible ones - to see the full distribution shape (RL patients and
% missing-data rows excluded from both, via NaN).
% Reports, in the command window, patients whose contralateral shoulder is
% eligible at BOTH timepoints (PRE row AND POST row both Eligible_Overall_*
% = 'Oui') - a stronger signal than either timepoint alone, now that PRE
% and POST are independent rows (see file header) rather than one fused
% value per patient. Reported separately for HT and HG since they're
% independent verdicts. Only meaningful for patients with BOTH a PRE and a
% POST row (single-condition/blank-row patients are excluded by construction).
function ReportOverlap(Results)
disp(' ');
disp('=== Épaules controlatérales éligibles aux DEUX temps (PRE et POST) ===');
if isempty(Results)
    disp('Aucune donnée.');
    return;
end

ids = unique({Results.PatientID}, 'stable');
overlapHT = {};
overlapHG = {};
nBoth = 0;
for i = 1:numel(ids)
    id = ids{i};
    rows  = Results(strcmp({Results.PatientID}, id));
    conds = {rows.Condition};
    iPre  = find(strcmp(conds, 'PRE'),  1);
    iPost = find(strcmp(conds, 'POST'), 1);
    if isempty(iPre) || isempty(iPost)
        continue; % ce patient n'a pas les deux conditions - pas d'overlap possible
    end
    nBoth = nBoth + 1;
    if strcmp(rows(iPre).Eligible_Overall_HT, 'Oui') && strcmp(rows(iPost).Eligible_Overall_HT, 'Oui')
        overlapHT{end+1} = id; %#ok<AGROW>
    end
    if strcmp(rows(iPre).Eligible_Overall_HG, 'Oui') && strcmp(rows(iPost).Eligible_Overall_HG, 'Oui')
        overlapHG{end+1} = id; %#ok<AGROW>
    end
end

disp(['Patients avec PRE et POST tous les deux disponibles : ', num2str(nBoth)]);
disp(['  Overlap HT (éligible aux deux temps) : ', num2str(numel(overlapHT)), ' patient(s)', formatIdList(overlapHT)]);
disp(['  Overlap HG (éligible aux deux temps) : ', num2str(numel(overlapHG)), ' patient(s)', formatIdList(overlapHG)]);
end

function s = formatIdList(ids)
if isempty(ids)
    s = '';
else
    s = [' : ', strjoin(ids, ', ')];
end
end

function PlotContralateralROM(romMaxAll, label)
romMaxAll = romMaxAll(~isnan(romMaxAll));
if isempty(romMaxAll)
    disp(['PlotContralateralROM (', label, '): no valid data to plot.']);
    return;
end

% ---- Figure 1 : nombre de patients au-dessus de chaque seuil ----
thresholds = [120 130 140 150 160];
counts = arrayfun(@(t) sum(romMaxAll > t), thresholds);

figure('Name', [label, ' - stratification par seuil'], 'Color', 'w');
b = bar(thresholds, counts, 'FaceColor', [0 0.4470 0.7410]);
xlabel('Seuil ROM (°)');
ylabel('Nombre d''épaules controlatérales > seuil');
title(['Épaules controlatérales éligibles par seuil - ', label]);
xticks(thresholds);
xtips = b.XEndPoints; ytips = b.YEndPoints;
text(xtips, ytips, string(counts), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom');

% ---- Figure 2 : distribution complète, toutes épaules controlatérales ----
figure('Name', [label, ' - distribution complète'], 'Color', 'w');
histogram(romMaxAll, 'BinWidth', 10, 'FaceColor', [0.4660 0.6740 0.1880]);
xlabel([label, ' controlatérale max (°)']);
ylabel('Nombre d''épaules controlatérales');
title(sprintf('Distribution %s controlatérale - toute la cohorte (n=%d)', label, numel(romMaxAll)));
end

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
