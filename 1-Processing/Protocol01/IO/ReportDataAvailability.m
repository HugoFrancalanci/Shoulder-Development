% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   June 2026
% -------------------------------------------------------------------------
% Description:   Comprehensive data availability report for a patient session.
%
%                Sections:
%                  1. Trials present
%                  2. Raw C3D content (BTK)
%                  3. Markers — segment summary + full nominal listing
%                     + legacy cluster detection (numbered groups in BTK)
%                  4. EMG channels — checked across ALL FOUR ANALYTIC1-4
%                     tasks (not just the ANALYTIC1 reference trial used
%                     everywhere else in this report): a channel is only
%                     "Valid" if it has a real signal in every one of them.
%                  5. Kinematic cycles per ANALYTIC task
%                  6. Processing status
%
%                Legacy cluster logic:
%                  Any BTK marker group sharing the same base name + trailing
%                  digits (e.g. REOS1/2/3) that is NOT in the current
%                  markerSet is flagged as a legacy cluster group.
%                  In the segment summary, when all current-protocol cluster
%                  markers are absent AND a legacy group exists with the same
%                  side prefix (R/L), the line reads [LEGACY: BASE xN]
%                  instead of [!].
%                  Humerus segment special case: an even older naming, used
%                  at the very start of the protocol, has 3 individually-named
%                  markers {R/L}HDT/{R/L}HTI/{R/L}HBI (no trailing digits, so
%                  never grouped by the generic base-name logic above). When
%                  all 3 are present in the C3D, they take priority over any
%                  EOS legacy group for that side and are reported as
%                  [LEGACY: {R/L}H x3] instead.
%
% Inputs  : Trial    (struct array) — all trials from MAIN_Protocol_01
%           Patient  (struct, optional) — from ImportSessionData
%           Session  (struct, optional) — from ImportSessionData
%           Pathology(struct, optional) — from ImportSessionData
%
% Outputs : Report (struct)
%           .patientID / .sessionDate / .side
%           .trials.(taskName).present
%           .segments.(segName).total / .present / .missing / .cluster
%           .emg.total / .present / .empty / .labels_present / .labels_empty
%           .cycles.(taskName).R / .L
%           .legacy_groups — struct array: .base .count .labels
%           .kinematics_ok
% -------------------------------------------------------------------------

function Report = ReportDataAvailability(Trial, varargin)

Patient   = [];
Session   = [];
Pathology = [];
c3dFiles  = [];
if nargin >= 2, Patient   = varargin{1}; end
if nargin >= 3, Session   = varargin{2}; end
if nargin >= 4, Pathology = varargin{3}; end
if nargin >= 5, c3dFiles  = varargin{4}; end

SEP = repmat('=',1,66);

disp(' ');
disp(SEP);
disp('  PATIENT DATA AVAILABILITY REPORT');

Report.patientID    = '';
Report.sessionDate  = '';
Report.side         = '';
Report.legacy_groups = struct('base',{},'count',{},'labels',{});
Report.kinematics_ok = false;
if ~isempty(Patient),   Report.patientID   = Patient.ID; end
if ~isempty(Session),   try; Report.sessionDate = datestr(Session.date,'dd.mm.yyyy'); catch; end; end
if ~isempty(Pathology), Report.side        = Pathology.Diagnosis.side; end

% =========================================================================
%  SECTION 1 — TRIALS PRESENT
% =========================================================================
disp(SEP);
disp('  TRIALS AVAILABLE');
disp('  ----------------');

allTrialTasks = {Trial.task};

% C3D file names for detecting trials not loaded in Trial struct (STATIC, ISOMETRIC...)
c3dNames = {};
if ~isempty(c3dFiles)
    c3dNames = {c3dFiles.name};
end

taskGroups = { ...
    'STATIC',       6; ...
    'CALIBRATION',  6; ...
    'ISOMETRIC',    6; ...
    'ANALYTIC',     5; ...
    'FUNCTIONAL',   4; ...
};

