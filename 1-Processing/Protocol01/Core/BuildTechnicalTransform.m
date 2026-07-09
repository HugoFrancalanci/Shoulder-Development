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
% Description:   Build a per-frame rigid technical transform for a marker
%                cluster, relative to a fixed static reference pose,
%                using the Soderkvist & Wedin (1993) SVD rigid-body fit
%                (dependencies/soder.m). Same method/reference-trial
%                convention already used in Core/AddACMLandmarks.m for the
%                scapula ACM cluster, applied here to the clusters that
%                define the scapula/humerus segments in DefineSegments.m.
% -------------------------------------------------------------------------
% Inputs  : xRef           [k x 3] static reference pose of the cluster
%                           markers (e.g. mean position over CALIBRATION1)
%           clusterMarkers cell array {M1,...,Mk} of marker trajectories
%                           [3x1xN] on the trial to reconstruct
% Outputs : T               [4x4xN] homogeneous transform, global -> cluster
%                           (NaN frames where a marker is missing)
%           rmsFrames       [1xN] soder rigid-fit RMS residual per frame,
%                           in the same length unit as clusterMarkers
%                           (NaN frames where a marker is missing) — cluster
%                           rigidity quality metric, see Tests/TestSCoRE.m
% -------------------------------------------------------------------------
% Dependencies : dependencies/soder.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [T, rmsFrames] = BuildTechnicalTransform(xRef, clusterMarkers)

k = numel(clusterMarkers);
N = size(clusterMarkers{1}, 3);

T           = nan(4, 4, N);
T(4, 1:3, :) = 0;
T(4, 4, :)   = 1;
rmsFrames   = nan(1, N);

for t = 1:N
    y = nan(k, 3);
    for im = 1:k
        y(im, :) = clusterMarkers{im}(:, 1, t)';
    end
    if any(isnan(y(:)))
        continue;
    end
    [R, d, rms]    = soder(xRef, y);
    T(1:3, 1:3, t) = R;
    T(1:3, 4, t)   = d;
    rmsFrames(t)   = rms;
end

end
