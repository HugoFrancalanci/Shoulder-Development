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
% Description:   CT-based gold-standard validation of the glenohumeral CoR
%                (only meaningful for a patient with post-op CT available).
%                Split out of Tests/CoR/CompareScoreRab.m
%                so the CT-imaging theme can be read/run on its own.
%                  1) Rab vs SCoRE (vue humerus, the one used pipeline-wide)
%                     vs CT gold standard (glenosphere sphere fit, registered
%                     into the mocap lab frame) — see Core/CoR/ComputeCTGoldStandardCoR.m.
%                  2) "3bis" : SCoRE CoR reprojected via the scapula cluster
%                     (Ti*rCsi) vs via the humerus cluster (Tj*rCsj) against
%                     each other and against CT — same calibration (current
%                     4-trial combo), just the two reprojection paths — to
%                     see which cluster is less reliable for placing the CoR.
%                  3) Figure : plotCoR3D — postop scapula/humerus bone
%                     meshes (from CT) with the Rab/SCoRE RGJC trajectories,
%                     the CT CoR and the scapula-view CoR, all expressed in
%                     the scapula-local (CALIBRATION1-instant) frame —
%                     removes trunk/scapula motion so the plot isolates true
%                     CoR agreement, not essay-wide drift. Also plots
%                     distance to CT vs flexion (Rab/SCoRE).
%                  4) Calibration combo exploration : Tests/CoR/ExploreSCoRECombos.m
%                     ranks every combination of available ANALYTIC/FUNCTIONAL
%                     trials as SCoRE calibration input by distance to the CT
%                     gold standard on ANALYTIC1 — reports whether the default
%                     pool (ANALYTIC2+ANALYTIC4+FUNCTIONAL1+FUNCTIONAL3, see
%                     Core/CoR/ComputeSCoRE.m) is actually the best choice for
%                     this patient specifically.
% -------------------------------------------------------------------------
% Inputs  : TrialRab, TrialSCoRE (struct) same trial, kinematics computed
%             with Processing.GJC.method = 'Rab' / 'SCoRE' respectively
%           Session     (struct) needs Session.SCoRE (xRef, R.rCsi, R.rCsj)
%           ctFolder    (char)   folder with the CT .fcsv/.STL files
%           ctMocapData (char)   patient mocap folder (CALIBRATION1 reference)
% Outputs : CTGold  (struct, see Core/CoR/ComputeCTGoldStandardCoR.m)
%           Console report + figures (see above), not saved to disk
% -------------------------------------------------------------------------
% Dependencies : Core/CoR/ComputeCTGoldStandardCoR.m, Core/CoR/BuildTechnicalTransform.m,
%                Core/CoR/DistanceMM.m, Core/CoR/PrintCoRStats.m, Core/CoR/SubsamplePoints.m,
%                Tests/CoR/ExploreSCoRECombos.m,
%                stlread (built-in MATLAB function, R2018b+, no toolbox required)
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function CTGold = ValidateCoRvsCT(TrialRab, TrialSCoRE, Session, ctFolder, ctMocapData)

disp('  2) Comparaison au gold standard CT (glenosphere, cote droit) :');
CTGold = ComputeCTGoldStandardCoR(ctFolder, ctMocapData, 'R');

Ti_trial = BuildTechnicalTransform(Session.SCoRE.xRef.RS, ...
               {TrialRab.Marker(11).Trajectory.full, TrialRab.Marker(12).Trajectory.full, TrialRab.Marker(13).Trajectory.full});
RGJC_gold        = Mprod_array3(Ti_trial, repmat([CTGold.rCsi; 1], [1, 1, size(Ti_trial,3)]));
RGJC_gold(4,:,:) = [];

dRabGold   = DistanceMM(TrialRab.Vmarker(11).Trajectory.full,   RGJC_gold);
dSCoREGold = DistanceMM(TrialSCoRE.Vmarker(11).Trajectory.full, RGJC_gold);

PrintCoRStats('RGJC Rab vs CT',   dRabGold);
PrintCoRStats('RGJC SCoRE vs CT', dSCoREGold);
disp(' ');

