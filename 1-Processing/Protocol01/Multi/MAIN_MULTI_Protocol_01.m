% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Script maître multi-patients.
%                Traite uniquement les patients/côtés listés dans
%                userCommands_Multi.m (voir ce fichier pour la config),
%                appelle runProtocol01() pour chaque session PRE/POST, et
%                exporte PatientInfos + DataAvailability en Excel. Si

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
PatientInfos = struct('PatientID', {}, 'ID', {}, 'Gender', {}, 'Laterality', {}, 'ASA', {}, ...
    'Age_PRE', {}, 'Age_POST', {}, 'Height_PRE', {}, 'Height_POST', {}, ...
    'Mass_PRE', {}, 'Mass_POST', {}, 'BMI_PRE', {}, 'BMI_POST', {}, ...
    'EVA_PRE', {}, 'EVA_POST', {}, 'EVA_PRE_fallback', {}, 'EVA_POST_fallback', {}, ...
    'Diagnostic', {}, 'PreviousSurgery', {});
PatientInfos(nPatientRows).PatientID = [];

% Rapport de disponibilité des données (une ligne par examen PRE/POST)
DataAvail = struct([]);

% Base de données patient complète
if SaveDatabase
    if SkipKinematics
        warning(['SaveDatabase=true mais SkipKinematics=true : Trial.Segment/.Joint ', ...
            'seront vides dans PatientDatabase.mat (calcul cinematique saute).']);
    end
    Database = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'PRE', {}, 'POST', {});
    Database(nPatientRows).Numero = [];
end

ErrorLog = {};

dataDirList = dir(DataFolder);
dataDirList = dataDirList([dataDirList.isdir] & ~startsWith({dataDirList.name}, '.'));

for iP = 1:size(PatientSelection, 1)

    % Dossier patient 
    patientID     = num2str(PatientSelection{iP, 1});
    sidesToReport = parseSides(PatientSelection{iP, 2});

    matchIdx = find(contains({dataDirList.name}, patientID));
    if isempty(matchIdx)
        warning('Dossier introuvable pour l''ID %s', patientID);
        ErrorLog{end+1} = sprintf('%s | dossier introuvable', patientID); %#ok<AGROW>
        continue;
    end
    patientName   = dataDirList(matchIdx(1)).name;
    patientFolder = fullfile(DataFolder, patientName);

    % Sessions PRE/POST : dossier "YYYYMMDD"
    sessions.PRE  = findSessionFolder(patientFolder, PatientSelection{iP, 3});
    sessions.POST = findSessionFolder(patientFolder, PatientSelection{iP, 4});
    numeroWrittenForThisRow = false;

    conditions = fieldnames(sessions);
    for iC = 1:length(conditions)
        condition   = conditions{iC};
        sessionPath = sessions.(condition);
        if isempty(sessionPath)
            warning('Session %s introuvable pour %s (%s)', condition, patientID, num2str(PatientSelection{iP, 2 + iC}));
            ErrorLog{end+1} = sprintf('%s | %s | session introuvable', patientID, condition); %#ok<AGROW>
            continue;
        end

        disp(' ');
        disp(['--- ', patientName, ' — ', condition, ' (', strjoin(sidesToReport, '/'), ') ---']);

        try
            Folder.data = sessionPath;
            [Trial, Patient, Session, Pathology, c3dFiles] = runProtocol01(Folder);

            if SaveDatabase
                Database(iP).Numero    = iP;
                Database(iP).PatientID = patientID;
                Database(iP).Side      = sidesToReport;
                Database(iP).(condition).Trial     = StripBtkFromTrial(Trial);
                Database(iP).(condition).Patient   = Patient;
                Database(iP).(condition).Session   = Session;
                Database(iP).(condition).Pathology = Pathology;
                Database(iP).(condition).Date      = sessionPath;
            end

            % Age uses the session FOLDER NAME date (e.g. '20241217') rather
            % than Session.date (free-text cell in Session.xlsx, manually
            % typed and occasionally wrong/stale) - the folder name is
            % already trusted to locate this exact session on disk.
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

            % Indexé par iP (pas par ID) : voir commentaire à la
            % déclaration de PatientInfos plus haut.
            pi_idx = iP;
            if isempty(PatientInfos(pi_idx).PatientID)
                PatientInfos(pi_idx).PatientID  = patientID;
                PatientInfos(pi_idx).ID         = info.ID;
                PatientInfos(pi_idx).Gender     = info.Gender;
                PatientInfos(pi_idx).Laterality = info.Laterality;
                PatientInfos(pi_idx).ASA        = info.ASA;
                PatientInfos(pi_idx).Diagnostic      = info.Diagnostic;
                PatientInfos(pi_idx).PreviousSurgery = info.PreviousSurgery;
                PatientInfos(pi_idx).Age_PRE    = NaN; PatientInfos(pi_idx).Age_POST    = NaN;
                PatientInfos(pi_idx).Height_PRE = NaN; PatientInfos(pi_idx).Height_POST = NaN;
                PatientInfos(pi_idx).Mass_PRE   = NaN; PatientInfos(pi_idx).Mass_POST   = NaN;
                PatientInfos(pi_idx).BMI_PRE    = NaN; PatientInfos(pi_idx).BMI_POST    = NaN;
                PatientInfos(pi_idx).EVA_PRE    = '';  PatientInfos(pi_idx).EVA_POST    = '';
                PatientInfos(pi_idx).EVA_PRE_fallback  = false;
                PatientInfos(pi_idx).EVA_POST_fallback = false;
            end

            PatientInfos(pi_idx).(['EVA_', condition])             = info.EVA_formula;
            PatientInfos(pi_idx).(['EVA_', condition, '_fallback']) = info.EVA_fallback;
            PatientInfos(pi_idx).(['Age_', condition])    = info.Age;
            PatientInfos(pi_idx).(['Height_', condition]) = info.Height;
            PatientInfos(pi_idx).(['Mass_', condition])   = info.Mass;
            PatientInfos(pi_idx).(['BMI_', condition])    = info.BMI;

            % Contributions cliniques HT/GH/ST/TX : plus calculées ici. Voir
            % Multi/Core/ComputeClinicalContributionsFromDatabase.m (section
            % dédiée en bas de ce script), qui refait le même calcul mais
            % depuis PatientDatabase.mat - en quelques secondes sur toute la
            % cohorte, sans repasser par les C3D.

            % Rapport de disponibilité des données (une ligne par examen)
            avail = ComputeDataAvailability(Trial, Patient, Session, Pathology, c3dFiles, sidesToReport);
            di = length(DataAvail) + 1;
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
            if di == 1
                DataAvail = avail;
            else
                DataAvail(di) = avail;
            end

            disp('  -> OK');

        catch ME
            warning('  ERREUR %s %s : %s', patientName, condition, ME.message);
            ErrorLog{end+1} = sprintf('%s | %s | %s', patientName, condition, ME.message); %#ok<AGROW>
        end
    end

    % Sauvegarde apres chaque patient
    if SaveDatabase
        save(DatabaseFile, 'Database', '-v7.3');
    end
end

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
