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
% Description:   Extract a cluster's marker trajectories from a raw btk
%                Marker struct (btkGetMarkers output), converted to the
%                toolbox's [3x1xN] convention (see InitialiseMarkerTrajectories.m).
% -------------------------------------------------------------------------
% Inputs  : Marker (struct) btkGetMarkers output
%           labels (cell)   marker field names, e.g. {'Cluster_RS_01',...}
%           ratio  (double) unit ratio (input units -> 'm'), see GetUnitRatio.m
% Outputs : traj (cell) {[3x1xN], ...}, one per label
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function traj = ClusterTrajectoriesFromMarker(Marker, labels, ratio)
traj = cell(1, numel(labels));
for i = 1:numel(labels)
    traj{i} = permute(Marker.(labels{i}), [2, 3, 1]) * ratio;
end
end
