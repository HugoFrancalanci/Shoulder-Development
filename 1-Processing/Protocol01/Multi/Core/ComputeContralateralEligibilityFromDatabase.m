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
%                1a) HT_Criterion: humero-thoracic ANALYTIC1 (flexion-type,
%                   dof3) OR ANALYTIC2 (abduction-type, dof1) exceeds an
%                   AGE- AND SEX-SPECIFIC normative mean (not a fixed 120°
%                   for everyone) - see normativeMean, local function,
%                   sourced from Gill et al. 2020 (BMC Musculoskeletal
%                   Disorders 21:676, "Shoulder range of movement in the
%                   general population: age and gender stratified
%                   normative data using a community-based cohort") Tables
%                   1 (flexion) and 2 (abduction), mean active ROM by
%                   5-year age group/sex/side, n=2404 community-based
%                   cohort WITHOUT shoulder pain/stiffness history. Euler-
%                   based (Joint(1) right / Joint(6) left, same joints/
%                   convention as ComputeClinicalContributionsFromDatabase.m's
%                   HT). The Euler DOF that carries flexion/extension is
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
%                   not the - possibly leaning - trunk), same age/sex-
%                   normative comparison as HT (see 1a) - methodologically
%                   this is actually the BETTER match: Gill et al.'s
%                   inclinometer is gravity-referenced (patient standing),
%                   i.e. it measures the SAME thing HG does, whereas HT is
%                   trunk-relative. Applied to HT too (1a) as a deliberate
%                   approximation, by user decision (2026-08-26), since HT
%                   is the more commonly reported clinical measure. Euler-
%                   based (Joint(12) right / Joint(13) left, sequence YXY,
%                   DOF1/X = Elevation - see ComputeKinematics.m ~line
%                   395-439). Unlike HT, the elevation DOF is DOF1 for BOTH
%                   tasks (no task-dependent switching) and is stored
%                   identically on both sides (no sign flip on DOF1,
%                   confirmed in ComputeKinematics.m - only DOF2/DOF3 get
%                   sign-flipped on the left).
%                   Both HT_Criterion and HG_Criterion combine flexion vs
%                   abduction via OR (either exceeding ITS OWN age/sex
%                   norm is enough - see romCriterionOrDualThreshold),
%                   matching the same "ANALYTIC1 OR ANALYTIC2" spirit the
%                   fixed-threshold version had. HT_NormFlexion_deg/
%                   HT_NormAbduction_deg (and the HG_ equivalents) report
%                   the exact normative value used for that patient, for
%                   auditability. Blank ('') if age or sex is unknown, or
%                   age < 20 (article only covers 20+) - NOT silently
%                   defaulted to Non.
%                2) HT_EVA_Criterion/HG_EVA_Criterion: mean pain score
%                   (Session.Pain) across the 4 ANALYTIC tasks, taken
%                   directly for the CONTRALATERAL side (unlike
%                   ComputePatientInfos.m's EVA_PRE/POST, which targets the
%                   affected side with a fallback - here the side is fixed
%                   to the contralateral one, no fallback) < 1 (changed from
%                   ==0, 2026-08-26). ONE PER
%                   BUNDLE (not shared) - see the PRE/POST rule below for
%                   why: HT's EVA must come from the SAME condition as
%                   HT's ROM, and likewise for HG, so they can genuinely
%                   differ between the two bundles.
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
%                ONE ROW PER PATIENT. PRE/POST combination rule, decided
%                per BUNDLE (HT-bundle = HT_Criterion+HT_EVA_Criterion+
%                Antecedents_Criterion; HG-bundle = the HG equivalent) -
%                NOT per individual criterion (that was a bug in an
%                earlier version of this logic: it let e.g. HT_Criterion
%                come from PRE while the EVA feeding into Eligible_Overall_HT
%                came from POST - two different real-world timepoints
%                mixed into one verdict, which doesn't correspond to any
%                actual clinical visit of that patient). Within a bundle,
%                it's ALWAYS "all 3 from PRE" or "all 3 from POST", never a
%                mix - see bundleStopAtPre, local function:
%                  1) Evaluate ROM + EVA at PRE. If that alone already
%                     gives Eligible_Overall_*='Oui' (with Antecedents,
%                     which doesn't vary by condition - see below) -> use
%                     PRE for BOTH ROM and EVA in this bundle, done.
%                  2) Otherwise -> evaluate ROM + EVA at POST instead; if
%                     POST has ANY usable data (Trial or Session present),
%                     use POST for BOTH ROM and EVA in this bundle,
%                     whatever verdict that gives (Oui/Non/blank).
%                  3) POST has no data either -> fall back to PRE's (non-
%                     passing) ROM+EVA pair - i.e. PRE and POST both
%                     fail/missing -> Non (or blank if truly nothing at all).
%                `HT_Condition`/`HG_Condition` record which condition
%                determined that ENTIRE bundle (ROM and EVA together) -
%                HT and HG remain two INDEPENDENT reports and MAY still
%                resolve to a DIFFERENT condition from EACH OTHER (e.g.
%                HT_Condition='PRE' while HG_Condition='POST', if HT
%                already passed as a whole at PRE but HG only passed as a
%                whole at POST) - only the mix WITHIN one bundle is excluded.
%
%                Antecedents are the one exception - a medical-history
%                fact, not a session measurement - so they stay a UNION of
%                BOTH PRE and POST text (POST being a superset of PRE in
%                practice - new lines are only appended at POST, see
%                Antich_Jaime_617113/Abreu_Serafim_301190 in the raw data),
%                computed once per patient, not tied to whichever condition
%                HT/HG/EVA happened to settle on.
%
%                Patients whose PatientSelection side is "RL" (both sides
%                analysed) have no contralateral side: all criteria and
%                both Eligible_Overall_HT/_HG left blank, ContralateralSide
%                = 'N/A (deux cotes analyses)'.
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
%                HT_Max_deg/HG_Max_deg = max(*_ANALYTIC1_deg, *_ANALYTIC2_deg)
%                FOR WHICHEVER CONDITION WON (see HT_Condition/HG_Condition) -
%                the same value HT_Criterion/HG_Criterion is based on.
%                (The HT_130/140/150/160 fixed-threshold stratification
%                columns from an earlier version were removed 2026-08-26,
%                once Eligible_Overall_HT/_HG became age/sex-normative -
%                a flat 130/140/150/160° bar no longer meant anything
%                consistent once the real pass/fail bar moved per patient.)
%
%                Age/Gender: one pair per patient (not per bundle), simple
%                PRE-priority/POST-fallback reporting fields (see
%                getPatientAgeGender) - independent of which condition
%                HT/HG individually settled on, just here so the cohort's
%                age/sex spread is visible next to the eligibility result.
%                Gender: 1=Femme, 0=Homme, blank=inconnu (ComputePatientInfos.m
%                convention).
%
%                HT_FailureReason/HG_FailureReason: which of the 3 criteria
%                explicitly failed ('Non'), joined (e.g. "ROM + EVA") - only
%                populated when the overall verdict is a CONFIRMED 'Non'
%                (blank if 'Oui' or '' - a missing-data row has nothing
%                confirmed to attribute a failure to).
%
%                Six figures generated after the Excel export, three per
%                measure (HT then HG): (1) PlotContralateralROM, local
%                function - histogram of *_Max_deg across ALL contralateral
%                shoulders with a valid measurement (not just the eligible
%                ones), to see the full distribution shape; (2)
%                PlotEligibilityCounts, local function - bar chart of the
%                REAL outcome, counts of Eligible_Overall_HT/_HG =
%                Oui/Non/blank - this is what replaced the old fixed-
%                threshold stratification bars, which stopped reflecting
%                the actual (now per-patient) criterion; (3)
%                PlotFailureBreakdown, local function - among the 'Non'
%                patients, how many have EACH of ROM/EVA/Antécédents among
%                their failure reasons (not mutually exclusive - a patient
%                failing two criteria counts in both bars), to see which
%                criterion is the biggest blocker overall.
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