Report.trials = struct();
for ig = 1:size(taskGroups,1)
    prefix = taskGroups{ig,1};
    nmax   = taskGroups{ig,2};
    groupTasks = arrayfun(@(n) sprintf('%s%d',prefix,n), 1:nmax, 'UniformOutput', false);
    fprintf('  %s\n', prefix);
    lineStr = '  '; col = 0;
    for it = 1:nmax
        tk    = groupTasks{it};
        % Check Trial struct first, then C3D file names as fallback
        found = ismember(tk, allTrialTasks) || ...
                any(cellfun(@(f) contains(f, tk), c3dNames));
        Report.trials.(matlab.lang.makeValidName(tk)).present = found;
        lineStr = [lineStr, sprintf('%-14s%-6s   ', tk, ternStr(found,'[OK]','[--]'))]; %#ok<AGROW>
        col = col + 1;
        if col == 3, disp(lineStr); lineStr = '  '; col = 0; end
    end
    if col > 0, disp(lineStr); end
    disp(' ');
end

% =========================================================================
%  FIND REFERENCE TRIAL — first ANALYTIC1
% =========================================================================
tidx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task,'ANALYTIC1'), tidx = k; break; end
end

if isempty(tidx)
    disp(' ');
    disp('  [!] ANALYTIC1 not found — skipping marker / EMG / cycle sections.');
    Report.segments = []; Report.emg = []; Report.cycles = [];
    disp(SEP); disp(' ');
    return;
end

t = Trial(tidx);

% =========================================================================
%  SECTION 2 — RAW C3D CONTENT (BTK)
% =========================================================================
disp(SEP);
disp('  RAW C3D CONTENT  (reference: ANALYTIC1)');
disp('  -----------------------------------------');

btk_available = isfield(t,'btk') && ~isempty(t.btk);
allBtkMarkers = {};

if btk_available
    try
        allBtkMarkers = fieldnames(btkGetMarkers(t.btk));
        fprintf('  C3D markers : %d\n', length(allBtkMarkers));
        printList(allBtkMarkers, 6);
    catch
        disp('  [!] Could not read C3D markers from BTK.');
    end
    try
        analogData = btkGetAnalogs(t.btk);
        allAnalogs = fieldnames(analogData);
        n_ok  = 0;
        n_empty = 0;
        fprintf('  C3D analogs : %d\n', length(allAnalogs));
        lineStr = '  '; col = 0;
        for ia = 1:length(allAnalogs)
            lbl = allAnalogs{ia};
            sig = analogData.(lbl);
            hasData = ~isempty(sig) && ~all(isnan(sig(:))) && any(sig(:) ~= 0);
            if hasData; n_ok = n_ok + 1; tag = '[OK]';
            else;        n_empty = n_empty + 1; tag = '[--]';
            end
            lineStr = [lineStr, sprintf('%-20s%-6s   ', lbl, tag)]; %#ok<AGROW>
            col = col + 1;
            if col == 3, disp(lineStr); lineStr = '  '; col = 0; end
        end
        if col > 0, disp(lineStr); end
        fprintf('  -> signal present: %d   empty: %d\n', n_ok, n_empty);
    catch
        disp('  [!] Could not read C3D analogs from BTK.');
    end
    try
        fskin = btkGetPointFrequency(t.btk);
        fprintf('  Fs markers  : %d Hz\n', fskin);
    catch
        disp('  [!] Could not read fs markers from BTK.');
    end
    try
        fsemg = btkGetAnalogFrequency(t.btk);
        fprintf('  Fs analogs  : %d Hz\n', fsemg);
    catch
        disp('  [!] Could not read fs analogs from BTK.');
    end
else
    disp('  (BTK not available in Trial struct)');
end

% =========================================================================
%  PRE-COMPUTE LEGACY GROUPS
%  Find numbered groups in BTK not in current markerSet. "count" only
%  includes members with an actual valid (non-empty, non-all-NaN)
%  trajectory: a marker name can remain in the C3D's marker-set template
%  as an unused/empty label slot from an older protocol naming scheme
%  even when it holds no real data for this particular session (e.g.
%  HDT/HTI/HBI and EOS can both appear as labels while only one of them
%  actually has recorded data) - counting it as "present" would be wrong.
% =========================================================================
legacyGroups = struct('base',{},'count',{},'labels',{});

