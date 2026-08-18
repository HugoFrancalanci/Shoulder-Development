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
% Description:   Console summary table of kinematic contributions for
%                presentation purposes.
%
%                Trials : ANALYTIC1, ANALYTIC2
%                Sides  : Right (R) and Left (L) separately
%
%                Functional analysis (table 1) uses the sequence-free
%                quaternion total rotation angle (Joint(i).QuatAngle, see
%                Core/ComputeQuaternionKinematics.m) instead of a single
%                Euler DOF -- no per-task DOF/sequence selection needed,
%                since the total angle does not depend on which plane the
%                movement happens to be in.
%
%                Metrics :
%                  HG range : max(QuatAngle) - min(QuatAngle) on cycle
%                  %GH      : range_GH / range_HG * 100
%                  %ST      : range_ST / range_HG * 100
%                  %TH      : range_TH / range_HG * 100
%
%                Clinical analysis (table 2, unchanged) stays Euler/HT-
%                referenced, matching prior clinical-literature convention.
%
% Inputs  : Trial (struct array) all trials from MAIN_Protocol_01
% Outputs : Console table
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function ExportKinematicsSummary(Trial)

disp(' ');
disp('------------------------------------------------------------------');
disp('Kinematics summary');
disp(' ');
disp('Functional analysis (quaternions)');
disp('------------------------------------------------');

% -------------------------------------------------------------------------
% TARGET TRIALS
% -------------------------------------------------------------------------
targetTasks = {'ANALYTIC2'};

% -------------------------------------------------------------------------
% COLLECT DATA
% -------------------------------------------------------------------------
rows = {};

for itask = 1:length(targetTasks)
    task = targetTasks{itask};

    % Find trial
    tidx = [];
    for k = 1:length(Trial)
        if contains(Trial(k).task, task)
            tidx = k;
            break;
        end
    end
    if isempty(tidx), continue; end

    t       = Trial(tidx);
    isCalib = contains(task, 'CALIBRATION');

    % ---- RIGHT SIDE ----
    [hg_R, gh_R, st_R, th_R] = computeQuatContributions(t, 12, 2, 3, 11, isCalib, 'rcycle');
    pgh_R = safePct(gh_R, hg_R);
    pst_R = safePct(st_R, hg_R);
    pth_R = safePct(th_R, hg_R);
    rows{end+1} = {[task, ' R'], hg_R, gh_R, pgh_R, st_R, pst_R, th_R, pth_R}; %#ok<AGROW>

    % ---- LEFT SIDE ----
    [hg_L, gh_L, st_L, th_L] = computeQuatContributions(t, 13, 7, 8, 11, isCalib, 'lcycle');
    pgh_L = safePct(gh_L, hg_L);
    pst_L = safePct(st_L, hg_L);
    pth_L = safePct(th_L, hg_L);
    rows{end+1} = {[task, ' L'], hg_L, gh_L, pgh_L, st_L, pst_L, th_L, pth_L}; %#ok<AGROW>
end

if isempty(rows)
    disp('  No data available.');
    return;
end

% -------------------------------------------------------------------------
% CONSOLE TABLE
% -------------------------------------------------------------------------
fprintf('\n');
fprintf('  %-16s  %10s  %10s  %6s  %10s  %6s  %10s  %6s\n', ...
    'Trial', 'HG range', 'GH range', '%GH', 'ST range', '%ST', 'TH range', '%TH');
disp(repmat('-', 1, 90));

for i = 1:length(rows)
    r = rows{i};
    if i > 1 && ~strcmp(rows{i}{1}(1:end-2), rows{i-1}{1}(1:end-2))
        disp(repmat('-', 1, 90));
    end
    fprintf('  %-16s  %9.1f°  %9.1f°  %5.1f%%  %9.1f°  %5.1f%%  %9.1f°  %5.1f%%\n', ...
        r{1}, r{2}, r{3}, r{4}, r{5}, r{6}, r{7}, r{8});
end

disp(repmat('-', 1, 90));
disp('  Range = amplitude de l''angle de rotation total (quaternion), pas d''un DOF Euler isole.');
disp('  %  = contribution range / HG range * 100');

% -------------------------------------------------------------------------
% TABLEAU 2 — CONTRIBUTIONS EXPRIMÉES EN % DE HT
% -------------------------------------------------------------------------
disp(' ');
disp('Clinical analysis (euler)');
disp('-------------------');

rows2 = {};