Results = struct('Numero', {}, 'PatientID', {}, 'Age', {}, 'Gender', {}, 'AnalysedSide', {}, 'ContralateralSide', {}, ...
    'HT_ANALYTIC1_deg', {}, 'HT_ANALYTIC2_deg', {}, 'HT_Max_deg', {}, 'HT_Condition', {}, ...
    'HT_NormFlexion_deg', {}, 'HT_NormAbduction_deg', {}, 'HT_Criterion', {}, ...
    'HT_EVA_Contralateral', {}, 'HT_EVA_Criterion', {}, ...
    'HG_ANALYTIC1_deg', {}, 'HG_ANALYTIC2_deg', {}, 'HG_Max_deg', {}, 'HG_Condition', {}, ...
    'HG_NormFlexion_deg', {}, 'HG_NormAbduction_deg', {}, 'HG_Criterion', {}, ...
    'HG_EVA_Contralateral', {}, 'HG_EVA_Criterion', {}, ...
    'Antecedents_Details', {}, 'Antecedents_Criterion', {}, ...
    'Eligible_Overall_HT', {}, 'HT_FailureReason', {}, ...
    'Eligible_Overall_HG', {}, 'HG_FailureReason', {});

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
        [patientAge, patientGender] = getPatientAgeGender(d);
        Results(ri).Age          = patientAge;
        Results(ri).Gender       = patientGender; % 1=Femme, 0=Homme, NaN=inconnu (meme convention que ComputePatientInfos.m)
        Results(ri).AnalysedSide = strjoin(d.Side, '/');

        if numel(d.Side) ~= 1
            % 'RL' : les deux côtés sont analysés, pas de côté controlatéral
            Results(ri).ContralateralSide     = 'N/A (deux côtés analysés)';
            Results(ri).HT_ANALYTIC1_deg       = NaN;
            Results(ri).HT_ANALYTIC2_deg       = NaN;
            Results(ri).HT_Max_deg             = NaN;
            Results(ri).HT_Condition           = '';
            Results(ri).HT_NormFlexion_deg     = NaN;
            Results(ri).HT_NormAbduction_deg   = NaN;
            Results(ri).HT_Criterion           = '';
            Results(ri).HT_EVA_Contralateral   = NaN;
            Results(ri).HT_EVA_Criterion       = '';
            Results(ri).HG_ANALYTIC1_deg       = NaN;
            Results(ri).HG_ANALYTIC2_deg       = NaN;
            Results(ri).HG_Max_deg             = NaN;
            Results(ri).HG_Condition           = '';
            Results(ri).HG_NormFlexion_deg     = NaN;
            Results(ri).HG_NormAbduction_deg   = NaN;
            Results(ri).HG_Criterion           = '';
            Results(ri).HG_EVA_Contralateral   = NaN;
            Results(ri).HG_EVA_Criterion       = '';
            Results(ri).Antecedents_Details    = '';
            Results(ri).Antecedents_Criterion  = '';
            Results(ri).Eligible_Overall_HT    = '';
            Results(ri).HT_FailureReason        = '';
            Results(ri).Eligible_Overall_HG    = '';
            Results(ri).HG_FailureReason        = '';
            continue;
        end

        if strcmp(d.Side{1}, 'R'), contraSide = 'L'; else, contraSide = 'R'; end
        Results(ri).ContralateralSide = contraSide;

        if strcmp(contraSide, 'R')
            jiHT = 1; jiHG = 12; cycField = 'rcycle';
        else
            jiHT = 6; jiHG = 13; cycField = 'lcycle';
        end

        % ---- Antécédents : fait médical partagé par les deux rapports
        % (HT/HG), pas une mesure de session - union PRE+POST comme avant,
        % calculé une seule fois, AVANT les rapports HT/HG puisqu'ils en
        % ont besoin (voir bundleStopAtPre) ----
        details = {};
        for iC = 1:numel(conditions)
            condition = conditions{iC};
            if ~hasField(d, condition, 'Pathology'), continue; end
            details = [details, findSideMentions(d.(condition).Pathology, contraSide)]; %#ok<AGROW>
        end
        details = unique(details, 'stable');
        Results(ri).Antecedents_Details = strjoin(details, ' / ');
        if isempty(details)
            antecedentsCriterion = 'Oui';
        else
            antecedentsCriterion = 'Non';
        end
        Results(ri).Antecedents_Criterion = antecedentsCriterion;

        % ---- 1a) HT : rapport COMPLET (ROM + EVA + Antécédents) décidé en
        % UN SEUL bloc par condition - "soit les 3 critères en PRE, soit
        % les 3 en POST", jamais un mélange (voir bundleStopAtPre, en-tête
        % du fichier). Seuils normatifs âge/sexe (Gill et al. 2020, voir
        % normativeMean) au lieu d'un seuil fixe - Oui si flexion
        % (ANALYTIC1) > moyenne normative flexion(âge,sexe,côté) OU
        % abduction (ANALYTIC2) > moyenne normative abduction(âge,sexe,côté) ----
        [ht1, ht2, htCond, htCrit, htNormFlex, htNormAbd, htEvaVal, htEvaCrit] = ...
            bundleStopAtPre(d, 'ANALYTIC1', 3, 'ANALYTIC2', 1, jiHT, cycField, contraSide, analyticPainMap, antecedentsCriterion);
        Results(ri).HT_ANALYTIC1_deg     = ht1;
        Results(ri).HT_ANALYTIC2_deg     = ht2;
        Results(ri).HT_Condition         = htCond;
        Results(ri).HT_NormFlexion_deg   = htNormFlex;
        Results(ri).HT_NormAbduction_deg = htNormAbd;
        Results(ri).HT_Criterion         = htCrit;
        Results(ri).HT_EVA_Contralateral = htEvaVal;
        Results(ri).HT_EVA_Criterion     = htEvaCrit;
        htMax = max([ht1, ht2], [], 'omitnan');
        Results(ri).HT_Max_deg = htMax;
        Results(ri).Eligible_Overall_HT = overallVerdict(htCrit, htEvaCrit, antecedentsCriterion);
        Results(ri).HT_FailureReason    = failureReason(htCrit, htEvaCrit, antecedentsCriterion, Results(ri).Eligible_Overall_HT);

        % ---- 1b) HG : même principe (rapport complet en un seul bloc),
        % DOF1 pour les deux tâches (pas de switch task-dependant
        % contrairement à HT). Note méthodologique : l'article mesure au
        % clinomètre gravitaire (patient debout) - ça correspond
        % précisément à HG (huméro-gravitaire), pas HT (huméro-thoracique,
        % relatif au tronc) ; appliqué ici aux deux par choix de
        % l'utilisateur, HG étant la mesure la plus cohérente avec l'article.
        % HT et HG restent deux rapports INDÉPENDANTS : ils peuvent
        % chacun retenir une condition différente (PRE pour l'un, POST
        % pour l'autre), seul le mélange À L'INTÉRIEUR d'un même rapport
        % est exclu ----
        [hg1, hg2, hgCond, hgCrit, hgNormFlex, hgNormAbd, hgEvaVal, hgEvaCrit] = ...
            bundleStopAtPre(d, 'ANALYTIC1', 1, 'ANALYTIC2', 1, jiHG, cycField, contraSide, analyticPainMap, antecedentsCriterion);
        Results(ri).HG_ANALYTIC1_deg     = hg1;
        Results(ri).HG_ANALYTIC2_deg     = hg2;
        Results(ri).HG_Condition         = hgCond;
        Results(ri).HG_NormFlexion_deg   = hgNormFlex;
        Results(ri).HG_NormAbduction_deg = hgNormAbd;
        Results(ri).HG_Criterion         = hgCrit;
        Results(ri).HG_EVA_Contralateral = hgEvaVal;
        Results(ri).HG_EVA_Criterion     = hgEvaCrit;
        hgMax = max([hg1, hg2], [], 'omitnan');
        Results(ri).HG_Max_deg = hgMax;
        Results(ri).Eligible_Overall_HG = overallVerdict(hgCrit, hgEvaCrit, antecedentsCriterion);
        Results(ri).HG_FailureReason    = failureReason(hgCrit, hgEvaCrit, antecedentsCriterion, Results(ri).Eligible_Overall_HG);
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
PlotEligibilityCounts({Results.Eligible_Overall_HT}, 'HT (huméro-thoracique)');
PlotFailureBreakdown({Results.HT_Criterion}, {Results.HT_EVA_Criterion}, {Results.Antecedents_Criterion}, {Results.Eligible_Overall_HT}, 'HT (huméro-thoracique)');
PlotContralateralROM([Results.HG_Max_deg], 'HG (huméro-gravitaire)');
PlotEligibilityCounts({Results.Eligible_Overall_HG}, 'HG (huméro-gravitaire)');
PlotFailureBreakdown({Results.HG_Criterion}, {Results.HG_EVA_Criterion}, {Results.Antecedents_Criterion}, {Results.Eligible_Overall_HG}, 'HG (huméro-gravitaire)');

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
% Age (years) and Gender for a patient - simple reporting field, PRE
% priority with POST fallback ONLY if PRE gives nothing at all (unlike
% bundleStopAtPre, this is NOT tied to any eligibility decision, just a
% general "how old/what sex is this patient" column for readability).
function [age, gender] = getPatientAgeGender(d)
[age, gender] = getAgeGenderForCondition(d, 'PRE');
if isnan(age) && isnan(gender)
    [age, gender] = getAgeGenderForCondition(d, 'POST');
end
end

% Range-of-motion lookup for ONE specific condition, no combination logic -
% see romStopAtPre for the PRE/POST decision built on top of this. dof1/
% dof2 let HT (task-dependent: 3 then 1) and HG (fixed: 1 then 1) share this.
function [v1, v2] = romForCondition(d, condition, task1, dof1, task2, dof2, ji, cycField)
v1 = NaN; v2 = NaN;
if ~hasField(d, condition, 'Trial'), return; end
Trial = d.(condition).Trial;
v1 = getEulerRangeCycleTask(Trial, task1, ji, dof1, cycField);
v2 = getEulerRangeCycleTask(Trial, task2, ji, dof2, cycField);
end

% PRE/POST combination for one COMPLETE bundle (ROM + EVA together, plus
% the already-shared antecedentsCriterion) - see file header: "soit les 3
% critères en PRE, soit les 3 en POST", never a mix of a PRE criterion
% with a POST criterion within the SAME bundle (HT is one bundle, HG is a
% separate one - they may independently land on different conditions from
% EACH OTHER, but internally each is fully PRE or fully POST):
%   1) Evaluate ROM + EVA at PRE; if PRE alone already gives an all-'Oui'
%      overall verdict (with antecedentsCriterion) -> use PRE for
%      everything in this bundle, done.
%   2) Otherwise, evaluate ROM + EVA at POST; if POST has ANY usable data
%      (Trial or Session present) -> use POST for everything in this
%      bundle, whatever verdict that gives (Oui/Non/partial-blank).
%   3) POST has no data either -> fall back to PRE's (non-passing) result.
% dof1/task1 = flexion-type measure (ANALYTIC1 for both HT and HG, though
% the DOF differs - see call site); dof2/task2 = abduction-type measure
% (ANALYTIC2). ROM threshold is age/sex-normative (Gill et al. 2020, see
% normativeMean), looked up separately for PRE's age and POST's age (a
% year may separate them).
function [v1, v2, cond, romCrit, normFlex, normAbd, evaVal, evaCrit] = ...
    bundleStopAtPre(d, task1, dof1, task2, dof2, ji, cycField, side, analyticPainMap, antecedentsCriterion)

