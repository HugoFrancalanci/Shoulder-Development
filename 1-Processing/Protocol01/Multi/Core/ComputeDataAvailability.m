% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Multi-patient version of ReportDataAvailability.m (IO/):
%                computes the same information for ONE session (PRE or
%                POST) but as binary (1/0) flags usable in an Excel report
%                (one row per exam), instead of a console display.
%
%                Reuses the same techniques as ReportDataAvailability
%                (legacy marker group detection by base name + trailing
%                digits, hasData check = non-empty/non-NaN/non-all-zero)
%                rather than duplicating another logic.
%
%                Unless stated otherwise, everything is evaluated on the
%                ANALYTIC1 reference trial (same as ReportDataAvailability).
%
%                What is extracted for each report column:
%
%                MOVEMENTS (on both Trial(k).task AND raw c3dFiles, since
%                STATIC/ISOMETRIC files are never loaded into Trial by
%                runProtocol01 - only CALIBRATION/ANALYTIC/FUNCTIONAL are -
%                so the .c3d file names on disk must also be checked to
%                detect them):
%                - Rcycle/Lcycle: number of cycles cut for
%                  Trial(ANALYTIC1) (numel of the .Rcycle/.Lcycle field,
%                  not just a 0/1 presence flag) - e.g. 3 is the normal
%                  count, another number means more/fewer repetitions were
%                  performed, 0 means no usable cycle (either no .mat in
%                  the session folder, or a .mat that was never manually
%                  cut for this trial - see CutCycles.m).
%                - Analytic1-4, Functional1-4: presence of an
%                  ANALYTICn/FUNCTIONALn trial/file.
%                - Calibration1-6: presence of CALIBRATIONn, with aliases
%                  depending on the protocol year - Calibration1-3 also
%                  accept STATIC1-3 (same acquisition, different name);
%                  Calibration5-6 also accept ISOMETRIC1-2. Calibration4
%                  has no alias.
%
%                POSTURE (presence of a given marker, non-empty/non-NaN
%                trajectory): CV7/TV3/TV5/TV8/S1
%
%                KINEMATICS (side evaluated = sidesToReport, i.e. the side
%                chosen in PatientSelection; if 'RL', presence = OR of both
%                sides, count = sum of both sides):
%                - Nombre: length(fieldnames(btkGetMarkers(t.btk)))
%                - Cluster AC/Type: scapular cluster. Looks first for the
%                  "current" markers Cluster_{R/L}S_01/02/03 (type 'S'); if
%                  absent, looks for a numbered legacy group with base
%                  '{R/L}ACM' (e.g. RACM1/2/3, type 'ACM'). Displayed type
%                  = "S (3)" / "ACM (3)" / "-" if nothing found.
%                - Cluster A/Type: humeral cluster. "Current" markers
%                  Cluster_{R/L}A_01..05 (type 'A'); otherwise a legacy
%                  fallback between two older naming schemes that can both
%                  appear as valid (non-NaN) labels in the same C3D even
%                  though only one is actually tracked (the other being a
%                  frozen/static leftover from an older marker-set
%                  template): the 3 named markers {R/L}HDT/{R/L}HTI/
%                  {R/L}HBI (type 'H') vs the numbered legacy group with
%                  base '{R/L}EOS' (type 'EOS'). Whichever shows real
%                  movement over the trial (range > 0 on any axis, see
%                  markerIsMoving) is reported; H wins the tie-break if
%                  both happen to show movement.
%                - Cluster FA/Type: forearm cluster. "Current" markers
%                  Cluster_{R/L}F_01/02/03 (type 'F'); otherwise legacy
%                  base '{R/L}F' (type 'F').
%                - Scapula/Humerus: at least one marker from the clusters
%                  above (current OR legacy) valid, for at least one of
%                  the requested sides -> kinematics judged usable.
%                - Thorax: at least one marker of the Thorax segment
%                  (t.Marker.Body.Segment.label == 'Thorax') valid.
%                - Fs: btkGetPointFrequency (marker frequency).
%
%                EMG (raw BTK analog channels, NOT the Trial.Emg field,
%                which is never filled by runProtocol01/MAIN_Protocol_01) -
%                UNLIKE every other section above, this one is checked
%                across ALL FOUR ANALYTIC1-4 tasks that exist for the
%                session, not just the ANALYTIC1 reference trial (a
%                channel can look fine on ANALYTIC1 while actually being
%                dead on e.g. ANALYTIC3):
%                - Nombre: number of distinct analog channels identified
%                  as a muscle (DELTA/DELTM/.../LATD), excluding the FORCE
%                  channel and excluding derived/processed channels
%                  ('_envelop'/'_onset' suffixes - not the raw recorded
%                  signal, ignored entirely). A channel is identified by
%                  the muscle code it CONTAINS, regardless of what
%                  precedes/follows it in the name (e.g. 'RDELTA',
%                  'RDELTA_2', '1_RDELTA' are all the same R-side/DELTA-
%                  muscle channel, counted once).
%                - DELTA_R/DELTA_L/DELTM_R/DELTM_L/.../LATD_R/LATD_L: ONE
%                  COLUMN PER SIDE PER MUSCLE (not merged/OR'd across R and
%                  L) - a dead channel on one side must not be masked by a
%                  healthy channel on the other side (real case found:
%                  RSERRA flat at exactly 0 across all 4 ANALYTIC tasks
%                  while LSERRA had a genuine signal - a single combined
%                  SERRA column would have wrongly read "1" from the L side
%                  alone). Marked present (1) if that specific side's raw
%                  channel has a signal ACTUALLY recorded (non-empty, not
%                  all-NaN, and showing some variation across samples - see
%                  hasRealSignal) in EVERY ANALYTIC1-4 task that exists. The
%                  variation check (rather than a strict all-zero check)
%                  also catches a dead/disconnected channel that is flat at
%                  a constant non-zero value (DC offset, saturation)
%                  instead of literally all-zero. A channel empty/flat/
%                  broken (or entirely missing from the C3D) in even a
%                  single one of those tasks counts as absent (0) overall.
%                - Fs: btkGetAnalogFrequency (analog/EMG frequency, from
%                  the ANALYTIC1 reference trial only).
%
%                POWER ('FORCE' analog channel) - unlike EMG above, this
%                is checked on the ANALYTIC1 reference trial only:
%                - Nombre: is a channel matching 'FORCE' detected (present
%                  in the C3D, regardless of its content).
%                - Force: does that channel actually have a recorded
%                  signal (same hasData check as EMG).
% -------------------------------------------------------------------------
% Inputs  : Trial         (struct array) from runProtocol01
%           Patient/Session/Pathology (struct) from runProtocol01 (not used
%                         directly here, kept for a signature consistent
%                         with ReportDataAvailability)
%           c3dFiles      (struct array) dir('*.c3d') from runProtocol01
%           sidesToReport (cellstr) {'R'} / {'L'} / {'R','L'}
% Outputs : Row (struct, a single record) - all Movements/Posture/
%           Kinematics/EMG/Power fields, values 1/0 (binary) or numeric
%           (Nombre/Fs) or text ('-'/'ACM (3)'...)
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
% DEFAULT VALUES
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
    'EMG_Nombre', 0, ...
    'DELTA_R', 0, 'DELTA_L', 0, 'DELTM_R', 0, 'DELTM_L', 0, ...
    'DELTP_R', 0, 'DELTP_L', 0, 'TRAPS_R', 0, 'TRAPS_L', 0, ...
    'TRAPM_R', 0, 'TRAPM_L', 0, 'TRAPI_R', 0, 'TRAPI_L', 0, ...
    'SERRA_R', 0, 'SERRA_L', 0, 'LATD_R', 0, 'LATD_L', 0, ...
    'EMG_Fs', NaN, ...
    'Force_Nombre', 0, 'Force', 0);