% -------------------------------------------------------------------------
% 3bis) CoR moyen SCoRE : cluster scapula vs cluster humerus (consigne prof).
% Le CoR local (rCsi/rCsj) est deja un point constant, calcule une seule
% fois sur l'ensemble des frames des essais de calibration (combinaison
% actuelle ANALYTIC2+ANALYTIC4+FUNCTIONAL1+FUNCTIONAL3, voir
% Core/CoR/ComputeSCoRE.m) - pas de nouvelle calibration ici. On compare
% juste les DEUX facons de le reprojeter en global sur cet essai :
% via le cluster scapula (Ti*rCsi) vs via le cluster humerus (Tj*rCsj,
% deja utilise comme RGJC SCoRE dans le reste du pipeline, Core/DefineSegments.m).
% Le cluster dont la reprojection s'ecarte le plus du CT est le moins
% fiable pour y placer le CoR.
% -------------------------------------------------------------------------
N                       = size(Ti_trial, 3);
RGJC_viaScapula         = Mprod_array3(Ti_trial, repmat([Session.SCoRE.R.rCsi; 1], [1, 1, N]));
RGJC_viaScapula(4,:,:)  = [];
RGJC_viaHumerus         = TrialSCoRE.Vmarker(11).Trajectory.full; % deja = Tj*rCsj

dScapVsHum  = DistanceMM(RGJC_viaScapula, RGJC_viaHumerus);
dScapVsGold = DistanceMM(RGJC_viaScapula, RGJC_gold);

disp('  CoR moyen SCoRE : cluster scapula vs cluster humerus (fiabilite) :');
PrintCoRStats('Scapula vs Humerus', dScapVsHum);
PrintCoRStats('Scapula vs CT',      dScapVsGold);
PrintCoRStats('Humerus vs CT',      dSCoREGold);
disp(' ');

plotCoR3D(TrialRab, TrialSCoRE, Session, CTGold, ctFolder);

ExploreSCoRECombos(ctMocapData, ctFolder, 'ANALYTIC1', [], CTGold);

end

% -------------------------------------------------------------------------
%  3D BONES (CT) + RGJC Rab/SCoRE/CT, ALL EXPRESSED IN THE SCAPULA-LOCAL
%  (CALIBRATION1-INSTANT) FRAME — removes the confound of scapula/trunk
%  motion during the trial, isolating the true CoR agreement.
% -------------------------------------------------------------------------
function plotCoR3D(TrialRab, TrialSCoRE, Session, CTGold, ctFolder)

scapulaSTL = dir(fullfile(ctFolder, '*postop_scapula.STL'));
humerusSTL = dir(fullfile(ctFolder, '*postop_humerus.STL'));
if isempty(scapulaSTL) || isempty(humerusSTL)
    warning('plotCoR3D:noSTL', 'Postop STL meshes not found in %s -> 3D bone plot skipped.', ctFolder);
    return;
end

scapMesh = stlread(fullfile(scapulaSTL(1).folder, scapulaSTL(1).name));
humMesh  = stlread(fullfile(humerusSTL(1).folder, humerusSTL(1).name));