[preV1, preV2] = romForCondition(d, 'PRE', task1, dof1, task2, dof2, ji, cycField);
[preAge, preGender] = getAgeGenderForCondition(d, 'PRE');
preNormFlex = normativeMean('flexion', preAge, preGender, side);
preNormAbd  = normativeMean('abduction', preAge, preGender, side);
preRomCrit  = romCriterionOrDualThreshold(preV1, preNormFlex, preV2, preNormAbd);
preEvaVal   = evaForCondition(d, 'PRE', analyticPainMap, side);
preEvaCrit  = evaCriterionFromValue(preEvaVal);
preOverall  = overallVerdict(preRomCrit, preEvaCrit, antecedentsCriterion);

if strcmp(preOverall, 'Oui')
    v1 = preV1; v2 = preV2; cond = 'PRE'; romCrit = preRomCrit;
    normFlex = preNormFlex; normAbd = preNormAbd;
    evaVal = preEvaVal; evaCrit = preEvaCrit;
    return;
end

[postV1, postV2] = romForCondition(d, 'POST', task1, dof1, task2, dof2, ji, cycField);
[postAge, postGender] = getAgeGenderForCondition(d, 'POST');
postNormFlex = normativeMean('flexion', postAge, postGender, side);
postNormAbd  = normativeMean('abduction', postAge, postGender, side);
postRomCrit  = romCriterionOrDualThreshold(postV1, postNormFlex, postV2, postNormAbd);
postEvaVal   = evaForCondition(d, 'POST', analyticPainMap, side);
postEvaCrit  = evaCriterionFromValue(postEvaVal);

