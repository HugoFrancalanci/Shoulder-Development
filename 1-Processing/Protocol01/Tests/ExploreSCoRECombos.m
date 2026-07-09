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
% Description:   Explores which combination of ANALYTIC/FUNCTIONAL trials,
%                pooled as SCoRE calibration input, gets the resulting CoR
%                (right side) closest to the CT gold standard
%                (Core/ComputeCTGoldStandardCoR.m) on a validation trial.
%
%                Each candidate trial is loaded ONCE (Core/LoadTechnicalFramesForTask.m)
%                and cached ; every non-empty subset of the candidate pool
%                is then evaluated by simply recombining the cached
%                technical frames and re-running SCoRE_array3 — no repeated
%                file I/O per combination.
%
%                Patient-specific (only meaningful where a CT gold standard
%                is available) — not part of the automatic pipeline.
% -------------------------------------------------------------------------
% Inputs  : folderData     (char) patient folder containing 'Processed\*.c3d'
%           ctFolder       (char) folder containing the CT .fcsv files
%           validationTask (char, optional) trial to evaluate on, default 'ANALYTIC1'
%           candidatePool  (cell, optional) trial name substrings to combine,
%                          default {'ANALYTIC1'..'ANALYTIC5','FUNCTIONAL1'..'FUNCTIONAL4'}
%                          (capped at 9 candidates -> 511 combinations)
% Outputs : results (table) every combination tested, sorted by mean
%           distance to CT (mm), ascending. Console top-10 + bar plot.
% -------------------------------------------------------------------------
% Dependencies : Core/GetCalibrationReferencePose.m, Core/LoadTechnicalFramesForTask.m,
%                Core/DropNanFrames.m, Core/ComputeCTGoldStandardCoR.m,
%                SCoRE_array3.m, Tinv_array3.m, Mprod_array3.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function results = ExploreSCoRECombos(folderData, ctFolder, validationTask, candidatePool)

if nargin < 3 || isempty(validationTask), validationTask = 'ANALYTIC1'; end
if nargin < 4 || isempty(candidatePool)
    candidatePool = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4', 'ANALYTIC5', ...
                      'FUNCTIONAL1', 'FUNCTIONAL2', 'FUNCTIONAL3', 'FUNCTIONAL4'};
end

disp(' ');
disp('====================================================================');
disp('Exploration des combinaisons de calibration SCoRE vs CT gold standard');
disp('====================================================================');

% -------------------------------------------------------------------------
% CT GOLD STANDARD (independent of every combination tested below)
% -------------------------------------------------------------------------
CTGold  = ComputeCTGoldStandardCoR(ctFolder, folderData, 'R');
CoR_CT  = CTGold.rCsi; % [3x1], scapula-local (CALIBRATION1-instant) numbering

% Same cd()-based file access convention as ComputeSCoRE.m / ComputeCTGoldStandardCoR.m
oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>
c3dFiles = dir('*.c3d');

% -------------------------------------------------------------------------
% DISCOVER AVAILABLE CANDIDATES + LOAD EACH ONCE
% -------------------------------------------------------------------------
available = {};
for i = 1:numel(candidatePool)
    if any(contains({c3dFiles.name}, candidatePool{i}))
        available{end+1} = candidatePool{i}; %#ok<AGROW>
    end
end
nA = numel(available);
if nA == 0
    error('ExploreSCoRECombos:noCandidates', 'None of the candidate trials were found in %s.', folderData);
end
if 2^nA - 1 > 511
    error('ExploreSCoRECombos:tooManyCombos', ...
          '%d candidate trials -> %d combinations (cap 511, i.e. 9 trials). Reduce candidatePool.', nA, 2^nA-1);
end
disp(['Essais disponibles (', num2str(nA), ') : ', strjoin(available, ', ')]);