allTrialTasks = {Trial.task};
c3dNames = {};
if ~isempty(c3dFiles), c3dNames = {c3dFiles.name}; end

% =========================================================================
%  MOVEMENTS
% =========================================================================
% Rcycle/Lcycle: actual cycle COUNT (numel), not just a 0/1 presence flag
% - e.g. 3 = normal, another number = more/fewer repetitions performed,
% 0 = no usable cycle (either no .mat, or a .mat that was never manually
% cut for this trial - CutCycles.m falls back to an interactive ginput
% selection in that case, which never runs unattended in a batch).
Row.Rcycle = 0; Row.Lcycle = 0;
tidxRef = findTask(Trial, 'ANALYTIC1');
if ~isempty(tidxRef)
    if isfield(Trial(tidxRef),'Rcycle'), Row.Rcycle = numel(Trial(tidxRef).Rcycle); end
    if isfield(Trial(tidxRef),'Lcycle'), Row.Lcycle = numel(Trial(tidxRef).Lcycle); end
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
    return; % No reference trial: Posture/Kinematics/EMG/Power stay at 0/NaN
end
t = Trial(tidxRef);

% =========================================================================
%  POSTURE - marker presence (reference trial)
%  Report column 'C7' <-> marker actually named 'CV7' in the markerSet
% =========================================================================
postureMarkers = {'C7','TV3','TV5','TV8','S1'};
postureLabels  = {'CV7','TV3','TV5','TV8','S1'};
for im = 1:length(postureMarkers)
    Row.(postureMarkers{im}) = markerValid(t, postureLabels{im});