postHasAnyData = ~isnan(postV1) || ~isnan(postV2) || ~isnan(postEvaVal);
if postHasAnyData
    v1 = postV1; v2 = postV2; cond = 'POST'; romCrit = postRomCrit;
    normFlex = postNormFlex; normAbd = postNormAbd;
    evaVal = postEvaVal; evaCrit = postEvaCrit;
    return;
end

% POST a rien d'exploitable -> repli sur PRE (qui n'avait pas donne Oui,
% donc 'Non' ou '' - jamais mélangé avec une donnée POST)
v1 = preV1; v2 = preV2; cond = 'PRE'; romCrit = preRomCrit;
normFlex = preNormFlex; normAbd = preNormAbd;
evaVal = preEvaVal; evaCrit = preEvaCrit;
end

% Oui/Non/'' combining a flexion-type and an abduction-type measurement,
% each against its OWN age/sex-normative threshold (may differ - see
% normativeMean), OR'd together (either passing is enough, matching the
% pre-existing "ANALYTIC1 OR ANALYTIC2" spirit). Blank ONLY if NEITHER
% comparison can be evaluated at all (missing ROM value or missing norm
% for BOTH movements) - e.g. age/gender unknown makes both thresholds NaN
% simultaneously, which must NOT silently collapse to 'Non'.
function crit = romCriterionOrDualThreshold(v1, threshold1, v2, threshold2)
canEval1 = ~isnan(v1) && ~isnan(threshold1);
canEval2 = ~isnan(v2) && ~isnan(threshold2);
if ~canEval1 && ~canEval2
    crit = '';
    return;
