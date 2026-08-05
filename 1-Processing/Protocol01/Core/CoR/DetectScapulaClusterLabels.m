% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Detects which scapula technical cluster marker set is
%                actually usable for a given patient/side, for the SCoRE
%                calibration (Core/CoR/ComputeSCoRE.m). Same discrepancy
%                already handled for the multi-patient data-availability
%                report, see Multi/Core/ComputeDataAvailability.m
%                (clusterStatus, called with the 'ACM' legacy suffix) —
%                reused here, but returning actual marker LABELS instead
%                of a presence flag (see Core/CoR/DetectHumerusClusterLabels.m
%                for the equivalent, more involved humerus-side detection).
%
%                Priority order :
%                  1) Current : Cluster_{side}S_01..03 — at least 3 must be
%                     present and valid (soder.m needs >=3 non-collinear
%                     points for a well-posed fit).
%                  2) Legacy  : numbered group {side}ACM<n> (the acromion
%                     cluster markers, e.g. RACM1/2/3 — used directly as
%                     the scapula technical cluster on older sessions that
%                     predate the dedicated Cluster_RS_0N plate ; also read
%                     elsewhere for a DIFFERENT purpose in
%                     Core/AddACMLandmarks.m, unrelated to this detection).
%                     At least 3 valid members required.
%                  No movement-based tie-break needed here (unlike the
%                  humerus 'H' vs 'EOS' case) : ComputeDataAvailability.m's
%                  clusterStatus doesn't observe the same frozen-leftover
%                  ambiguity for the scapula/ACM case.
%                  Returns {} if neither qualifies.
% -------------------------------------------------------------------------
% Inputs  : Marker (struct) btkGetMarkers() output (any trial works, no
%                    movement-based disambiguation needed — CALIBRATION1 is
%                    fine, unlike the humerus case)
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

function labels = DetectScapulaClusterLabels(Marker, side)

labels = {};

% -------------------------------------------------------------------------
% 1) CURRENT : Cluster_{side}S_01..03
% -------------------------------------------------------------------------
curLabels  = arrayfun(@(n) sprintf('Cluster_%sS_0%d', side, n), 1:3, 'UniformOutput', false);
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
% 2) LEGACY : numbered group {side}ACM<n>
% -------------------------------------------------------------------------
allNames = fieldnames(Marker);
acmBase  = [side, 'ACM'];
isAcm    = ~cellfun('isempty', regexp(allNames, ['^', acmBase, '\d+$'], 'once'));
acmNames = allNames(isAcm);
acmValid = acmNames(cellfun(@(l) MarkerValid(Marker.(l)), acmNames));
if numel(acmValid) >= 3
    labels = acmValid;
    return;
end

end
