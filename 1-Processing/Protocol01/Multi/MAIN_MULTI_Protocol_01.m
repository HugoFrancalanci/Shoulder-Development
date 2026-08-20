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
%                indépendants (voir userCommands_Multi.m - DatabaseFile sert
%                de nom de base, ex: Database_182..._part1of4.mat), écrits
%                sur disque paquet par paquet (matfile, écriture partielle)
%                plutôt que tout accumulé en RAM sur les 182 patients : un
%                patient (PRE+POST) pèse au moins ~40 Mo compressé (après
%                filtrage, voir FilterTrialForDatabase.m), largement plus une
%                fois décompressé en mémoire. Plusieurs fichiers plutôt qu'un
%                seul limitent aussi les dégâts si l'un se corrompt. Reprise
%                automatique : si le script a été interrompu (plantage,
%                fermeture) lors d'un run précédent, les patients déjà écrits
%                ne sont pas retraités au prochain lancement (statut suivi
%                dans PatientDatabase_progress.mat).
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

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
MainFolder     = 'C:\Users\franc\Desktop\Programming\01_Projects\E02_Classification_rTSA';
Folder.toolbox = [MainFolder, '\Shoulder_Dev\1-Processing\Protocol01'];
Folder.deps    = [MainFolder, '\Shoulder_Dev\1-Processing\dependencies'];
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

% Base de données patient complète : répartie sur NumDatabaseParts
% fichiers .mat indépendants (voir userCommands_Multi.m)

