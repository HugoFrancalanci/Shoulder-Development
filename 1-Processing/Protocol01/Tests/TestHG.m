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
% Description:   Unit test for the humero-gravitaire angle definition.
%
%                CALIBRATION3 = resting posture, both arms at side.
%                Expected values (YXY sequence) :
%                  DOF1 X : Elevation -> approx 0 deg (arms at side)
%
%                Note : DOF2 and DOF3 not evaluated — gimbal lock expected
%                near 0 deg elevation. Only DOF1 (elevation) is reliable.
%
% Inputs  : Trial (struct array) all trials from MAIN_Protocol_01
% Outputs : Console report
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function TestHG(Trial)

disp(' ');
disp('------------------------------------------------------------------');
disp('Test unitaire (angle humerogravitaire)');
disp('Reference : CALIBRATION3 (posture de repos avec les bras le long du corps)');
disp(' ');

% Thresholds (deg)
PASS_tol = 30.0; 
WARN_tol = 40.0; 

% -------------------------------------------------------------------------
% FIND CALIBRATION3
% -------------------------------------------------------------------------
calib3_idx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task,'CALIBRATION3'), calib3_idx = k; end
end

% -------------------------------------------------------------------------
% TEST CALIBRATION3 — Both arms at side, expected ~20 deg
% -------------------------------------------------------------------------
disp('  --- CALIBRATION3 ---');

if isempty(calib3_idx)
    disp('  CALIBRATION3 not found in Trial.');
else
    t3 = Trial(calib3_idx);
    if isempty(t3.Joint) || length(t3.Joint) < 13
        disp('  Joints not populated — check ComputeKinematics.');
    else
        fprintf('  Right humerus (expected ~20 deg) :\n');
        if isempty(t3.Joint(12).Euler.full)
            disp('  Joint(12).Euler.full empty.');
        else
            printDOFresults(t3.Joint(12), 20.0, PASS_tol, WARN_tol);
        end
        fprintf('  Left humerus (expected ~20 deg) :\n');
        if isempty(t3.Joint(13).Euler.full)
            disp('  Joint(13).Euler.full empty.');
        else
            printDOFresults(t3.Joint(13), 20.0, PASS_tol, WARN_tol);
        end
    end
end

disp(' ');
disp('  Note : DOF2 (elevation plane) and DOF3 (axial rotation) not evaluated due to glimbal lock');

end

function printDOFresults(joint, expected, pass_tol, warn_tol)

euler_X = squeeze(joint.Euler.full(1,1,:)); % DOF1 — elevation

mx_X = abs(max(euler_X, [], 'omitnan'));  % max elevation reached
sd_X = abs(std(euler_X,      'omitnan'));

fprintf('  %-20s  %8s  %8s  %s\n', 'DOF', 'max (deg)', 'std (deg)', 'Status');
disp(repmat('-', 1, 60));

% DOF1 — max elevation tested against expected value
% DOF2 and DOF3 not evaluated — gimbal lock expected near 0 deg elevation
status_X = getStatusElevation(mx_X, expected, pass_tol, warn_tol);
fprintf('  %-20s  %8.2f  %8.2f  %s\n', 'DOF1 X  Elevation', mx_X, sd_X, status_X);

disp(repmat('-', 1, 60));
end

function status = getStatusElevation(mn, expected, pass_tol, warn_tol)
diff = abs(mn - expected);
if diff < pass_tol
    status = sprintf('[+] PASS');
elseif diff < warn_tol
    status = sprintf('[~] WARN');
else
    status = sprintf('[!] FAIL');
end
end