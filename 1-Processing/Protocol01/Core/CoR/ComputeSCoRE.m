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
%                gold standard (glenosphere, one CT-validated patient,
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
%             .clusterLabels.RS/.LS/.RA/.LA  scapula/humerus cluster marker
%                                     labels actually used (current markers,
%                                     or a detected legacy set — see
%                                     Core/CoR/DetectScapulaClusterLabels.m
%                                     and Core/CoR/DetectHumerusClusterLabels.m).
%                                     Re-used by Core/DefineSegments.m so
%                                     the per-trial reconstruction matches
%                                     what the calibration was built on.
% -------------------------------------------------------------------------
% Dependencies : GetCalibrationReferencePose.m, LoadTechnicalFramesForTask.m,
%                DetectScapulaClusterLabels.m, DetectHumerusClusterLabels.m,
%                DefaultClusterLabels.m, DropNanFrames.m, SCoRE_array3.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function SCoRE = ComputeSCoRE(folderData, taskList)

if nargin < 2 || isempty(taskList)
    % Best-performing combo tested against the CT gold standard
    % via Tests/ExploreSCoRECombos.m — see header comment above.
    taskList = {'ANALYTIC2', 'ANALYTIC4', 'FUNCTIONAL1', 'FUNCTIONAL3'};
end

disp(' ');
disp('------------------------------------------------------------------');
disp('Center of rotation calibration (glenohumeral ScoRe approach, Ehrig et al. 2006)');
disp(['Calibration trials : ', strjoin(taskList, ', ')]);
disp('------------------------------------------------------------------');

% Same convention as MAIN_Protocol_01.m / runProtocol01.m : cd into the
% Processed folder and read files by relative name (absolute paths under
% deeply nested/accented folders, e.g. OneDrive, have been observed to
% make btkReadAcquisition fail with "File doesn't exist").
oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>

% -------------------------------------------------------------------------
% CLUSTER LABELS — detect, once per patient, whether the current markers
% (Cluster_{R/L}S_01-03 scapula / Cluster_{R/L}A_01-05 humerus) or a legacy
% naming are actually present (see DetectScapulaClusterLabels.m /
% DetectHumerusClusterLabels.m header for the priority order). Uses
% ANALYTIC1 specifically : a real movement trial is needed to disambiguate
% legacy humerus schemes that can both appear as valid-but-frozen labels in
% the same C3D (not required for the scapula case, but ANALYTIC1 works
% fine for it too). Falls back to the current/default labels if ANALYTIC1
% is missing or nothing usable is detected (unchanged behaviour).
% -------------------------------------------------------------------------
clusterLabels = DefaultClusterLabels();
c3dFilesLocal = dir('*.c3d');
idxA1         = find(contains({c3dFilesLocal.name}, 'ANALYTIC1'), 1);
if ~isempty(idxA1)
    acqA1    = btkReadAcquisition(c3dFilesLocal(idxA1).name);
    MarkerA1 = btkGetMarkers(acqA1);

    labelsRS = DetectScapulaClusterLabels(MarkerA1, 'R');
    labelsLS = DetectScapulaClusterLabels(MarkerA1, 'L');
    if ~isempty(labelsRS) && ~isequal(labelsRS, clusterLabels.RS)
        clusterLabels.RS = labelsRS;
        disp(['  Cluster scapula droit (legacy detecte) : ', strjoin(labelsRS, ', ')]);
    end
    if ~isempty(labelsLS) && ~isequal(labelsLS, clusterLabels.LS)
        clusterLabels.LS = labelsLS;
        disp(['  Cluster scapula gauche (legacy detecte) : ', strjoin(labelsLS, ', ')]);
    end

    labelsRA = DetectHumerusClusterLabels(MarkerA1, 'R');
    labelsLA = DetectHumerusClusterLabels(MarkerA1, 'L');
    if ~isempty(labelsRA) && ~isequal(labelsRA, clusterLabels.RA)
        clusterLabels.RA = labelsRA;
        disp(['  Cluster humerus droit (legacy detecte) : ', strjoin(labelsRA, ', ')]);
    end
    if ~isempty(labelsLA) && ~isequal(labelsLA, clusterLabels.LA)
        clusterLabels.LA = labelsLA;
        disp(['  Cluster humerus gauche (legacy detecte) : ', strjoin(labelsLA, ', ')]);
    end
end

% -------------------------------------------------------------------------
% STATIC REFERENCE POSE (CALIBRATION1)
% -------------------------------------------------------------------------
xRef = GetCalibrationReferencePose(clusterLabels);

% -------------------------------------------------------------------------
% CALIBRATION FRAMES (pooled across taskList)
% -------------------------------------------------------------------------
Ti_R = []; Tj_R = []; Ti_L = []; Tj_L = [];
rmsTi_R = []; rmsTj_R = []; rmsTi_L = []; rmsTj_L = [];
for it = 1:numel(taskList)
    [Ti_R_trial, Tj_R_trial, Ti_L_trial, Tj_L_trial, rms] = LoadTechnicalFramesForTask(taskList{it}, xRef, clusterLabels);
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

SCoRE.xRef          = xRef;
SCoRE.clusterLabels = clusterLabels;
SCoRE.R.rCsi        = rCsi_R;
SCoRE.R.rCsj        = rCsj_R;
SCoRE.L.rCsi        = rCsi_L;
SCoRE.L.rCsj        = rCsj_L;

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
%  CoR SELF-CONSISTENCY RESIDUAL (mm) Ehrig et al. 2006 quality metric
% -------------------------------------------------------------------------
function residual_mm = corResidual_mm(Ti, Tj, rCsi, rCsj)
N            = size(Ti, 3);
rCi          = Mprod_array3(Ti, repmat([rCsi; 1], [1, 1, N]));
rCj          = Mprod_array3(Tj, repmat([rCsj; 1], [1, 1, N]));
d            = squeeze(rCi(1:3, 1, :) - rCj(1:3, 1, :)); % [3xN]
residual_mm  = sqrt(sum(d.^2, 1)) * 1e3; % m -> mm
end
