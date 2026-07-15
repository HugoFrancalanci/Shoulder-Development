% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   June 2026
% -------------------------------------------------------------------------
% Description:   Version fonction de MAIN_Protocol_01.
%
% Usage (multi-patients, depuis MAIN_Database.m) :
%   for iP = 1:nPatients
%       Folder.data = patientSessions(iP);
%       [Trial, Patient, Session, Pathology] = runProtocol01(Folder);
%       DB(iP).Trial    = Trial;
%       DB(iP).Patient  = Patient;
%       DB(iP).Posture  = extractPosture(Trial);
%   end
%
% Outputs : Trial     (struct array)  tous les trials traités
%           Patient   (struct)        depuis ImportSessionData
%           Session   (struct)        depuis ImportSessionData
%           Pathology (struct)        depuis ImportSessionData
%           c3dFiles  (struct array)  dir('*.c3d') du dossier Processed —
%                     utile pour détecter des fichiers non chargés dans
%                     Trial (ex: STATIC/ISOMETRIC, absents de trialTypes)
% -------------------------------------------------------------------------

function [Trial, Patient, Session, Pathology, c3dFiles] = runProtocol01(Folder)

% -------------------------------------------------------------------------
% CHEMINS
% -------------------------------------------------------------------------
addpath(Folder.toolbox);
addpath(genpath(Folder.deps));
addpath(fullfile(Folder.toolbox, 'Core'));
addpath(fullfile(Folder.toolbox, 'Init'));
addpath(fullfile(Folder.toolbox, 'IO'));
addpath(fullfile(Folder.toolbox, 'Plot'));
addpath(fullfile(Folder.toolbox, 'Templates'));
addpath(fullfile(Folder.toolbox, 'Tests'));

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
% CALIBRATION SCoRE (une fois par patient, si selectionnee dans userCommands.txt)
% -------------------------------------------------------------------------
if strcmpi(Processing.GJC.method,'SCoRE')
    Session.SCoRE = ComputeSCoRE(Folder.data);
    TestSCoRE(Session);
end

% -------------------------------------------------------------------------
% CHARGEMENT DES FICHIERS C3D
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

% -------------------------------------------------------------------------
% BOUCLE TRIALS
% -------------------------------------------------------------------------
for i = orderedIdx
    for j = 1:size(trialTypes, 2)
        if contains(c3dFiles(i).name, trialTypes{j})
            disp(' ');
            % Nom de la tâche
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
            % Unités
            Units            = SetUnits(Trial);
            % Événements
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
            if i ~= 8 % Not applicable
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
% PLOTS — désactivés en mode multi-patients
% -------------------------------------------------------------------------
plotMode = false; 

if plotMode
    for k_plot = 1:length(Trial)
        if contains(Trial(k_plot).task, 'ANALYTIC')
            PlotThoraxPosture(Trial(k_plot), Trial(k_plot).task);
            PlotThoraxInclination(Trial(k_plot), Trial(k_plot).task);
        end
    end
    PlotKinematics(Trial, Pathology);
    PlotHumeroGravitaire(Trial, Pathology);
    PlotComparison(Trial, Folder.data, Pathology);
    TestICS(Trial);
    TestHG(Trial);
end

% -------------------------------------------------------------------------
% EXPORTS CONSOLE
% -------------------------------------------------------------------------
ExportPostureSummary(Trial, Patient, Session);
ExportKinematicsSummary(Trial);

% -------------------------------------------------------------------------
% FIN
% -------------------------------------------------------------------------
cd(Folder.toolbox);

end