% Scapula : registered via its own landmarks (SRS/SAA/SIA).
% Humerus  : registered INDEPENDENTLY (CTGold.humerus.Rreg/dreg — cup
% centre + HME/HLE, see Core/CoR/ComputeCTGoldStandardCoR.m), not by reusing
% the scapula's registration. See CTGold.humerus.sameScanDiscrepancy_mm
% (printed by ComputeCTGoldStandardCoR) for how much this differs from the
% previous "same CT scan" assumption.
scapV_m = (CTGold.Rreg          * (scapMesh.Points'/1e3) + CTGold.dreg)';          % [Nx3], m
humV_m  = (CTGold.humerus.Rreg  * (humMesh.Points'/1e3)  + CTGold.humerus.dreg)';  % [Nx3], m

% Numeric check (camera-angle independent) : bounding boxes + closest
% point between the two transformed meshes, to confirm/refute a visual
% impression of a gap between scapula and humerus.
disp('  -- Figure 3D : maillages CT + trajectoires Rab/SCoRE/CT --');
checkMeshGap(scapV_m, humV_m);

% Rab/SCoRE RGJC trajectories -> scapula-local (CALIBRATION1-instant) frame
Ti_trial = BuildTechnicalTransform(Session.SCoRE.xRef.RS, ...
               {TrialRab.Marker(11).Trajectory.full, TrialRab.Marker(12).Trajectory.full, TrialRab.Marker(13).Trajectory.full});
TiInv    = Tinv_array3(Ti_trial);
N        = size(Ti_trial, 3);

RGJC_Rab_h          = ones(4, 1, N);
RGJC_Rab_h(1:3,1,:) = TrialRab.Vmarker(11).Trajectory.full;
RGJC_Rab_local       = Mprod_array3(TiInv, RGJC_Rab_h);
RGJC_Rab_local_mm    = squeeze(RGJC_Rab_local(1:3,1,:))' * 1e3; % [Nx3], mm

RGJC_SCoRE_h          = ones(4, 1, N);
RGJC_SCoRE_h(1:3,1,:) = TrialSCoRE.Vmarker(11).Trajectory.full;
RGJC_SCoRE_local       = Mprod_array3(TiInv, RGJC_SCoRE_h);
RGJC_SCoRE_local_mm    = squeeze(RGJC_SCoRE_local(1:3,1,:))' * 1e3; % [Nx3], mm

CoR_CT_mm = CTGold.rCsi' * 1e3; % [1x3]

% CoR moyen SCoRE, vue scapula (Ti*rCsi reprojete puis re-exprime en local
% scapula = rCsi lui-meme, constant par construction — voir section 3bis de
% Tests/CoR/ValidateCoRvsCT.m : la distance a CT est fixe (ne depend pas de
% la posture), contrairement a la version humerus (nuage rouge ci-dessous).
CoR_viaScapula_mm = Session.SCoRE.R.rCsi' * 1e3; % [1x3], mm

% HT flexion (right, DOF stored at position 3 = Z, first axis of the
% 'ZXY' sequence used for ANALYTIC1 sagittal elevation, see
% ComputeKinematics.m). Z is the dominant axis for a movement staying
% close to the sagittal plane (X, position 1, only captures the
% out-of-plane residual -> was showing an artificially small range).
% Magnitude only (abs) : the toolbox's +/- sign convention for this
% floating axis is not reliably "0=rest" across the full excursion (a
% signed flip still showed negative values down to -120) -> using the
% absolute angle avoids that ambiguity, still 0 = rest / larger = more
% flexed regardless of sign convention.
% Colors BOTH clouds (Rab and SCoRE) on the same scale, so movement phase
% is directly comparable between methods (marker shape distinguishes them).
elevAngle_Rab   = abs(squeeze(TrialRab.Joint(1).Euler.full(1, 3, :)));
elevAngle_SCoRE = abs(squeeze(TrialSCoRE.Joint(1).Euler.full(1, 3, :)));

figure('Name', 'RGJC 3D - Rab vs SCoRE vs CT (repere scapula)', 'NumberTitle', 'off');
trisurf(scapMesh.ConnectivityList, scapV_m(:,1)*1e3, scapV_m(:,2)*1e3, scapV_m(:,3)*1e3, ...
    'FaceColor', [0.80 0.80 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.35, 'DisplayName', 'Scapula (CT)');
hold on;
trisurf(humMesh.ConnectivityList, humV_m(:,1)*1e3, humV_m(:,2)*1e3, humV_m(:,3)*1e3, ...
    'FaceColor', [0.90 0.80 0.70], 'EdgeColor', 'none', 'FaceAlpha', 0.35, 'DisplayName', 'Humerus (CT)');

scatter3(RGJC_Rab_local_mm(:,1), RGJC_Rab_local_mm(:,2), RGJC_Rab_local_mm(:,3), 30, elevAngle_Rab, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.35, 'DisplayName', 'RGJC Rab (trajectoire, colore par flexion HT)');
scatter3(RGJC_SCoRE_local_mm(:,1), RGJC_SCoRE_local_mm(:,2), RGJC_SCoRE_local_mm(:,3), 30, elevAngle_SCoRE, '^', 'filled', ...
    'MarkerFaceAlpha', 0.35, 'DisplayName', 'RGJC SCoRE (vue humerus, trajectoire, colore par flexion HT)');

% Instant de reference commun (bras le plus proche du repos, flexion mini)
% -> comparaison directe Rab/SCoRE/CT au meme moment, plutot que le nuage
% entier de l'essai contre un seul point CT statique.
[~, idxRef] = min(elevAngle_Rab + elevAngle_SCoRE);
dRab_ref   = norm(RGJC_Rab_local_mm(idxRef,:)   - CoR_CT_mm);
dSCoRE_ref = norm(RGJC_SCoRE_local_mm(idxRef,:) - CoR_CT_mm);
fprintf('  Instant repos (%.1f deg) : Rab vs CT=%.2f mm | SCoRE vs CT=%.2f mm\n', ...
        (elevAngle_Rab(idxRef)+elevAngle_SCoRE(idxRef))/2, dRab_ref, dSCoRE_ref);
scatter3(RGJC_Rab_local_mm(idxRef,1), RGJC_Rab_local_mm(idxRef,2), RGJC_Rab_local_mm(idxRef,3), ...
    180, 'o', 'filled', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
    'DisplayName', 'RGJC Rab (instant repos)');
scatter3(RGJC_SCoRE_local_mm(idxRef,1), RGJC_SCoRE_local_mm(idxRef,2), RGJC_SCoRE_local_mm(idxRef,3), ...
    180, '^', 'filled', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
    'DisplayName', 'RGJC SCoRE (vue humerus, instant repos)');
scatter3(CoR_CT_mm(1), CoR_CT_mm(2), CoR_CT_mm(3), 150, 'g', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', 'CoR CT (gold standard)');
scatter3(CoR_viaScapula_mm(1), CoR_viaScapula_mm(2), CoR_viaScapula_mm(3), 180, 'm', 'd', 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', 'CoR SCoRE (vue scapula, fixe)');

colormap(gca, 'jet');
% trisurf(TRI,X,Y,Z) implicitly derives a Z-based CData even with
% 'FaceColor' set to a literal RGB, which was polluting the shared axes
% color limits (colorbar was showing ~Z-in-mm, not degrees) -> force the
% limits explicitly to the true elevAngle range, shared across both clouds.
clim(gca, [min([elevAngle_Rab; elevAngle_SCoRE]), max([elevAngle_Rab; elevAngle_SCoRE])]);
cb = colorbar; cb.Label.String = 'Flexion HT droite (deg, 0=repos)';
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
axis equal; grid on; view(3); camlight; lighting gouraud;
legend('Location', 'best');
title({'RGJC Rab vs SCoRE vs CT — repere scapula (essai complet)', ...
       'losange magenta = CoR SCoRE vue scapula (fixe) ; triangle rouge = vue humerus (varie)', ...
       TrialRab.file}, 'Interpreter', 'none');

% -------------------------------------------------------------------------
% VERIFICATION : l'ecart au CT croit-il avec l'eloignement de la posture
% neutre ? Hypothese : l'erreur de calibration (fixe dans le repere
% humerus pour SCoRE / thorax pour Rab) est "emportee" par la rotation du
% bras -> distance au CT correlee positivement avec l'angle de flexion.
% -------------------------------------------------------------------------
dRab_all_mm   = sqrt(sum((RGJC_Rab_local_mm   - CoR_CT_mm).^2, 2));
dSCoRE_all_mm = sqrt(sum((RGJC_SCoRE_local_mm - CoR_CT_mm).^2, 2));

RmatRab   = corrcoef(elevAngle_Rab,   dRab_all_mm);
RmatSCoRE = corrcoef(elevAngle_SCoRE, dSCoRE_all_mm);
fprintf('  Correlation distance-au-CT vs flexion (r Pearson) : Rab=%.2f | SCoRE=%.2f\n', RmatRab(1,2), RmatSCoRE(1,2));

figure('Name', 'Distance au CT vs flexion', 'NumberTitle', 'off');
scatter(elevAngle_Rab, dRab_all_mm, 10, 'b', 'filled', 'DisplayName', 'Rab'); hold on;
scatter(elevAngle_SCoRE, dSCoRE_all_mm, 10, 'r', 'filled', 'DisplayName', 'SCoRE');
xlabel('Flexion HT (deg, 0=repos)'); ylabel('Distance au CT gold standard (mm)');
legend('Location', 'best'); grid on;
title({'Ecart au CT en fonction de l''eloignement du repos', TrialRab.file}, 'Interpreter', 'none');

end

% -------------------------------------------------------------------------
%  NUMERIC BONE-GAP CHECK (bounding boxes + closest-point distance),
%  independent of camera angle/transparency — see if a visual "dislocation"
%  is real or a rendering artefact.
% -------------------------------------------------------------------------
function checkMeshGap(scapV_m, humV_m)

scapBBox_mm = [min(scapV_m); max(scapV_m)] * 1e3; % [2x3] : row1=min, row2=max
humBBox_mm  = [min(humV_m);  max(humV_m)]  * 1e3;

fprintf('  Scapula mesh bbox (mm) : X[%.1f %.1f] Y[%.1f %.1f] Z[%.1f %.1f]\n', ...
        scapBBox_mm(1,1), scapBBox_mm(2,1), scapBBox_mm(1,2), scapBBox_mm(2,2), scapBBox_mm(1,3), scapBBox_mm(2,3));
fprintf('  Humerus mesh bbox (mm) : X[%.1f %.1f] Y[%.1f %.1f] Z[%.1f %.1f]\n', ...
        humBBox_mm(1,1), humBBox_mm(2,1), humBBox_mm(1,2), humBBox_mm(2,2), humBBox_mm(1,3), humBBox_mm(2,3));

% Closest-point distance between the two point clouds (subsampled to keep
% the brute-force N-by-M distance search tractable, no toolbox required)
nSub = 3000;
Ps = SubsamplePoints(scapV_m, nSub);
Ph = SubsamplePoints(humV_m,  nSub);

minD_mm = inf;
for i = 1:size(Ps,1)
    d    = sqrt(sum((Ph - Ps(i,:)).^2, 2));
    minD_mm = min(minD_mm, min(d));
end
minD_mm = minD_mm * 1e3;

fprintf('  Distance minimale scapula-humerus (mm) : %.2f %s\n', minD_mm, ...
        char(ternary(minD_mm < 5, '(quasi en contact)', '(ecart visible)')));
end

function s = ternary(cond, a, b)
if cond, s = a; else, s = b; end
end