end

% =========================================================================
%  KINEMATICS
% =========================================================================
try
    Row.Kin_Nombre = length(fieldnames(btkGetMarkers(t.btk))); % same method as ReportDataAvailability.m (Section 2)
catch
    Row.Kin_Nombre = NaN;
end
try
    Row.Kin_Fs = btkGetPointFrequency(t.btk);
catch
    Row.Kin_Fs = NaN;
end

legacyGroups = detectLegacyGroups(t);

% --- Cluster AC (scapula): current 'Cluster_{s}S_0N' (type S) vs legacy base '{s}ACM' ---
[Row.ClusterAC, Row.ClusterAC_Type] = clusterStatus(t, legacyGroups, sidesToReport, ...
    @(s) arrayfun(@(n) sprintf('Cluster_%sS_0%d', s, n), 1:3, 'UniformOutput', false), 'S', 'ACM');

% --- Cluster A (humerus): current 'Cluster_{s}A_0N' (A) vs legacy 'H' (HDT/HTI/HBI, takes priority over EOS) vs legacy base '{s}EOS' ---
[Row.ClusterA, Row.ClusterA_Type] = clusterStatusHumerus(t, legacyGroups, sidesToReport);

% --- Cluster FA (forearm): current 'Cluster_{s}F_0N' (type F) vs legacy base '{s}F' ---
[Row.ClusterFA, Row.ClusterFA_Type] = clusterStatus(t, legacyGroups, sidesToReport, ...
    @(s) arrayfun(@(n) sprintf('Cluster_%sF_0%d', s, n), 1:3, 'UniformOutput', false), 'F', 'F');

% --- Segments usable for kinematics (OR across requested sides) ---
Row.Kin_Scapula = segmentUsable(t, legacyGroups, sidesToReport, 'Cluster_%sS_0%d', 3, 'ACM');
Row.Kin_Humerus = Row.ClusterA; % ClusterA (present, above) already covers current/H/EOS
Row.Kin_Thorax  = thoraxUsable(t);

