% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Detects which humerus technical cluster marker set is
%                actually usable for a given patient/side, for the SCoRE
%                calibration (Core/CoR/ComputeSCoRE.m). Some patients were
%                recorded with the current 5-marker plate
%                (Cluster_{R/L}A_01-05), others with an older marker-set
%                naming — same discrepancy already handled for the
%                multi-patient data-availability report, see
%                Multi/Core/ComputeDataAvailability.m (clusterStatusHumerus)
%                — this function reuses the SAME detection principle
%                (current -> legacy 'H' -> legacy 'EOS', movement-based
%                tie-break) but returns actual marker LABELS usable for a
%                soder.m rigid-body fit, not just a presence flag.
%
%                Priority order :
%                  1) Current   : Cluster_{side}A_01..05 — at least 3 must
%                     exist as fields (soder.m needs >=3 non-collinear
%                     points for a well-posed fit) ; returns exactly the
%                     ones present (3, 4 or 5), NaN gaps within are left to
%                     the existing DropNanFrames.m handling downstream.
%                  2) Legacy 'H': {side}HDT/HTI/HBI, all 3 required, AND
%                     all 3 must show real movement (range > 0 on some axis
%                     over the trial) — a leftover/unused label slot from
%                     an older marker-set template can hold a frozen/static
%                     position instead of genuinely absent data, so
%                     presence alone is not enough (same rationale as
%                     ComputeDataAvailability.m).
%                  3) Legacy 'EOS': numbered group {side}EOS<n>, at least 3
%                     moving members. NOTE : ComputeDataAvailability.m
%                     accepts >=2 for its presence REPORT ; here we require
%                     >=3 because soder.m genuinely needs that many points
%                     for a rigid-body fit — 2 points cannot constrain
%                     rotation about the line joining them.
%                  Returns {} if none of the three qualify.
% -------------------------------------------------------------------------
% Inputs  : Marker (struct) btkGetMarkers() output from a MOVEMENT trial
%                    (ANALYTIC1 — a static/near-static trial like
%                    CALIBRATION1 cannot reliably disambiguate 'H' vs 'EOS')
%           side   (char)   'R' or 'L'
% Outputs : labels (cell array of char), or {} if nothing usable was found
% -------------------------------------------------------------------------
% Dependencies : Core/CoR/MarkerValid.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function labels = DetectHumerusClusterLabels(Marker, side)

labels = {};

% -------------------------------------------------------------------------
% 1) CURRENT : Cluster_{side}A_01..05
% -------------------------------------------------------------------------
curLabels  = arrayfun(@(n) sprintf('Cluster_%sA_0%d', side, n), 1:5, 'UniformOutput', false);
curValid   = false(1, numel(curLabels));
for i = 1:numel(curLabels)
    curValid(i) = isfield(Marker, curLabels{i}) && MarkerValid(Marker.(curLabels{i}));
end
curPresent = curLabels(curValid);
if numel(curPresent) >= 3
    labels = curPresent;
    return;
end

% -------------------------------------------------------------------------
% 2) LEGACY 'H' : {side}HDT / {side}HTI / {side}HBI
% -------------------------------------------------------------------------
hLabels = {[side 'HDT'], [side 'HTI'], [side 'HBI']};
if all(isfield(Marker, hLabels)) && all(cellfun(@(l) markerIsMoving(Marker.(l)), hLabels))
    labels = hLabels;
    return;
end

% -------------------------------------------------------------------------
% 3) LEGACY 'EOS' : numbered group {side}EOS<n>
% -------------------------------------------------------------------------
allNames  = fieldnames(Marker);
eosBase   = [side, 'EOS'];
isEos     = ~cellfun('isempty', regexp(allNames, ['^', eosBase, '\d+$'], 'once'));
eosNames  = allNames(isEos);
movingEos = eosNames(cellfun(@(l) markerIsMoving(Marker.(l)), eosNames));
if numel(movingEos) >= 3
    labels = movingEos;
    return;
end

end

% -------------------------------------------------------------------------
function tf = markerIsMoving(traj)
% Same "variation" principle as Multi/Core/ComputeDataAvailability.m :
% a marker counts as genuinely tracked if its trajectory shows real
% movement across the trial, not stuck at a constant (frozen) position.
tf = false;
if isempty(traj), return; end
valid = traj(~any(isnan(traj), 2), :);
if size(valid,1) < 2, return; end
tf = any(max(valid,[],1) - min(valid,[],1) > 0);
end
