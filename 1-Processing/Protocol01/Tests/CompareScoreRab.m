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
%                  3) Imaging section (patient 558792 / Jurg Muller only) :
%                     CT-based gold-standard CoR (glenosphere sphere fit,
%                     registered into the mocap lab frame) compared to both
%                     Rab and SCoRE — see Core/ComputeCTGoldStandardCoR.m.
%                     Hardcoded to this patient's data (only patient with
%                     CT available) ; skipped for any other trial. Also
%                     produces a 3D figure : postop scapula/humerus bone
%                     meshes (from CT, same relative pose as scanned) with
%                     the Rab/SCoRE RGJC trajectories and the CT CoR, all
%                     expressed in the scapula-local (CALIBRATION1-instant)
%                     frame — removes trunk/scapula motion so the plot
%                     isolates true CoR agreement, not essay-wide drift.
%                  4) Calibration combo exploration (patient 558792 only) :
%                     Tests/ExploreSCoRECombos.m ranks every combination of
%                     available ANALYTIC/FUNCTIONAL trials as SCoRE
%                     calibration input by distance to the CT gold standard
%                     on ANALYTIC1 — reports whether the default pool
%                     (ANALYTIC2+ANALYTIC4+FUNCTIONAL1+FUNCTIONAL3, see
%                     Core/ComputeSCoRE.m) is actually the best choice for
%                     this patient specifically.
%                  5) Plots : RGJC/LGJC distance vs frame, HT/GH/ST Euler
%                     angles (Rab vs SCoRE overlay, both sides).
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
%                Core/ComputeSCoRE.m, Core/ComputeCTGoldStandardCoR.m,
%                Core/BuildTechnicalTransform.m, Tests/TestSCoRE.m,
%                Tests/ExploreSCoRECombos.m,
%                stlread (built-in MATLAB function, R2018b+, no toolbox required)
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
disp('                       (Ehrig et al. 2006) sur les essais de calibration -> quantifie l''ecart a');
disp('                       l''hypothese d''articulation spherique (domine par la STA scapulaire).');
TestSCoRE(Session);

% -------------------------------------------------------------------------
% 2) Rab vs SCoRE — same call chain as MAIN_Protocol_01.m, computed
% independently on two copies of Trial, so results are guaranteed
% consistent with the standard pipeline (not a shortcut computation).
% CutCycles/ComputeSHR intentionally NOT called : neither one modifies
% Joint(*).Euler.full (CutCycles only adds .rcycle/.lcycle, ComputeSHR
% only reads cycles to compute a ratio), and CutCycles can pop up an
% interactive ginput() dialog when no legacy .mat is found — undesirable
% in an automated diagnostic function.
% -------------------------------------------------------------------------
Processing.GJC.method = 'Rab';
TrialRab   = InitialiseSegments(Trial);
TrialRab   = InitialiseJoints(TrialRab);
TrialRab   = DefineSegments(c3dFiles, Session, TrialRab, Processing);
TrialRab   = ComputeKinematics(c3dFiles, TrialRab);
TrialRab   = ComputeThoraxPosture(TrialRab);

Processing.GJC.method = 'SCoRE';
TrialSCoRE = InitialiseSegments(Trial);
TrialSCoRE = InitialiseJoints(TrialSCoRE);
TrialSCoRE = DefineSegments(c3dFiles, Session, TrialSCoRE, Processing);
TrialSCoRE = ComputeKinematics(c3dFiles, TrialSCoRE);
TrialSCoRE = ComputeThoraxPosture(TrialSCoRE);

dR = distance_mm(TrialRab.Vmarker(11).Trajectory.full, TrialSCoRE.Vmarker(11).Trajectory.full);
dL = distance_mm(TrialRab.Vmarker(13).Trajectory.full, TrialSCoRE.Vmarker(13).Trajectory.full);

disp('  2) Ecart Rab vs SCoRE sur cet essai (mm) :');
printStats('RGJC (droit)',  dR);
printStats('LGJC (gauche)', dL);
disp(' ');

% -------------------------------------------------------------------------
% 3) IMAGERIE (CT) — patient 558792 (Jurg Muller) uniquement
% -------------------------------------------------------------------------
if contains(Trial.file, '558792')
    ctFolder    = ['C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\', ...
                   '01_Data\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data\Muller_Jurg_558792\CT'];
    ctMocapData = ['C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\', ...
                   '01_Data\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data\Muller_Jurg_558792\20260324'];

    disp('  3) Comparaison au gold standard CT (glenosphere, cote droit) :');
    CTGold = ComputeCTGoldStandardCoR(ctFolder, ctMocapData, 'R');

    Ti_trial = BuildTechnicalTransform(Session.SCoRE.xRef.RS, ...
                   {TrialRab.Marker(11).Trajectory.full, TrialRab.Marker(12).Trajectory.full, TrialRab.Marker(13).Trajectory.full});
    RGJC_gold        = Mprod_array3(Ti_trial, repmat([CTGold.rCsi; 1], [1, 1, size(Ti_trial,3)]));
    RGJC_gold(4,:,:) = [];

    dRabGold   = distance_mm(TrialRab.Vmarker(11).Trajectory.full,   RGJC_gold);
    dSCoREGold = distance_mm(TrialSCoRE.Vmarker(11).Trajectory.full, RGJC_gold);

    printStats('RGJC Rab vs CT',   dRabGold);
    printStats('RGJC SCoRE vs CT', dSCoREGold);
    disp(' ');

    plotCoR3D(TrialRab, TrialSCoRE, Session, CTGold, ctFolder);

    disp('  4) Exploration des combinaisons de calibration SCoRE (vs CT) :');
    ExploreSCoRECombos(ctMocapData, ctFolder, 'ANALYTIC1');
