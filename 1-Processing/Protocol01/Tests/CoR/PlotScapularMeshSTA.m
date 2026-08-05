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
% Description:   STA VISUALISATION : scapular anatomical markers (AA/IA/TS/AC,
%                same landmarks as Tests/CoR/TestScapularCluster.m) overlaid
%                on the CT scapula mesh (only meaningful for a patient with
%                CT data available),
%                reprojected into the scapula-local (CALIBRATION1-instant)
%                frame and coloured by flexion angle. If a marker is rigid
%                on the bone, its point cloud should sit as a tight dot on
%                the mesh surface regardless of colour ; visible spreading
%                away from the surface, especially at higher (redder)
%                flexion, is the visual signature of soft tissue artefact
%                (STA). Right side only (matches the rest of this patient's
%                CT validation).
%
%                Also computes a NUMERIC check : distance from each marker
%                to the nearest mesh vertex, per frame — does the marker
%                actually sit on the true bone surface, and does that
%                distance grow with flexion (a more direct STA signal than
%                the inter-landmark distances in Tests/CoR/TestScapularCluster.m,
%                which only see DIFFERENTIAL drift between markers, not
%                drift relative to the true bone).
%
%                Split out of Tests/CoR/CompareScoreRab.m so the STA theme
%                can be read/run independently of the CoR-vs-CT validation.
% -------------------------------------------------------------------------
% Inputs  : TrialRab (struct) trial with Rab kinematics computed
%           Session  (struct) needs Session.SCoRE.xRef.RS
%           CTGold   (struct) see Core/CoR/ComputeCTGoldStandardCoR.m
%           ctFolder (char)   folder with the CT .STL files
% Outputs : Console report (mean/max distance mm + Pearson r vs flexion,
%             per marker) ; 2 figures (not saved to disk)
% -------------------------------------------------------------------------
% Dependencies : Core/CoR/BuildTechnicalTransform.m, Core/CoR/SubsamplePoints.m,
%                stlread (built-in MATLAB function, R2018b+, no toolbox required)
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotScapularMeshSTA(TrialRab, Session, CTGold, ctFolder)

scapulaSTL = dir(fullfile(ctFolder, '*postop_scapula.STL'));
if isempty(scapulaSTL)
    warning('PlotScapularMeshSTA:noSTL', 'Postop scapula STL not found in %s -> skipped.', ctFolder);
    return;
