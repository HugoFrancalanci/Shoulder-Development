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
%                arthroplasty (rTSA), the true mechanical centre of
%                rotation is the implanted glenosphere (scapula side),
%                its centre is extracted by sphere-fitting a CT-digitised
%                point cloud of its surface (FitSphereLS.m), then
%                registered from CT space into the mocap lab frame via a
%                rigid transform (Soderkvist & Wedin 1993, soder.m) using
%                3 scapula landmarks (SRS/SAA/SIA) digitised in both CT
%                and on the patient (mocap markers at CALIBRATION1) — same
%                registration principle as Core/AddACMLandmarks.m and
%                Core/ComputeSCoRE.m.
%
%                Also computes an INDEPENDENT humerus registration (not
%                assumed identical to the scapula's, even though both STL
%                meshes come from the same CT session — that assumption is
%                never verified otherwise). Uses the mechanical constraint
%                that, in a reverse shoulder prosthesis, the humeral cup
%                centre and the glenosphere centre coincide : sphere-fits
%                the humeral cup point cloud to get a 3rd non-collinear
%                correspondence point (in addition to HME/HLE, otherwise
%                under-determined with only 2 points), then solves a full
%                rigid registration for the humerus via soder.m. Also
%                reports how far the humerus would land if the scapula's
%                registration were (as previously assumed) reused directly
%                — a large discrepancy would reveal a real CT-series
%                registration issue between the two STL exports.
%
%                Expects, in ctFolder :
%                  *_scapula.fcsv        3 landmarks (SRS, SAA, SIA)
%                  *_scapula_sphere.fcsv glenosphere surface point cloud
%                  *_humerus.fcsv        HME, HLE + humeral cup point cloud
%                                        (excludes *_preop_humerus.fcsv)
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
%             .Rreg/.dreg            [3x3]/[3x1] CT(m)->lab(m) rigid transform
%                                     for the SCAPULA, reusable to place CT
%                                     geometry rigidly attached to it
%             .humerus.Rreg/.dreg    [3x3]/[3x1] INDEPENDENT CT(m)->lab(m)
%                                     rigid transform for the HUMERUS
%             .humerus.registrationRMS_mm RMS of that registration (mm)
%             .humerus.cupRadius_mm       humeral cup radius (mm)
%             .humerus.cupFitResidual_mm  RMS sphere fit residual (mm)
%             .humerus.sameScanDiscrepancy_mm  distance (mm) between the
%                                     cup centre predicted by reusing the
%                                     scapula's registration (old
%                                     assumption) vs the true glenosphere
%                                     position — 0 would mean the two STL
%                                     exports are perfectly co-registered
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
    lbl    = {'RSRS', 'RSAA', 'RSIA'};
    lblHum = {'RHME', 'RHLE'};
else
    lbl    = {'LSRS', 'LSAA', 'LSIA'};
    lblHum = {'LHME', 'LHLE'};
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

% Humerus : HME/HLE landmarks + humeral cup point cloud (excludes the
% *_preop_humerus.fcsv variant, which has no HME/HLE labels)
humerusFile = dir(fullfile(ctFolder, '*_humerus.fcsv'));
humerusFile = humerusFile(~contains({humerusFile.name}, 'preop'));
if isempty(humerusFile)
    error('ComputeCTGoldStandardCoR:missingHumerusFile', ...
          'Expected *_humerus.fcsv (excluding *_preop_humerus.fcsv) in %s', ctFolder);
end
[ptsHumerus, labelsHum] = ReadFcsvPoints(fullfile(humerusFile(1).folder, humerusFile(1).name));

idxHME = find(strcmpi(labelsHum, 'HME'), 1);
idxHLE = find(strcmpi(labelsHum, 'HLE'), 1);
if isempty(idxHME) || isempty(idxHLE)
    error('ComputeCTGoldStandardCoR:missingHumerusLandmarks', ...
          'HME/HLE not found in %s', humerusFile(1).name);
end
HME_CT_mm = ptsHumerus(idxHME, :);
HLE_CT_mm = ptsHumerus(idxHLE, :);

% Remaining (unlabelled "F-") points = humeral cup surface point cloud
idxCup       = ~strcmpi(labelsHum, 'HME') & ~strcmpi(labelsHum, 'HLE');
ptsCup       = ptsHumerus(idxCup, :);
[cupCenter_mm, cupRadius_mm, cupResidual_mm] = FitSphereLS(ptsCup);

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