end
pass1 = canEval1 && (v1 > threshold1);
pass2 = canEval2 && (v2 > threshold2);
if pass1 || pass2
    crit = 'Oui';
else
    crit = 'Non';
end
end

% Age (years) and Gender (1=Femme/0=Homme, NaN=inconnu) for one condition,
% reusing ComputePatientInfos.m (same Patient/Session/Pathology already
% used by MAIN_MULTI_Protocol_01.m - avoids duplicating age/gender parsing
% logic). examDate parsed from the session folder name in d.(condition).Date
% (same 8-digit-prefix convention as MAIN_MULTI_Protocol_01.m), falling
% back to Session.date inside ComputePatientInfos.m if that fails.
function [age, gender] = getAgeGenderForCondition(d, condition)
age = NaN; gender = NaN;
if ~hasField(d, condition, 'Patient') || ~hasField(d, condition, 'Session') || ~hasField(d, condition, 'Pathology')
    return;
end
examDate = [];
if isfield(d.(condition), 'Date') && ischar(d.(condition).Date)
    [~, sessionFolderName] = fileparts(d.(condition).Date);
    dateDigits = regexp(sessionFolderName, '^\d{8}', 'match', 'once');
    if ~isempty(dateDigits)
        try
            examDate = datetime(dateDigits, 'InputFormat', 'yyyyMMdd');
        catch
            examDate = [];
        end
    end