end
scapMesh = stlread(fullfile(scapulaSTL(1).folder, scapulaSTL(1).name));
scapV_m  = (CTGold.Rreg * (scapMesh.Points'/1e3) + CTGold.dreg)'; % [Nx3], m

% Scapula-local (CALIBRATION1-instant) technical frame for this trial —
% same construction as Tests/CoR/ValidateCoRvsCT.m's plotCoR3D.
Ti_trial = BuildTechnicalTransform(Session.SCoRE.xRef.RS, ...
               {TrialRab.Marker(11).Trajectory.full, TrialRab.Marker(12).Trajectory.full, TrialRab.Marker(13).Trajectory.full});
TiInv = Tinv_array3(Ti_trial);
N     = size(Ti_trial, 3);

% AA/IA/TS/AC, right side — same indices as Tests/CoR/TestScapularCluster.m
AA = reprojectLocal_mm(TiInv, TrialRab.Marker(16).Trajectory.full, N);
IA = reprojectLocal_mm(TiInv, TrialRab.Marker(14).Trajectory.full, N);
TS = reprojectLocal_mm(TiInv, TrialRab.Marker(15).Trajectory.full, N);
AC = reprojectLocal_mm(TiInv, TrialRab.Marker(10).Trajectory.full, N);

elevAngle = abs(squeeze(TrialRab.Joint(1).Euler.full(1, 3, :)));

% -------------------------------------------------------------------------
% NUMERIC CHECK : distance from each marker to the nearest mesh vertex,
% per frame — mesh subsampled (same helper as checkMeshGap in
% Tests/CoR/ValidateCoRvsCT.m) to keep this tractable.
% -------------------------------------------------------------------------
meshVerts_mm = SubsamplePoints(scapV_m, 4000) * 1e3; % [Mx3], mm

dAA_mm = distanceToMesh(AA, meshVerts_mm);
dIA_mm = distanceToMesh(IA, meshVerts_mm);
dTS_mm = distanceToMesh(TS, meshVerts_mm);
dAC_mm = distanceToMesh(AC, meshVerts_mm);

RmatAA = corrcoef(elevAngle, dAA_mm); RmatIA = corrcoef(elevAngle, dIA_mm);
RmatTS = corrcoef(elevAngle, dTS_mm); RmatAC = corrcoef(elevAngle, dAC_mm);

disp('  -- Distance entre marqueurs cinematiques et maillage CT (mm) --');
fprintf('  %-4s %7s %7s %7s\n', 'Rep.', 'Mean', 'Max', 'r');
disp(['  ', repmat('-', 1, 28)]);
fprintf('  %-4s %7.2f %7.2f %7.2f\n', 'AA', mean(dAA_mm,'omitnan'), max(dAA_mm), RmatAA(1,2));
fprintf('  %-4s %7.2f %7.2f %7.2f\n', 'IA', mean(dIA_mm,'omitnan'), max(dIA_mm), RmatIA(1,2));
fprintf('  %-4s %7.2f %7.2f %7.2f\n', 'TS', mean(dTS_mm,'omitnan'), max(dTS_mm), RmatTS(1,2));
fprintf('  %-4s %7.2f %7.2f %7.2f\n', 'AC', mean(dAC_mm,'omitnan'), max(dAC_mm), RmatAC(1,2));
disp(' ');

figure('Name', 'Distance marqueurs-maillage vs flexion', 'NumberTitle', 'off');
scatter(elevAngle, dAA_mm, 8, 'filled', 'DisplayName', 'AA'); hold on;
scatter(elevAngle, dIA_mm, 8, 'filled', 'DisplayName', 'IA');
scatter(elevAngle, dTS_mm, 8, 'filled', 'DisplayName', 'TS');
scatter(elevAngle, dAC_mm, 8, 'filled', 'DisplayName', 'AC');
xlabel('Flexion HT (deg, 0=repos)'); ylabel('Distance au maillage CT (mm)');
legend('Location', 'best'); grid on;
title({'Distance marqueur scapulaire -> os (CT) vs flexion', TrialRab.file}, 'Interpreter', 'none');

figure('Name', 'Marqueurs scapulaires sur maillage CT', 'NumberTitle', 'off');
trisurf(scapMesh.ConnectivityList, scapV_m(:,1)*1e3, scapV_m(:,2)*1e3, scapV_m(:,3)*1e3, ...
    'FaceColor', [0.80 0.80 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.35, 'DisplayName', 'Scapula (CT)');
hold on;
scatter3(AA(1,:), AA(2,:), AA(3,:), 14, elevAngle, 'o', 'filled', 'DisplayName', 'AA');
scatter3(IA(1,:), IA(2,:), IA(3,:), 14, elevAngle, '^', 'filled', 'DisplayName', 'IA');
scatter3(TS(1,:), TS(2,:), TS(3,:), 14, elevAngle, 's', 'filled', 'DisplayName', 'TS');
scatter3(AC(1,:), AC(2,:), AC(3,:), 14, elevAngle, 'd', 'filled', 'DisplayName', 'AC');
colormap(gca, 'jet');
clim(gca, [min(elevAngle), max(elevAngle)]);
cb = colorbar; cb.Label.String = 'Flexion HT droite (deg, 0=repos)';
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
axis equal; grid on; view(3); camlight; lighting gouraud; legend('Location', 'best');
title({'Marqueurs scapulaires (AA/IA/TS/AC) sur maillage CT', TrialRab.file}, 'Interpreter', 'none');

end

% -------------------------------------------------------------------------
function p_local_mm = reprojectLocal_mm(TiInv, p_global, N)
p_h          = ones(4, 1, N);
p_h(1:3,1,:) = p_global;
p_local      = Mprod_array3(TiInv, p_h);
p_local_mm   = squeeze(p_local(1:3,1,:)) * 1e3; % [3xN], mm
end

% -------------------------------------------------------------------------
%  DISTANCE FROM A MOVING POINT (PER FRAME) TO THE NEAREST VERTEX OF A
%  (SUBSAMPLED) STATIC MESH POINT CLOUD.
% -------------------------------------------------------------------------
function d_mm = distanceToMesh(points_mm, meshVerts_mm)
N    = size(points_mm, 2);
d_mm = nan(1, N);
for i = 1:N
    diffs   = meshVerts_mm - points_mm(:,i)';
    d_mm(i) = min(sqrt(sum(diffs.^2, 2)));
end
end
