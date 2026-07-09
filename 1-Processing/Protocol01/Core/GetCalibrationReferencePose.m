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
% Description:   Static reference pose (CALIBRATION1) of the scapula/humerus
%                technical clusters, right and left — the "x" reference
%                used by soder.m throughout the SCoRE calibration and CoR
%                reconstruction (see BuildTechnicalTransform.m). Extracted
%                from Core/ComputeSCoRE.m for reuse (e.g. Tests/ExploreSCoRECombos.m).
% -------------------------------------------------------------------------
% Inputs  : (none) — assumes the current directory is already the patient's
%           'Processed' folder (same convention as ComputeSCoRE.m/
%           ComputeCTGoldStandardCoR.m; caller is responsible for cd()).
%           clusterLabels (struct, optional) defaults to DefaultClusterLabels()
% Outputs : xRef (struct) .RS/.RA/.LS/.LA [k x 3]
% -------------------------------------------------------------------------
% Dependencies : GetUnitRatio.m, ClusterReferencePoseFromMarker.m, DefaultClusterLabels.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function xRef = GetCalibrationReferencePose(clusterLabels)

if nargin < 1, clusterLabels = DefaultClusterLabels(); end

c3dFiles  = dir('*.c3d');
calib1Idx = find(contains({c3dFiles.name}, 'CALIBRATION1'), 1);
if isempty(calib1Idx)
    error('GetCalibrationReferencePose:noCalibration1', ...
          'CALIBRATION1.c3d not found in the current folder.');
end
acq    = btkReadAcquisition(c3dFiles(calib1Idx).name);
ratio  = GetUnitRatio(acq);
Marker = btkGetMarkers(acq);

xRef.RS = ClusterReferencePoseFromMarker(Marker, clusterLabels.RS, ratio);
xRef.RA = ClusterReferencePoseFromMarker(Marker, clusterLabels.RA, ratio);
xRef.LS = ClusterReferencePoseFromMarker(Marker, clusterLabels.LS, ratio);
xRef.LA = ClusterReferencePoseFromMarker(Marker, clusterLabels.LA, ratio);

end
