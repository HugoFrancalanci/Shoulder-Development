% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Version "multi-patients" de ReportDataAvailability.m (IO/) :
%                calcule, pour UNE session (PRE ou POST), la même chose mais
%                sous forme binaire (1/0) exploitable dans un rapport Excel
%                (une ligne par examen), au lieu d'un affichage console.
%
%                Réutilise les mêmes techniques que ReportDataAvailability
%                (détection des groupes de marqueurs "legacy" par nom de
%                base + chiffres finaux, check hasData = non vide/non-NaN/
%                non tout-zéro) plutôt que de dupliquer une autre logique.
%
%                Sauf mention contraire, tout est évalué sur le trial de
%                référence ANALYTIC1 (comme ReportDataAvailability).
%
%                Ce qui est extrait pour chaque colonne du rapport :
%
%                MOUVEMENTS (sur Trial(k).task ET c3dFiles bruts, car les
%                fichiers STATIC/ISOMETRIC ne sont jamais chargés dans Trial
%                par runProtocol01 - seul CALIBRATION/ANALYTIC/FUNCTIONAL le
%                sont ; il faut donc aussi checker les noms de fichiers .c3d
%                sur le disque pour les détecter) :
%                - Rcycle/Lcycle : le champ Trial(ANALYTIC1).Rcycle/.Lcycle
%                  est-il non vide (cycles de marche coupés avec succès).
%                - Analytic1-4, Functional1-4 : présence d'un trial/fichier
%                  ANALYTICn / FUNCTIONALn.
%                - Calibration1-6 : présence de CALIBRATIONn, avec alias
%                  selon l'année du protocole - Calibration1-3 acceptent
%                  aussi STATIC1-3 (même acquisition, nom différent) ;
%                  Calibration5-6 acceptent aussi ISOMETRIC1-2. Calibration4
%                  n'a pas d'alias.
%
%                POSTURE (présence d'un marqueur donné, trajectoire non
%                vide/non-NaN) : CV7/TV3/TV5/TV8/S1
%
%                CINÉMATIQUE (côté évalué = sidesToReport, c-à-d le
%                côté choisi dans PatientSelection; si 'RL', présence = OR des deux
%                côtés, compte = somme des deux côtés) :
%                - Nombre : length(fieldnames(btkGetMarkers(t.btk)))
%                - Cluster AC/Type : cluster scapulaire. Cherche d'abord les
%                  marqueurs "current" Cluster_{R/L}S_01/02/03 (type 'S') ;
%                  si absents, cherche un groupe legacy numéroté de base
%                  '{R/L}ACM' (ex: RACM1/2/3, type 'ACM'). Type affiché =
%                  "S (3)" / "ACM (3)" / "-" si rien trouvé.
%                - Cluster A/Type : cluster huméral. Marqueurs "current"
%                  Cluster_{R/L}A_01..05 (type 'A') ; sinon legacy de base
%                  '{R/L}EOS' (type 'EOS').
%                - Cluster FA/Type : cluster avant-bras. Marqueurs "current"
%                  Cluster_{R/L}F_01/02/03 (type 'F') ; sinon legacy de base
%                  '{R/L}F' (type 'F').
%                - Scapula/Humérus : au moins un marqueur des clusters
%                  ci-dessus (current OU legacy) valide, pour au moins un
%                  des côtés demandés -> cinématique jugée exploitable.
%                - Thorax : au moins un marqueur du segment Thorax
%                  (t.Marker.Body.Segment.label == 'Thorax') valide.
%                - Fs : btkGetPointFrequency (fréquence marqueurs).
%
%                ELECTROMYOGRAPHIE (canaux analog bruts BTK, PAS le champ
%                Trial.Emg qui n'est jamais rempli par runProtocol01/
%                MAIN_Protocol_01) :
%                - Nombre : nombre de canaux analog distincts identifiés
%                  comme un muscle (DELTA/DELTM/.../LATD), hors canal FORCE.
%                  Un canal est identifié par le code muscle qu'il CONTIENT,
%                  peu importe ce qu'il y a devant/derrière dans son nom
%                  (ex: 'RDELTA', 'RDELTA_2', '1_RDELTA' sont tous le même
%                  canal côté R / muscle DELTA, compté une seule fois).
%                - DELTA/DELTM/DELTP/TRAPS/TRAPM/TRAPI/SERRA/LATD : marqué
%                  présent (1) si au moins un côté (R ou L) de ce muscle a
%                  un signal RÉELLEMENT enregistré (non vide, pas tout-NaN,
%                  pas tout-zéro) - un canal présent mais vide/bugué compte
%                  comme absent (0).
%                - Fs : btkGetAnalogFrequency (fréquence analog/EMG).
%
%                PUISSANCE (même canal analog 'FORCE', identifié comme les
%                canaux EMG ci-dessus) :
%                - Nombre : un canal correspondant à 'FORCE' est-il détecté
%                  (présent dans le C3D, indépendamment de son contenu).
%                - Force : ce canal a-t-il réellement un signal enregistré
%                  (même check hasData que l'EMG).
% -------------------------------------------------------------------------
% Inputs  : Trial         (struct array) depuis runProtocol01
%           Patient/Session/Pathology (struct) depuis runProtocol01 (non
%                         utilisés directement ici, gardés pour signature
%                         homogène avec ReportDataAvailability)
%           c3dFiles      (struct array) dir('*.c3d') depuis runProtocol01
%           sidesToReport (cellstr) {'R'} / {'L'} / {'R','L'}
% Outputs : Row (struct, un seul enregistrement) — tous les champs
%           Mouvements/Posture/Cinématique/EMG/Puissance, valeurs 1/0
%           (binaire) ou numériques (Nombre/Fs) ou texte ('-'/'ACM (3)'...)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Row = ComputeDataAvailability(Trial, Patient, Session, Pathology, c3dFiles, sidesToReport) %#ok<INUSD>

% -------------------------------------------------------------------------
% VALEURS PAR DÉFAUT
% -------------------------------------------------------------------------
Row = struct( ...
    'Rcycle', 0, 'Lcycle', 0, ...
    'Analytic1', 0, 'Analytic2', 0, 'Analytic3', 0, 'Analytic4', 0, ...
    'Functional1', 0, 'Functional2', 0, 'Functional3', 0, 'Functional4', 0, ...
    'Calibration1', 0, 'Calibration2', 0, 'Calibration3', 0, ...
    'Calibration4', 0, 'Calibration5', 0, 'Calibration6', 0, ...
    'C7', 0, 'TV3', 0, 'TV5', 0, 'TV8', 0, 'S1', 0, ...
    'Kin_Nombre', NaN, 'ClusterAC', 0, 'ClusterAC_Type', '-', ...
    'ClusterA', 0, 'ClusterA_Type', '-', 'ClusterFA', 0, 'ClusterFA_Type', '-', ...
    'Kin_Scapula', 0, 'Kin_Humerus', 0, 'Kin_Thorax', 0, 'Kin_Fs', NaN, ...
    'EMG_Nombre', 0, 'DELTA', 0, 'DELTM', 0, 'DELTP', 0, ...
    'TRAPS', 0, 'TRAPM', 0, 'TRAPI', 0, 'SERRA', 0, 'LATD', 0, 'EMG_Fs', NaN, ...
    'Force_Nombre', 0, 'Force', 0);

allTrialTasks = {Trial.task};
c3dNames = {};
if ~isempty(c3dFiles), c3dNames = {c3dFiles.name}; end

% =========================================================================
%  MOUVEMENTS
% =========================================================================
Row.Rcycle = 0; Row.Lcycle = 0;
tidxRef = findTask(Trial, 'ANALYTIC1');
if ~isempty(tidxRef)
    Row.Rcycle = double(isfield(Trial(tidxRef),'Rcycle') && ~isempty(Trial(tidxRef).Rcycle));
    Row.Lcycle = double(isfield(Trial(tidxRef),'Lcycle') && ~isempty(Trial(tidxRef).Lcycle));
end

for n = 1:4
    Row.(sprintf('Analytic%d',n))   = presentAny(allTrialTasks, c3dNames, {sprintf('ANALYTIC%d',n)});
    Row.(sprintf('Functional%d',n)) = presentAny(allTrialTasks, c3dNames, {sprintf('FUNCTIONAL%d',n)});
end

calAliases = { ...
    {'CALIBRATION1','STATIC1'}; {'CALIBRATION2','STATIC2'}; {'CALIBRATION3','STATIC3'}; ...
    {'CALIBRATION4'}; {'CALIBRATION5','ISOMETRIC1'}; {'CALIBRATION6','ISOMETRIC2'}};
for n = 1:6
    Row.(sprintf('Calibration%d',n)) = presentAny(allTrialTasks, c3dNames, calAliases{n});
end

if isempty(tidxRef)
    return; % Pas de trial de référence : Posture/Cinématique/EMG/Puissance restent à 0/NaN
end
t = Trial(tidxRef);

% =========================================================================
%  POSTURE — présence marqueur (trial de référence)
%  Colonne 'C7' du rapport <-> marqueur réellement nommé 'CV7' dans le markerSet
% =========================================================================
postureMarkers = {'C7','TV3','TV5','TV8','S1'};
postureLabels  = {'CV7','TV3','TV5','TV8','S1'};
for im = 1:length(postureMarkers)
    Row.(postureMarkers{im}) = markerValid(t, postureLabels{im});
end

% =========================================================================
%  CINÉMATIQUE
% =========================================================================
try
    Row.Kin_Nombre = length(fieldnames(btkGetMarkers(t.btk))); % même méthode que ReportDataAvailability.m (Section 2)
catch
    Row.Kin_Nombre = NaN;
end
try
    Row.Kin_Fs = btkGetPointFrequency(t.btk);
catch
    Row.Kin_Fs = NaN;
end

legacyGroups = detectLegacyGroups(t);

% --- Cluster AC (scapula) : current 'Cluster_{s}S_0N' (type S) vs legacy base '{s}ACM' ---
[Row.ClusterAC, Row.ClusterAC_Type] = clusterStatus(t, legacyGroups, sidesToReport, ...
    @(s) arrayfun(@(n) sprintf('Cluster_%sS_0%d', s, n), 1:3, 'UniformOutput', false), 'S', 'ACM');

% --- Cluster A (humerus) : current 'Cluster_{s}A_0N' (type A) vs legacy base '{s}EOS' ---
[Row.ClusterA, Row.ClusterA_Type] = clusterStatus(t, legacyGroups, sidesToReport, ...
    @(s) arrayfun(@(n) sprintf('Cluster_%sA_0%d', s, n), 1:5, 'UniformOutput', false), 'A', 'EOS');

% --- Cluster FA (forearm) : current 'Cluster_{s}F_0N' (type F) vs legacy base '{s}F' ---
[Row.ClusterFA, Row.ClusterFA_Type] = clusterStatus(t, legacyGroups, sidesToReport, ...
    @(s) arrayfun(@(n) sprintf('Cluster_%sF_0%d', s, n), 1:3, 'UniformOutput', false), 'F', 'F');

% --- Segments utilisables pour la cinématique (OR sur les côtés demandés) ---
Row.Kin_Scapula = segmentUsable(t, legacyGroups, sidesToReport, 'Cluster_%sS_0%d', 3, 'ACM');
Row.Kin_Humerus = segmentUsable(t, legacyGroups, sidesToReport, 'Cluster_%sA_0%d', 5, 'EOS');
Row.Kin_Thorax  = thoraxUsable(t);

% =========================================================================
%  EMG / PUISSANCE — trial de référence (ANALYTIC1) uniquement. Un canal
%  est identifié par le code muscle qu'il contient, peu importe ce qu'il y
%  a devant/derrière dans le nom (ex: 'RDELTA', 'RDELTA_2', '1_RDELTA' sont
%  tous le même canal côté R / muscle DELTA, compté une seule fois).
% =========================================================================
muscleCodes = {'DELTA','DELTM','DELTP','TRAPS','TRAPM','TRAPI','SERRA','LATD'};

try
    analogData = btkGetAnalogs(t.btk);
catch
    analogData = struct();
end
Row.EMG_Fs = NaN;
try
    Row.EMG_Fs = btkGetAnalogFrequency(t.btk);
catch
end

labels      = fieldnames(analogData);
channelIDs  = {};
hasDataByID = containers.Map('KeyType','char','ValueType','logical');

for il = 1:length(labels)
    lbl = labels{il};
    id  = identifyChannel(lbl, muscleCodes);
    if isempty(id), continue; end % canal non reconnu (ni un muscle, ni FORCE)
    sig = analogData.(lbl);
    hd  = ~isempty(sig) && ~all(isnan(sig(:))) && any(sig(:) ~= 0);
    if ~any(strcmp(channelIDs, id)), channelIDs{end+1} = id; end %#ok<AGROW>
    if isKey(hasDataByID, id)
        hasDataByID(id) = hasDataByID(id) || hd;
    else
        hasDataByID(id) = hd;
    end
end

isForceID = strcmp(channelIDs, 'FORCE');
emgIDs    = channelIDs(~isForceID);
Row.EMG_Nombre = length(emgIDs);

for im = 1:length(muscleCodes)
    code = muscleCodes{im};
    Row.(code) = double(any(cellfun(@(id) endsWith(id, ['_' code]) && hasDataByID(id), emgIDs)));
end

Row.Force_Nombre = double(any(isForceID));
Row.Force        = double(any(isForceID) && hasDataByID('FORCE'));

end

% =========================================================================
%  HELPERS
% =========================================================================
function tidx = findTask(Trial, taskName)
tidx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task, taskName), tidx = k; return; end
end
end

