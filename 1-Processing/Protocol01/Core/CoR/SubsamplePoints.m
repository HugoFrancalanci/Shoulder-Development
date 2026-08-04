% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Random subsample of point cloud rows, to keep brute-force
%                nearest-neighbour searches tractable. No-op if P already
%                has <= n rows. Shared by Tests/CoR/ValidateCoRvsCT.m
%                (checkMeshGap) and Tests/CoR/PlotScapularMeshSTA.m.
% -------------------------------------------------------------------------

function P = SubsamplePoints(P, n)
if size(P,1) > n
    P = P(randperm(size(P,1), n), :);
end
end
