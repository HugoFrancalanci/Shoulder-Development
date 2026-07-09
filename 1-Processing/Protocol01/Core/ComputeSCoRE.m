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
%                Calibration frames     : ANALYTIC1-4 pooled (covers all DOFs).
% -------------------------------------------------------------------------
% Inputs  : folderData (char) patient folder containing 'Processed\*.c3d'
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
% Dependencies : BuildTechnicalTransform.m, SCoRE_array3.m, SetUnits.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function SCoRE = ComputeSCoRE(folderData)

disp(' ');
disp('------------------------------------------------------------------');
disp('SCoRE calibration (glenohumeral CoR, Ehrig et al. 2006)');
disp('------------------------------------------------------------------');

% Same convention as MAIN_Protocol_01.m / runProtocol01.m : cd into the
% Processed folder and read files by relative name (absolute paths under
% deeply nested/accented folders, e.g. OneDrive, have been observed to
% make btkReadAcquisition fail with "File doesn't exist").
oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>
c3dFiles = dir('*.c3d');

clusterLabels.RS = {'Cluster_RS_01', 'Cluster_RS_02', 'Cluster_RS_03'};
clusterLabels.RA = {'Cluster_RA_01', 'Cluster_RA_02', 'Cluster_RA_03', 'Cluster_RA_04', 'Cluster_RA_05'};
clusterLabels.LS = {'Cluster_LS_01', 'Cluster_LS_02', 'Cluster_LS_03'};
clusterLabels.LA = {'Cluster_LA_01', 'Cluster_LA_02', 'Cluster_LA_03', 'Cluster_LA_04', 'Cluster_LA_05'};

% -------------------------------------------------------------------------
% STATIC REFERENCE POSE (CALIBRATION1)
% -------------------------------------------------------------------------
calib1Idx = find(contains({c3dFiles.name}, 'CALIBRATION1'), 1);
if isempty(calib1Idx)
    error('ComputeSCoRE:noCalibration1', ...
          'CALIBRATION1.c3d not found in %s -> cannot build the SCoRE static reference.', folderData);
end
acq    = btkReadAcquisition(c3dFiles(calib1Idx).name);
ratio  = getUnitRatio(acq);
Marker = btkGetMarkers(acq);

xRef.RS = clusterReferencePose(Marker, clusterLabels.RS, ratio);
xRef.RA = clusterReferencePose(Marker, clusterLabels.RA, ratio);
xRef.LS = clusterReferencePose(Marker, clusterLabels.LS, ratio);
xRef.LA = clusterReferencePose(Marker, clusterLabels.LA, ratio);

% -------------------------------------------------------------------------
% ANALYTIC1-4 CALIBRATION FRAMES
% -------------------------------------------------------------------------
Ti_R = []; Tj_R = []; Ti_L = []; Tj_L = [];
rmsTi_R = []; rmsTj_R = []; rmsTi_L = []; rmsTj_L = [];
for itask = 1:4
    taskName = sprintf('ANALYTIC%d', itask);
    idx = find(contains({c3dFiles.name}, taskName), 1);
    if isempty(idx)
        warning('ComputeSCoRE:missingTrial', '%s not found -> excluded from SCoRE calibration.', taskName);
        continue;
    end
    acq    = btkReadAcquisition(c3dFiles(idx).name);
    ratio  = getUnitRatio(acq);
    Marker = btkGetMarkers(acq);

    clRS = clusterTrajectories(Marker, clusterLabels.RS, ratio);
    clRA = clusterTrajectories(Marker, clusterLabels.RA, ratio);
    clLS = clusterTrajectories(Marker, clusterLabels.LS, ratio);
    clLA = clusterTrajectories(Marker, clusterLabels.LA, ratio);

    [Ti_R_trial, rms_Ti_R] = BuildTechnicalTransform(xRef.RS, clRS);
    [Tj_R_trial, rms_Tj_R] = BuildTechnicalTransform(xRef.RA, clRA);
    [Ti_L_trial, rms_Ti_L] = BuildTechnicalTransform(xRef.LS, clLS);
    [Tj_L_trial, rms_Tj_L] = BuildTechnicalTransform(xRef.LA, clLA);

    Ti_R = cat(3, Ti_R, Ti_R_trial); Tj_R = cat(3, Tj_R, Tj_R_trial);
    Ti_L = cat(3, Ti_L, Ti_L_trial); Tj_L = cat(3, Tj_L, Tj_L_trial);
    rmsTi_R = [rmsTi_R, rms_Ti_R]; rmsTj_R = [rmsTj_R, rms_Tj_R]; %#ok<AGROW>
    rmsTi_L = [rmsTi_L, rms_Ti_L]; rmsTj_L = [rmsTj_L, rms_Tj_L]; %#ok<AGROW>

    disp(['  - ', taskName, ' loaded (', num2str(size(clRA{1}, 3)), ' frames)']);
end

% Drop frames with a missing marker on either segment of the pair
% (a single NaN would otherwise corrupt the whole pinv solution, not just that frame)
[Ti_R, Tj_R] = dropNanFrames(Ti_R, Tj_R);
[Ti_L, Tj_L] = dropNanFrames(Ti_L, Tj_L);

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
%  UNIT RATIO (mm -> m), same convention as SetUnits.m
% -------------------------------------------------------------------------
function ratio = getUnitRatio(acq)
tmpTrial(1).btk = acq;
Units           = SetUnits(tmpTrial);
ratio           = Units.ratio;
end

% -------------------------------------------------------------------------
%  CLUSTER TRAJECTORIES ON A TRIAL -> {[3x1xN], ...}
% -------------------------------------------------------------------------
function traj = clusterTrajectories(Marker, labels, ratio)
traj = cell(1, numel(labels));
for i = 1:numel(labels)
    traj{i} = permute(Marker.(labels{i}), [2, 3, 1]) * ratio;
end
end

% -------------------------------------------------------------------------
%  STATIC REFERENCE POSE (mean marker position over CALIBRATION1)
% -------------------------------------------------------------------------
function xRef = clusterReferencePose(Marker, labels, ratio)
xRef = nan(numel(labels), 3);
for i = 1:numel(labels)
    m           = Marker.(labels{i}) * ratio; % [N x 3]
    xRef(i, :)  = mean(m, 1, 'omitnan');
end
end

% -------------------------------------------------------------------------
%  DROP FRAMES WHERE Ti OR Tj COULD NOT BE BUILT (missing marker)
% -------------------------------------------------------------------------
function [Ti, Tj] = dropNanFrames(Ti, Tj)
valid = ~squeeze(any(any(isnan(Ti(1:3, :, :)), 1), 2)) & ...
        ~squeeze(any(any(isnan(Tj(1:3, :, :)), 1), 2));
Ti = Ti(:, :, valid);
Tj = Tj(:, :, valid);
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
