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
% -------------------------------------------------------------------------

clearvars; close all; warning off; clc;
disp('Pipeline multi-patients');
ticTotal = tic;

% -------------------------------------------------------------------------
% CONFIGURATION
% -------------------------------------------------------------------------
Folder.toolbox = resolveToolboxFolder();
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
isCD8 = strcmp(getenv('COMPUTERNAME'), 'CD-8K18T74');
if isCD8
    % S: déjà pris sur ce PC :
    % première lettre libre à partir de Z:
    shortDrive = findFreeDriveLetter();
end
longDataFolder = DataFolder;
DataFolder = EnsureShortDataPath(DataFolder, shortDrive);
if isCD8 && strcmp(DataFolder, longDataFolder)
    error('MAIN_MULTI_Protocol_01:substFailed', ...
        'subst %s a échoué (voir warning ci-dessus) - arrêt avant traitement, les C3D ne seraient pas lisibles (chemins > 260 caractères).', ...
        shortDrive);
end

% Transmis à runProtocol01 via Folder
Folder.skipKinematics = SkipKinematics;

disp(['Patients à traiter : ', num2str(size(PatientSelection, 1))]);

% -------------------------------------------------------------------------
% BOUCLE PATIENTS / SESSIONS
% -------------------------------------------------------------------------
% Infos démographiques/cliniques
nPatientRows = size(PatientSelection, 1);
% Numéro du registre de chaque ligne (userCommands_Multi.m) ; à défaut, le
% numéro de ligne (cohorte complète dans l'ordre des numéros)
if ~exist('PatientNumbers', 'var') || numel(PatientNumbers) ~= nPatientRows
    PatientNumbers = (1:nPatientRows)';
end
PatientInfos = newPatientInfosStruct(nPatientRows);

ErrorLogPerPatient  = cell(nPatientRows, 1);
DataAvailPerPatient = cell(nPatientRows, 1);

nBatches = ceil(nPatientRows / BatchSize);

% Stockage par projet (userCommands_Multi.m) : valeurs par défaut si absentes
if ~exist('StockageProjet', 'var'), StockageProjet = false; end
if ~exist('CopyInputFiles', 'var'), CopyInputFiles = false; end
RabFallbackPerPatient = cell(nPatientRows, 1); % côtés sans calibration SCoRE (repli sur Rab)
if ~isfolder(ResultsFolder), mkdir(ResultsFolder); end

% Base de données patient complète
PartDone = false(nBatches, 1);
if SaveDatabase
    if SkipKinematics
        warning(['SaveDatabase=true mais SkipKinematics=true : Trial.Segment/.Joint ', ...
            'seront vides dans PatientDatabase.mat (calcul cinematique saute).']);
    end

    if StockageProjet
        % Un .mat par épaule dans ProjectFolder\Patients\, progression dans le projet
        ProgressFile = fullfile(ProjectFolder, 'progress.mat');
        if ~isfolder(DatabaseFile), mkdir(DatabaseFile); end
    else
        [dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
        ProgressFile = strrep(DatabaseFile, '.mat', '_progress.mat');
    end
    if isfile(ProgressFile)
        try
            prog    = load(ProgressFile, 'PartDone', 'PatientInfos', 'DataAvailPerPatient');
            nCommon = min(nPatientRows, numel(prog.PatientInfos));
            nPCommon = min(nBatches, numel(prog.PartDone));
            PartDone(1:nPCommon)            = prog.PartDone(1:nPCommon);
            PatientInfos(1:nCommon)         = prog.PatientInfos(1:nCommon);
            DataAvailPerPatient(1:nCommon)  = prog.DataAvailPerPatient(1:nCommon);
            if ismember('RabFallbackPerPatient', who('-file', ProgressFile))
                prog2 = load(ProgressFile, 'RabFallbackPerPatient');
                RabFallbackPerPatient(1:nCommon) = prog2.RabFallbackPerPatient(1:nCommon);
            end
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
        numero = PatientNumbers(iP); % numéro du registre de l'épaule
        warning off;
        localErrors = {};
        localAvail  = struct([]);

        % Dossier patient
        patientID     = num2str(PatientSelection{iP, 1});
        sidesToReport = parseSides(PatientSelection{iP, 2});

        % Dossier "Nom_Prenom_ID" : l'ID doit terminer le nom
        matchIdx = find(endsWith({dataDirList.name}, ['_' patientID]));
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
                    BatchDatabase(k).Numero    = numero;
                    BatchDatabase(k).PatientID = patientID;
                    BatchDatabase(k).Side      = sidesToReport;
                    BatchDatabase(k).(condition).Trial     = StripBtkFromTrial(FilterTrialForDatabase(Trial));
                    BatchDatabase(k).(condition).Patient   = Patient;
                    BatchDatabase(k).(condition).Session   = Session;
                    BatchDatabase(k).(condition).Pathology = Pathology;
                    BatchDatabase(k).(condition).Date      = sessionPath;
                end
                % Stockage par projet : copie des C3D de Processed\ et de
                % Session.xlsx de la séance, tels qu'ils ont servi au calcul
                if SaveDatabase && CopyInputFiles
                    CopySessionInputs(sessionPath, fullfile(DatabaseFile, ...
                        shoulderFolderName(numero, patientID, sidesToReport), condition));
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

                % Côté de PatientSelection ('L'/'R') : Session.xlsx ne donne
                % qu'un côté par séance, faux pour une séance partagée
                % (post d'une épaule + pré de l'autre, ex. n°163 et n°190)
                info = ComputePatientInfos(Patient, Session, Pathology, examDate, strjoin(sidesToReport, ''));

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
                    avail.Numero = numero;
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
        if StockageProjet
            % Un .mat par épaule (même struct Database, 1x1), écrit en une
            % seule fois comme les parties : Patients\<n°>_<ID>_<côté>\<ID>_<côté>.mat
            for k = 1:nBatchPatients
                Database = BatchDatabase(k);
                if isempty(Database.Numero), continue; end % patient introuvable ou en erreur aux deux séances
                dossierEpaule = fullfile(DatabaseFile, shoulderFolderName(Database.Numero, Database.PatientID, Database.Side));
                if ~isfolder(dossierEpaule), mkdir(dossierEpaule); end
                save(fullfile(dossierEpaule, sprintf('%s_%s.mat', Database.PatientID, strjoin(Database.Side, ''))), ...
                    'Database', '-v7.3', '-nocompression');
                RabFallbackPerPatient{batchIdx(k)} = rabFallbackSides(Database);
            end
        else
            Database = BatchDatabase; %#ok<NASGU>
            partFile = fullfile(dbFolder, sprintf('%s_part%dof%d%s', dbName, iBatch, nBatches, dbExt));
            save(partFile, 'Database', '-v7.3', '-nocompression');
        end
        clear Database BatchDatabase

        PartDone(iBatch) = true;
        save(ProgressFile, 'PartDone', 'PatientInfos', 'DataAvailPerPatient', 'RabFallbackPerPatient');
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

% Stockage par projet : résumé du run (projet.json), pour savoir plus tard
% comment les .mat ont été calculés
if StockageProjet
    texte = @(x) strtrim(num2str(x));
    Epaules = struct('Numero', num2cell(PatientNumbers(:)), ...
        'ID', cellfun(texte, PatientSelection(:, 1), 'UniformOutput', false), ...
        'Cote', cellfun(texte, PatientSelection(:, 2), 'UniformOutput', false), ...
        'Pre', cellfun(texte, PatientSelection(:, 3), 'UniformOutput', false), ...
        'Post', cellfun(texte, PatientSelection(:, 4), 'UniformOutput', false));
    for iP = 1:nPatientRows
        Epaules(iP).Dossier = shoulderFolderName(PatientNumbers(iP), Epaules(iP).ID, parseSides(PatientSelection{iP, 2}));
    end
    WriteProjectSummary(ProjectFolder, struct('Projet', ProjectCode, 'Toolbox', Folder.toolbox, ...
        'DataFolder', longDataFolder, 'Epaules', Epaules, ...
        'ReplisRab', {[RabFallbackPerPatient{:}]}, 'Erreurs', {ErrorLog}, 'DureeMinutes', tTotal / 60));
end

if isfolder(ResultsFolder)
    cd(ResultsFolder);
end

if ispc
    system(sprintf('subst %s /d', shortDrive));
end

% =========================================================================
%  UTILITAIRES
% =========================================================================

function toolboxFolder = resolveToolboxFolder()
% Chemin de Protocol01/ (2 niveaux au-dessus de ce script, dans Multi/).
% mfilename('fullpath') ne renvoie le vrai chemin de ce fichier que quand
% le script tourne dans son intégralité
candidate = fileparts(fileparts(mfilename('fullpath')));
if isfolder(fullfile(candidate, 'Multi', 'Core'))
    toolboxFolder = candidate;
    return;
end
try
    candidate = fileparts(fileparts(matlab.desktop.editor.getActiveFilename()));
    if isfolder(fullfile(candidate, 'Multi', 'Core'))
        toolboxFolder = candidate;
        return;
    end
catch
end
error('MAIN_MULTI_Protocol_01:toolboxNotFound', ...
    ['Impossible de localiser Protocol01/ automatiquement (exécution par ', ...
     'section/sélection ?). Ouvre MAIN_MULTI_Protocol_01.m dans l''éditeur ', ...
     '(onglet actif) avant de relancer une section, ou lance le script en entier (F5).']);
end

function drive = findFreeDriveLetter()
% Première lettre de lecteur libre, de Z: vers D: - ni disque/subst
% existant (isfolder), ni lecteur réseau mappé même déconnecté (net use).
[~, netOut] = system('net use');
for c = 'ZYXWVUTRQPONMLKJIHGFED'
    drive = [c, ':'];
    if ~isfolder([drive, '\']) && ~contains(netOut, drive, 'IgnoreCase', true)
        return;
    end
end
error('MAIN_MULTI_Protocol_01:noFreeDrive', 'Aucune lettre de lecteur libre pour subst.');
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

function nom = shoulderFolderName(numero, patientID, sides)
% Dossier d'une épaule dans ProjectFolder\Patients\ : <n°>_<ID>_<côté>,
% numéro sur 3 chiffres pour garder l'ordre de la cohorte
nom = sprintf('%03d_%s_%s', numero, strtrim(num2str(patientID)), strjoin(sides, ''));
end

function replis = rabFallbackSides(d)
% Séances et côtés où la calibration SCoRE manque (cluster scapula ou humérus
% absent : rCsi / rCsj à NaN, voir Core/CoR/ComputeSCoRE.m) ; selon
% Processing.GJC.view, Core/DefineSegments.m y prend alors Rab
% (WriteProjectSummary garde le cas qui correspond à la vue du run)
replis = struct('Numero', {}, 'ID', {}, 'Cote', {}, 'Examen', {}, 'ScapulaAbsente', {}, 'HumerusAbsent', {});
for c = {'PRE', 'POST'}
    if ~isfield(d, c{1}) || ~isstruct(d.(c{1})) || ~isfield(d.(c{1}), 'Session') || ...
            ~isfield(d.(c{1}).Session, 'SCoRE') || ~isstruct(d.(c{1}).Session.SCoRE)
        continue;
    end
    S = d.(c{1}).Session.SCoRE;
    for s = d.Side
        if ~isfield(S, s{1}), continue; end
        scap = isfield(S.(s{1}), 'rCsi') && any(isnan(S.(s{1}).rCsi(:)));
        hum  = isfield(S.(s{1}), 'rCsj') && any(isnan(S.(s{1}).rCsj(:)));
        if scap || hum
            replis(end+1) = struct('Numero', d.Numero, 'ID', d.PatientID, 'Cote', s{1}, 'Examen', c{1}, ...
                'ScapulaAbsente', scap, 'HumerusAbsent', hum); %#ok<AGROW>
        end
    end
end
end


%% ========================================================================
%  Results extraction from.mat
% MAIN_MULTI_Protocol_01.m doit être l'onglet actif dans l'éditeur MATLAB
% au moment où la section est lancée.
Folder.toolbox = resolveToolboxFolder();
addpath(fullfile(Folder.toolbox, 'Multi'));
addpath(fullfile(Folder.toolbox, 'Multi', 'Core'));
addpath(fullfile(Folder.toolbox, 'Multi', 'IO'));
run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m')); % DatabaseFile, OutputFile, FunctionalOutputFile, CoRQualityOutputFile, CurveQualityOutputFile, ResultsFolder
% Calcul une fois, puis relecture (Core/CachedCompute.m) : chaque fonction
% ...FromDatabase relit toute la base ; ses sorties sont gardées dans
% CacheFolder (Valeurs\Cache du projet) et relues tant qu'aucun .mat n'a
% changé. RecomputeValues = true (userCommands_Multi.m) force le recalcul.
if ~exist('RecomputeValues', 'var'), RecomputeValues = false; end
if ~exist('CacheFolder', 'var'),     CacheFolder = fullfile(ResultsFolder, 'Cache'); end
% Référence figée de la correction ST/TX inversée (Core/InversionReference.m)
if ~exist('InversionReferenceFile', 'var'),  InversionReferenceFile = fullfile(Folder.toolbox, 'Multi', 'InversionReference_STTX.csv'); end
if ~exist('BuildInversionReference', 'var'), BuildInversionReference = false; end
OptsContrib = struct('AsymptomaticSelection', {AsymptomaticSelection}, ...
    'InversionReference', InversionReferenceFile, 'BuildInversionReference', BuildInversionReference);

%% Metric validation
% CoR residual validation
[CoRRes, CoRAsym] = CachedCompute('QualiteCoR', CacheFolder, RecomputeValues, DatabaseFile, ...
    @ComputeCoRQualityFromDatabase, DatabaseFile, CoRQualityOutputFile, ResultsFolder, 30, ...
    struct('AsymptomaticSelection', {AsymptomaticSelection}));

% Curve validity diagnostic
[CurveQualRes, CurveQualAsym] = CachedCompute('QualiteCourbes', CacheFolder, RecomputeValues, DatabaseFile, ...
    @ComputeCurveQualityFromDatabase, DatabaseFile, CurveQualityOutputFile, ResultsFolder, ...
    struct('AsymptomaticSelection', {AsymptomaticSelection}));

% Contrôle des courbes patient par patient : sauts ±180°, forme, élévation 3D
% (recalcul aussi quand PostureDataFile, qui donne les épaules, est plus récent que le cache)
[CurveQC, CurveQCSummary, CurveCycles] = CachedCompute('ControleCourbes', CacheFolder, RecomputeValues, {DatabaseFile, PostureDataFile}, ...
    @CheckCurvesFromDatabase, DatabaseFile, PostureDataFile, CurveCheckFolder, CurveQualityOutputFile);

%% Asymptomatic selection
% Asymptomatic shoulder classification
EligRes = CachedCompute('Eligibilite', CacheFolder, RecomputeValues, DatabaseFile, ...
    @ComputeContralateralEligibilityFromDatabase, DatabaseFile, ContralateralEligibilityFile, ResultsFolder);

%% Curve analysis
% Valeurs et courbes lues sur le cycle retenu (meilleur des 3 cycles, alertes
% en console et colonnes Cycle_* / CycleAlert_*), voir Core/BestCycle.m
% Clinical movement decomposition : HT, GH, ST, TX
% (recalcul aussi quand la référence figée est plus récente que le cache)
[ClinRes, ClinAsym, ClinCurves, ClinAsymCurves] = CachedCompute('Clinique', CacheFolder, ...
    RecomputeValues || BuildInversionReference, {DatabaseFile, InversionReferenceFile}, ...
    @ComputeClinicalContributionsFromDatabase, DatabaseFile, OutputFile, ResultsFolder, OptsContrib);

% Functional decomposition : HG, GH, ST, TX
[FuncRes, FuncAsym, FuncCurves, FuncAsymCurves] = CachedCompute('Fonctionnel', CacheFolder, ...
    RecomputeValues || BuildInversionReference, {DatabaseFile, InversionReferenceFile}, ...
    @ComputeFunctionalContributionsFromDatabase, DatabaseFile, FunctionalOutputFile, ResultsFolder, OptsContrib);

% Données brutes : angles d'Euler X, Y, Z de HT, GH, ST et thorax, cycle retenu (registre)
RawCurves = CachedCompute('Brut', CacheFolder, RecomputeValues, DatabaseFile, ...
    @ComputeRawCurvesFromDatabase, DatabaseFile);

%% Posture analysis
% Posture : inclinaison thoracique et classification de Moroder
[PostRes, PostAsym] = CachedCompute('Posture', CacheFolder, RecomputeValues, DatabaseFile, ...
    @ComputePostureFromDatabase, DatabaseFile, PostureOutputFile, ResultsFolder, ...
    struct('AsymptomaticSelection', {AsymptomaticSelection}));

%% Registre : export des résultats par épaule et mise à jour du site
% Résultats et courbes des sections ci-dessus déjà lancées (une section non
% lancée est simplement absente de l'export) ; voir IO/ExportRegistre.m
% Valeurs par défaut si userCommands_Multi.m a été lu avant leur ajout
if ~exist('RegistreFolder', 'var'), RegistreFolder = fullfile(ResultsFolder, 'Registre'); end
if ~exist('RegistreURL', 'var'),    RegistreURL    = 'http://127.0.0.1:8765';              end
RegTables = struct(); RegCourbes = struct();
if exist('ClinRes', 'var'),      RegTables.Clinique       = ClinRes;      end
if exist('FuncRes', 'var'),      RegTables.Fonctionnel    = FuncRes;      end
if exist('PostRes', 'var'),      RegTables.Posture        = PostRes;      end
if exist('CoRRes', 'var'),       RegTables.QualiteCoR     = CoRRes;       end
if exist('CurveQualRes', 'var'), RegTables.QualiteCourbes = CurveQualRes; end
% Épaules asymptomatiques et éligibilité controlatérale (rattachées à l'épaule opérée)
if exist('ClinAsym', 'var'),      RegTables.CliniqueAsym       = ClinAsym;      end
if exist('FuncAsym', 'var'),      RegTables.FonctionnelAsym    = FuncAsym;      end
if exist('PostAsym', 'var'),      RegTables.PostureAsym        = PostAsym;      end
if exist('CoRAsym', 'var'),       RegTables.QualiteCoRAsym     = CoRAsym;       end
if exist('CurveQualAsym', 'var'), RegTables.QualiteCourbesAsym = CurveQualAsym; end
if exist('EligRes', 'var'),       RegTables.Eligibilite        = EligRes;       end
if exist('ClinCurves', 'var'),     RegCourbes.Clinique        = ClinCurves;     end
if exist('FuncCurves', 'var'),     RegCourbes.Fonctionnel     = FuncCurves;     end
if exist('ClinAsymCurves', 'var'), RegCourbes.CliniqueAsym    = ClinAsymCurves; end
if exist('FuncAsymCurves', 'var'), RegCourbes.FonctionnelAsym = FuncAsymCurves; end
if exist('RawCurves', 'var'),      RegCourbes.Brut            = RawCurves;      end
ExportRegistre(RegistreFolder, RegTables, RegCourbes, ...
    struct('URL', RegistreURL, 'NbEpaules', size(PatientSelection, 1), 'CodeFolder', Folder.toolbox));

%% Article E02_01_Posture
% H2 : posture PRE x élévation (HT, HG), 48 corrélations
CorrelatePostureROM(PostureDataFile, CorrelationROMOutputFile);

% H1 : contribution du thorax (mouvement au pic, amplitude, vérification HG moins HT)
AnalyseThoraxContribution(PostureDataFile, CorrelationROMOutputFile);

% Analyses secondaires : Moroder vs 2024, inclinaison x SIR, assis vs debout, HG moins HT vs posture
PostureSecondaryAnalyses(PostureDataFile, CorrelationROMOutputFile);

% Inclinaison thoracique : stratification (vs Moroder) et seuil critique 
InclinationClassification(PostureDataFile, InclinationOutputFile);

% Courbes moyennes HG, HT, GH, ST, thorax : rTSA PRE, POST et épaules saines
MeanCurves = PlotMeanCurvesFromDatabase(DatabaseFile, PostureDataFile);

% Épaules asymptomatiques controlatérales vs rTSA 
AsymptomaticComparison(PostureDataFile, AsymptomaticOutputFile);

% Illustrations des mesures (inclinaison, SIR, HG et HT) sur un patient réel
Folder.deps = fullfile(fileparts(Folder.toolbox), 'dependencies');
IllustrationInfo = PlotMeasureIllustrations(Folder, PatientSelection, DataFolder, PostureDataFile, ...
    IllustrationFolder, 152);

% Figures
% Figures de l'article (format JSES, une par fichier, flexion et scaption) ;
% toutes les comparaisons sur l'amplitude (max moins min)
[ArticleFigures, ThoracicShare, ThoracicDecomp] = PlotArticleFigures(PostureDataFile, ArticleFigureFolder);

%% SHR methodology analysis
% Courbes HT, GH, ST point par point (PRE et POST, cycle retenu, 101 points) :
% SHR_Curves.xlsx écrit par le registre dans SHRDataFolder pour les épaules du
% projet TPC2_SHR (aucune relecture des .mat). Contrôle depuis les .mat
% (quelques minutes) : ExportSHRCurvesFromDatabase(DatabaseFile, PostureDataFile, SHRCurvesOutputFile)

% Formules de SHR (familles A GH:ST, B TH:ST, C TH:GH au pic) sur ces courbes ;
% scaption seule par défaut, SHR_Formulas.xlsx écrit dans SHRDataFolder,
% figures dans SHRFigureFolder
SHRFormulas = TestSHRFormulas(SHRDataFolder, struct('FigureFolder', SHRFigureFolder));

