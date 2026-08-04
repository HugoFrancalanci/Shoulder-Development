% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   June 2026
% -------------------------------------------------------------------------
% Description:   Function version of MAIN_Protocol_01, callable once per
%                patient session from MAIN_MULTI_Protocol_01.m.
%
% Usage (multi-patient, from MAIN_MULTI_Protocol_01.m):
%   for iP = 1:nPatients
%       Folder.data = patientSessions(iP);
%       [Trial, Patient, Session, Pathology] = runProtocol01(Folder);
%       DB(iP).Trial    = Trial;
%       DB(iP).Patient  = Patient;
%       DB(iP).Posture  = extractPosture(Trial);
%   end
% -------------------------------------------------------------------------
% Inputs  : Folder (struct) .toolbox, .deps, .data (session folder) and
%           optionally .skipKinematics (see SkipKinematics)
% Outputs : Trial     (struct array)  all processed trials
%           Patient   (struct)        from ImportSessionData
%           Session   (struct)        from ImportSessionData
%           Pathology (struct)        from ImportSessionData
%           c3dFiles  (struct array)  dir('*.c3d') of the Processed folder
%                     - useful to detect files not loaded into Trial (e.g.
%                     STATIC/ISOMETRIC, absent from trialTypes)
% -------------------------------------------------------------------------
% Dependencies : ImportSessionData.m, ComputeSCoRE.m, TestSCoRE.m,
%                SetUnits.m, InitialiseMarkerTrajectories.m,
%                InitialiseVmarkerTrajectories.m, InitialiseSegments.m,
%                InitialiseJoints.m, DefineSegments.m, ComputeKinematics.m,
%                ComputeThoraxPosture.m, CutCycles.m, ComputeSHR.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Trial, Patient, Session, Pathology, c3dFiles] = runProtocol01(Folder)

% -------------------------------------------------------------------------
% PATHS
% -------------------------------------------------------------------------
addpath(Folder.toolbox);
addpath(genpath(Folder.deps));
addpath(fullfile(Folder.toolbox, 'Core'));
addpath(fullfile(Folder.toolbox, 'Core', 'CoR'));
addpath(fullfile(Folder.toolbox, 'Init'));
addpath(fullfile(Folder.toolbox, 'IO'));

% -------------------------------------------------------------------------
% SESSION DATA
% -------------------------------------------------------------------------
disp('Get session information');
disp('-----------------------');
cd(Folder.data);
[Patient, Session, Pathology] = ImportSessionData();
disp(' ');

% -------------------------------------------------------------------------
% USER COMMANDS
% -------------------------------------------------------------------------
cd(Folder.toolbox);
txtFile      = 'userCommands.txt';
userCommands = fileread(txtFile);
eval(userCommands);

% -------------------------------------------------------------------------
% CALIBRATION SCoRE
% -------------------------------------------------------------------------
if strcmpi(Processing.GJC.method,'SCoRE')
    if strcmpi(Processing.GJC.calibTrials,'all')
        Session.SCoRE = ComputeSCoRE(Folder.data, DiscoverAvailableTrials(Folder.data));
    else
        Session.SCoRE = ComputeSCoRE(Folder.data);
    end
    TestSCoRE(Session);
end

% -------------------------------------------------------------------------
% LOADING C3D FILES
% -------------------------------------------------------------------------
cd(fullfile(Folder.data, 'Processed'));
c3dFiles   = dir('*.c3d');
trialTypes = {'CALIBRATION', 'ANALYTIC', 'FUNCTIONAL'};
k          = 1;
Trial      = [];

trialOrder = {'CALIBRATION3','CALIBRATION1','CALIBRATION2','CALIBRATION4', ...
              'CALIBRATION5','CALIBRATION6', ...
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

% SkipKinematics
skipKinematics = isfield(Folder, 'skipKinematics') && Folder.skipKinematics;

% -------------------------------------------------------------------------
% TRIALS LOOP
% -------------------------------------------------------------------------
for i = orderedIdx
    for j = 1:size(trialTypes, 2)
        if contains(c3dFiles(i).name, trialTypes{j})
            disp(' ');
            % Task name
            if contains(c3dFiles(i).name, 'CALIBRATION')
                Trial(k).task = c3dFiles(i).name(end-18:end-7);
            elseif contains(c3dFiles(i).name, 'ANALYTIC')
                Trial(k).task = c3dFiles(i).name(end-15:end-7);
            elseif contains(c3dFiles(i).name, 'FUNCTIONAL')
                Trial(k).task = c3dFiles(i).name(end-17:end-7);
            end
            Trial(k).file    = c3dFiles(i).name;
            Trial(k).btk     = btkReadAcquisition(c3dFiles(i).name);
            Trial(k).n0      = btkGetFirstFrame(Trial(k).btk);
            Trial(k).n1      = btkGetLastFrame(Trial(k).btk) - Trial(k).n0 + 1;
            Trial(k).fmarker = btkGetPointFrequency(Trial(k).btk);
            Trial(k).fanalog = btkGetAnalogFrequency(Trial(k).btk);
            disp(['File loading : ', Trial(k).task]);
            % Units
            Units            = SetUnits(Trial);
            % Events
            Event            = btkGetEvents(Trial(k).btk);
            % Markers
            Marker           = btkGetMarkers(Trial(k).btk);
            Trial(k).Marker  = [];
            Trial(k)         = InitialiseMarkerTrajectories(markerSet, Trial(k), Marker, Units);
            % Virtual markers
            Trial(k).Vmarker = [];
            Trial(k)         = InitialiseVmarkerTrajectories(Trial(k));
            % Kinematics
            Trial(k).Segment = [];
            Trial(k).Joint   = [];
            Trial(k).Rcycle  = [];
            Trial(k).Lcycle  = [];
            Trial(k).SHR     = [];
            if ~contains(c3dFiles(i).name, 'CALIBRATION4') && ~skipKinematics % Not applicable / fast mode
                Trial(k) = InitialiseSegments(Trial(k));
                Trial(k) = InitialiseJoints(Trial(k));
                Trial(k) = DefineSegments(c3dFiles(i), Session, Trial(k), Processing);
                Trial(k) = ComputeKinematics(c3dFiles(i), Trial(k));
                Trial(k) = ComputeThoraxPosture(Trial(k));
                Trial(k) = CutCycles(c3dFiles(i), Trial(k), Folder.data);
                Trial(k) = ComputeSHR(c3dFiles(i), Trial(k), Trial(k));
                close all;
            end
            k = k + 1;
        end
    end
end
close all;

% -------------------------------------------------------------------------
% END
% -------------------------------------------------------------------------
cd(Folder.toolbox);

end
