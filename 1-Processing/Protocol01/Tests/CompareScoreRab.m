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
% Description:   Validation report for the SCoRE glenohumeral CoR method,
%                on a given trial :
%                  1) Recap of the SCoRE calibration quality (TestSCoRE).
%                  2) Distance (mm) between RGJC/LGJC obtained by Rab vs
%                     SCoRE — computed independently (Core/DefineSegments.m
%                     called twice on a copy of Trial, no shared mutation),
%                     with the underlying kinematics (Core/ComputeKinematics.m)
%                     recomputed for both so HT/GH/ST can be compared too.
%                  3) Plots : RGJC/LGJC distance vs frame, HT/GH/ST Euler
%                     angles (Rab vs SCoRE overlay, both sides), and the
%                     3D RGJC/LGJC trajectory (Rab vs SCoRE) alongside the
%                     acromion/elbow for a quick anatomical plausibility check.
%
%                Not part of the automatic per-trial pipeline (cost =
%                computing both methods) — called once on ANALYTIC1 from
%                MAIN_Protocol_01.m when Processing.GJC.method == 'SCoRE'.
% -------------------------------------------------------------------------
% Inputs  : c3dFiles   (struct) needs only a .name field matching Trial.file
%           Session    (struct) session info; Session.SCoRE used/computed if missing
%           Trial      (struct) trial with .Marker populated
%           folderData (char)   patient folder, only needed if Session.SCoRE
%                                is not yet computed (optional)
% Outputs : Console report (mean/max/std distance in mm, right and left)
%           Figures    : RGJC/LGJC distance vs frame ; HT/GH/ST Euler angles
% -------------------------------------------------------------------------
% Dependencies : Core/DefineSegments.m, Core/ComputeKinematics.m,
%                Core/ComputeSCoRE.m, Tests/TestSCoRE.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function CompareScoreRab(c3dFiles, Session, Trial, folderData)

if nargin < 4, folderData = ''; end

if ~isfield(Session, 'SCoRE') || isempty(Session.SCoRE)
    if isempty(folderData)
        error('CompareScoreRab:noSCoRE', ...
              'Session.SCoRE is not computed and no folderData was provided to compute it.');
    end
    Session.SCoRE = ComputeSCoRE(folderData);
end

% -------------------------------------------------------------------------
% 1) RECAP — SCoRE calibration quality
% -------------------------------------------------------------------------
disp(' ');
disp('====================================================================');
disp(['SCoRE validation report - ', Trial.file]);
disp('====================================================================');
disp('  1) Qualite de la calibration SCoRE :');
disp('     - Cluster RMS   : rigidite des clusters scapula/humerus (soder vs CALIBRATION1),');
disp('                       doit rester petit quelle que soit la population (tissu + marqueurs).');
disp('     - CoR residual  : accord entre le CoR vu depuis la scapula et depuis l''humerus');
disp('                       (Ehrig et al. 2006) sur ANALYTIC1-4 -> quantifie l''ecart a');
disp('                       l''hypothese d''articulation spherique (domine par la STA scapulaire).');
TestSCoRE(Session);

% -------------------------------------------------------------------------
% 2) Rab vs SCoRE — segments + kinematics, computed independently
% -------------------------------------------------------------------------
Processing.GJC.method = 'Rab';
TrialRab   = DefineSegments(c3dFiles, Session, Trial, Processing);
TrialRab   = ComputeKinematics(c3dFiles, TrialRab);

Processing.GJC.method = 'SCoRE';
TrialSCoRE = DefineSegments(c3dFiles, Session, Trial, Processing);
TrialSCoRE = ComputeKinematics(c3dFiles, TrialSCoRE);

dR = distance_mm(TrialRab.Vmarker(11).Trajectory.full, TrialSCoRE.Vmarker(11).Trajectory.full);
dL = distance_mm(TrialRab.Vmarker(13).Trajectory.full, TrialSCoRE.Vmarker(13).Trajectory.full);

disp('  2) Ecart Rab vs SCoRE sur cet essai (mm) :');
printStats('RGJC (droit)',  dR);
printStats('LGJC (gauche)', dL);
disp(' ');

% -------------------------------------------------------------------------
% 3) PLOTS
% -------------------------------------------------------------------------
plotDistance(dR, dL, Trial.file);
plotJointComparison(TrialRab, TrialSCoRE, 1, 6, 'HT (Humero-thoracique)');
plotJointComparison(TrialRab, TrialSCoRE, 2, 7, 'GH (Gleno-humeral)');
plotJointComparison(TrialRab, TrialSCoRE, 3, 8, 'ST (Scapulo-thoracique)');
plotGJC3D(TrialRab, TrialSCoRE);

end

% -------------------------------------------------------------------------
function d_mm = distance_mm(a, b)
d    = squeeze(a - b); % [3xN]
d_mm = sqrt(sum(d.^2, 1)) * 1e3; % m -> mm
end

% -------------------------------------------------------------------------
function printStats(label, d_mm)
fprintf('  %-16s  mean=%6.2f mm   max=%6.2f mm   std=%6.2f mm\n', ...
        label, mean(d_mm, 'omitnan'), max(d_mm), std(d_mm, 'omitnan'));
