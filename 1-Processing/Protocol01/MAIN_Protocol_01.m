% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description: (1) Research & Development Branch. 
%              (2) Extension of the KLAB_ShoulderAnalysis_Toolbox (F. Moissenet)
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% INIT WORKSPACE
% -------------------------------------------------------------------------
clearvars;
close all;
warning off;
clc;
disp('------------------------------------------------------------------');
disp('KLAB_UpperLimb_toolbox_PhD_Development_Branch_Shoulder_Dev');
disp('------------------------------------------------------------------');
disp(' ');

% -------------------------------------------------------------------------
% SET FOLDERS
% ------------------------------------------------------------------------
MainFolder           = 'C:\Users\franc\Desktop\Programming\01_Projects\E02_Classification_rTSA';
Folder.toolbox       = [MainFolder,'\Shoulder_Dev\1-Processing\Protocol01'];
Folder.data          = uigetdir(); 
Folder.dependencies  = [MainFolder,'\Shoulder_Dev\1-Processing\dependencies'];

% Folder access
addpath(Folder.toolbox);
addpath(genpath(Folder.dependencies));
addpath(fullfile(Folder.toolbox, 'Core'));
addpath(fullfile(Folder.toolbox, 'Core', 'CoR'));
addpath(fullfile(Folder.toolbox, 'Core', 'Thorax'));
addpath(fullfile(Folder.toolbox, 'Core', 'SHR'));
addpath(fullfile(Folder.toolbox, 'Init'));
addpath(fullfile(Folder.toolbox, 'IO'));
addpath(fullfile(Folder.toolbox, 'Plot'));
addpath(fullfile(Folder.toolbox, 'Templates'));
addpath(fullfile(Folder.toolbox, 'Tests'));
addpath(fullfile(Folder.toolbox, 'Tests', 'CoR'));
addpath(fullfile(Folder.toolbox, 'Tests', 'Thorax'));
disp(' ');

% Short path
Folder.dataLong = Folder.data;
shortDrive       = 'S:';
Folder.data      = EnsureShortDataPath(Folder.data, shortDrive);

