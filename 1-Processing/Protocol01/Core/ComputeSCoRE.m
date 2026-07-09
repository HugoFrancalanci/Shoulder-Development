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
% Description:   One-time-per-patient SCoRE calibration (Ehrig et al. 2006)
%                of the glenohumeral centre of rotation (CoR), right and
%                left. Proximal segment = scapula, distal segment = humerus
%                (Session.SCoRE.*.rCsi / .rCsj, expressed in each segment's
%                technical cluster frame, see BuildTechnicalTransform.m).
%
%                Static reference pose  : CALIBRATION1 (Static_reference1),
%                same reference-trial convention as Core/AddACMLandmarks.m.
%                Calibration frames     : taskList, pooled. Default
%                {ANALYTIC2, ANALYTIC4, FUNCTIONAL1, FUNCTIONAL3} — chosen
%                via Tests/ExploreSCoRECombos.m, validated against a CT
%                gold standard (glenosphere, patient 558792 / Jurg Muller,
%                see Core/ComputeCTGoldStandardCoR.m) : 21.5mm mean distance
%                to CT on ANALYTIC1, vs 27.9mm for the previous default
%                (ANALYTIC1-4). The single best-scoring combo on that same
%                validation was FUNCTIONAL1 alone (20.8mm), but a 4-trial
%                pool spanning both ANALYTIC and FUNCTIONAL movement types
%                was preferred for robustness (less reliant on any one
%                trial's specific conditions). Re-run ExploreSCoRECombos.m
%                if CT data becomes available for other patients, to check
%                this default still holds.
% -------------------------------------------------------------------------
% Inputs  : folderData (char) patient folder containing 'Processed\*.c3d'
%           taskList   (cell, optional) trial name substrings to pool as
%                       calibration input. Default {'ANALYTIC2','ANALYTIC4',
%                       'FUNCTIONAL1','FUNCTIONAL3'}.
% Outputs : SCoRE (struct)
%             .xRef.RS/.RA/.LS/.LA   [k x 3] static reference cluster pose
%             .R/.L.rCsi             [3x1] CoR in scapula technical frame
%             .R/.L.rCsj             [3x1] CoR in humerus technical frame
%             .R/.L.residual_mm      [1xN] agreement between the CoR
%                                     estimated via Ti vs via Tj, per
%                                     calibration frame (quality metric)
%             .R/.L.clusterRMS       .scapula_mm/.humerus_mm mean soder
%                                     rigid-fit RMS residual (mm)
% -------------------------------------------------------------------------
% Dependencies : GetCalibrationReferencePose.m, LoadTechnicalFramesForTask.m,
%                DropNanFrames.m, SCoRE_array3.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function SCoRE = ComputeSCoRE(folderData, taskList)

if nargin < 2 || isempty(taskList)
    % Best-performing combo tested against the CT gold standard (patient
    % 558792) via Tests/ExploreSCoRECombos.m — see header comment above.
    taskList = {'ANALYTIC2', 'ANALYTIC4', 'FUNCTIONAL1', 'FUNCTIONAL3'};
end

disp(' ');
disp('------------------------------------------------------------------');
disp('SCoRE calibration (glenohumeral CoR, Ehrig et al. 2006)');
disp(['Calibration trials : ', strjoin(taskList, ', ')]);
disp('------------------------------------------------------------------');

% Same convention as MAIN_Protocol_01.m / runProtocol01.m : cd into the
% Processed folder and read files by relative name (absolute paths under
% deeply nested/accented folders, e.g. OneDrive, have been observed to
% make btkReadAcquisition fail with "File doesn't exist").
oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>

% -------------------------------------------------------------------------
% STATIC REFERENCE POSE (CALIBRATION1)
% -------------------------------------------------------------------------
xRef = GetCalibrationReferencePose();

% -------------------------------------------------------------------------
% CALIBRATION FRAMES (pooled across taskList)
% -------------------------------------------------------------------------
Ti_R = []; Tj_R = []; Ti_L = []; Tj_L = [];
rmsTi_R = []; rmsTj_R = []; rmsTi_L = []; rmsTj_L = [];
for it = 1:numel(taskList)
    [Ti_R_trial, Tj_R_trial, Ti_L_trial, Tj_L_trial, rms] = LoadTechnicalFramesForTask(taskList{it}, xRef);
    if isempty(Ti_R_trial), continue; end

    Ti_R = cat(3, Ti_R, Ti_R_trial); Tj_R = cat(3, Tj_R, Tj_R_trial);
    Ti_L = cat(3, Ti_L, Ti_L_trial); Tj_L = cat(3, Tj_L, Tj_L_trial);
    rmsTi_R = [rmsTi_R, rms.TiR]; rmsTj_R = [rmsTj_R, rms.TjR]; %#ok<AGROW>
    rmsTi_L = [rmsTi_L, rms.TiL]; rmsTj_L = [rmsTj_L, rms.TjL]; %#ok<AGROW>
end

if isempty(Ti_R)
    error('ComputeSCoRE:noCalibrationFrames', ...
          'None of the requested trials (%s) were found -> no SCoRE calibration possible.', strjoin(taskList, ', '));
end

% Drop frames with a missing marker on either segment of the pair
% (a single NaN would otherwise corrupt the whole pinv solution, not just that frame)
[Ti_R, Tj_R] = DropNanFrames(Ti_R, Tj_R);
[Ti_L, Tj_L] = DropNanFrames(Ti_L, Tj_L);

% -------------------------------------------------------------------------
% SCoRE (Ehrig et al. 2006)
% -------------------------------------------------------------------------
[~, rCsi_R, rCsj_R] = SCoRE_array3(Ti_R, Tj_R);
[~, rCsi_L, rCsj_L] = SCoRE_array3(Ti_L, Tj_L);

SCoRE.xRef   = xRef;
SCoRE.R.rCsi = rCsi_R;
SCoRE.R.rCsj = rCsj_R;
SCoRE.L.rCsi = rCsi_L;
SCoRE.L.rCsj = rCsj_L;

% -------------------------------------------------------------------------
% DIAGNOSTICS — agreement between the two independent CoR estimates
% (rC via scapula frame vs rC via humerus frame), see Tests/TestSCoRE.m
% -------------------------------------------------------------------------
SCoRE.R.residual_mm = corResidual_mm(Ti_R, Tj_R, rCsi_R, rCsj_R);
SCoRE.L.residual_mm = corResidual_mm(Ti_L, Tj_L, rCsi_L, rCsj_L);

% Cluster rigidity quality (soder RMS fit residual), in mm
SCoRE.R.clusterRMS.scapula_mm = mean(rmsTi_R, 'omitnan') * 1e3;
SCoRE.R.clusterRMS.humerus_mm = mean(rmsTj_R, 'omitnan') * 1e3;
SCoRE.L.clusterRMS.scapula_mm = mean(rmsTi_L, 'omitnan') * 1e3;
SCoRE.L.clusterRMS.humerus_mm = mean(rmsTj_L, 'omitnan') * 1e3;

disp(['  Right CoR residual (mm) : mean=', num2str(mean(SCoRE.R.residual_mm), '%.2f'), ...
      '  max=', num2str(max(SCoRE.R.residual_mm), '%.2f')]);
disp(['  Left  CoR residual (mm) : mean=', num2str(mean(SCoRE.L.residual_mm), '%.2f'), ...
      '  max=', num2str(max(SCoRE.L.residual_mm), '%.2f')]);
disp(' ');

end

% -------------------------------------------------------------------------
%  CoR SELF-CONSISTENCY RESIDUAL (mm) — Ehrig et al. 2006 quality metric
% -------------------------------------------------------------------------
function residual_mm = corResidual_mm(Ti, Tj, rCsi, rCsj)
N            = size(Ti, 3);
rCi          = Mprod_array3(Ti, repmat([rCsi; 1], [1, 1, N]));
rCj          = Mprod_array3(Tj, repmat([rCsj; 1], [1, 1, N]));
d            = squeeze(rCi(1:3, 1, :) - rCj(1:3, 1, :)); % [3xN]
residual_mm  = sqrt(sum(d.^2, 1)) * 1e3; % m -> mm
end