end

% -------------------------------------------------------------------------
function plotDistance(dR, dL, fileName)
figure('Name', 'RGJC/LGJC distance - Rab vs SCoRE', 'NumberTitle', 'off');
subplot(2,1,1); plot(dR, 'b-'); ylabel('Distance (mm)'); title('RGJC (droit) - |Rab - SCoRE|');
subplot(2,1,2); plot(dL, 'r-'); ylabel('Distance (mm)'); xlabel('Frame'); title('LGJC (gauche) - |Rab - SCoRE|');
sgtitle(['Rab vs SCoRE - ', fileName], 'Interpreter', 'none');
end

% -------------------------------------------------------------------------
function plotJointComparison(TrialRab, TrialSCoRE, idxR, idxL, jointName)
figure('Name', [jointName, ' - Rab vs SCoRE'], 'NumberTitle', 'off');
sides     = {'Droit', 'Gauche'};
jointIdx  = [idxR, idxL];
dofLabels = {'DOF1', 'DOF2', 'DOF3'};
for is = 1:2
    for id = 1:3
        subplot(3, 2, (id-1)*2 + is);
        eR = squeeze(TrialRab.Joint(jointIdx(is)).Euler.full(1, id, :));
        eS = squeeze(TrialSCoRE.Joint(jointIdx(is)).Euler.full(1, id, :));
        plot(eR, 'b-', 'DisplayName', 'Rab'); hold on;
        plot(eS, 'r--', 'DisplayName', 'SCoRE');
        if id == 1, title(sides{is}); end
        if is == 1, ylabel([dofLabels{id}, ' (deg)']); end
        if id == 3, xlabel('Frame'); end
        if id == 1 && is == 1, legend('Location', 'best'); end
    end
end
sgtitle([jointName, ' - Rab vs SCoRE (', TrialRab.file, ')'], 'Interpreter', 'none');
end

% -------------------------------------------------------------------------
function plotGJC3D(TrialRab, TrialSCoRE)
% Marker/Vmarker trajectories not affected by Processing.GJC.method
% (RCAJ/LCAJ = raw markers, REJC/LEJC = elbow, identical in both Trials)
% -> read them from TrialRab for convenience.
RCAJ = squeeze(TrialRab.Marker(10).Trajectory.full) * 1e3;  % mm
LCAJ = squeeze(TrialRab.Marker(33).Trajectory.full) * 1e3;
REJC = squeeze(TrialRab.Vmarker(10).Trajectory.full) * 1e3; % elbow (coude)
LEJC = squeeze(TrialRab.Vmarker(12).Trajectory.full) * 1e3;

RGJC_Rab   = squeeze(TrialRab.Vmarker(11).Trajectory.full)   * 1e3;
RGJC_SCoRE = squeeze(TrialSCoRE.Vmarker(11).Trajectory.full) * 1e3;
LGJC_Rab   = squeeze(TrialRab.Vmarker(13).Trajectory.full)   * 1e3;
LGJC_SCoRE = squeeze(TrialSCoRE.Vmarker(13).Trajectory.full) * 1e3;

figure('Name', 'RGJC/LGJC 3D - Rab vs SCoRE', 'NumberTitle', 'off');

subplot(1,2,1);
plot3(RCAJ(1,:), RCAJ(2,:), RCAJ(3,:), 'k:', 'DisplayName', 'RCAJ (acromion)'); hold on;
plot3(REJC(1,:), REJC(2,:), REJC(3,:), 'g:', 'DisplayName', 'REJC (coude)');
plot3(RGJC_Rab(1,:),   RGJC_Rab(2,:),   RGJC_Rab(3,:),   'b-', 'LineWidth', 1.5, 'DisplayName', 'RGJC Rab');
plot3(RGJC_SCoRE(1,:), RGJC_SCoRE(2,:), RGJC_SCoRE(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'RGJC SCoRE');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Droit'); legend('Location', 'best'); axis equal; grid on; view(3);

subplot(1,2,2);
plot3(LCAJ(1,:), LCAJ(2,:), LCAJ(3,:), 'k:', 'DisplayName', 'LCAJ (acromion)'); hold on;
plot3(LEJC(1,:), LEJC(2,:), LEJC(3,:), 'g:', 'DisplayName', 'LEJC (coude)');
plot3(LGJC_Rab(1,:),   LGJC_Rab(2,:),   LGJC_Rab(3,:),   'b-', 'LineWidth', 1.5, 'DisplayName', 'LGJC Rab');
plot3(LGJC_SCoRE(1,:), LGJC_SCoRE(2,:), LGJC_SCoRE(3,:), 'r-', 'LineWidth', 1.5, 'DisplayName', 'LGJC SCoRE');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Gauche'); legend('Location', 'best'); axis equal; grid on; view(3);

sgtitle(['RGJC/LGJC 3D - Rab vs SCoRE (', TrialRab.file, ')'], 'Interpreter', 'none');
end