if btk_available && ~isempty(allBtkMarkers)
    % Current markerSet labels
    knownLabels = {};
    for im = 1:length(t.Marker)
        knownLabels{end+1} = t.Marker(im).label; %#ok<AGROW>
    end

    % BTK markers not in current markerSet
    unknown = allBtkMarkers(~ismember(allBtkMarkers, knownLabels));

    % Group by base name (strip trailing digits)
    bases = regexprep(unknown, '\d+$', '');
    uniqueBases = unique(bases);

    try
        rawMarkerData = btkGetMarkers(t.btk);
    catch
        rawMarkerData = struct();
    end

    for ib = 1:length(uniqueBases)
        b = uniqueBases{ib};
        if isempty(b), continue; end
        members = unknown(strcmp(bases, b));
        validMembers = members(cellfun(@(m) isfield(rawMarkerData, m) && ...
            ~isempty(rawMarkerData.(m)) && ~all(isnan(rawMarkerData.(m)(:))), members));
        if length(validMembers) >= 2
            g.base   = b;
            g.count  = length(validMembers);
            g.labels = validMembers;
            legacyGroups(end+1) = g; %#ok<AGROW>
        end
    end
end

Report.legacy_groups = legacyGroups;

% =========================================================================
%  SECTION 3 — MARKERS
% =========================================================================
disp(SEP);
disp('  MARKERS  (reference: ANALYTIC1)');

% ------------------------------------------------------------------
%  3a. Segment summary
% ------------------------------------------------------------------
disp(' ');
fprintf('  %-18s  %5s  %7s  %7s\n','Segment','Total','Present','Missing');
disp('  --------------------------------------------------------');

% segDef: segName | currentClusterPrefix | sidePrefix for legacy matching
segDef = { ...
    'Thorax',    '',            ''; ...
    'RScapula',  'Cluster_RS_', 'R'; ...
    'LScapula',  'Cluster_LS_', 'L'; ...
    'RHumerus',  'Cluster_RA_', 'R'; ...
    'LHumerus',  'Cluster_LA_', 'L'; ...
    'RForearm',  'Cluster_RF_', 'R'; ...
    'LForearm',  'Cluster_LF_', 'L'; ...
};

Report.segments = struct();

