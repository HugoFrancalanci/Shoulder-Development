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
% Description:   Load one trial's scapula/humerus technical frames (right
%                and left), for use as SCoRE calibration input. Extracted
%                from Core/ComputeSCoRE.m for reuse (e.g. Tests/ExploreSCoRECombos.m) —
%                same computation, callable per-trial so calibration frames
%                from different trials can be freely combined without
%                re-reading files for every combination tested.
% -------------------------------------------------------------------------
% Inputs  : taskName      (char)   substring identifying the trial (e.g. 'ANALYTIC1')
%           xRef          (struct) .RS/.RA/.LS/.LA, see GetCalibrationReferencePose.m
%           clusterLabels (struct, optional) defaults to DefaultClusterLabels()
%           (assumes the current directory is already the patient's
%           'Processed' folder — caller is responsible for cd())
% Outputs : Ti_R, Tj_R, Ti_L, Tj_L (struct fields) [4x4xN] technical transforms
%           rms                    (struct) .TiR/.TjR/.TiL/.TjL [1xN] soder RMS
%           Empty (with a warning) if taskName is not found among the
%           patient's c3d files.
% -------------------------------------------------------------------------
% Dependencies : GetUnitRatio.m, ClusterTrajectoriesFromMarker.m,
%                DefaultClusterLabels.m, BuildTechnicalTransform.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Ti_R, Tj_R, Ti_L, Tj_L, rms] = LoadTechnicalFramesForTask(taskName, xRef, clusterLabels)

if nargin < 3, clusterLabels = DefaultClusterLabels(); end

Ti_R = []; Tj_R = []; Ti_L = []; Tj_L = [];
rms.TiR = []; rms.TjR = []; rms.TiL = []; rms.TjL = [];

c3dFiles = dir('*.c3d');
idx = find(contains({c3dFiles.name}, taskName), 1);
if isempty(idx)
    warning('LoadTechnicalFramesForTask:missingTrial', '%s not found -> excluded.', taskName);
    return;
end

acq    = btkReadAcquisition(c3dFiles(idx).name);
ratio  = GetUnitRatio(acq);
Marker = btkGetMarkers(acq);

clRS = ClusterTrajectoriesFromMarker(Marker, clusterLabels.RS, ratio);
clRA = ClusterTrajectoriesFromMarker(Marker, clusterLabels.RA, ratio);
clLS = ClusterTrajectoriesFromMarker(Marker, clusterLabels.LS, ratio);
clLA = ClusterTrajectoriesFromMarker(Marker, clusterLabels.LA, ratio);

[Ti_R, rms.TiR] = BuildTechnicalTransform(xRef.RS, clRS);
[Tj_R, rms.TjR] = BuildTechnicalTransform(xRef.RA, clRA);
[Ti_L, rms.TiL] = BuildTechnicalTransform(xRef.LS, clLS);
[Tj_L, rms.TjL] = BuildTechnicalTransform(xRef.LA, clLA);

disp(['  - ', taskName, ' loaded (', num2str(size(clRA{1}, 3)), ' frames)']);

end