end
try
    info   = ComputePatientInfos(d.(condition).Patient, d.(condition).Session, d.(condition).Pathology, examDate);
    age    = info.Age;
    gender = info.Gender;
catch
    age = NaN; gender = NaN;
end
end

% Age/sex/side-specific mean active shoulder ROM (degrees), from Gill et
% al. 2020 (BMC Musculoskeletal Disorders 21:676) - "Shoulder range of
% movement in the general population: age and gender stratified normative
% data using a community-based cohort". Community-based cohort (n=2404,
% 51.5% male), participants WITHOUT a history of shoulder pain/stiffness,
% measured with a gravity-referenced inclinometer (patient standing) -
% methodologically this matches HG (humerus vs vertical/gravity), not HT
% (vs trunk); applied to both per user decision (2026-08-26), as an
% approximation for HT. Table 1 (flexion) and Table 2 (abduction) means,
% by 5-year age group (20-24 ... 80-84, then 85+), sex, and side. Article
% only covers age >= 20 - returns NaN below that (and for unknown age/sex).
function meanVal = normativeMean(movement, age, genderBinary, side)
meanVal = NaN;
if isnan(age) || isnan(genderBinary) || age < 20
    return;
end
bracket = min(floor((age - 20) / 5) + 1, 14); % 1=20-24 ... 13=80-84, 14=85+

