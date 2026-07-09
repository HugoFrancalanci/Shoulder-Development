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
% Description:   Marker labels of the scapula/humerus technical clusters
%                (see userCommands.txt markerSet), shared by every function
%                that builds a scapula/humerus technical frame (soder-based).
% -------------------------------------------------------------------------
% Outputs : clusterLabels (struct) .RS/.RA/.LS/.LA (cell arrays of char)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function clusterLabels = DefaultClusterLabels()
clusterLabels.RS = {'Cluster_RS_01', 'Cluster_RS_02', 'Cluster_RS_03'};
clusterLabels.RA = {'Cluster_RA_01', 'Cluster_RA_02', 'Cluster_RA_03', 'Cluster_RA_04', 'Cluster_RA_05'};
clusterLabels.LS = {'Cluster_LS_01', 'Cluster_LS_02', 'Cluster_LS_03'};
clusterLabels.LA = {'Cluster_LA_01', 'Cluster_LA_02', 'Cluster_LA_03', 'Cluster_LA_04', 'Cluster_LA_05'};
end
