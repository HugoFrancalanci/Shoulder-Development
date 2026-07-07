% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   May 2026
% -------------------------------------------------------------------------
% Description:   Aggregate thorax PostureSummary across all ANALYTIC and
%                FUNCTIONAL trials and display a formatted console summary
%                (one per session).
%
%                Console content (one row per trial) :
%                  - Trial task name
%                  - Posture angle (deg) + posture type
%                  - Moroder R / L
%                  - Rot Y  : mean | range (min / max)
%                  - Tilt X : mean | range (min / max)
%                  - Flex Z : mean | range (min / max)
%
% Inputs  : Trial    (struct array)  all trials from MAIN_Protocol_01
%           Patient  (struct)        from ImportSessionData
%           Session  (struct)        from ImportSessionData
%
% Outputs : Console display only
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function ExportPostureSummary(Trial, Patient, Session)

disp(' ');
disp('------------------------------------------------------------------');
disp('Patient posture summary');
disp(' ');

% -------------------------------------------------------------------------
% COLLECT DATA
% -------------------------------------------------------------------------
rows = {};

for k = 1:length(Trial)
    t = Trial(k);

    if ~(contains(t.task,'ANALYTIC') || contains(t.task,'FUNCTIONAL') || contains(t.task,'CALIBRATION3'))
        continue;
    end
    if isempty(t.Joint) || length(t.Joint) < 11
        continue;
    end
    if ~isfield(t.Joint(11),'PostureSummary') || isempty(t.Joint(11).PostureSummary)
        continue;
    end

    ps = t.Joint(11).PostureSummary;

    % osture + short type
    posture     = safeGet(ps,'thoracic_curvature_angle', NaN);
    postureType = getPostureShort(safeGetStr(ps,'thorax_posture_type','N/A'), posture);

    % Moroder

    SIR_R     = safeGet(ps,'SIR_R', NaN); 
    SIR_L     = safeGet(ps,'SIR_L', NaN);
    moroder_R = extractMoroderShort(safeGetStr(ps,'moroder_R','N/A'), SIR_R);
    moroder_L = extractMoroderShort(safeGetStr(ps,'moroder_L','N/A'), SIR_L);

    % Euler stats from Joint(11).Euler.full
    [rotY_mean,  rotY_range,  rotY_min,  rotY_max]  = getEulerStats(t.Joint(11), 2); % Y
    [tiltX_mean, tiltX_range, tiltX_min, tiltX_max] = getEulerStats(t.Joint(11), 1); % X
    [flex_mean,  flex_range,  flex_min,  flex_max]  = getEulerStats(t.Joint(11), 3); % Z

    rows{end+1} = {t.task, posture, postureType, moroder_R, moroder_L, ...
                   rotY_mean,  rotY_range,  rotY_min,  rotY_max, ...
                   tiltX_mean, tiltX_range, tiltX_min, tiltX_max, ...
                   flex_mean,  flex_range,  flex_min,  flex_max}; %#ok<AGROW>
end

if isempty(rows)
    disp('  Aucun trial ANALYTIC/FUNCTIONAL avec PostureSummary disponible.');
    return;
end

% -------------------------------------------------------------------------
% CONSOLE SUMMARY
% -------------------------------------------------------------------------
fprintf('  %-14s  %-20s  %-16s  %-16s  %-24s  %-24s  %-24s\n', ...
    'Task', 'Posture', ...
    'Mor.R', 'Mor.L', ...
'Tilt X : mean | range (min/max)', ...
'Rot Y : mean | range (min/max)', ...
'Flex Z : mean | range (min/max)');
disp(repmat('-', 1, 120));

for i = 1:length(rows)
    r = rows{i};
    fprintf('  %-14s  %-16s  %5s  %5s  %5.1f | %5.1f (%5.1f/%5.1f)  %5.1f | %5.1f (%5.1f/%5.1f)  %5.1f | %5.1f (%5.1f/%5.1f)\n', ...
        r{1},  r{3},  r{4},  r{5}, ...
        r{10}, r{11}, r{12}, r{13}, ... 
        r{6},  r{7},  r{8},  r{9},...
        r{14}, r{15}, r{16}, r{17});
end

disp(repmat('-', 1, 120));
disp('All values in deg.');

end

% -------------------------------------------------------------------------
%  EULER STATS FROM Joint(11).Euler.full
%  dof : 1=X(tilt), 2=Y(rot), 3=Z(flex)
% -------------------------------------------------------------------------
function [mn, rng, mn_val, mx_val] = getEulerStats(joint, dof)
mn = NaN; rng = NaN; mn_val = NaN; mx_val = NaN;
if isempty(joint.Euler.full), return; end
data = squeeze(joint.Euler.full(1, dof, :));
if isempty(data), return; end
mn     = mean(data,  'omitnan');
mn_val = min(data,   [], 'omitnan');
mx_val = max(data,   [], 'omitnan');
rng    = mx_val - mn_val;
end

% -------------------------------------------------------------------------
%  POSTURE TYPE
% -------------------------------------------------------------------------
function short = getPostureShort(full, posture)
if contains(full,'Erect')
    short = sprintf('Erect-like (%.1f deg)', posture);
elseif contains(full,'Slouched')
    short = sprintf('Slouched-like (%.1f deg)', posture);
else
    short = sprintf('N/A (%.1f deg)', posture);
end
end

function val = safeGet(s, field, default)
if isfield(s,field) && ~isempty(s.(field)) && ~isnan(s.(field))
    val = s.(field);
else
    val = default;
end
end

function val = safeGetStr(s, field, default)
if isfield(s,field) && ~isempty(s.(field))
    val = s.(field);
else
    val = default;
end
end

function short = extractMoroderShort(full, SIR)
if nargin < 2, SIR = NaN; end
if isnan(SIR), valStr = '';
else,          valStr = sprintf(' (%.1f deg)', SIR);
end
if contains(full,'Type A'),     short = ['A', valStr];
elseif contains(full,'Type B'), short = ['B', valStr];
elseif contains(full,'Type C'), short = ['C', valStr];
else,                           short = 'N/A';
end
end