xRef  = GetCalibrationReferencePose();
cache = repmat(struct('Ti_R', [], 'Tj_R', []), 1, nA);
for i = 1:nA
    [Ti_R, Tj_R] = LoadTechnicalFramesForTask(available{i}, xRef);
    cache(i).Ti_R = Ti_R;
    cache(i).Tj_R = Tj_R;
end

% Validation trial's technical frames (right) : reuse the cache if it is
% itself part of the candidate pool, otherwise load it separately. Using
% the same trial for calibration AND validation is not a concern here,
% since the ground truth (CT) is entirely independent of the mocap data.
idxVal = find(strcmp(available, validationTask), 1);
if ~isempty(idxVal)
    Ti_val = cache(idxVal).Ti_R;
    Tj_val = cache(idxVal).Tj_R;
else
    [Ti_val, Tj_val] = LoadTechnicalFramesForTask(validationTask, xRef);
end
if isempty(Ti_val)
    error('ExploreSCoRECombos:noValidationTrial', '%s not found -> cannot validate against CT.', validationTask);
end
TiInv_val = Tinv_array3(Ti_val);
Nval      = size(Ti_val, 3);

% -------------------------------------------------------------------------
% ENUMERATE EVERY NON-EMPTY COMBINATION
% -------------------------------------------------------------------------
nCombos     = 2^nA - 1;
comboLabel  = cell(nCombos, 1);
meanDist_mm = nan(nCombos, 1);
maxDist_mm  = nan(nCombos, 1);
stdDist_mm  = nan(nCombos, 1);
nFrames     = nan(nCombos, 1);

for c = 1:nCombos
    idx = find(bitget(c, 1:nA));
    comboLabel{c} = strjoin(available(idx), '+');

    Ti_R_combo = cat(3, cache(idx).Ti_R);
    Tj_R_combo = cat(3, cache(idx).Tj_R);
    [Ti_R_combo, Tj_R_combo] = DropNanFrames(Ti_R_combo, Tj_R_combo);
    if size(Ti_R_combo, 3) < 3
        continue; % not enough frames for a well-posed least-squares fit
    end

    [~, ~, rCsj_combo] = SCoRE_array3(Ti_R_combo, Tj_R_combo);

    RGJC_global = Mprod_array3(Tj_val, repmat([rCsj_combo; 1], [1, 1, Nval]));
    RGJC_local  = Mprod_array3(TiInv_val, RGJC_global);
    d_mm        = squeeze(sqrt(sum((RGJC_local(1:3, 1, :) - CoR_CT).^2, 1))) * 1e3;

    meanDist_mm(c) = mean(d_mm, 'omitnan');
    maxDist_mm(c)  = max(d_mm);
    stdDist_mm(c)  = std(d_mm, 'omitnan');
    nFrames(c)     = size(Ti_R_combo, 3);
end

% -------------------------------------------------------------------------
% RANK + REPORT
% -------------------------------------------------------------------------
results = table(comboLabel, meanDist_mm, maxDist_mm, stdDist_mm, nFrames, ...
                 'VariableNames', {'Combo', 'MeanDist_mm', 'MaxDist_mm', 'StdDist_mm', 'NFrames'});
results = sortrows(results, 'MeanDist_mm');

disp(' ');
disp(['Top 10 combinaisons (validation sur ', validationTask, ', droite) :']);
disp(results(1:min(10, height(results)), :));

figure('Name', 'SCoRE calibration combos vs CT', 'NumberTitle', 'off');
nShow = min(15, height(results));
barh(results.MeanDist_mm(nShow:-1:1));
set(gca, 'YTick', 1:nShow, 'YTickLabel', results.Combo(nShow:-1:1), 'TickLabelInterpreter', 'none');
xlabel('Distance moyenne au CT gold standard (mm)');
title({'Combinaisons de calibration SCoRE - meilleures 15', ...
       ['Validation : ', validationTask, ' (droite)']}, 'Interpreter', 'none');
grid on;

end