for itask = 1:length(targetTasks)
    task = targetTasks{itask};

    tidx = [];
    for k = 1:length(Trial)
        if contains(Trial(k).task, task)
            tidx = k;
            break;
        end
    end
    if isempty(tidx), continue; end

    t       = Trial(tidx);
    isCalib = contains(task, 'CALIBRATION');

    % ANALYTIC2 : HT DOF1 X = abduction (XZY)
    dofHT = 1;
    dofGH = 1;
    dofST = 1;
    dofTX = 3;

    % ---- RIGHT SIDE ----
    ht_R = getRangeCycle(t, 1, dofHT, 'rcycle');
    gh_R = getRangeCycle(t, 2, dofGH, 'rcycle');
    st_R = getRangeCycle(t, 3, dofST, 'rcycle');
    th_R = getRangeCycleTH(t, 11, dofTX, 'rcycle');
    pgh_R = safePct(gh_R, ht_R);
    pst_R = safePct(st_R, ht_R);
    pth_R = safePct(th_R, ht_R);
    rows2{end+1} = {[task, ' R'], ht_R, gh_R, pgh_R, st_R, pst_R, th_R, pth_R}; %#ok<AGROW>

    % ---- LEFT SIDE ----
    ht_L = getRangeCycle(t, 6, dofHT, 'lcycle');
    gh_L = getRangeCycle(t, 7, dofGH, 'lcycle');
    st_L = getRangeCycle(t, 8, dofST, 'lcycle');
    th_L = getRangeCycleTH(t, 11, dofTX, 'lcycle');
    pgh_L = safePct(gh_L, ht_L);
    pst_L = safePct(st_L, ht_L);
    pth_L = safePct(th_L, ht_L);
    rows2{end+1} = {[task, ' L'], ht_L, gh_L, pgh_L, st_L, pst_L, th_L, pth_L}; %#ok<AGROW>
end

if ~isempty(rows2)
    fprintf('\n');
    fprintf('  %-16s  %10s  %10s  %6s  %10s  %6s  %10s  %6s\n', ...
        'Trial', 'HT range', 'GH range', '%GH', 'ST range', '%ST', 'TH range', '%TH');
    disp(repmat('-', 1, 90));

    for i = 1:length(rows2)
        r = rows2{i};
        if i > 1 && ~strcmp(rows2{i}{1}(1:end-2), rows2{i-1}{1}(1:end-2))
            disp(repmat('-', 1, 90));
        end
        fprintf('  %-16s  %9.1f°  %9.1f°  %5.1f%%  %9.1f°  %5.1f%%  %9.1f°  %5.1f%%\n', ...
            r{1}, r{2}, r{3}, r{4}, r{5}, r{6}, r{7}, r{8});
    end

    disp(repmat('-', 1, 90));
    disp('  HT : humero-thoracic (Joint 1/6, DOF1 X abduction XZY)');
    disp('  %  = contribution range / HT range * 100');
end

end

function [hg_range, gh_range, st_range, th_range] = ...
    computeQuatContributions(t, jiHG, jiGH, jiST, jiTH, isCalib, cycField)

hg_range = getQuatRange(t, jiHG, isCalib, cycField);
gh_range = getQuatRange(t, jiGH, isCalib, cycField);
st_range = getQuatRange(t, jiST, isCalib, cycField);
th_range = getQuatRangeTH(t, jiTH, isCalib, cycField);
end

function r = getQuatRange(t, ji, isCalib, cycField)
r = NaN;
if length(t.Joint) < ji, return; end
if isCalib
    if isempty(t.Joint(ji).QuatAngle.full), return; end
    data = squeeze(t.Joint(ji).QuatAngle.full);
    r    = max(data, [], 'omitnan') - min(data, [], 'omitnan');
else
    if isempty(t.Joint(ji).QuatAngle.(cycField)), return; end
    data = squeeze(t.Joint(ji).QuatAngle.(cycField));
    if isvector(data), data = data(:); end
    ranges = max(data, [], 1) - min(data, [], 1);
    r      = mean(ranges, 'omitnan');
end
end

function r = getQuatRangeTH(t, ji, isCalib, cycField)
r  = NaN;
if length(t.Joint) < ji, return; end
cf = cycField;
if ~isCalib && (~isfield(t.Joint(ji).QuatAngle, cf) || isempty(t.Joint(ji).QuatAngle.(cf)))
    if strcmp(cf,'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
r = getQuatRange(t, ji, isCalib, cf);
end

function r = getRangeCycle(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function r = getRangeCycleTH(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji, return; end
cf = cycField;
if isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf,'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function p = safePct(num, den)
if isnan(num) || isnan(den) || den == 0
    p = NaN;
else
    p = num / den * 100;
end
end