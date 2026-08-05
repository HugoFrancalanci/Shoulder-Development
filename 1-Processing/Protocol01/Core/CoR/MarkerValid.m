% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Non-empty, non-all-NaN trajectory check (same principle as
%                Multi/Core/ComputeDataAvailability.m's markerValid) —
%                presence of a marker field alone is not enough, an
%                occlusion-only/never-digitised marker must not be counted
%                as usable. Shared by Core/CoR/DetectHumerusClusterLabels.m
%                and Core/CoR/DetectScapulaClusterLabels.m.
% -------------------------------------------------------------------------
% Inputs  : traj (matrix) raw marker trajectory (Nx3, btkGetMarkers convention)
% Outputs : tf (logical)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function tf = MarkerValid(traj)
tf = ~isempty(traj) && ~all(isnan(traj(:)));
end