% -------------------------------------------------------------------------
% GET SESSION DATA
% -------------------------------------------------------------------------
disp('Get session information');
disp('-----------------------');
cd([Folder.data,'\']);
[Patient,Session,Pathology] = ImportSessionData();
disp(' ');

% -------------------------------------------------------------------------
% PROCESS DATA
% -------------------------------------------------------------------------
cd(Folder.toolbox);
txtFile      = 'userCommands.txt';
userCommands = fileread(txtFile);
eval(userCommands);

% -------------------------------------------------------------------------
% RUN OPTIONS 
% -------------------------------------------------------------------------
doPlots      = input('Plots (1 Oui 0 Non) : ');
doValidation = input('Validation (1 Oui 0 Non) : ');
doExport     = input('Export (1 Oui 0 Non) : ');
doCoRvsCT    = input('Comparaison CT (1 Oui 0 Non) : ');

% -------------------------------------------------------------------------
% CoR CALIBRATION
% -------------------------------------------------------------------------
if strcmpi(Processing.GJC.method,'SCoRE')
    if strcmpi(Processing.GJC.calibTrials,'all')
        Session.SCoRE = ComputeSCoRE(Folder.data, DiscoverAvailableTrials(Folder.data));
    else
        Session.SCoRE = ComputeSCoRE(Folder.data);
    end
end

% Load data
cd([Folder.data,'\Processed\']);
c3dFiles   = dir('*.c3d');
trialTypes = {'CALIBRATION','STATIC','ISOMETRIC','ANALYTIC','FUNCTIONAL'};
k          = 1;

%%
trialOrder = {'CALIBRATION3','STATIC3','CALIBRATION1','STATIC1','CALIBRATION2','STATIC2', ...
              'CALIBRATION4', ...
              'CALIBRATION5','ISOMETRIC1','CALIBRATION6','ISOMETRIC2', ...
              'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4','ANALYTIC5', ...
              'FUNCTIONAL1','FUNCTIONAL2','FUNCTIONAL3','FUNCTIONAL4'};

orderedIdx = zeros(1, length(c3dFiles));
nIdx = 0;
for itype = 1:length(trialOrder)
    for ifile = 1:length(c3dFiles)
        if contains(c3dFiles(ifile).name, trialOrder{itype})
            nIdx = nIdx + 1;
            orderedIdx(nIdx) = ifile;
        end
    end
end
orderedIdx = orderedIdx(1:nIdx);

for i = orderedIdx
    for j = 1:size(trialTypes,2)
        if contains(c3dFiles(i).name, trialTypes{j})
            disp(' ');
            % Extract data from C3D files
            % Task name = whichever trialOrder entry actually matches this
            % file — robust to STATIC/ISOMETRIC aliases (their name length
            % differs from CALIBRATION, so a fixed character offset can't
            % be used here).
            Trial(k).task = trialOrder{find(cellfun(@(t) contains(c3dFiles(i).name, t), trialOrder), 1)};
            Trial(k).file        = c3dFiles(i).name;
            Trial(k).btk         = btkReadAcquisition(c3dFiles(i).name);
            Trial(k).n0          = btkGetFirstFrame(Trial(k).btk);
            Trial(k).n1          = btkGetLastFrame(Trial(k).btk)-Trial(k).n0+1;
            Trial(k).fmarker     = btkGetPointFrequency(Trial(k).btk);
            Trial(k).fanalog     = btkGetAnalogFrequency(Trial(k).btk);       
            disp(['File loading : ',Trial(k).task]);
            % Set units
            Units                = SetUnits(Trial);
            % Import events
            Event                = btkGetEvents(Trial(k).btk);
            % Import marker trajectories
            Marker               = btkGetMarkers(Trial(k).btk);
            Trial(k).Marker      = [];
            Trial(k)             = InitialiseMarkerTrajectories(markerSet,Trial(k),Marker,Units);
            % Initialise virtual marker trajectories
            Trial(k).Vmarker     = [];
            Trial(k)             = InitialiseVmarkerTrajectories(Trial(k));            
            % Manage kinematics
            Trial(k).Segment     = [];
            Trial(k).Joint       = [];
            Trial(k).Rcycle      = [];
            Trial(k).Lcycle      = [];
            Trial(k).SHR         = [];
            if ~contains(c3dFiles(i).name, 'CALIBRATION4') % Not applicable
                % Initialise segments
                Trial(k)         = InitialiseSegments(Trial(k));
                % Initialise joints
                Trial(k)         = InitialiseJoints(Trial(k));
                % Define body segments (and joint centres)
                Trial(k)         = DefineSegments(c3dFiles(i),Session,Trial(k),Processing);   
                % Compute inverse kinematics
                Trial(k)         = ComputeKinematics(c3dFiles(i),Trial(k));
                % Compute Thorax
                Trial(k)         = ComputeThoraxPosture(Trial(k));
                % Movement cycles (based on .mat)   
                Trial(k)         = CutCycles(c3dFiles(i), Trial(k), Folder.data);
                % Compute SHR
                Trial(k)         = ComputeSHR(c3dFiles(i),Trial(k),Trial(k));
                close all;
            end
            % Increment trial index
            k                    = k+1;
        end
    end
end
close all;

% =========================================================================
% PLOTS
% =========================================================================
if doPlots
    % Posture (thorax/patient-ICS) for ANALYTIC trials
    PlotThoraxPosture(Trial);
    PlotThoraxInclination(Trial);

    % Kinematics (HT, GH, ST, SHR, HG) for ANALYTIC trials
    PlotKinematics(Trial, Pathology);
    PlotHumeroGravitaire(Trial, Pathology);
    PlotQuaternionKinematics(Trial, Pathology); 

    % Comparaison with .mat from original K-LAB toolbox
    PlotComparison(Trial, Folder.data, Pathology);
end

% =========================================================================
% VALIDATION
% =========================================================================
if doValidation
    TestICS(Trial);              % Validation posture
    TestHG(Trial);                % Validation HG angles
    TestQuaternionValidation(Trial); % Validation quaternion
    TestSCoRE(Session);            % Qualite calibration SCoRE
    TestScapularCluster(Trial);   % STA scapulaire
    CompareScoreRab(Trial, Session, Processing, Folder.data, doCoRvsCT, Folder.dataLong); % Rab vs SCoRE comparaison
end

% =========================================================================
% EXPORT
% =========================================================================
if doExport
    ExportPostureSummary(Trial, Patient, Session);
    ExportKinematicsSummary(Trial);
    ReportDataAvailability(Trial, Patient, Session, Pathology, c3dFiles);
end
% close all

% =========================================================================
% END
% =========================================================================
cd(Folder.toolbox);

if ispc
    system(sprintf('subst %s /d', shortDrive));
end
