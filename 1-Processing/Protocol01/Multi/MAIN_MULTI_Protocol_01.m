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
% Description:   Script multi-patients.
%                Traite uniquement les patients/côtés listés dans
%                userCommands_Multi.m (voir ce fichier pour la config), par
%                paquets de BatchSize patients traités en parallèle (parfor,
%                un patient par worker) ; appelle runProtocol01() pour
%                chaque session PRE/POST, et exporte PatientInfos +
%                DataAvailability en Excel. Si SaveDatabase=true, sauvegarde
%                aussi Trial (sans .btk) + Patient/Session/Pathology de
%                chaque patient, réparti sur NumDatabaseParts fichiers .mat
%                indépendants 
%
%                BatchSize est aligné sur NumDatabaseParts (voir
%                userCommands_Multi.m : BatchSize = ceil(nPatients/NumDatabaseParts))
%                de sorte qu'un PAQUET = une PARTIE exactement. Chaque
%                partie est écrite en UNE SEULE FOIS (save() en bloc,
%                -nocompression) une fois tous ses patients traités, plutôt
%                qu'en écritures partielles indexées au fil des paquets
%                (mesuré ~25x plus lent : les écritures partielles dans un
%                struct array imbriqué stocké en -v7.3/HDF5 ont un coût fixe
%                élevé par appel, indépendant du volume réel écrit - la
%                compression n'est PAS en cause, désactiver la compression
%                seule sur l'ancien schéma n'apporte quasiment rien).
%
%                Fonctions propres au pipeline multi (Compute*/Export*/Plot*)
%                rangées dans Multi/Core, Multi/IO, Multi/Plot, séparées des
%                dossiers Core/IO/Plot partagés avec le protocole solo, que
%                seul runProtocol01() ajoute encore au path (il en a besoin
%                pour le calcul cinématique commun aux deux pipelines).
%
%                Pour ajouter un nouvel export calculé depuis Trial :
%                  - Analyse à faire pendant le run C3D (dépend d'un état
%                    live, ex: c3dFiles) : l'ajouter ici, comme
%                    ComputeDataAvailability/ComputePatientInfos.
%                  - Analyse sur des valeurs déjà calculées (Segment/Joint/
%                    Euler...) : en faire une fonction Multi/Core/ComputeXxxFromDatabase.m
%                    (voir ComputeClinicalContributionsFromDatabase.m comme
%                    modèle), pour bénéficier du calcul instantané depuis le .mat.
% -------------------------------------------------------------------------

clearvars; close all; warning off; clc;
disp('Pipeline multi-patients');
ticTotal = tic;

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
Folder.toolbox = fileparts(fileparts(mfilename('fullpath')));
Folder.deps    = fullfile(fileparts(Folder.toolbox), 'dependencies');
addpath(fullfile(Folder.toolbox, 'Multi'));
addpath(fullfile(Folder.toolbox, 'Multi', 'Core'));
addpath(fullfile(Folder.toolbox, 'Multi', 'IO'));
addpath(fullfile(Folder.toolbox, 'Multi', 'RedCap'));
addpath(fullfile(Folder.toolbox, 'Multi', 'Results'));

run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m'));

if isempty(DataFolder)
    DataFolder = uigetdir('', 'Sélectionner le dossier Data');
    if isequal(DataFolder, 0), disp('Annulé.'); return; end
end

% Raccourcit DataFolder via un lecteur virtuel (subst)
shortDrive = 'S:';
DataFolder = EnsureShortDataPath(DataFolder, shortDrive);

% Transmis à runProtocol01 via Folder
Folder.skipKinematics = SkipKinematics;

disp(['Patients à traiter : ', num2str(size(PatientSelection, 1))]);

% -------------------------------------------------------------------------
% BOUCLE PATIENTS / SESSIONS
% -------------------------------------------------------------------------
% Infos démographiques/cliniques
nPatientRows = size(PatientSelection, 1);
PatientInfos = newPatientInfosStruct(nPatientRows);

ErrorLogPerPatient  = cell(nPatientRows, 1);
DataAvailPerPatient = cell(nPatientRows, 1);

nBatches = ceil(nPatientRows / BatchSize);

