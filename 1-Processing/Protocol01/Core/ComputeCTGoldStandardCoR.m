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
% Description:   CT-based gold-standard glenohumeral CoR, for validation
%                against Rab/SCoRE. For a reverse total shoulder
%                arthroplasty (RTSA), the true mechanical centre of
%                rotation is the implanted glenosphere (scapula side) —
%                its centre is extracted by sphere-fitting a CT-digitised
%                point cloud of its surface (FitSphereLS.m), then
%                registered from CT space into the mocap lab frame via a
%                rigid transform (Soderkvist & Wedin 1993, soder.m) using
%                3 scapula landmarks (SRS/SAA/SIA) digitised in both CT
%                and on the patient (mocap markers at CALIBRATION1) — same
%                registration principle as Core/AddACMLandmarks.m and
%                Core/ComputeSCoRE.m.
%
%                Expects, in ctFolder :
%                  *_scapula.fcsv        3 landmarks (SRS, SAA, SIA)
%                  *_scapula_sphere.fcsv glenosphere surface point cloud
% -------------------------------------------------------------------------
% Inputs  : ctFolder   (char) folder containing the CT .fcsv files
%           folderData (char) patient mocap folder containing 'Processed\*.c3d'
%           side       (char) 'R' or 'L' — which scapula the CT data belongs to
% Outputs : CTGold (struct)
%             .side                  'R' or 'L'
%             .rCsi                  [3x1] CoR, in the same local coordinate
%                                     convention as Session.SCoRE.<side>.rCsi
%                                     (i.e. re-projectable via
%                                     BuildTechnicalTransform(xRef.<R/L>S, ...))
%             .sphereRadius_mm       glenosphere radius (mm)
%             .sphereFitResidual_mm  RMS sphere fit residual (mm)
%             .registrationRMS_mm    RMS of the CT->lab rigid registration (mm)
%             .Rreg/.dreg            [3x3]/[3x1] CT(m)->lab(m) rigid transform,
%                                     reusable to place other CT geometry
%                                     (e.g. STL meshes) in the same frame
% -------------------------------------------------------------------------
% Dependencies : ReadFcsvPoints.m, FitSphereLS.m, soder.m, SetUnits.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function CTGold = ComputeCTGoldStandardCoR(ctFolder, folderData, side)

disp(' ');
disp('------------------------------------------------------------------');
disp('CT gold-standard CoR (glenosphere sphere fit + CT->lab registration)');
disp('------------------------------------------------------------------');

if strcmpi(side, 'R')
    lbl = {'RSRS', 'RSAA', 'RSIA'};
else
    lbl = {'LSRS', 'LSAA', 'LSIA'};
end

% -------------------------------------------------------------------------
% CT DATA
% -------------------------------------------------------------------------
scapulaFile = dir(fullfile(ctFolder, '*_scapula.fcsv'));
sphereFile  = dir(fullfile(ctFolder, '*_scapula_sphere.fcsv'));
if isempty(scapulaFile) || isempty(sphereFile)
    error('ComputeCTGoldStandardCoR:missingFiles', ...
          'Expected *_scapula.fcsv and *_scapula_sphere.fcsv in %s', ctFolder);
end

[ptsLandmarks, labels] = ReadFcsvPoints(fullfile(scapulaFile(1).folder, scapulaFile(1).name));
ptsSphere               = ReadFcsvPoints(fullfile(sphereFile(1).folder,  sphereFile(1).name));

idxSRS = find(strcmpi(labels, 'SRS'), 1);
idxSAA = find(strcmpi(labels, 'SAA'), 1);
idxSIA = find(strcmpi(labels, 'SIA'), 1);
if isempty(idxSRS) || isempty(idxSAA) || isempty(idxSIA)
    error('ComputeCTGoldStandardCoR:missingLandmarks', ...
          'SRS/SAA/SIA not all found in %s', scapulaFile(1).name);
end
xCT_mm = [ptsLandmarks(idxSRS,:); ptsLandmarks(idxSAA,:); ptsLandmarks(idxSIA,:)]; % [3x3], order SRS/SAA/SIA

[sphereCenter_mm, sphereRadius_mm, sphereResidual_mm] = FitSphereLS(ptsSphere);

% -------------------------------------------------------------------------
% MOCAP REFERENCE (CALIBRATION1) — same landmarks, same reference-trial
% convention as Core/ComputeSCoRE.m
% -------------------------------------------------------------------------
oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>
c3dFiles  = dir('*.c3d');
calib1Idx = find(contains({c3dFiles.name}, 'CALIBRATION1'), 1);
if isempty(calib1Idx)
    error('ComputeCTGoldStandardCoR:noCalibration1', 'CALIBRATION1.c3d not found in %s', folderData);
end
acq             = btkReadAcquisition(c3dFiles(calib1Idx).name);
tmpTrial(1).btk = acq;
Units           = SetUnits(tmpTrial);
Marker          = btkGetMarkers(acq);

xMocap_m = [mean(Marker.(lbl{1}), 1, 'omitnan'); ...
            mean(Marker.(lbl{2}), 1, 'omitnan'); ...
            mean(Marker.(lbl{3}), 1, 'omitnan')] * Units.ratio; % [3x3], m

% -------------------------------------------------------------------------
% RIGID REGISTRATION CT -> LAB (Soderkvist & Wedin 1993, soder.m)
% -------------------------------------------------------------------------
[Rreg, dreg, regRMS_m] = soder(xCT_mm/1e3, xMocap_m); % CT (m) -> lab (m)

sphereCenter_lab_m = Rreg * (sphereCenter_mm/1e3) + dreg;

CTGold.side                 = upper(side);
CTGold.rCsi                 = sphereCenter_lab_m;   % [3x1] m, local coords = xRef.<side>S convention
CTGold.sphereRadius_mm      = sphereRadius_mm;
CTGold.sphereFitResidual_mm = sphereResidual_mm;
CTGold.registrationRMS_mm   = regRMS_m * 1e3;
CTGold.Rreg                 = Rreg;  % [3x3] CT(m) -> lab(m) rotation, reusable to place CT meshes (e.g. STL)
CTGold.dreg                 = dreg;  % [3x1] CT(m) -> lab(m) translation

disp(['  Sphere fit residual (mm)      : ', num2str(sphereResidual_mm, '%.2f')]);
disp(['  Glenosphere radius (mm)       : ', num2str(sphereRadius_mm,  '%.2f')]);
disp(['  CT->lab registration RMS (mm) : ', num2str(CTGold.registrationRMS_mm, '%.2f')]);
disp(' ');

end