% =========================================================================
%  EMG - a channel must have a real signal in EVERY ANALYTIC1-4 task that
%  exists for this session to be marked present; missing signal (or the
%  channel entirely absent from the C3D) in any one of them marks it
%  absent overall. A channel is identified by the muscle code it contains,
%  regardless of what precedes/follows it in the name (e.g. 'RDELTA',
%  'RDELTA_2', '1_RDELTA' are all the same R-side/DELTA-muscle channel,
%  counted once). FORCE is handled separately below (reference trial only).
% =========================================================================
muscleCodes   = {'DELTA','DELTM','DELTP','TRAPS','TRAPM','TRAPI','SERRA','LATD'};
analyticTasks = {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4'};

Row.EMG_Fs = NaN;
try
    Row.EMG_Fs = btkGetAnalogFrequency(t.btk);
catch
end

hasDataPerTask = {}; % one id->hasData map per existing ANALYTIC1-4 task
for itask = 1:length(analyticTasks)
    tidx2 = findTask(Trial, analyticTasks{itask});
    if isempty(tidx2), continue; end
    tt = Trial(tidx2);
    try
        analogData = btkGetAnalogs(tt.btk);
    catch
        analogData = struct();
    end
    labels  = fieldnames(analogData);
    taskMap = containers.Map('KeyType','char','ValueType','logical');
    for il = 1:length(labels)
        lbl = labels{il};
        id  = identifyChannel(lbl, muscleCodes);
        if isempty(id) || strcmp(id,'FORCE'), continue; end % unrecognised, or FORCE (handled below)
        sig = analogData.(lbl);
        hd  = hasRealSignal(sig);
        if isKey(taskMap, id)
            taskMap(id) = taskMap(id) || hd; % merge duplicate raw labels for the same id within this trial
        else
            taskMap(id) = hd;
        end
    end
    hasDataPerTask{end+1} = taskMap; %#ok<AGROW>
end

emgIDs = {};
for it2 = 1:length(hasDataPerTask)
    emgIDs = union(emgIDs, keys(hasDataPerTask{it2}));
end

hasDataByID = containers.Map('KeyType','char','ValueType','logical');
for ii = 1:length(emgIDs)
    id = emgIDs{ii};
    ok = ~isempty(hasDataPerTask); % false if no ANALYTIC task was found at all
    for it2 = 1:length(hasDataPerTask)
        tm = hasDataPerTask{it2};
        ok = ok && isKey(tm, id) && tm(id);
    end
    hasDataByID(id) = ok;
end

Row.EMG_Nombre = length(emgIDs);

% One column per side per muscle (not merged R/L OR'd together): a dead
% channel on one side must not be masked by a healthy channel on the
% other side (real case: RSERRA flat at 0 across all 4 ANALYTIC while
% LSERRA has a real signal - a single combined SERRA column would have
% wrongly read "1" from the L side alone).
for im = 1:length(muscleCodes)
    code = muscleCodes{im};
    Row.([code '_R']) = double(isKey(hasDataByID, ['R_' code]) && hasDataByID(['R_' code]));
    Row.([code '_L']) = double(isKey(hasDataByID, ['L_' code]) && hasDataByID(['L_' code]));
end

% =========================================================================
%  POWER (FORCE channel) - reference trial (ANALYTIC1) only, unchanged.
% =========================================================================
try
    analogDataRef = btkGetAnalogs(t.btk);
catch
    analogDataRef = struct();
end
refLabels      = fieldnames(analogDataRef);
isForcePresent = false;
forceHasData   = false;
for il = 1:length(refLabels)
    lbl = refLabels{il};
    if contains(lbl, 'FORCE', 'IgnoreCase', true)
        isForcePresent = true;
        sig = analogDataRef.(lbl);
        if hasRealSignal(sig)
            forceHasData = true;
        end
    end
end
Row.Force_Nombre = double(isForcePresent);
Row.Force        = double(isForcePresent && forceHasData);

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

function tf = hasRealSignal(sig)
% A channel counts as having a real (non-flat) signal if it is not empty,
% not entirely NaN, and shows some variation across samples. A dead/
% disconnected analog channel can be clipped/saturated at a constant
% value rather than literally all-zero (e.g. a fixed DC offset), so
% checking for ANY variation (range > 0) catches that case too, not just
% strict all-zero.
tf = false;
if isempty(sig), return; end
v = sig(~isnan(sig(:)));
if isempty(v), return; end
tf = (max(v) - min(v)) > 0;
end

function tf = markerValid(t, label)
tf = 0;
idx = find(strcmp({t.Marker.label}, label), 1);
if isempty(idx), return; end
traj = t.Marker(idx).Trajectory.full;
tf = double(~isempty(traj) && ~all(isnan(traj(:))));
end

function legacyGroups = detectLegacyGroups(t)
% Same logic as ReportDataAvailability.m: BTK markers unknown to the
% current markerSet, grouped by base name (trailing digits stripped).
% "count" only includes members with an actual valid (non-empty, non-all-
% NaN) trajectory: a marker name can remain in the C3D's marker-set
% template as an unused/empty label slot from an older protocol naming
% scheme even when it holds no real data for this particular session -
% counting it as "present" would be wrong (see clusterStatusHumerus, which
% hits exactly this with HDT/HTI/HBI vs EOS both present as labels).
legacyGroups = struct('base',{},'count',{},'labels',{});
if ~isfield(t,'btk') || isempty(t.btk), return; end
try
    allBtkMarkers = btkGetMarkers(t.btk);
catch
    return;
end
allNames = fieldnames(allBtkMarkers);
knownLabels = {t.Marker.label};
unknown = allNames(~ismember(allNames, knownLabels));
bases = regexprep(unknown, '\d+$', '');
uniqueBases = unique(bases);
for ib = 1:length(uniqueBases)
    b = uniqueBases{ib};
    if isempty(b), continue; end
    members = unknown(strcmp(bases, b));
    validMembers = members(cellfun(@(m) rawMarkerValid(allBtkMarkers.(m)), members));
    if length(validMembers) >= 2
        g.base = b; g.count = length(validMembers); g.labels = validMembers;
        legacyGroups(end+1) = g; %#ok<AGROW>
    end
end
end

function tf = rawMarkerValid(traj)
% Trajectory validity for a raw BTK marker (Nx3 matrix straight from
% btkGetMarkers), used for legacy markers that are not part of t.Marker.
tf = ~isempty(traj) && ~all(isnan(traj(:)));
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

function [present, typeStr] = clusterStatusHumerus(t, legacyGroups, sides)
% Like clusterStatus, but specific to the humeral cluster, which has 3
% priority tiers: 1) current 'Cluster_{s}A_0N' (type 'A'); 2) named legacy
% '{s}HDT'/'{s}HTI'/'{s}HBI' (type 'H'); 3) numbered legacy group with base
% '{s}EOS' (type 'EOS').
%
% Both naming schemes can appear as LABELS in the same C3D with valid
% (non-empty/non-NaN) trajectories even though only one of them is
% actually being tracked for this session - a leftover/unused label slot
% from an older marker-set template can hold a frozen/static position
% rather than genuinely absent data. Since real markers on a moving limb
% during ANALYTIC1 must show actual displacement over time, whichever of
% H/EOS shows real movement (range > 0 on at least one axis, see
% markerIsMoving) is taken as the active one; H wins the tie-break if both
% happen to show movement (kept from the original H > EOS priority).
totalCount = 0;
matchedType = '';