function tf = presentAny(allTrialTasks, c3dNames, aliases)
tf = 0;
for ia = 1:length(aliases)
    if any(contains(allTrialTasks, aliases{ia})) || any(cellfun(@(f) contains(f, aliases{ia}), c3dNames))
        tf = 1; return;
    end
end
end

function tf = markerValid(t, label)
tf = 0;
idx = find(strcmp({t.Marker.label}, label), 1);
if isempty(idx), return; end
traj = t.Marker(idx).Trajectory.full;
tf = double(~isempty(traj) && ~all(isnan(traj(:))));
end

function legacyGroups = detectLegacyGroups(t)
% Reprend la logique de ReportDataAvailability.m : marqueurs BTK inconnus
% du markerSet courant, regroupés par nom de base (chiffres finaux ôtés).
legacyGroups = struct('base',{},'count',{},'labels',{});
if ~isfield(t,'btk') || isempty(t.btk), return; end
try
    allBtkMarkers = fieldnames(btkGetMarkers(t.btk));
catch
    return;
end
knownLabels = {t.Marker.label};
unknown = allBtkMarkers(~ismember(allBtkMarkers, knownLabels));
bases = regexprep(unknown, '\d+$', '');
uniqueBases = unique(bases);
for ib = 1:length(uniqueBases)
    b = uniqueBases{ib};
    if isempty(b), continue; end
    members = unknown(strcmp(bases, b));
    if length(members) >= 2
        g.base = b; g.count = length(members); g.labels = members;
        legacyGroups(end+1) = g; %#ok<AGROW>
    end
