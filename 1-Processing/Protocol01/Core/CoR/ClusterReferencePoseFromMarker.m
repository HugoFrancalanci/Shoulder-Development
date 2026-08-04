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
% Description:   Static reference pose of a marker cluster (mean position
%                over all available frames of a raw btk Marker struct),
%                used as the "x" reference for soder.m rigid-body fits
%                (see BuildTechnicalTransform.m).
% -------------------------------------------------------------------------
% Inputs  : Marker (struct) btkGetMarkers output
%           labels (cell)   marker field names, e.g. {'Cluster_RS_01',...}
%           ratio  (double) unit ratio (input units -> 'm'), see GetUnitRatio.m
% Outputs : xRef (k x 3) mean marker position, k = numel(labels)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function xRef = ClusterReferencePoseFromMarker(Marker, labels, ratio)
xRef = nan(numel(labels), 3);
for i = 1:numel(labels)
    m          = Marker.(labels{i}) * ratio; % [N x 3]
    xRef(i, :) = mean(m, 1, 'omitnan');
end
end
