% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Validation + visualisation of the quaternion / axis-angle
%                kinematics (Core/ComputeQuaternionKinematics.m) for HG,
%                GH, ST and TX (Joint 12/13, 2/7, 3/8, 11).
%
%                CHECK : Regression guard
%                Recomputes the total rotation angle directly from each
%                joint's own T.full via the rotation-matrix trace formula
%                (acos((trace(R)-1)/2)), an independent identity, no
%                Euler decomposition, no quaternion — and compares it to
%                the QuatAngle stored by ComputeKinematics.m. Any gap
%                beyond numerical noise means the production quaternion
%                pipeline has drifted from what was validated (e.g. the
%                local R2q_array3.m indexing patch got lost on a toolbox
%                update — see that file's header).
%
%                PLOT
%                For one trial (ANALYTIC2 by default) : total rotation
%                angle over time for all 7 joints, and the rotation axis
%                trajectory on a unit sphere, per joint.
%
% Inputs  : Trial (struct array) all trials from MAIN_Protocol_01
% Outputs : Console report + figure
% -------------------------------------------------------------------------
% Dependencies : None (reads Joint(i).T.full / QuatAngle / QuatAxis,
%                already computed by ComputeKinematics.m)
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function TestQuaternionValidation(Trial)

disp(' ');
disp('------------------------------------------------------------------');
disp('Test de validation (quaternion, HG/GH/ST/TX)');
disp('Reference : ANALYTIC2');
disp(' ');

PASS_tol = 0.1; % deg
WARN_tol = 1.0; % deg

% -------------------------------------------------------------------------
% FIND ANALYTIC2
% -------------------------------------------------------------------------
analytic_idx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task,'ANALYTIC2')
        analytic_idx = k;
        break;
    end
end

if isempty(analytic_idx)
    disp('  ANALYTIC2 not found in Trial.');
    return;
end

t = Trial(analytic_idx);

joints = struct('label', {'HG R','HG L','GH R','GH L','ST R','ST L','TX'}, ...
                 'idx',   {12,    13,    2,     7,     3,     8,     11});

% -------------------------------------------------------------------------
% REGRESSION CHECK
% -------------------------------------------------------------------------
fprintf('  %-8s  %10s  %s\n', 'Joint', 'ecart max', 'Status');
disp(repmat('-', 1, 40));
% Joint 8 (ST-L) and Joint 13 (HG-L) : ComputeKinematics.m applies a
% two-sided left-side mirror correction (diag(1,1,-1)*R*diag(-1,1,1)) to
% a LOCAL COPY before the quaternion call, to undo the uncorrected-
% formula-on-mirrored-anatomy asymmetry in Segment 5/6 (see that file's
% header, and Tests/FindMirrorCorrection.m for how it was derived).
% T.full itself is left untouched, so the independent recomputation
% below must apply the SAME correction, or it compares a corrected angle
% to an uncorrected one and reports a spurious gap.
leftFix  = diag([1 1 -1]);
rightFix = diag([-1 1 1]);

for j = 1:length(joints)
    ji = joints(j).idx;
    if ji > length(t.Joint) || isempty(t.Joint(ji).QuatAngle.full) || isempty(t.Joint(ji).T.full)
        fprintf('  %-8s  %10s  [ ] SKIP (donnees manquantes)\n', joints(j).label, '-');
        continue;
    end
    R = t.Joint(ji).T.full(1:3,1:3,:);
    if ji == 8 || ji == 13
        n = size(R,3);
        R = Mprod_array3(repmat(leftFix,[1,1,n]), R);
        R = Mprod_array3(R, repmat(rightFix,[1,1,n]));
    end
    tr       = squeeze(R(1,1,:) + R(2,2,:) + R(3,3,:));
    theta_tr = rad2deg(acos(max(-1, min(1, (tr-1)/2))));
    theta_q  = squeeze(t.Joint(ji).QuatAngle.full);
    d        = max(abs(theta_q - theta_tr));
    fprintf('  %-8s  %9.4f°  %s\n', joints(j).label, d, getStatus(d, PASS_tol, WARN_tol));
end
disp(' ');

% -------------------------------------------------------------------------
% VISUALISATION
% -------------------------------------------------------------------------
plotQuaternionOverview(t, joints);

end

% =========================================================================
%  PLOT
% =========================================================================
function plotQuaternionOverview(t, joints)

figure('Name', 'Validation quaternion - HG/GH/ST/TX', 'Color', 'w');
colors = lines(length(joints));

% --- Total angle time series ---
subplot(1,2,1); hold on;
for j = 1:length(joints)
    ji = joints(j).idx;
    if ji > length(t.Joint) || isempty(t.Joint(ji).QuatAngle.full), continue; end
    theta = squeeze(t.Joint(ji).QuatAngle.full);
    plot(1:length(theta), theta, 'Color', colors(j,:), ...
        'DisplayName', joints(j).label, 'LineWidth', 1.2);
end
xlabel('Frame'); ylabel('Angle total (deg)');
title('Angle de rotation total (quaternion)');
legend('Location', 'best'); grid on; box on;

% --- Axis trajectory on unit sphere ---
subplot(1,2,2); hold on;
[sx, sy, sz] = sphere(24);
surf(sx, sy, sz, 'FaceAlpha', 0.05, 'EdgeAlpha', 0.08, 'FaceColor', [0.7 0.7 0.7]);
axis equal; grid on; box on;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Trajectoire de l''axe de rotation');
for j = 1:length(joints)
    ji = joints(j).idx;
    if ji > length(t.Joint) || isempty(t.Joint(ji).QuatAxis.full), continue; end
    ax    = squeeze(t.Joint(ji).QuatAxis.full); % [3 x n]
    valid = all(~isnan(ax), 1);
    plot3(ax(1,valid), ax(2,valid), ax(3,valid), '.', 'Color', colors(j,:), ...
        'DisplayName', joints(j).label, 'MarkerSize', 6);
end
legend('Location', 'best');
view(45, 25);

end

% =========================================================================
%  STATUS EVALUATION
% =========================================================================
function status = getStatus(d, pass_tol, warn_tol)
if d < pass_tol
    status = '[+] PASS';
elseif d < warn_tol
    status = '[~] WARN';
else
    status = '[!] FAIL';
end
end
