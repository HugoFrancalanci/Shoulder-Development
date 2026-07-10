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
% Description:   Soft tissue artefact (STA) diagnostic for the scapular
%                skin markers, following supervisor feedback : an
%                internal-consistency check (e.g. a marker moving rigidly
%                with its own cluster) does NOT prove the cluster itself
%                stays fixed relative to the true bone — a cluster can be
%                perfectly rigid internally while sliding as a whole on
%                the skin. This test checks the RIGID BODY assumption
%                directly : if the scapula (AA, IA, TS, AC) truly moves as
%                one rigid segment, the pairwise distances between these
%                4 landmarks must stay constant throughout the movement.
%                Drift in these distances, plotted against the humeral
%                flexion angle, reveals the STA onset angle — expected in
%                the literature around 90-100 deg (e.g. Karduna et al. 2001).
%
%                AA  = acromial angle    (RSAA / LSAA)
%                IA  = inferior angle    (RSIA / LSIA)
%                TS  = trigonum spinae   (RSRS / LSRS)
%                AC  = acromion          (RCAJ / LCAJ) — Rab's reference point
%
%                Independent of GJC method (Rab/SCoRE) and of the CT gold
%                standard — pure raw-marker diagnostic, usable on any patient.
%                Same convention as TestHG.m/TestICS.m : takes the full
%                Trial array, finds the relevant task itself, loops both sides.
% -------------------------------------------------------------------------
% Inputs  : Trial    (struct array) all trials from MAIN_Protocol_01
%                     (Segment/Joint must already be populated, i.e. called
%                     after DefineSegments + ComputeKinematics)
%           taskName (char, optional) trial to analyse, default 'ANALYTIC1'
% Outputs : Console report (STA onset angle per landmark pair, deg)
%           Figures (per side) : landmark 3D trajectories (thorax-local
%                     frame, colored by flexion) ; inter-landmark distances
%                     vs flexion angle ; zoomed deviation-from-rest version
%                     (all pairs on a common +/-10mm scale, regardless of
%                     their absolute baseline distance)
% -------------------------------------------------------------------------
% Dependencies : Tinv_array3.m, Mprod_array3.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function TestScapularCluster(Trial, taskName)

if nargin < 2 || isempty(taskName), taskName = 'ANALYTIC1'; end

idx = find(contains({Trial.file}, taskName), 1);
if isempty(idx)
    disp(' ');
    disp(['  TestScapularCluster : ', taskName, ' introuvable -> test ignore.']);
    return;
end

runSTAcheck(Trial(idx), 'R');
runSTAcheck(Trial(idx), 'L');

end

% -------------------------------------------------------------------------
function runSTAcheck(Trial, side)

if strcmpi(side, 'R')
    idxAA = 16; idxIA = 14; idxTS = 15; idxAC = 10; idxJoint = 1;
    sideLabel = 'Droit';
else
    idxAA = 39; idxIA = 37; idxTS = 38; idxAC = 33; idxJoint = 6;
    sideLabel = 'Gauche';
end

disp(' ');
disp('------------------------------------------------------------------');
disp(['STA scapulaire (AA/IA/TS/AC) - ', sideLabel, ' - ', Trial.file]);
disp('------------------------------------------------------------------');