for is = 1:size(segDef,1)
    segName    = segDef{is,1};
    clusterPfx = segDef{is,2};
    sidePfx    = segDef{is,3};

    seg_total = 0; seg_present = 0;
    seg_missing_all  = {};
    clust_total = 0; clust_present = 0;
    clust_missing = {};

    for im = 1:length(t.Marker)
        if ~strcmp(t.Marker(im).Body.Segment.label, segName), continue; end
        seg_total = seg_total + 1;
        lbl  = t.Marker(im).label;
        traj = t.Marker(im).Trajectory.full;
        ok   = ~isempty(traj) && ~all(isnan(traj(:)));
        if ok; seg_present = seg_present + 1;
        else;  seg_missing_all{end+1} = lbl; %#ok<AGROW>
        end
        if ~isempty(clusterPfx) && startsWith(lbl, clusterPfx)
            clust_total = clust_total + 1;
            if ok; clust_present = clust_present + 1;
            else;  clust_missing{end+1} = lbl; %#ok<AGROW>
            end
        end
    end

    % Non-cluster missing markers (for display)
    nonClustMiss = seg_missing_all(~startsWith(seg_missing_all, clusterPfx));

    % Count "real" missing: exclude current-protocol cluster markers when
    % they're all absent and a legacy replacement exists for this segment
    legacyForSeg = findLegacyForSide(legacyGroups, sidePfx);

    % Humerus special case: named legacy markers {s}HDT/{s}HTI/{s}HBI (no
    % trailing digits, so never grouped by the base-name logic above) take
    % priority over any EOS/other legacy match for this side when all 3
    % have a real valid trajectory in the C3D, even if an EOS group also
    % exists. Checked against actual trajectory validity, not just label
    % presence, since HDT/HTI/HBI can remain as unused label slots in the
    % marker-set template while EOS is the one that actually has data.
    if (strcmp(segName,'RHumerus') || strcmp(segName,'LHumerus')) && ~isempty(sidePfx) && btk_available
        hLabels = {[sidePfx 'HDT'], [sidePfx 'HTI'], [sidePfx 'HBI']};
        try
            hMarkerData = btkGetMarkers(t.btk);
        catch
            hMarkerData = struct();
        end
        hValid = cellfun(@(m) isfield(hMarkerData, m) && ...
            ~isempty(hMarkerData.(m)) && ~all(isnan(hMarkerData.(m)(:))), hLabels);
        if sum(hValid) == 3
            legacyForSeg = struct('base', {[sidePfx 'H']}, 'count', {3}, 'labels', {hLabels});
        end
    end

    allClusterMissing = ~isempty(clusterPfx) && clust_total > 0 && clust_present == 0;
    hasLegacyReplacement = allClusterMissing && ~isempty(legacyForSeg);

    seg_miss_n = length(nonClustMiss);
    if ~hasLegacyReplacement
        seg_miss_n = seg_miss_n + (clust_total - clust_present);
    end

    seg_status = ternStr(seg_miss_n == 0 && (~allClusterMissing || hasLegacyReplacement), '[OK]', '[!]');
    fprintf('  %-18s  %5d  %7d  %7d  %s\n', segName, seg_total, seg_present, seg_miss_n, seg_status);

    % Cluster sub-line
    if ~isempty(clusterPfx) && clust_total > 0
        clust_miss_n = clust_total - clust_present;
        if hasLegacyReplacement
            legacyStr = strjoin(arrayfun(@(g) sprintf('%s x%d', g.base, g.count), ...
                legacyForSeg, 'UniformOutput', false), ', ');
            fprintf('    └ cluster %-10s %3d  %7d  %7d  [LEGACY: %s]\n', ...
                clusterPfx, clust_total, clust_present, clust_miss_n, legacyStr);
        else
            fprintf('    └ cluster %-10s %3d  %7d  %7d  %s\n', ...
                clusterPfx, clust_total, clust_present, clust_miss_n, ...
                ternStr(clust_miss_n==0,'[OK]','[!]'));
            if ~isempty(clust_missing)
                fprintf('      missing: %s\n', strjoin(clust_missing,', '));
            end
        end
    elseif ~isempty(clusterPfx) && clust_total == 0
        % Cluster markers absent from markerSet entirely (shouldn't happen normally)
        if hasLegacyReplacement
            legacyStr = strjoin(arrayfun(@(g) sprintf('%s x%d', g.base, g.count), ...
                legacyForSeg, 'UniformOutput', false), ', ');
            fprintf('    └ cluster %-10s  [LEGACY: %s]\n', clusterPfx, legacyStr);
        end
    end

    % Non-cluster missing
    if ~isempty(nonClustMiss)
        fprintf('      missing: %s\n', strjoin(nonClustMiss,', '));
    end

    sfn = matlab.lang.makeValidName(segName);
    Report.segments.(sfn).total   = seg_total;
    Report.segments.(sfn).present = seg_present;
    Report.segments.(sfn).missing = seg_missing_all;
    if ~isempty(clusterPfx)
        Report.segments.(sfn).cluster.prefix       = clusterPfx;
        Report.segments.(sfn).cluster.total        = clust_total;
        Report.segments.(sfn).cluster.present      = clust_present;
        Report.segments.(sfn).cluster.missing      = clust_missing;
        Report.segments.(sfn).cluster.legacy_used  = hasLegacyReplacement;
        Report.segments.(sfn).cluster.legacy_groups = legacyForSeg;
    end
end

% ------------------------------------------------------------------
%  3b. Full nominal listing — valid then missing (non-cluster only
%      when legacy protocol detected, to avoid noise)
% ------------------------------------------------------------------
disp(' ');
disp('  --- Valid markers (current markerSet) ---');
valid_lbls   = {};
missing_lbls = {};
for im = 1:length(t.Marker)
    traj = t.Marker(im).Trajectory.full;
    if ~isempty(traj) && ~all(isnan(traj(:)))
        valid_lbls{end+1} = t.Marker(im).label; %#ok<AGROW>
    else
        missing_lbls{end+1} = t.Marker(im).label; %#ok<AGROW>
    end
end
fprintf('  Count: %d / %d\n', length(valid_lbls), length(t.Marker));
printList(valid_lbls, 6);

if ~isempty(missing_lbls)
    % Separate cluster markers (expected missing in legacy protocol) from
    % true anatomical landmarks that should always be present
    clusterPrefixes = {'Cluster_RS_','Cluster_LS_','Cluster_RA_','Cluster_LA_','Cluster_RF_','Cluster_LF_'};
    isClusterMarker = cellfun(@(lbl) any(cellfun(@(p) startsWith(lbl,p), clusterPrefixes)), missing_lbls);
    truelyMissing   = missing_lbls(~isClusterMarker);
    clusterMissing  = missing_lbls(isClusterMarker);

    if ~isempty(truelyMissing)
        disp(' ');
        disp('  --- Missing anatomical landmarks ---');
        fprintf('  Count: %d\n', length(truelyMissing));
        printList(truelyMissing, 6);
    end

    if ~isempty(clusterMissing)
        disp(' ');
        disp('  --- Cluster markers not in C3D (expected if legacy protocol) ---');
        fprintf('  Count: %d\n', length(clusterMissing));
        printList(clusterMissing, 6);
    end
end

% ------------------------------------------------------------------
%  3c. Legacy numbered groups
% ------------------------------------------------------------------
disp(' ');
disp('  --- Legacy numbered groups detected in C3D ---');
if isempty(legacyGroups)
    disp('  None detected.');
else
    fprintf('  %-12s  %5s  %s\n','Base','Count','Labels');
    disp('  ------------------------------------------------');
    for ig = 1:length(legacyGroups)
        g = legacyGroups(ig);
        fprintf('  %-12s  %5d  %s\n', g.base, g.count, strjoin(g.labels,', '));
    end
end

% =========================================================================
%  SECTION 4 — EMG
% =========================================================================
disp(SEP);
disp('  EMG CHANNELS  (checked across ANALYTIC1-4)');
disp('  --------------------------------------------');

% Trial.Emg/Trial.EMG is never populated by runProtocol01/MAIN_Protocol_01
% (the only function that would fill it, Init/InitialiseEmgSignals.m, is
% never called) - reading raw BTK analog channels instead, same source and
% hasData check as Section 2 "RAW C3D CONTENT" above. FORCE is excluded
% here (reported separately, not an EMG channel).
%
% Unlike every other section in this report, EMG is checked across ALL
% FOUR ANALYTIC1-4 tasks that exist for the session, not just the
% ANALYTIC1 reference trial: a channel can look fine on ANALYTIC1 while
% actually being dead on e.g. ANALYTIC3. A channel is only marked "Valid"
% if it has a real signal in EVERY one of those tasks; missing/empty in
% even a single one (or entirely absent from that trial's C3D) makes it
% "Empty" overall.
analyticTasks  = {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4'};
hasDataPerTask = {}; % one label->hasData map per existing ANALYTIC1-4 task

for itask = 1:length(analyticTasks)
    tidx2 = [];
    for k = 1:length(Trial)
        if strcmp(Trial(k).task, analyticTasks{itask}), tidx2 = k; break; end
    end
    if isempty(tidx2) || ~isfield(Trial(tidx2),'btk') || isempty(Trial(tidx2).btk)
        continue;
    end
    try
        analogData = btkGetAnalogs(Trial(tidx2).btk);
    catch
        continue;
    end
    labels  = fieldnames(analogData);
    taskMap = containers.Map('KeyType','char','ValueType','logical');
    for il = 1:length(labels)
        lbl = labels{il};
        if contains(lbl, 'FORCE', 'IgnoreCase', true), continue; end
        sig = analogData.(lbl);
        taskMap(lbl) = ~isempty(sig) && ~all(isnan(sig(:))) && any(sig(:) ~= 0);
    end
    hasDataPerTask{end+1} = taskMap; %#ok<AGROW>
end

allLabels = {};
for it2 = 1:length(hasDataPerTask)
    allLabels = union(allLabels, keys(hasDataPerTask{it2}));
end

Report.emg.total          = 0;
Report.emg.present        = 0;
Report.emg.empty          = 0;
Report.emg.labels_present = {};
Report.emg.labels_empty   = {};

if isempty(allLabels)
    disp('  No EMG (non-FORCE) analog channels found in C3D.');
else
    n_emg = length(allLabels);
    Report.emg.total = n_emg;

    for i = 1:n_emg
        lbl = allLabels{i};
        hasData = ~isempty(hasDataPerTask);
        for it2 = 1:length(hasDataPerTask)
            tm = hasDataPerTask{it2};
            hasData = hasData && isKey(tm, lbl) && tm(lbl);
        end
        if hasData
            Report.emg.present = Report.emg.present + 1;
            Report.emg.labels_present{end+1} = lbl;
        else
            Report.emg.empty = Report.emg.empty + 1;
            Report.emg.labels_empty{end+1} = lbl;
        end
    end

    fprintf('  Total: %d   Present: %d   Empty: %d\n', n_emg, Report.emg.present, Report.emg.empty);

    if ~isempty(Report.emg.labels_present)
        disp(' ');
        disp('  Valid EMG channels :');
        printList(Report.emg.labels_present, 7);
    end
    if ~isempty(Report.emg.labels_empty)
        disp(' ');
        disp('  [!] Empty EMG channels :');
        printList(Report.emg.labels_empty, 7);
    end
end

% =========================================================================
%  SECTION 5 — KINEMATIC CYCLES
% =========================================================================
disp(SEP);
disp('  KINEMATIC CYCLES');
fprintf('  %-14s  %8s  %8s  %s\n','Task','R cycles','L cycles','Status');
disp('  -----------------------------------------------');

analyticTasks = {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4','ANALYTIC5'};
Report.cycles = struct();

for ia = 1:length(analyticTasks)
    tk = analyticTasks{ia};
    kidx = [];
    for k = 1:length(Trial)
        if strcmp(Trial(k).task, tk), kidx = k; break; end
    end
    if isempty(kidx), continue; end

    tr = Trial(kidx);
    nR = 0; nL = 0;
    if isfield(tr,'Rcycle') && ~isempty(tr.Rcycle), nR = length(tr.Rcycle); end
    if isfield(tr,'Lcycle') && ~isempty(tr.Lcycle), nL = length(tr.Lcycle); end

    if     nR == 0 && nL == 0, status = '[!] No cycles';
    elseif nR == 0,             status = '[!] No R cycles';
    elseif nL == 0,             status = '[!] No L cycles';
    else,                       status = '[OK]';
    end
    fprintf('  %-14s  %8d  %8d  %s\n', tk, nR, nL, status);

    Report.cycles.(matlab.lang.makeValidName(tk)).R = nR;
    Report.cycles.(matlab.lang.makeValidName(tk)).L = nL;
end

% =========================================================================
%  SECTION 6 — PROCESSING STATUS
% =========================================================================
disp(SEP);
disp('  PROCESSING STATUS  (reference: ANALYTIC1)');
disp('  -------------------------------------------');

hasJoints  = isfield(t,'Joint')   && ~isempty(t.Joint)   && isfield(t.Joint(1),'Euler');
hasThorax  = isfield(t,'Segment') && ~isempty(t.Segment);
hasRcycles = isfield(t,'Rcycle')  && ~isempty(t.Rcycle);
hasLcycles = isfield(t,'Lcycle')  && ~isempty(t.Lcycle);

fprintf('  Kinematics (Joints) : %s\n', ternStr(hasJoints,  '[OK]', '[missing]'));
fprintf('  Segments defined    : %s\n', ternStr(hasThorax,  '[OK]', '[missing]'));
fprintf('  Right cycles cut    : %s\n', ternStr(hasRcycles, '[OK]', '[missing/0]'));
fprintf('  Left  cycles cut    : %s\n', ternStr(hasLcycles, '[OK]', '[missing/0]'));

Report.kinematics_ok = hasJoints && hasThorax;

disp(SEP);
disp(' ');

end

% =========================================================================
%  FIND LEGACY GROUPS MATCHING A SIDE PREFIX
%  Returns subset of legacyGroups whose base name starts with sidePfx
% =========================================================================
function match = findLegacyForSide(legacyGroups, sidePfx)
match = struct('base',{},'count',{},'labels',{});
if isempty(sidePfx) || isempty(legacyGroups), return; end
for ig = 1:length(legacyGroups)
    if startsWith(legacyGroups(ig).base, sidePfx)
        match(end+1) = legacyGroups(ig); %#ok<AGROW>
    end
end
end

% =========================================================================
%  HELPERS
% =========================================================================
function s = ternStr(cond, a, b)
if cond, s = a; else, s = b; end
end

function printList(lst, ncols)
if isempty(lst), disp('    (none)'); return; end
for i = 1:length(lst)
    if mod(i-1, ncols) == 0, fprintf('    '); end
    fprintf('%-20s', lst{i});
    if mod(i, ncols) == 0 || i == length(lst), fprintf('\n'); end
end
end