% Columns: 20-24 25-29 30-34 35-39 40-44 45-49 50-54 55-59 60-64 65-69 70-74 75-79 80-84 85+
flexionMaleLeft    = [168.6 165.0 166.2 162.3 160.9 162.9 163.6 157.3 155.9 149.9 143.3 143.0 137.1 129.6];
flexionMaleRight   = [170.8 165.2 167.9 162.8 165.5 164.9 165.0 159.4 157.4 152.3 146.8 143.4 140.2 127.8];
flexionFemaleLeft  = [166.4 164.8 162.9 165.2 160.2 158.0 158.0 154.7 146.0 151.6 145.9 138.1 132.1 129.9];
flexionFemaleRight = [164.7 166.0 164.4 166.2 163.7 159.9 160.1 157.1 146.5 152.1 144.8 141.9 133.7 124.1];

abductionMaleLeft    = [158.8 153.4 156.1 153.4 151.6 152.4 154.6 146.5 145.0 135.7 134.8 134.2 125.0 119.7];
abductionMaleRight   = [158.4 154.1 157.0 155.1 154.9 154.5 158.1 148.6 145.9 137.5 137.2 136.4 130.5 118.9];
abductionFemaleLeft  = [156.0 155.2 155.9 156.4 152.5 148.5 149.3 146.2 138.2 140.5 131.8 127.8 115.0 118.9];
abductionFemaleRight = [156.4 157.3 156.0 158.8 154.9 151.1 151.4 149.6 138.8 142.6 132.7 133.3 120.9 119.5];

isFemale = (genderBinary == 1);
isLeft   = strcmp(side, 'L');

if strcmp(movement, 'flexion')
    if isFemale, tbl = ternary(isLeft, flexionFemaleLeft, flexionFemaleRight);
    else,        tbl = ternary(isLeft, flexionMaleLeft, flexionMaleRight);
    end
else % 'abduction'
    if isFemale, tbl = ternary(isLeft, abductionFemaleLeft, abductionFemaleRight);
    else,        tbl = ternary(isLeft, abductionMaleLeft, abductionMaleRight);
    end
end
meanVal = tbl(bracket);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

% Mean contralateral pain score for ONE specific condition, no combination
% logic - see evaStopAtPre.
function evaVal = evaForCondition(d, condition, analyticPainMap, side)
evaVal = NaN;
if ~hasField(d, condition, 'Session'), return; end
vals = collectPainValsSide(d.(condition).Session, analyticPainMap, side);
if ~isempty(vals)
    evaVal = mean(vals);
end
end

function crit = evaCriterionFromValue(v)
if isnan(v)
    crit = '';
elseif v < 1
    crit = 'Oui';
else
    crit = 'Non';
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

% Which of the 3 criteria explicitly failed ('Non'), for patients whose
% overall verdict is confirmed 'Non' - blank if the verdict is 'Oui' or ''
% (missing data - not a confirmed failure, nothing to attribute). Joined
% list (e.g. "ROM + EVA") since a patient can fail more than one at once.
function reason = failureReason(romCriterion, evaCriterion, antecedentsCriterion, verdict)
reason = '';
if ~strcmp(verdict, 'Non')
    return;
end
parts = {};
if strcmp(romCriterion, 'Non'), parts{end+1} = 'ROM'; end
if strcmp(evaCriterion, 'Non'), parts{end+1} = 'EVA'; end
if strcmp(antecedentsCriterion, 'Non'), parts{end+1} = 'Antécédents'; end
reason = strjoin(parts, ' + ');
end