% -------------------------------------------------------------------------
% LANDMARKS -> repere thorax (retire le mouvement du tronc, convention
% standard dans la litterature pour ce type d'analyse)
% -------------------------------------------------------------------------
TiInv = Tinv_array3(Trial.Segment(4).T.full);
N     = size(Trial.Segment(4).T.full, 3);

AA = reprojectLocal(TiInv, Trial.Marker(idxAA).Trajectory.full, N);
IA = reprojectLocal(TiInv, Trial.Marker(idxIA).Trajectory.full, N);
TS = reprojectLocal(TiInv, Trial.Marker(idxTS).Trajectory.full, N);
AC = reprojectLocal(TiInv, Trial.Marker(idxAC).Trajectory.full, N);

% Angle de flexion HT (meme convention que CompareScoreRab.m : position 3
% = Z, sequence 'ZXY' pour ANALYTIC1 sagittal ; magnitude uniquement)
elevAngle = abs(squeeze(Trial.Joint(idxJoint).Euler.full(1, 3, :)));

% -------------------------------------------------------------------------
% DISTANCES INTER-LANDMARKS (doivent rester constantes si corps rigide)
% -------------------------------------------------------------------------
pairs = {'AA-IA', AA, IA; 'AA-TS', AA, TS; 'AA-AC', AA, AC; ...
         'IA-TS', IA, TS; 'IA-AC', IA, AC; 'TS-AC', TS, AC};
nPairs = size(pairs, 1);

allDist_mm      = nan(nPairs, N);
allDeviation_mm = nan(nPairs, N);
onsetAngle      = nan(nPairs, 1);
colors          = lines(nPairs);

for ip = 1:nPairs
    d_mm = squeeze(sqrt(sum((pairs{ip,2} - pairs{ip,3}).^2, 1))) * 1e3;
    allDist_mm(ip,:) = d_mm;

    % Reference = distance moyenne pour les frames a faible flexion (<20 deg)
    refMask = elevAngle < 20;
    if any(refMask)
        dRef = mean(d_mm(refMask), 'omitnan');
    else
        dRef = mean(d_mm, 'omitnan');
    end
    signedDeviation_mm    = d_mm - dRef;
    allDeviation_mm(ip,:) = signedDeviation_mm;

    % Angle a partir duquel |deviation| depasse 5mm et y reste (evite un
    % faux positif isole) : premier angle trie au-dela duquel >=90% des
    % frames plus elevees restent au-dessus du seuil
    [sortedAngle, order] = sort(elevAngle);
    sortedDev             = abs(signedDeviation_mm(order));
    thresholdExceeded     = sortedDev > 5;
    idxOnset = find(movmean(double(thresholdExceeded), [0 numel(thresholdExceeded)], 'Endpoints', 'shrink') > 0.9, 1);
    if ~isempty(idxOnset)
        onsetAngle(ip) = sortedAngle(idxOnset);
    end
end

disp('  Angle a partir duquel la deviation depasse 5mm (STA) :');
for ip = 1:nPairs
    if isnan(onsetAngle(ip))
        fprintf('    %-6s : jamais depasse sur cet essai (std=%.2fmm, max ecart=%.2fmm)\n', ...
                pairs{ip,1}, std(allDeviation_mm(ip,:), 'omitnan'), max(abs(allDeviation_mm(ip,:))));
    else
        fprintf('    %-6s : %.0f deg\n', pairs{ip,1}, onsetAngle(ip));
    end
end
disp(' ');

% -------------------------------------------------------------------------
% PLOT 1/3 : DISTANCES BRUTES (echelle absolue)
% -------------------------------------------------------------------------
figure('Name', ['Distances inter-landmarks scapulaires - ', sideLabel], 'NumberTitle', 'off');
hold on;
for ip = 1:nPairs
    scatter(elevAngle, allDist_mm(ip,:), 8, colors(ip,:), 'filled', 'DisplayName', pairs{ip,1});
end
xline(90, '--k', '90 deg (litterature)');
xlabel('Flexion HT (deg, 0=repos)'); ylabel('Distance inter-landmark (mm)');
legend('Location', 'best'); grid on;
title({['Verification corps rigide scapulaire - ', sideLabel], Trial.file}, 'Interpreter', 'none');

% -------------------------------------------------------------------------
% PLOT 2/3 : TRAJECTOIRES 3D (repere thorax), colorees par flexion
% -------------------------------------------------------------------------
figure('Name', ['Trajectoires landmarks scapulaires (repere thorax) - ', sideLabel], 'NumberTitle', 'off');
hold on;
scatter3(AA(1,:)*1e3, AA(2,:)*1e3, AA(3,:)*1e3, 10, elevAngle, 'o', 'filled', 'DisplayName', 'AA');
scatter3(IA(1,:)*1e3, IA(2,:)*1e3, IA(3,:)*1e3, 10, elevAngle, '^', 'filled', 'DisplayName', 'IA');
scatter3(TS(1,:)*1e3, TS(2,:)*1e3, TS(3,:)*1e3, 10, elevAngle, 's', 'filled', 'DisplayName', 'TS');
scatter3(AC(1,:)*1e3, AC(2,:)*1e3, AC(3,:)*1e3, 10, elevAngle, 'd', 'filled', 'DisplayName', 'AC');
colormap(gca, 'jet');
clim(gca, [min(elevAngle), max(elevAngle)]);
cb = colorbar; cb.Label.String = 'Flexion HT (deg, 0=repos)';
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
axis equal; grid on; view(3); legend('Location', 'best');
title({['AA/IA/TS/AC - repere thorax - ', sideLabel], Trial.file}, 'Interpreter', 'none');

% -------------------------------------------------------------------------
% PLOT 3/3 : ZOOM — deviation par rapport a la posture de repos, meme
% echelle (+/-10mm) pour toutes les paires quelle que soit leur distance
% de base — rend visible une derive meme petite, masquee sur le plot 1
% par l'echelle absolue (40-220mm).
% -------------------------------------------------------------------------
figure('Name', ['Zoom deviation inter-landmarks - ', sideLabel], 'NumberTitle', 'off');
hold on;
for ip = 1:nPairs
    scatter(elevAngle, allDeviation_mm(ip,:), 8, colors(ip,:), 'filled', 'DisplayName', pairs{ip,1});
end
yline(5, '--r', '+5mm'); yline(-5, '--r', '-5mm');
xline(90, '--k', '90 deg (litterature)');
ylim([-10, 10]);
xlabel('Flexion HT (deg, 0=repos)'); ylabel('Deviation vs posture de repos (mm)');
legend('Location', 'best'); grid on;
title({['ZOOM - Deviation corps rigide scapulaire - ', sideLabel], Trial.file}, 'Interpreter', 'none');

end

% -------------------------------------------------------------------------
function p_local_m = reprojectLocal(TiInv, p_global, N)
p_h          = ones(4, 1, N);
p_h(1:3,1,:) = p_global;
p_local      = Mprod_array3(TiInv, p_h);
p_local_m    = squeeze(p_local(1:3,1,:)); % [3xN], m — converted to mm by callers where needed
end
