% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Euclidean distance (mm) between two [3x1xN] point
%                trajectories expressed in meters. Shared by
%                Tests/CoR/CompareScoreRab.m, ValidateCoRvsCT.m.
% -------------------------------------------------------------------------

function d_mm = DistanceMM(a, b)
d    = squeeze(a - b); % [3xN]
d_mm = sqrt(sum(d.^2, 1)) * 1e3; % m -> mm
end