HME_mocap_m = mean(Marker.(lblHum{1}), 1, 'omitnan') * Units.ratio; % [1x3], m
HLE_mocap_m = mean(Marker.(lblHum{2}), 1, 'omitnan') * Units.ratio; % [1x3], m

% -------------------------------------------------------------------------
% RIGID REGISTRATION CT -> LAB, SCAPULA (Soderkvist & Wedin 1993, soder.m)
% -------------------------------------------------------------------------
[Rreg, dreg, regRMS_m] = soder(xCT_mm/1e3, xMocap_m); % CT (m) -> lab (m)

sphereCenter_lab_m = Rreg * (sphereCenter_mm/1e3) + dreg;

% -------------------------------------------------------------------------
% RIGID REGISTRATION CT -> LAB, HUMERUS — INDEPENDENT of the scapula's.
% 3rd non-collinear correspondence point = humeral cup centre (CT) <->
% glenosphere centre (already known in the lab frame, sphereCenter_lab_m)
% -- the mechanical ball-and-socket constraint of the rTSA. Otherwise only
% HME/HLE (2 points) would be available, which cannot constrain a full
% rigid rotation (under-determined about the HME-HLE axis).
% -------------------------------------------------------------------------
xCT_hum_mm = [cupCenter_mm'; HME_CT_mm; HLE_CT_mm]; % [3x3], order cup/HME/HLE
yLab_hum_m = [sphereCenter_lab_m'; HME_mocap_m; HLE_mocap_m]; % [3x3]

[Rreg_hum, dreg_hum, regRMS_hum_m] = soder(xCT_hum_mm/1e3, yLab_hum_m);

% Comparison to the previous assumption ("same CT scan -> reuse the
% scapula's registration directly for the humerus mesh too") : apply the
% SCAPULA's registration to the cup centre and see how far it lands from
% the true (independently-known) glenosphere position. Non-zero reveals a
% real discrepancy between the two STL/point-cloud exports, not visible
% otherwise since both meshes "look" joined regardless (a single shared
% rigid transform cannot separate two rigidly-linked objects, see
% Tests/CompareScoreRab.m checkMeshGap — this test is different : it
% compares two INDEPENDENT registrations, not the same one applied twice).
cupCenter_viaScapulaReg_m = Rreg * (cupCenter_mm/1e3) + dreg; % cupCenter_mm is already [3x1] (FitSphereLS)
sameScanDiscrepancy_mm    = norm(cupCenter_viaScapulaReg_m - sphereCenter_lab_m) * 1e3;

CTGold.side                 = upper(side);
CTGold.rCsi                 = sphereCenter_lab_m;   % [3x1] m, local coords = xRef.<side>S convention
CTGold.sphereRadius_mm      = sphereRadius_mm;
CTGold.sphereFitResidual_mm = sphereResidual_mm;
CTGold.registrationRMS_mm   = regRMS_m * 1e3;
CTGold.Rreg                 = Rreg;  % [3x3] CT(m) -> lab(m) rotation, reusable to place CT meshes (e.g. STL)
CTGold.dreg                 = dreg;  % [3x1] CT(m) -> lab(m) translation

CTGold.humerus.Rreg                    = Rreg_hum;
CTGold.humerus.dreg                    = dreg_hum;
CTGold.humerus.registrationRMS_mm      = regRMS_hum_m * 1e3;
CTGold.humerus.cupRadius_mm            = cupRadius_mm;
CTGold.humerus.cupFitResidual_mm       = cupResidual_mm;
CTGold.humerus.sameScanDiscrepancy_mm  = sameScanDiscrepancy_mm;

disp(['  Sphere fit residual (mm)      : ', num2str(sphereResidual_mm, '%.2f')]);
disp(['  Glenosphere radius (mm)       : ', num2str(sphereRadius_mm,  '%.2f')]);
disp(['  CT->lab registration RMS (mm) : ', num2str(CTGold.registrationRMS_mm, '%.2f')]);
disp(' ');
disp('  -- Recalage humerus independant --');
disp(['  Cupule - fit residual (mm)         : ', num2str(cupResidual_mm, '%.2f')]);
disp(['  Cupule - rayon (mm)                : ', num2str(cupRadius_mm,  '%.2f')]);
disp(['  Recalage humerus - RMS (mm)        : ', num2str(CTGold.humerus.registrationRMS_mm, '%.2f')]);
disp(['  Ecart vs hypothese "meme scan" (mm): ', num2str(sameScanDiscrepancy_mm, '%.2f')]);
disp(' ');

end
