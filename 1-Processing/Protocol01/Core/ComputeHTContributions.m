% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Decompose the humerothoracic (HT) range of motion into
%                glenohumeral (GH), scapulothoracic (ST) and thoracic (TX)
%                sub-contributions, in degrees and in % of HT range.
%
%                Only ANALYTIC2 (coronal elevation) is supported: it is a
%                uniplanar movement, which ensures a coherent GH/ST/TX
%                decomposition of the HT angle (see DOF mapping below).
%
%                DOF mapping (ANALYTIC2) :
%                  HT Joint(1/6)  DOF1 X — abduction     (XZY)
%                  GH Joint(2/7)  DOF1 X — abduction     (XZY)
%                  ST Joint(3/8)  DOF1 X — upward rot.   (YXZ)
%                  TX Joint(11)   DOF3 Z — flexion       (ZXY)
%
%                Used by MAIN_MULTI_Protocol_01.m for the multi-patient
%                Excel export. Same decomposition as the "Tableau 2" in
%                ExportKinematicsSummary.m (single-patient console report),
%                kept as a separate implementation there on purpose.
%
%                HT_curve/GH_curve/ST_curve : courbe moyenne (sur les
%                cycles) angle vs % cycle (0-100%), même nombre de points
%                que la normalisation de cycle faite par CutCycles.m.
%                Sert au tracé PRE/POST (courbes individuelles + moyenne
%                en gras) dans MAIN_MULTI_Protocol_01.m /
%                Plot/PlotHTContributionsCurves.m.
%
% Inputs  : Trial (struct array) all trials from runProtocol01/MAIN_Protocol_01
% Outputs : Contrib (1x2 struct array, one row per side 'R'/'L') with fields
%           task, side, HT_range, GH_range, GH_pct, ST_range, ST_pct, TX_range, TX_pct,
%           HT_curve, GH_curve, ST_curve
%           Empty (0x0) struct array if ANALYTIC2 is not found in Trial.
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Contrib = ComputeHTContributions(Trial)

Contrib = struct('task', {}, 'side', {}, 'HT_range', {}, ...
                  'GH_range', {}, 'GH_pct', {}, 'ST_range', {}, 'ST_pct', {}, ...
                  'TX_range', {}, 'TX_pct', {}, ...
                  'HT_curve', {}, 'GH_curve', {}, 'ST_curve', {});

task = 'ANALYTIC2';
tidx = [];
for k = 1:length(Trial)
    if contains(Trial(k).task, task)
        tidx = k;
        break;
    end
end
if isempty(tidx), return; end
t = Trial(tidx);

dofHT = 1; dofGH = 1; dofST = 1; dofTX = 3;

sideDef = struct('side', {'R','L'}, 'jiHT', {1,6}, 'jiGH', {2,7}, 'jiST', {3,8}, ...
                  'cycField', {'rcycle','lcycle'});

for iS = 1:length(sideDef)
    s  = sideDef(iS);
    ht = getRangeCycle(t, s.jiHT, dofHT, s.cycField);
    gh = getRangeCycle(t, s.jiGH, dofGH, s.cycField);
    st = getRangeCycle(t, s.jiST, dofST, s.cycField);
    tx = getRangeCycleTH(t, 11, dofTX, s.cycField);

    Contrib(iS).task     = t.task;
    Contrib(iS).side     = s.side;
    Contrib(iS).HT_range = ht;
    Contrib(iS).GH_range = gh;
    Contrib(iS).GH_pct   = safePct(gh, ht);
    Contrib(iS).ST_range = st;
    Contrib(iS).ST_pct   = safePct(st, ht);
    Contrib(iS).TX_range = tx;
    Contrib(iS).TX_pct   = safePct(tx, ht);

    Contrib(iS).HT_curve = getCurveCycle(t, s.jiHT, dofHT, s.cycField);
    Contrib(iS).GH_curve = getCurveCycle(t, s.jiGH, dofGH, s.cycField);
    Contrib(iS).ST_curve = getCurveCycle(t, s.jiST, dofST, s.cycField);
end

end

function r = getRangeCycle(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function r = getRangeCycleTH(t, ji, dof, cycField)
r = NaN;
if length(t.Joint) < ji, return; end
cf = cycField;
if isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf,'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :)));
if isvector(data), data = data(:); end
ranges = max(data, [], 1) - min(data, [], 1);
r = mean(ranges, 'omitnan');
end

function c = getCurveCycle(t, ji, dof, cycField)
% Courbe moyenne (sur les cycles) de l'angle, déjà normalisée en % cycle
% par CutCycles.m (même nombre de points pour tous les cycles/patients).
c = [];
if length(t.Joint) < ji || isempty(t.Joint(ji).Euler.(cycField)), return; end
data = abs(squeeze(t.Joint(ji).Euler.(cycField)(1, dof, :, :)));
if isvector(data), data = data(:); end
c = mean(data, 2, 'omitnan');
end

function p = safePct(num, den)
if isnan(num) || isnan(den) || den == 0
    p = NaN;
else
    p = num / den * 100;
end
end