% Base de données patient complète
PartDone = false(nBatches, 1);
if SaveDatabase
    if SkipKinematics
        warning(['SaveDatabase=true mais SkipKinematics=true : Trial.Segment/.Joint ', ...
            'seront vides dans PatientDatabase.mat (calcul cinematique saute).']);
    end

    [dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
    ProgressFile = strrep(DatabaseFile, '.mat', '_progress.mat');
    if isfile(ProgressFile)
        try
            prog    = load(ProgressFile, 'PartDone', 'PatientInfos', 'DataAvailPerPatient');
            nCommon = min(nPatientRows, numel(prog.PatientInfos));
            nPCommon = min(nBatches, numel(prog.PartDone));
            PartDone(1:nPCommon)            = prog.PartDone(1:nPCommon);
            PatientInfos(1:nCommon)         = prog.PatientInfos(1:nCommon);
            DataAvailPerPatient(1:nCommon)  = prog.DataAvailPerPatient(1:nCommon);
            disp(['Reprise : ', num2str(sum(PartDone)), '/', num2str(nBatches), ...
                  ' parties déjà traitées (', ProgressFile, '), non retraitées.']);
            clear prog
        catch
            warning(['Fichier de progression incompatible (ancien format par patient) - ', ...
                'ignoré, reprise depuis zéro : ', ProgressFile]);
        end
    end
end

dataDirList = dir(DataFolder);
dataDirList = dataDirList([dataDirList.isdir] & ~startsWith({dataDirList.name}, '.'));

% Fenêtre de progression, mise à jour en direct pendant le run
batchSizes = arrayfun(@(p) numel((p-1)*BatchSize+1 : min(p*BatchSize, nPatientRows)), (1:nBatches)');
nDoneAlready = sum(batchSizes(PartDone));
hWait = waitbar(nDoneAlready / max(nPatientRows,1), ...
    sprintf('%d/%d patients traités', nDoneAlready, nPatientRows), ...
    'Name', 'Pipeline multi-patients');
hWait.UserData = nDoneAlready;
progressQueue = parallel.pool.DataQueue;
afterEach(progressQueue, @(~) updateProgressWaitbar(hWait, nPatientRows));

% Redémarrage périodique du pool de workers parfor
PoolRestartEveryNBatches = 2;

for iBatch = 1:nBatches
    batchIdx       = (iBatch-1)*BatchSize + 1 : min(iBatch*BatchSize, nPatientRows);
    nBatchPatients = numel(batchIdx);

    if SaveDatabase && PartDone(iBatch)
        disp(' ');
        disp(['=== Paquet ', num2str(iBatch), '/', num2str(nBatches), ' : déjà traité (reprise), ignoré ===']);
        continue;
    end

    if mod(iBatch - 1, PoolRestartEveryNBatches) == 0
        disp('  (redémarrage du pool de workers)');
        delete(gcp('nocreate'));
        % Taille du pool forcée à BatchSize
        parpool(BatchSize);
    end

    disp(' ');
    disp(['=== Paquet ', num2str(iBatch), '/', num2str(nBatches), ...
          ' (patients ', num2str(batchIdx(1)), '-', num2str(batchIdx(end)), ') ===']);

    % Accumulateurs propres à ce paquet uniquement
    BatchPatientInfos  = newPatientInfosStruct(nBatchPatients);
    BatchErrorLog      = cell(nBatchPatients, 1);
    BatchDataAvail     = cell(nBatchPatients, 1);
    if SaveDatabase
        BatchDatabase = newDatabaseStruct(nBatchPatients);
    end

    ticBatchProcessing = tic;
    parfor k = 1:nBatchPatients
        iP = batchIdx(k);
        warning off;
        localErrors = {};
        localAvail  = struct([]);

        % Dossier patient
        patientID     = num2str(PatientSelection{iP, 1});
        sidesToReport = parseSides(PatientSelection{iP, 2});

        matchIdx = find(contains({dataDirList.name}, patientID));
        if isempty(matchIdx)
            warning('Dossier introuvable pour l''ID %s', patientID);
            localErrors{end+1} = sprintf('%s | dossier introuvable', patientID); %#ok<AGROW>
            BatchErrorLog{k} = localErrors;
            send(progressQueue, 1);
            continue;
        end
        patientName   = dataDirList(matchIdx(1)).name;
        patientFolder = fullfile(DataFolder, patientName);

        sessions = struct( ...
            'PRE',  findSessionFolder(patientFolder, PatientSelection{iP, 3}), ...
            'POST', findSessionFolder(patientFolder, PatientSelection{iP, 4}));
        numeroWrittenForThisRow = false;

        conditions = fieldnames(sessions);
        for iC = 1:length(conditions)
            condition   = conditions{iC};
            sessionPath = sessions.(condition);
            if isempty(sessionPath)
                warning('Session %s introuvable pour %s (%s)', condition, patientID, num2str(PatientSelection{iP, 2 + iC}));
                localErrors{end+1} = sprintf('%s | %s | session introuvable', patientID, condition); %#ok<AGROW>
                continue;
            end

            disp(' ');
            disp(['--- ', patientName, ' — ', condition, ' (', strjoin(sidesToReport, '/'), ') ---']);

            try
                FolderLocal      = Folder;
                FolderLocal.data = sessionPath;
                [Trial, Patient, Session, Pathology, c3dFiles] = runProtocol01(FolderLocal);

                if SaveDatabase
                    BatchDatabase(k).Numero    = iP;
                    BatchDatabase(k).PatientID = patientID;
                    BatchDatabase(k).Side      = sidesToReport;
                    BatchDatabase(k).(condition).Trial     = StripBtkFromTrial(FilterTrialForDatabase(Trial));
                    BatchDatabase(k).(condition).Patient   = Patient;
                    BatchDatabase(k).(condition).Session   = Session;
                    BatchDatabase(k).(condition).Pathology = Pathology;
                    BatchDatabase(k).(condition).Date      = sessionPath;
                end

                [~, sessionFolderName] = fileparts(sessionPath);
                examDate = [];
                dateDigits = regexp(sessionFolderName, '^\d{8}', 'match', 'once');
                if ~isempty(dateDigits)
                    try
                        examDate = datetime(dateDigits, 'InputFormat', 'yyyyMMdd');
                    catch
                        examDate = [];
                    end
                end

                info = ComputePatientInfos(Patient, Session, Pathology, examDate);

                if isempty(BatchPatientInfos(k).PatientID)
                    BatchPatientInfos(k).PatientID  = patientID;
                    BatchPatientInfos(k).ID         = info.ID;
                    BatchPatientInfos(k).Gender     = info.Gender;
                    BatchPatientInfos(k).Laterality = info.Laterality;
                    BatchPatientInfos(k).ASA        = info.ASA;
                    BatchPatientInfos(k).Diagnostic      = info.Diagnostic;
                    BatchPatientInfos(k).PreviousSurgery = info.PreviousSurgery;
                    BatchPatientInfos(k).Age_PRE    = NaN; BatchPatientInfos(k).Age_POST    = NaN;
                    BatchPatientInfos(k).Height_PRE = NaN; BatchPatientInfos(k).Height_POST = NaN;
                    BatchPatientInfos(k).Mass_PRE   = NaN; BatchPatientInfos(k).Mass_POST   = NaN;
                    BatchPatientInfos(k).BMI_PRE    = NaN; BatchPatientInfos(k).BMI_POST    = NaN;
                    BatchPatientInfos(k).EVA_PRE    = '';  BatchPatientInfos(k).EVA_POST    = '';
                    BatchPatientInfos(k).EVA_PRE_fallback  = false;
                    BatchPatientInfos(k).EVA_POST_fallback = false;
                end

                BatchPatientInfos(k).(['EVA_', condition])             = info.EVA_formula;
                BatchPatientInfos(k).(['EVA_', condition, '_fallback']) = info.EVA_fallback;
                BatchPatientInfos(k).(['Age_', condition])    = info.Age;
                BatchPatientInfos(k).(['Height_', condition]) = info.Height;
                BatchPatientInfos(k).(['Mass_', condition])   = info.Mass;
                BatchPatientInfos(k).(['BMI_', condition])    = info.BMI;

                % Rapport de disponibilité des données
                avail = ComputeDataAvailability(Trial, Patient, Session, Pathology, c3dFiles, sidesToReport);
                avail.Numero   = '';
                avail.ID       = '';
                avail.IDRedCap = '';
                if ~numeroWrittenForThisRow
                    avail.Numero = iP;
                    avail.ID     = patientID;
                    numeroWrittenForThisRow = true;
                end
                avail.Examen = [upper(condition(1)), lower(condition(2:end))]; % 'Pre'/'Post'
                avail.Date   = PatientSelection{iP, 2 + iC};
                if isempty(localAvail)
                    localAvail = avail;
                else
                    localAvail(end+1) = avail; %#ok<AGROW>
                end

                disp('  -> OK');

            catch ME
                if ~isempty(ME.stack)
                    origin = sprintf('%s (ligne %d)', ME.stack(1).name, ME.stack(1).line);
                else
                    origin = 'origine inconnue';
                end
                warning('  ERREUR %s %s : %s [%s]', patientName, condition, ME.message, origin);
                localErrors{end+1} = sprintf('%s | %s | %s [%s]', patientName, condition, ME.message, origin); %#ok<AGROW>
            end
        end

        BatchErrorLog{k}  = localErrors;
        BatchDataAvail{k} = localAvail;
        send(progressQueue, 1);
    end
    tProcessing = toc(ticBatchProcessing);
    disp(['  Temps traitement (paquet) : ', num2str(tProcessing, '%.1f'), ' s']);

    PatientInfos(batchIdx)        = BatchPatientInfos;
    ErrorLogPerPatient(batchIdx)  = BatchErrorLog;
    DataAvailPerPatient(batchIdx) = BatchDataAvail;

    if SaveDatabase
        ticBatchSave = tic;
        Database = BatchDatabase; %#ok<NASGU>
        partFile = fullfile(dbFolder, sprintf('%s_part%dof%d%s', dbName, iBatch, nBatches, dbExt));
        save(partFile, 'Database', '-v7.3', '-nocompression');
        clear Database BatchDatabase

        PartDone(iBatch) = true;
        save(ProgressFile, 'PartDone', 'PatientInfos', 'DataAvailPerPatient');
        tSave = toc(ticBatchSave);
        disp(['  Temps sauvegarde (partie) : ', num2str(tSave, '%.1f'), ' s']);
    end
end

if isvalid(hWait)
    close(hWait);
end

ErrorLog  = [ErrorLogPerPatient{:}];
DataAvail = [DataAvailPerPatient{~cellfun(@isempty, DataAvailPerPatient)}];

if ~isempty(ErrorLog)
    disp(' ');
    disp('=== Patients avec erreurs ===');
    for i = 1:length(ErrorLog)
        disp(['  ', ErrorLog{i}]);
    end
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
ExportPatientInfos(PatientInfos, PatientInfosFile);
ExportDataAvailability(DataAvail, DataAvailabilityFile);

tTotal = toc(ticTotal);
disp(' ');
disp(['Temps total du run : ', num2str(tTotal, '%.1f'), ' s (', num2str(tTotal/60, '%.1f'), ' min)']);

if isfolder(ResultsFolder)
    cd(ResultsFolder);
end

if ispc
    system(sprintf('subst %s /d', shortDrive));
end

% =========================================================================
%  UTILITAIRES
% =========================================================================

function updateProgressWaitbar(hWait, total)
if ~isvalid(hWait)
    return;
end
n = hWait.UserData + 1;
hWait.UserData = n;
waitbar(min(n / max(total,1), 1), hWait, sprintf('%d/%d patients traités', n, total));
end

function s = newPatientInfosStruct(n)
s = struct('PatientID', {}, 'ID', {}, 'Gender', {}, 'Laterality', {}, 'ASA', {}, ...
    'Age_PRE', {}, 'Age_POST', {}, 'Height_PRE', {}, 'Height_POST', {}, ...
    'Mass_PRE', {}, 'Mass_POST', {}, 'BMI_PRE', {}, 'BMI_POST', {}, ...
    'EVA_PRE', {}, 'EVA_POST', {}, 'EVA_PRE_fallback', {}, 'EVA_POST_fallback', {}, ...
    'Diagnostic', {}, 'PreviousSurgery', {});
if n > 0
    s(n).PatientID = [];
end
end

function s = newDatabaseStruct(n)
s = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'PRE', {}, 'POST', {});
if n > 0
    s(n).Numero = [];
end
end

function sessionPath = findSessionFolder(patientFolder, dateOrYear)
sessionPath = '';
key = strtrim(num2str(dateOrYear));
if isempty(key), return; end

sessionList = dir(patientFolder);
sessionList = sessionList([sessionList.isdir] & ~startsWith({sessionList.name}, '.'));
matchIdx    = find(startsWith({sessionList.name}, key));
if isempty(matchIdx), return; end
if length(matchIdx) > 1
    warning('Plusieurs sessions correspondent à "%s" dans %s : ambigu, la première est utilisée', key, patientFolder);
end
sessionPath = fullfile(patientFolder, sessionList(matchIdx(1)).name);
end

function sides = parseSides(sideCode)
if isnumeric(sideCode)
    if sideCode == 1
        sideCode = 'L';
    elseif sideCode == 0
        sideCode = 'R';
    else
        error('Côté invalide : %g (attendu 0, 1, R, L ou RL)', sideCode);
    end
end
switch upper(strtrim(sideCode))
    case 'R',  sides = {'R'};
    case 'L',  sides = {'L'};
    case 'RL', sides = {'R', 'L'};
    otherwise
        error('Côté invalide : "%s" (attendu R, L ou RL)', sideCode);
end
end


%% ========================================================================
%  Results extraction from.mat
Folder.toolbox = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(Folder.toolbox, 'Multi'));
addpath(fullfile(Folder.toolbox, 'Multi', 'Core'));
addpath(fullfile(Folder.toolbox, 'Multi', 'IO'));
run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m')); % DatabaseFile, OutputFile, ResultsFolder

%%
ComputeClinicalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder);

%%
ComputeContralateralEligibilityFromDatabase(DatabaseFile, ContralateralEligibilityFile, ResultsFolder);
