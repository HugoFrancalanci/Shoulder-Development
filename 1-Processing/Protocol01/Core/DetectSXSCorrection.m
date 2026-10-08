% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Checks the virtual xiphoid landmark (SXS) of a session and
%                decides whether it must be rebuilt before kinematics.
%
%                SXS is not a physical marker: the K-LAB toolbox computes it
%                from a stylus pointing in CALIBRATION3 (Remote event) and
%                writes it into every C3D (AddPointedLandmarks.m). In some
%                sessions (mostly January-June 2024) it was computed at the
%                wrong instant (start of the trial instead of the pointing
%                event), which puts SXS 30 cm to 1.5 m away from the sternum
%                and corrupts the thorax frame (HT, ST, TX, SIR).
%
%                At the pointing event, the candidate xiphoid positions are:
%                  1) STY05 : tip marker of the current stylus ("Stylusb",
%                     in use since 2024; STY05 = SXS in correct sessions,
%                     median difference 0 mm over 128 sessions)
%                  2) tip of the older stylus ("Stylus1" model of
%                     AddPointedLandmarks.m, tip 230 mm from STY04)
%                Plausibility, relative to SJN (IJ) at the same frame,
%                vertical = lab Z:
%                  lenient : 80-280 mm from IJ and at least 40 mm below IJ
%                  strict  : 100-260 mm from IJ and mostly below IJ
%                            (vertical drop >= 0.65 x distance)
%                Rule:
%                  - C3D SXS plausible (lenient):
%                      replace by STY05 only if STY05 is strictly plausible
%                      and more than DevMax mm away from the C3D SXS
%                      (old-stylus sessions keep their SXS: there STY05 is
%                      not the tip and is never strictly plausible)
%                  - C3D SXS missing or implausible:
%                      STY05 if plausible (lenient), else old-stylus tip if
%                      plausible, else no correction (warning)
%                The chosen point is stored in the thorax technical frame
%                used by AddPointedLandmarks.m (origin SJN, Y = SJN - SME,
%                Z = (SME - TV5) x (CV7 - TV5)), so that ApplySXSCorrection
%                can rebuild SXS frame by frame in every trial.
%                Nothing is written to the C3D files.
% -------------------------------------------------------------------------
% Inputs  : c3dFiles (struct array) dir('*.c3d') of the Processed folder
%                    (current folder)
% Outputs : Fix (struct)
%             .apply        true when SXS must be rebuilt in every trial
%             .source       'STY05' | 'Stylus1' | '' (no correction)
%             .reason       short text, also printed in the console
%             .local_mm     [3x1] SXS in the thorax technical frame (mm)
%             .file         calibration file used
%             .SXS_IJ_mm    distance C3D SXS - IJ at the event (NaN if none)
%             .New_IJ_mm    distance corrected SXS - IJ at the event
%             .Dev_mm       distance C3D SXS - candidate at the event
% -------------------------------------------------------------------------
% Dependencies : BTK
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Fix = DetectSXSCorrection(c3dFiles)

DevMax = 20;   % mm : beyond this, a plausible C3D SXS is replaced by STY05

Fix = struct('apply', false, 'source', '', 'reason', '', 'local_mm', NaN(3, 1), 'file', '', ...
             'SXS_IJ_mm', NaN, 'New_IJ_mm', NaN, 'Dev_mm', NaN);

% Calibration trial (STATIC3 = older-session alias of CALIBRATION3)
names = {c3dFiles.name};
i = find(contains(names, 'CALIBRATION3'), 1);
if isempty(i), i = find(contains(names, 'STATIC3'), 1); end
if isempty(i)
    Fix.reason = 'pas d''essai CALIBRATION3 : SXS non vérifié';
    report(Fix); return;
end
Fix.file = names{i};

acq   = btkReadAcquisition(Fix.file);
M     = btkGetMarkers(acq);
E     = btkGetEvents(acq);
f0    = btkGetFirstFrame(acq);
fr    = btkGetPointFrequency(acq);
nf    = btkGetPointFrameNumber(acq);
toMM  = 1;
if strcmpi(btkGetPointsUnit(acq, 'Marker'), 'm'), toMM = 1000; end
btkDeleteAcquisition(acq);

need = {'SJN', 'SME', 'CV7', 'TV5'};
if ~all(isfield(M, need))
    Fix.reason = 'SJN, SME, CV7 ou TV5 absent : SXS non vérifié';
    report(Fix); return;
end
P = @(lab, k) toMM * M.(lab)(k, :);
present = @(lab, k) isfield(M, lab) && any(M.(lab)(k, :) ~= 0);

% Pointing events
T = [];
for e = fieldnames(E)', T = [T, E.(e{1})(:)']; end %#ok<AGROW>
K = unique(round(T * fr) - f0 + 1);
K = K(K >= 1 & K <= nf);
if isempty(K)
    Fix.reason = 'pas d''événement de pointage : SXS non vérifié';
    report(Fix); return;
end

