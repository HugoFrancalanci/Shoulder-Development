% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Script maître multi-patients.
%                Traite uniquement les patients/côtés listés dans
%                userCommands_Multi.m (voir ce fichier pour la config),
%                appelle runProtocol01() pour chaque session PRE/POST, et
%                exporte le rapport humérothoracique (contributions
%                GH/ST/TX) dans un fichier Excel.
%
%                Fonctions propres au pipeline multi (Compute*/Export*/Plot*)
%                rangées dans Multi/Core, Multi/IO, Multi/Plot - séparées des
%                dossiers Core/IO/Plot partagés avec le protocole solo, que
%                seul runProtocol01() ajoute encore au path (il en a besoin
%                pour le calcul cinématique commun aux deux pipelines).
%
%                Pour ajouter un nouvel export :
%                  1. Créer une fonction ComputeMaMetrique(Trial) dans Multi/Core/
%                     (voir Multi/Core/ComputeHTContributions.m comme modèle)
%                  2. L'appeler dans la boucle patients ci-dessous
%                  3. Ajouter les colonnes correspondantes aux "rows"
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
addpath(fullfile(Folder.toolbox, 'Multi', 'Plot'));

run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m')); % DataFolder, PatientSelection, OutputFile

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
% Numero = ligne de PatientSelection (iP) qui a produit cette entrée - la
% recherche d'une entrée existante se fait sur (Numero, Side), pas sur
% (PatientID, Side) : un ID Cinésiologie répété sur 2 lignes de
% PatientSelection (patient bilatéral avec 2 opérations du MÊME côté à des
% dates différentes - cas rare mais possible, différent des 5 patients
% bilatéraux actuels qui ont chacun un côté différent par ligne) serait
% sinon fusionné à tort sur la même ligne, comme on l'a eu pour
% PatientInfos/DataAvailability avant leur fix.
Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'HT_PRE_deg', {}, 'GH_PRE_deg', {}, 'GH_PRE_pct', {}, ...
    'ST_PRE_deg', {}, 'ST_PRE_pct', {}, 'TX_PRE_deg', {}, 'TX_PRE_pct', {}, ...
    'HT_POST_deg', {}, 'GH_POST_deg', {}, 'GH_POST_pct', {}, ...
    'ST_POST_deg', {}, 'ST_POST_pct', {}, 'TX_POST_deg', {}, 'TX_POST_pct', {});

% Courbes angle vs % cycle
Curves = struct('Numero', {}, 'PatientID', {}, 'Side', {}, ...
    'HT_PRE', {}, 'HT_POST', {}, 'GH_PRE', {}, 'GH_POST', {}, 'ST_PRE', {}, 'ST_POST', {});

% Infos démographiques/cliniques
% Une ligne par ligne de PatientSelection (indexée directement par iP, pas
% par recherche d'ID) : les patients bilatéraux ont le même ID Cinésiologie
% sur 2 lignes de PatientSelection (côté/dates différents) - indexer par
% recherche d'ID les aurait fusionnés à tort sur une seule ligne. Pré-alloué
% à la taille de PatientSelection pour garder exactement l'ordre établi,
% même si un patient échoue entièrement (PRE et POST introuvables/erreur).
nPatientRows = size(PatientSelection, 1);
PatientInfos = struct('PatientID', {}, 'ID', {}, 'Gender', {}, 'Laterality', {}, 'ASA', {}, ...
    'Age_PRE', {}, 'Age_POST', {}, 'Height_PRE', {}, 'Height_POST', {}, ...
    'Mass_PRE', {}, 'Mass_POST', {}, 'BMI_PRE', {}, 'BMI_POST', {}, ...
    'EVA_PRE', {}, 'EVA_POST', {}, 'EVA_PRE_fallback', {}, 'EVA_POST_fallback', {}, ...
    'Diagnostic', {}, 'PreviousSurgery', {});
PatientInfos(nPatientRows).PatientID = [];

% Rapport de disponibilité des données (une ligne par examen PRE/POST)
DataAvail = struct([]);

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

    % Numéro/ID de CETTE ligne de PatientSelection (iP) uniquement - remis
    % à false à chaque iP, pour ne pas confondre avec une ligne antérieure
    % du même ID Cinésiologie (patients bilatéraux, même ID sur 2 lignes
    % de PatientSelection avec côté/dates différents).
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

            if ~SkipKinematics
                Contrib = ComputeHTContributions(Trial);

                for iS = 1:length(Contrib)
                    c = Contrib(iS);
                    if ~ismember(c.side, sidesToReport), continue; end

                    ri = find([Results.Numero] == iP & strcmp({Results.Side}, c.side), 1);
                    if isempty(ri)
                        ri = length(Results) + 1;
                        Results(ri).Numero       = iP;
                        Results(ri).PatientID    = patientID;
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
                        Curves(ri).Numero    = iP;
                        Curves(ri).PatientID = patientID;
                        Curves(ri).Side      = c.side;
                    end
                    Curves(ri).(['HT_', condition]) = c.HT_curve;
                    Curves(ri).(['GH_', condition]) = c.GH_curve;
                    Curves(ri).(['ST_', condition]) = c.ST_curve;
                end
            end

            % Rapport de disponibilité des données (une ligne par examen)
            avail = ComputeDataAvailability(Trial, Patient, Session, Pathology, c3dFiles, sidesToReport);
            di = length(DataAvail) + 1;
            % Numéro/ID sur la 1re ligne de CETTE ligne de PatientSelection
            % (PRE normalement, mais POST si la session PRE a échoué/est
            % introuvable) - basé sur numeroWrittenForThisRow (propre à cet
            % iP), pas une recherche d'ID sur tout DataAvail : un ID
            % Cinésiologie répété sur une AUTRE ligne (patient bilatéral)
            % ne doit pas empêcher celle-ci d'avoir son propre Numéro/ID.
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
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if ~isempty(Results)
    T = struct2table(Results);
    % writetable never clears a pre-existing sheet, only overwrites the
    % range it writes to - a previous run with more rows would leave stale
    % data behind. Delete first for a fully fresh sheet.
    if isfile(OutputFile), delete(OutputFile); end
    writetable(T, OutputFile, 'Sheet', 'HT_Contributions');
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
else
    disp(' ');
    disp('Aucune donnée à exporter.');
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
PlotHTContributionsCurves(Curves);

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