% One figure for ONE ROM measure (called once for HT, once for HG - see
% call site): histogram of *_Max_deg across ALL contralateral shoulders
% with a valid measurement - not just the eligible ones - to see the full
% distribution shape (RL patients and missing-data rows excluded, via NaN).
% The fixed-threshold stratification bar chart that used to sit alongside
% this was removed (2026-08-26): once Eligible_Overall_HT/_HG became
% age/sex-normative (see bundleStopAtPre), fixed 120-160° bars no longer
% reflected the actual per-patient criterion - see PlotEligibilityCounts
% for the chart that replaced it (the real Oui/Non/blank outcome).
function PlotContralateralROM(romMaxAll, label)
romMaxAll = romMaxAll(~isnan(romMaxAll));
if isempty(romMaxAll)
    disp(['PlotContralateralROM (', label, '): no valid data to plot.']);
    return;
end

figure('Name', [label, ' - distribution complète'], 'Color', 'w');
histogram(romMaxAll, 'BinWidth', 10, 'FaceColor', [0.4660 0.6740 0.1880]);
xlabel([label, ' controlatérale max (°)']);
ylabel('Nombre d''épaules controlatérales');
title(sprintf('Distribution %s controlatérale - toute la cohorte (n=%d)', label, numel(romMaxAll)));
end

% Bar chart of the REAL eligibility outcome for one measure (HT or HG):
% counts of Eligible_Overall_HT/_HG = 'Oui' / 'Non' / '' (missing data) -
% replaces the old fixed-threshold stratification bars (see
% PlotContralateralROM), which no longer matched the age/sex-normative
% criterion once that was introduced.
function PlotEligibilityCounts(verdicts, label)
counts = [sum(strcmp(verdicts, 'Oui')), sum(strcmp(verdicts, 'Non')), sum(strcmp(verdicts, ''))];
if sum(counts) == 0
    disp(['PlotEligibilityCounts (', label, '): no data to plot.']);
    return;
end

figure('Name', [label, ' - résultat éligibilité'], 'Color', 'w');
catNames = categorical({'Oui', 'Non', 'Donnée manquante'});
catNames = reordercats(catNames, {'Oui', 'Non', 'Donnée manquante'});
b = bar(catNames, counts, 'FaceColor', 'flat');
b.CData(1,:) = [0.4660 0.6740 0.1880]; % vert
b.CData(2,:) = [0.8500 0.3250 0.0980]; % rouge
b.CData(3,:) = [0.6 0.6 0.6];          % gris
ylabel('Nombre de patients');
title(['Éligibilité controlatérale (résultat réel) - ', label]);
text(1:3, counts, string(counts), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% Bar chart: among patients with a CONFIRMED 'Non' overall verdict for
% this measure, how many have EACH criterion among their failure reasons -
% NOT mutually exclusive (a patient failing both ROM and EVA is counted in
% both bars), so this answers "which criterion is the biggest blocker
% overall", not "how many fail for exactly this reason alone" (that finer
% breakdown is in HT_FailureReason/HG_FailureReason instead, e.g. "ROM +
% EVA" as one combined string, for manual review in Excel).
function PlotFailureBreakdown(romCriterion, evaCriterion, antecedentsCriterion, verdicts, label)
isNon = strcmp(verdicts, 'Non');
nNon = sum(isNon);
if nNon == 0
    disp(['PlotFailureBreakdown (', label, '): no Non-verdict patients to break down.']);
    return;
end

nRom = sum(isNon & strcmp(romCriterion, 'Non'));
nEva = sum(isNon & strcmp(evaCriterion, 'Non'));
nAnt = sum(isNon & strcmp(antecedentsCriterion, 'Non'));

figure('Name', [label, ' - raisons d''échec'], 'Color', 'w');
catNames = categorical({'ROM', 'EVA', 'Antécédents'});
catNames = reordercats(catNames, {'ROM', 'EVA', 'Antécédents'});
counts = [nRom, nEva, nAnt];
bar(catNames, counts, 'FaceColor', [0.8500 0.3250 0.0980]);
ylabel('Nombre de patients (non-exclusif)');
title(sprintf('Raisons d''échec parmi les %d patients Non - %s', nNon, label));
text(1:3, counts, string(counts), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
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