end
end

function [present, typeStr] = clusterStatus(t, legacyGroups, sides, currentLabelsFn, currentType, legacyBaseSuffix)
totalCount = 0;
matchedType = '';
for is = 1:length(sides)
    s = sides{is};
    % Current protocol markers
    curLabels = currentLabelsFn(s);
    curCount = 0;
    for il = 1:length(curLabels)
        curCount = curCount + markerValid(t, curLabels{il});
    end
    if curCount > 0
        totalCount = totalCount + curCount;
        if isempty(matchedType), matchedType = currentType; end
        continue;
    end
    % Legacy markers (numbered group whose base = side + suffix, e.g. 'RACM','LEOS','RFA')
    legBase = [s, legacyBaseSuffix];
    gi = find(strcmpi({legacyGroups.base}, legBase), 1);
    if ~isempty(gi)
        totalCount = totalCount + legacyGroups(gi).count;
        if isempty(matchedType), matchedType = legacyBaseSuffix; end
    end
end
present = double(totalCount > 0);
if totalCount > 0
    typeStr = sprintf('%s (%d)', matchedType, totalCount);
else
    typeStr = '-';
end
end

function ok = segmentUsable(t, legacyGroups, sides, currentPattern, nCurrent, legacySuffix)
ok = 0;
for is = 1:length(sides)
    s = sides{is};
    curLabels = arrayfun(@(n) sprintf(currentPattern, s, n), 1:nCurrent, 'UniformOutput', false);
    curCount = 0;
    for il = 1:length(curLabels)
        curCount = curCount + markerValid(t, curLabels{il});
    end
    if curCount > 0, ok = 1; return; end
    legBase = [s, legacySuffix];
    gi = find(strcmpi({legacyGroups.base}, legBase), 1);
    if ~isempty(gi) && legacyGroups(gi).count > 0, ok = 1; return; end