Done = false(nPatientRows, 1);
if SaveDatabase
    if SkipKinematics
        warning(['SaveDatabase=true mais SkipKinematics=true : Trial.Segment/.Joint ', ...
            'seront vides dans PatientDatabase.mat (calcul cinematique saute).']);
    end

    ProgressFile = strrep(DatabaseFile, '.mat', '_progress.mat');
    if isfile(ProgressFile)
        prog    = load(ProgressFile, 'Done', 'PatientInfos', 'DataAvailPerPatient');
        nCommon = min(nPatientRows, numel(prog.Done));
        Done(1:nCommon)                = prog.Done(1:nCommon);
        PatientInfos(1:nCommon)        = prog.PatientInfos(1:nCommon);
        DataAvailPerPatient(1:nCommon) = prog.DataAvailPerPatient(1:nCommon);
        disp(['Reprise : ', num2str(sum(Done)), '/', num2str(nPatientRows), ...
              ' patients déjà traités (', ProgressFile, '), non retraités.']);
        clear prog
    end

    [dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
    partSize   = ceil(nPatientRows / NumDatabaseParts);
    partBounds = zeros(NumDatabaseParts, 2);
    dbFiles    = cell(NumDatabaseParts, 1);
    for p = 1:NumDatabaseParts
        partBounds(p, 1) = (p-1)*partSize + 1;
        partBounds(p, 2) = min(p*partSize, nPatientRows);
        nInPart          = partBounds(p, 2) - partBounds(p, 1) + 1;
        if nInPart <= 0
            continue; % NumDatabaseParts > nPatientRows : cette partie est vide
        end
        partFile = fullfile(dbFolder, sprintf('%s_part%dof%d%s', dbName, p, NumDatabaseParts, dbExt));
        if isfile(partFile)
            dbFiles{p}   = matfile(partFile, 'Writable', true);
            existingSize = size(dbFiles{p}, 'Database');
            if existingSize(2) < nInPart
                dbFiles{p}.Database(1, nInPart) = newDatabaseStruct(1);
            end
        else
            Database = newDatabaseStruct(nInPart);
            save(partFile, 'Database', '-v7.3');
            clear Database
            dbFiles{p} = matfile(partFile, 'Writable', true);
        end
    end
end

dataDirList = dir(DataFolder);
dataDirList = dataDirList([dataDirList.isdir] & ~startsWith({dataDirList.name}, '.'));

% Fenêtre de progression, mise à jour en direct pendant le run
hWait = waitbar(sum(Done) / max(nPatientRows,1), ...
    sprintf('%d/%d patients traités', sum(Done), nPatientRows), ...
    'Name', 'Pipeline multi-patients');
hWait.UserData = sum(Done);
progressQueue = parallel.pool.DataQueue;
afterEach(progressQueue, @(~) updateProgressWaitbar(hWait, nPatientRows));

nBatches = ceil(nPatientRows / BatchSize);
for iBatch = 1:nBatches
    batchIdx       = (iBatch-1)*BatchSize + 1 : min(iBatch*BatchSize, nPatientRows);
    nBatchPatients = numel(batchIdx);

    disp(' ');
    disp(['=== Paquet ', num2str(iBatch), '/', num2str(nBatches), ...
          ' (patients ', num2str(batchIdx(1)), '-', num2str(batchIdx(end)), ') ===']);

    % Accumulateurs propres à ce paquet uniquement (vidés de la RAM après
    % écriture sur disque, voir fin de boucle)
    BatchPatientInfos  = newPatientInfosStruct(nBatchPatients);
    BatchErrorLog      = cell(nBatchPatients, 1);
    BatchDataAvail     = cell(nBatchPatients, 1);
    if SaveDatabase
        BatchDatabase = newDatabaseStruct(nBatchPatients);
    end

    parfor k = 1:nBatchPatients
        iP = batchIdx(k);
        if Done(iP)
            continue; % déjà traité lors d'un run précédent (reprise)
        end
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

        % Sessions PRE/POST : dossier "YYYYMMDD". Construit en une seule
        % assignation (pas en deux lignes sessions.PRE=.../sessions.POST=...) :
        % parfor a besoin de voir "sessions" pleinement défini d'un coup pour
        % le classer comme variable temporaire propre à chaque itération.
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
                % Copie locale : Folder est une broadcast variable (lue par
                % tous les workers)
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
                warning('  ERREUR %s %s : %s', patientName, condition, ME.message);
                localErrors{end+1} = sprintf('%s | %s | %s', patientName, condition, ME.message); %#ok<AGROW>
            end
        end

        BatchErrorLog{k}  = localErrors;
        BatchDataAvail{k} = localAvail;
        send(progressQueue, 1);
    end

    attemptedMask = reshape(~Done(batchIdx), 1, []);
    PatientInfos(batchIdx(attemptedMask))        = BatchPatientInfos(attemptedMask);
    ErrorLogPerPatient(batchIdx(attemptedMask))  = BatchErrorLog(attemptedMask);
    DataAvailPerPatient(batchIdx(attemptedMask)) = BatchDataAvail(attemptedMask);

    if SaveDatabase
        hasNumero     = arrayfun(@(s) ~isempty(s.Numero), BatchDatabase);
        successMask   = attemptedMask & hasNumero;
        if any(successMask)
            successIdx  = batchIdx(successMask);   % numeros globaux de patient
            successData = BatchDatabase(successMask);
            for p = 1:NumDatabaseParts
                inPart = successIdx >= partBounds(p,1) & successIdx <= partBounds(p,2);
                if any(inPart)
                    localIdx = successIdx(inPart) - partBounds(p,1) + 1;
                    writeContiguousRuns(dbFiles{p}, localIdx, successData(inPart));
                end
            end
            Done(successIdx) = true;
        end
        clear BatchDatabase

        save(ProgressFile, 'Done', 'PatientInfos', 'DataAvailPerPatient');
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

if isfolder(ResultsFolder)
    cd(ResultsFolder);
end

if ispc
    system(sprintf('subst %s /d', shortDrive));
end

% =========================================================================
%  UTILITAIRES
% =========================================================================

function writeContiguousRuns(dbFileObj, localIdx, data)
n = numel(localIdx);
i = 1;
while i <= n
    j = i;
    while j < n && localIdx(j+1) == localIdx(j) + 1
        j = j + 1;
    end
    dbFileObj.Database(1, localIdx(i):localIdx(j)) = data(i:j);
    i = j + 1;
end
end

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
MainFolder     = 'C:\Users\franc\Desktop\Programming\01_Projects\E02_Classification_rTSA';
Folder.toolbox = [MainFolder, '\Shoulder_Dev\1-Processing\Protocol01'];
addpath(fullfile(Folder.toolbox, 'Multi'));
addpath(fullfile(Folder.toolbox, 'Multi', 'Core'));
addpath(fullfile(Folder.toolbox, 'Multi', 'IO'));
run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m')); % DatabaseFile, OutputFile, ResultsFolder

ComputeClinicalContributionsFromDatabase(DatabaseFile, OutputFile, ResultsFolder);