% Best candidate of each type over the events (closest to 170 mm from IJ)
cand = struct('STY05', [], 'Stylus1', []);
best = struct('STY05', Inf, 'Stylus1', Inf);
kSel = K(1);
for k = K
    if ~all(cellfun(@(l) present(l, k), need)), continue; end
    ij = P('SJN', k);
    pts = struct('STY05', [], 'Stylus1', []);
    if present('STY05', k), pts.STY05 = P('STY05', k); end
    pts.Stylus1 = stylus1Tip(M, k, toMM);
    for c = {'STY05', 'Stylus1'}
        p = pts.(c{1});
        if isempty(p) || any(isnan(p)), continue; end
        d = abs(norm(p - ij) - 170);
        if plausible(p - ij, 'lenient') && d < best.(c{1})
            best.(c{1}) = d; cand.(c{1}) = struct('p', p, 'k', k);
        end
    end
end
if ~isempty(cand.STY05), kSel = cand.STY05.k; elseif ~isempty(cand.Stylus1), kSel = cand.Stylus1.k; end

% C3D SXS at the selected event
ij  = P('SJN', kSel);
sxs = [];
if present('SXS', kSel), sxs = P('SXS', kSel); Fix.SXS_IJ_mm = norm(sxs - ij); end
c3dOK = ~isempty(sxs) && plausible(sxs - ij, 'lenient');

% Decision
chosen = [];
if c3dOK
    if ~isempty(cand.STY05) && plausible(cand.STY05.p - ij, 'strict')
        Fix.Dev_mm = norm(sxs - cand.STY05.p);
        if Fix.Dev_mm > DevMax
            chosen = cand.STY05; Fix.source = 'STY05';
            Fix.reason = sprintf('SXS du C3D à %.0f mm du pointage STY05 : remplacé', Fix.Dev_mm);
        end
    end
    if isempty(chosen) && ~isnan(Fix.Dev_mm)
        Fix.reason = sprintf('SXS du C3D cohérent (%.0f mm de STY05) : conservé', Fix.Dev_mm);
    elseif isempty(chosen)
        Fix.reason = 'SXS du C3D cohérent : conservé';
    end
else
    if ~isempty(cand.STY05)
        chosen = cand.STY05; Fix.source = 'STY05';
    elseif ~isempty(cand.Stylus1)
        chosen = cand.Stylus1; Fix.source = 'Stylus1';
    end
    if isempty(sxs), what = 'absent'; else, what = sprintf('à %.0f mm de IJ', Fix.SXS_IJ_mm); end
    if isempty(chosen)
        Fix.reason = sprintf('SXS du C3D %s et aucun pointage plausible : NON corrigé', what);
        warning('DetectSXSCorrection:noCandidate', '%s (%s)', Fix.reason, Fix.file);
    else
        Fix.reason = sprintf('SXS du C3D %s : remplacé par %s', what, Fix.source);
        if ~isempty(sxs), Fix.Dev_mm = norm(sxs - chosen.p); end
    end
end

if ~isempty(chosen)
    k = chosen.k;
    R = thoraxFrame(P('SJN', k), P('SME', k), P('CV7', k), P('TV5', k));
    Fix.local_mm  = R' * (chosen.p - P('SJN', k))';
    Fix.New_IJ_mm = norm(chosen.p - P('SJN', k));
    Fix.apply     = true;
end
report(Fix);
end

% -------------------------------------------------------------------------
function ok = plausible(v, mode)
d = norm(v); drop = -v(3);
switch mode
    case 'lenient', ok = d >= 80 && d <= 280 && drop >= 40;
    case 'strict',  ok = d >= 100 && d <= 260 && drop >= 0.65 * d;
end
end

% Older stylus tip (Stylus1 model of AddPointedLandmarks.m), in mm
function tip = stylus1Tip(M, k, toMM)
tip = [];
labs = {'STY01', 'STY02', 'STY03', 'STY04', 'STY05'};
if ~all(isfield(M, labs)) || any(cellfun(@(l) all(M.(l)(k, :) == 0), labs)), return; end
g  = @(l) toMM * M.(l)(k, :);
Ys = g('STY02') - g('STY05'); Ys = Ys / norm(Ys);
Xs = cross(g('STY03') - g('STY05'), g('STY01') - g('STY05')); Xs = Xs / norm(Xs);
Zs = cross(Xs, Ys); Xs = cross(Ys, Zs);
tip = g('STY04') + ([Xs' Ys' Zs'] * [1.018; -230.005; -0.106])';
end

% Thorax technical frame of AddPointedLandmarks.m (orthonormalised)
function R = thoraxFrame(sjn, sme, cv7, tv5)
Y = sjn - sme;                     Y = Y / norm(Y);
Z = cross(sme - tv5, cv7 - tv5);   Z = Z / norm(Z);
X = cross(Y, Z);                   X = X / norm(X);
Z = cross(X, Y);
R = [X' Y' Z'];
end

function report(Fix)
disp(['  - Contrôle SXS : ', Fix.reason]);
end