else
    disp('  3) Section imagerie (CT) ignoree : essai non associe au patient 558792.');
    disp(' ');
end

% -------------------------------------------------------------------------
% 5) PLOTS
% -------------------------------------------------------------------------
plotDistance(dR, dL, Trial.file);
plotJointComparison(TrialRab, TrialSCoRE, 1, 6, 'HT (Humero-thoracique)');
plotJointComparison(TrialRab, TrialSCoRE, 2, 7, 'GH (Gleno-humeral)');
plotJointComparison(TrialRab, TrialSCoRE, 3, 8, 'ST (Scapulo-thoracique)');

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

% Both meshes come from the SAME CT scan -> the SAME registration (scapula
% landmarks) places them together preserving their true relative pose as
% captured on CT (no separate humerus registration needed/well-posed with
% only 2 humeral landmarks available).
scapV_m = (CTGold.Rreg * (scapMesh.Points'/1e3) + CTGold.dreg)'; % [Nx3], m
humV_m  = (CTGold.Rreg * (humMesh.Points'/1e3)  + CTGold.dreg)'; % [Nx3], m

% Numeric check (camera-angle independent) : bounding boxes + closest
% point between the two transformed meshes, to confirm/refute a visual
% impression of a gap between scapula and humerus.
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

% -------------------------------------------------------------------------
% SANITY CHECK (prof's remark) : RCAJ (acromion marker, rigidly attached
% to the scapula, index 10 in markerSet, NOT one of the Cluster_RS_01-03
% markers used to build the technical frame -> independent check) should
% appear near-stationary once expressed in the scapula-local frame. If it
% doesn't, there is a real bug in the technical-frame code. If it IS
% stationary but Rab's full RGJC still sweeps an arc, that arc is a real
% property of Rab's formula (RCAJ + fixed-magnitude offset along
% thoraxSIaxis, which is thorax-anchored, not scapula-anchored -> its
% direction rotates relative to the scapula during scapulothoracic rhythm).
% -------------------------------------------------------------------------
RCAJ_h          = ones(4, 1, N);
RCAJ_h(1:3,1,:) = TrialRab.Marker(10).Trajectory.full;
RCAJ_local       = Mprod_array3(TiInv, RCAJ_h);
RCAJ_local_mm    = squeeze(RCAJ_local(1:3,1,:))' * 1e3; % [Nx3], mm
RCAJ_range_mm    = max(RCAJ_local_mm, [], 1) - min(RCAJ_local_mm, [], 1);
fprintf('  [check prof] RCAJ (acromion) range in scapula-local frame (mm) : X=%.1f Y=%.1f Z=%.1f\n', ...
        RCAJ_range_mm(1), RCAJ_range_mm(2), RCAJ_range_mm(3));

CoR_CT_mm = CTGold.rCsi' * 1e3; % [1x3]

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
    'MarkerFaceAlpha', 0.35, 'DisplayName', 'RGJC SCoRE (trajectoire, colore par flexion HT)');

% Instant de reference commun (bras le plus proche du repos, flexion mini)
% -> comparaison directe Rab/SCoRE/CT au meme moment, plutot que le nuage
% entier de l'essai contre un seul point CT statique.
[~, idxRef] = min(elevAngle_Rab + elevAngle_SCoRE);
dRab_ref   = norm(RGJC_Rab_local_mm(idxRef,:)   - CoR_CT_mm);
dSCoRE_ref = norm(RGJC_SCoRE_local_mm(idxRef,:) - CoR_CT_mm);
fprintf('  Instant repos (frame %d, flexion Rab=%.1f deg, SCoRE=%.1f deg) :\n', ...
        idxRef, elevAngle_Rab(idxRef), elevAngle_SCoRE(idxRef));
fprintf('    RGJC Rab   vs CT : %.2f mm\n', dRab_ref);
fprintf('    RGJC SCoRE vs CT : %.2f mm\n', dSCoRE_ref);
scatter3(RGJC_Rab_local_mm(idxRef,1), RGJC_Rab_local_mm(idxRef,2), RGJC_Rab_local_mm(idxRef,3), ...
    180, 'o', 'filled', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
    'DisplayName', 'RGJC Rab (instant repos)');
scatter3(RGJC_SCoRE_local_mm(idxRef,1), RGJC_SCoRE_local_mm(idxRef,2), RGJC_SCoRE_local_mm(idxRef,3), ...
    180, '^', 'filled', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
    'DisplayName', 'RGJC SCoRE (instant repos)');
scatter3(CoR_CT_mm(1), CoR_CT_mm(2), CoR_CT_mm(3), 150, 'g', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'DisplayName', 'CoR CT (gold standard)');

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
title({'RGJC Rab vs SCoRE vs CT — repere scapula (essai complet)', TrialRab.file}, 'Interpreter', 'none');

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
fprintf('  Correlation distance-au-CT vs flexion HT (r de Pearson) :\n');
fprintf('    Rab   : r = %.2f\n', RmatRab(1,2));
fprintf('    SCoRE : r = %.2f\n', RmatSCoRE(1,2));

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
Ps = subsample(scapV_m, nSub);
Ph = subsample(humV_m,  nSub);

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

function P = subsample(P, n)
if size(P,1) > n
    P = P(randperm(size(P,1), n), :);
end
end
