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
%                Metrics :
%                  HG range : max(|DOF1|) - min(|DOF1|) on cycle
%                  %GH      : range_GH / range_HG * 100
%                  %ST      : range_ST / range_HG * 100
%                  %TH      : range_TH / range_HG * 100
%
%                DOF mapping per task :
%                  ANALYTIC1 (sagittal elevation) :
%                    HG Joint(12/13) DOF1 X — elevation     (YXY)
%                    GH Joint(2/7)   DOF3 Z — flexion       (ZXY)
%                    ST Joint(3/8)   DOF1 X — upward rot.   (YXZ)
%                    TH Joint(11)    DOF3 Z — flexion       (ZXY)
%                  ANALYTIC2 (coronal elevation) :
%                    HG Joint(12/13) DOF1 X — elevation     (YXY)
%                    GH Joint(2/7)   DOF1 X — abduction     (XZY)
%                    ST Joint(3/8)   DOF1 X — upward rot.   (YXZ)
%                    TH Joint(11)    DOF3 Z — flexion       (ZXY)
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

    % DOF selection per task
    if contains(t.task, 'ANALYTIC1')
        dofHG = 1; % HG YXY — elevation      (X -> DOF1)
        dofGH = 3; % GH ZXY — flexion        (Z -> DOF3)
        dofST = 1; % ST YXZ — upward rot.    (X -> DOF1)
        dofTX = 3; % TH ZXY — flexion        (Z -> DOF3)
    elseif contains(t.task, 'ANALYTIC2')
        dofHG = 1; % HG YXY — elevation      (X -> DOF1)
        dofGH = 1; % GH XZY — abduction      (X -> DOF1)
        dofST = 1; % ST YXZ — upward rot.    (X -> DOF1)
        dofTX = 3; % TH ZXY — flexion        (Z -> DOF3)
    else
        continue;
    end

    % ---- RIGHT SIDE ----
    [hg_R, gh_R, st_R, th_R] = computeContributions(t, 12, 2, 3, 11, ...
        isCalib, 'rcycle', dofHG, dofGH, dofST, dofTX);
    pgh_R = safePct(gh_R, hg_R);
    pst_R = safePct(st_R, hg_R);
    pth_R = safePct(th_R, hg_R);
    rows{end+1} = {[task, ' R'], hg_R, gh_R, pgh_R, st_R, pst_R, th_R, pth_R}; %#ok<AGROW>

    % ---- LEFT SIDE ----
    [hg_L, gh_L, st_L, th_L] = computeContributions(t, 13, 7, 8, 11, ...
        isCalib, 'lcycle', dofHG, dofGH, dofST, dofTX);
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
disp('  %  = contribution range / HG range * 100');
disp('  Note : ANALYTIC2 (coronal elevation) selected --> uniplanar movement');
disp('         ensures coherent GH/ST/TH decomposition.');

% -------------------------------------------------------------------------
% TABLEAU 2 — CONTRIBUTIONS EXPRIMÉES EN % DE HT
% -------------------------------------------------------------------------
disp(' ');

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
    computeContributions(t, jiHG, jiGH, jiST, jiTH, isCalib, cycField, ...
                         dofHG, dofGH, dofST, dofTX)

hg_range = NaN; gh_range = NaN; st_range = NaN; th_range = NaN;

if isCalib
    hg_range = getRange(t, jiHG, dofHG);
    gh_range = getRange(t, jiGH, dofGH);
    st_range = getRange(t, jiST, dofST);
    th_range = getRange(t, jiTH, dofTX);
else
    hg_range = getRangeCycle(t, jiHG, dofHG, cycField);
    gh_range = getRangeCycle(t, jiGH, dofGH, cycField);
    st_range = getRangeCycle(t, jiST, dofST, cycField);
    th_range = getRangeCycleTH(t, jiTH, dofTX, cycField);
end
end

function r = getRange(t, ji, dof)
r = NaN;
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.full), return; end
data = abs(squeeze(t.Joint(ji).Euler.full(1, dof, :)));
r    = max(data, [], 'omitnan') - min(data, [], 'omitnan');
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