allBtkMarkers = struct();
if isfield(t,'btk') && ~isempty(t.btk)
    try
        allBtkMarkers = btkGetMarkers(t.btk);
    catch
    end
end

for is = 1:length(sides)
    s = sides{is};

    curLabels = arrayfun(@(n) sprintf('Cluster_%sA_0%d', s, n), 1:5, 'UniformOutput', false);
    curCount = 0;
    for il = 1:length(curLabels)
        curCount = curCount + markerValid(t, curLabels{il});
    end
    if curCount > 0
        totalCount = totalCount + curCount;
        if isempty(matchedType), matchedType = 'A'; end
        continue;
    end

    hLabels = {[s 'HDT'], [s 'HTI'], [s 'HBI']};
    hMovingCount = 0;
    for il = 1:length(hLabels)
        lbl = hLabels{il};
        if isfield(allBtkMarkers, lbl) && markerIsMoving(allBtkMarkers.(lbl))
            hMovingCount = hMovingCount + 1;
        end
    end

    legBase = [s, 'EOS'];
    gi = find(strcmpi({legacyGroups.base}, legBase), 1);
    eosMovingCount = 0;
    if ~isempty(gi)
        eosLabels = legacyGroups(gi).labels;
        eosMovingCount = sum(cellfun(@(m) isfield(allBtkMarkers, m) && ...
            markerIsMoving(allBtkMarkers.(m)), eosLabels));
    end

    if hMovingCount == 3
        totalCount = totalCount + hMovingCount;
        if isempty(matchedType), matchedType = 'H'; end
    elseif ~isempty(gi) && eosMovingCount >= 2
        totalCount = totalCount + eosMovingCount;
        if isempty(matchedType), matchedType = 'EOS'; end
    end
end
present = double(totalCount > 0);
if totalCount > 0
    typeStr = sprintf('%s (%d)', matchedType, totalCount);
else
    typeStr = '-';
end
end

function tf = markerIsMoving(traj)
% A marker counts as genuinely tracked (not a frozen/static leftover from
% an unused label slot) if its 3D trajectory shows real movement across
% the trial rather than being stuck at a constant position - same
% "variation" principle as hasRealSignal, applied per axis of the Nx3
% trajectory.
tf = false;
if isempty(traj), return; end
valid = traj(~any(isnan(traj), 2), :);
if size(valid,1) < 2, return; end
tf = any(max(valid,[],1) - min(valid,[],1) > 0);
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
% Thorax segment: no technical cluster (segDef clusterPfx='' in
% ReportDataAvailability.m), just the anatomical markers (C7/TV.../S1).
% Usable if at least one Thorax segment marker is valid.
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
% Identifies an analog channel by the muscle code it contains, regardless
% of what precedes/follows it in the name. 'FORCE' takes priority.
% Returns 'R_<code>' / 'L_<code>' / '_<code>' (unknown side) / 'FORCE' /
% '' (unrecognised channel, or a derived/processed channel - see below).
id = '';
if contains(lbl, {'_envelop','_onset'}, 'IgnoreCase', true)
    return; % derived/processed channels, not the raw recorded signal - ignored entirely
end
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
