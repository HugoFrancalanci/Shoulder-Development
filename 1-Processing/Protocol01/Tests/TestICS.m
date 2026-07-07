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
% Description:   Unit test for the patient-ICS definition.
%
%                CALIBRATION3 = patient standing in anatomical posture
%                (no movement). In this posture :
%                  - Tilt X (lateral tilt)   should be ≈ 0 deg
%                  - Rot Y  (axial rotation) should be ≈ 0 deg
%                  - Flex Z (flexion)        should be ≈ 0 deg
%                  - std of all DOF          should be small (< 2 deg)
%
%                The test also checks thoracic inclination consistency
%                between CALIBRATION3 (standing) and all ANALYTIC trials
%                (seated). Inclination = angle between vector TV8->CV7
%                and gravitational vertical [0;0;1].
%
% Inputs  : Trial (struct array) all trials from MAIN_Protocol_01
% Outputs : Console report + testResult struct
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function testResult = TestICS(Trial)

disp(' ');
disp('------------------------------------------------------------------');
disp('Tests unitaire (thorax et posture)');
disp('Reference : CALIBRATION3 (posture debout)');

% Thresholds (deg)
PASS_mean = 7.0;
PASS_std  = 2.0;
WARN_mean = 15.0;
WARN_std  = 5.0;

% -------------------------------------------------------------------------
% FIND CALIBRATION3 TRIAL
% -------------------------------------------------------------------------
calib3_idx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task,'CALIBRATION3')
        calib3_idx = k;
        break;
    end
end

if isempty(calib3_idx)
    disp('  No CALIBRATION3 trial found.');
    testResult = struct('status','SKIP','message','No CALIBRATION3 trial found.');
    return;
end

t = Trial(calib3_idx);

% Guard
if isempty(t.Joint) || length(t.Joint) < 11 || isempty(t.Joint(11).Euler.full)
    disp('  Joint(11).Euler.full empty for CALIBRATION3.');
    disp('  Check that DefineSegments and ComputeKinematics are called on CALIBRATION3.');
    testResult = struct('status','FAIL','message','Joint(11).Euler.full empty.');
    return;
end

% -------------------------------------------------------------------------
% EXTRACT EULER ANGLES
% Euler.full layout [1 x 3 x N] — K-LAB storage :
%   (1,1,:) X — lateral tilt
%   (1,2,:) Y — axial rotation
%   (1,3,:) Z — flexion
% -------------------------------------------------------------------------
euler_X = squeeze(t.Joint(11).Euler.full(1,1,:));
euler_Y = squeeze(t.Joint(11).Euler.full(1,2,:));
euler_Z = squeeze(t.Joint(11).Euler.full(1,3,:));

mn_X  = mean(euler_X,'omitnan');  sd_X = std(euler_X,'omitnan');
mn_Y  = mean(euler_Y,'omitnan');  sd_Y = std(euler_Y,'omitnan');
mn_Z  = mean(euler_Z,'omitnan');  sd_Z = std(euler_Z,'omitnan');

% -------------------------------------------------------------------------
% EVALUATE EACH DOF
% -------------------------------------------------------------------------
disp(' ');
disp('  --- Thoracic angles on CALIBRATION3 ---');
fprintf('  %-12s  %8s  %8s  %6s\n','DOF','mean (deg)','std','Status');
disp(repmat('-',1,52));

statusX = getStatus(mn_X, sd_X, PASS_mean, PASS_std, WARN_mean, WARN_std);
statusY = getStatus(mn_Y, sd_Y, PASS_mean, PASS_std, WARN_mean, WARN_std);
statusZ = getStatus(mn_Z, sd_Z, PASS_mean, PASS_std, WARN_mean, WARN_std);

fprintf('  %-12s  %8.2f  %8.2f  %s\n', 'Tilt X', mn_X, sd_X, statusX);
fprintf('  %-12s  %8.2f  %8.2f  %s\n', 'Rot Y',  mn_Y, sd_Y, statusY);
fprintf('  %-12s  %8.2f  %8.2f  %s\n', 'Flex Z', mn_Z, sd_Z, statusZ);
disp(repmat('-',1,52));

% -------------------------------------------------------------------------
% THORACIC INCLINATION (CALIBRATION3 vs ANALYTIC trials)
% Inclination = angle between vector TV8->CV7 and gravitational vertical
% CALIBRATION3 = standing, ANALYTIC = seated
% Expected difference : 5-15 deg (standing vs seated effect)
% -------------------------------------------------------------------------
disp(' ');
disp('  --- Thoracic inclination : CALIBRATION3 vs ANALYTIC ---');

incl_calib = NaN;
if isfield(t.Joint(11),'PostureSummary') && ...
   isfield(t.Joint(11).PostureSummary,'thoracic_curvature_angle')
    incl_calib = t.Joint(11).PostureSummary.thoracic_curvature_angle;
    fprintf('  Inclination CALIBRATION3 : %.1f deg\n', incl_calib);
else
    disp('  Inclination CALIBRATION3 : N/A (PostureSummary absent)');
end

incl_analytic = [];
for k = 1:length(Trial)
    if contains(Trial(k).task,'ANALYTIC') && ...
       ~isempty(Trial(k).Joint) && length(Trial(k).Joint) >= 11 && ...
       isfield(Trial(k).Joint(11),'PostureSummary') && ...
       isfield(Trial(k).Joint(11).PostureSummary,'thoracic_curvature_angle')
        incl_analytic(end+1) = Trial(k).Joint(11).PostureSummary.thoracic_curvature_angle; %#ok<AGROW>
        fprintf('  Inclination %-14s : %.1f deg\n', Trial(k).task, incl_analytic(end));
    end
end

if ~isnan(incl_calib) && ~isempty(incl_analytic)
    incl_diff = abs(incl_analytic - incl_calib);
    fprintf('  Difference max vs CALIBRATION3 : %.1f deg\n', max(incl_diff));
end

% -------------------------------------------------------------------------
% OUTPUT STRUCT
% -------------------------------------------------------------------------
testResult = struct(...
    'mean_X',             mn_X,   'std_X', sd_X, 'status_X', statusX, ...
    'mean_Y',             mn_Y,   'std_Y', sd_Y, 'status_Y', statusY, ...
    'mean_Z',             mn_Z,   'std_Z', sd_Z, 'status_Z', statusZ, ...
    'incl_calib',         incl_calib, ...
    'incl_analytic_mean', mean(incl_analytic,'omitnan'));

end

% =========================================================================
%  STATUS EVALUATION
% =========================================================================
function status = getStatus(mn, sd, pass_m, pass_s, warn_m, warn_s)
if abs(mn) < pass_m && sd < pass_s
    status = 'PASS';
elseif abs(mn) < warn_m && sd < warn_s
    status = 'WARN';
else
    status = 'FAIL';
end
end