end
end

function ok = thoraxUsable(t)
% Segment Thorax : pas de cluster technique (segDef clusterPfx='' dans
% ReportDataAvailability.m), juste les marqueurs anatomiques (C7/TV.../S1).
% Usable si au moins un marqueur du segment Thorax est valide.
ok = 0;
for im = 1:length(t.Marker)
    if strcmp(t.Marker(im).Body.Segment.label, 'Thorax')
        traj = t.Marker(im).Trajectory.full;
        if ~isempty(traj) && ~all(isnan(traj(:)))
            ok = 1; return;
        end
    end
end
end

function id = identifyChannel(lbl, muscleCodes)
% Identifie un canal analog par le code muscle qu'il contient, peu importe
% ce qu'il y a devant/derrière dans le nom. 'FORCE' est prioritaire.
% Retourne 'R_<code>' / 'L_<code>' / '_<code>' (côté inconnu) / 'FORCE' /
% '' (canal non reconnu).
id = '';
if contains(lbl, 'FORCE', 'IgnoreCase', true)
    id = 'FORCE'; return;
end
for ic = 1:length(muscleCodes)
    code = muscleCodes{ic};
    if contains(lbl, ['R' code], 'IgnoreCase', true)
        id = ['R_' code]; return;
    elseif contains(lbl, ['L' code], 'IgnoreCase', true)
        id = ['L_' code]; return;
    elseif contains(lbl, code, 'IgnoreCase', true)
        id = ['_' code]; return;
    end
end
end
