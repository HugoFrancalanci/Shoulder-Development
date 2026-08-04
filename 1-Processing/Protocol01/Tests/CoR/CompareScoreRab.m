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
% Description:   Core validation report for the SCoRE glenohumeral CoR
%                method vs Rab et al. 2002, on ANALYTIC1 (works for any
%                patient, no CT required) :
%                  1) Distance (mm) between RGJC/LGJC obtained by Rab vs
%                     SCoRE — computed independently (Core/DefineSegments.m
%                     called twice on a copy of the trial, no shared
%                     mutation), with the underlying kinematics
%                     (Core/ComputeKinematics.m) recomputed for both so
%                     HT/GH/ST can be compared too.
%                  2) Plots : RGJC/LGJC distance vs frame, HT/GH/ST Euler
%                     angles (Rab vs SCoRE overlay, both sides).
%
%                Finds ANALYTIC1 and no-ops (with a warning) if not found,
%                and no-ops silently if Processing.GJC.method ~= 'SCoRE' —
%                same self-contained convention as Tests/CoR/TestScapularCluster.m,
%                so it can be called unconditionally from MAIN_Protocol_01.m
%                with the full Trial array (no external find/if needed there).
%                Session.SCoRE calibration-quality recap is
%                Tests/CoR/TestSCoRE.m, called separately (also
%                unconditionally — it no-ops if Session.SCoRE is absent).
%
%                CT-based validation and scapular STA visualisation
%                (patient 558792 / Jurg Muller only) are delegated to
%                Tests/CoR/ValidateCoRvsCT.m and Tests/CoR/PlotScapularMeshSTA.m
%                — split out of this file so each theme (core Rab/SCoRE,
%                CT imaging, STA) can be read/run independently.
%
%                Not part of the automatic per-trial pipeline (cost =
%                computing both methods).
% -------------------------------------------------------------------------
% Inputs  : Trial      (struct array) all trials from MAIN_Protocol_01
%           Session    (struct) session info; Session.SCoRE used/computed if missing
%           Processing (struct) needs Processing.GJC.method ('Rab'/'SCoRE')
%           folderData (char)   patient folder, only needed if Session.SCoRE
%                                is not yet computed (optional)
% Outputs : Console report (mean/max/std distance in mm, right and left)
%           Figures    : RGJC/LGJC distance vs frame ; HT/GH/ST Euler angles
% -------------------------------------------------------------------------
% Dependencies : Core/DefineSegments.m, Core/ComputeKinematics.m,
%                Core/CoR/ComputeSCoRE.m, Core/CoR/DistanceMM.m,
%                Core/CoR/PrintCoRStats.m,
%                Tests/CoR/ValidateCoRvsCT.m, Tests/CoR/PlotScapularMeshSTA.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function CompareScoreRab(Trial, Session, Processing, folderData)

if nargin < 4, folderData = ''; end

if ~strcmpi(Processing.GJC.method, 'SCoRE')
    return;
end

idx = find(contains({Trial.file}, 'ANALYTIC1'), 1);
if isempty(idx)
    warning('CompareScoreRab:noAnalytic1', 'ANALYTIC1 not found -> SCoRE validation report skipped.');
    return;
end
TrialOne = Trial(idx);
c3dFiles = struct('name', TrialOne.file);

if ~isfield(Session, 'SCoRE') || isempty(Session.SCoRE)
    if isempty(folderData)
        error('CompareScoreRab:noSCoRE', ...
              'Session.SCoRE is not computed and no folderData was provided to compute it.');
    end
    Session.SCoRE = ComputeSCoRE(folderData);
end

disp(' ');
disp('====================================================================');
disp('SCoRE validation report');
disp('====================================================================');

% -------------------------------------------------------------------------
% 1) Rab vs SCoRE — same call chain as MAIN_Protocol_01.m, computed
% independently on two copies of the trial, so results are guaranteed
% consistent with the standard pipeline (not a shortcut computation).
% CutCycles/ComputeSHR intentionally NOT called : neither one modifies
% Joint(*).Euler.full (CutCycles only adds .rcycle/.lcycle, ComputeSHR
% only reads cycles to compute a ratio), and CutCycles can pop up an
% interactive ginput() dialog when no legacy .mat is found — undesirable
% in an automated diagnostic function.
% -------------------------------------------------------------------------
Processing.GJC.method = 'Rab';
TrialRab   = InitialiseSegments(TrialOne);
TrialRab   = InitialiseJoints(TrialRab);
TrialRab   = DefineSegments(c3dFiles, Session, TrialRab, Processing);
TrialRab   = ComputeKinematics(c3dFiles, TrialRab);
TrialRab   = ComputeThoraxPosture(TrialRab);

Processing.GJC.method = 'SCoRE';
TrialSCoRE = InitialiseSegments(TrialOne);
TrialSCoRE = InitialiseJoints(TrialSCoRE);
TrialSCoRE = DefineSegments(c3dFiles, Session, TrialSCoRE, Processing);
TrialSCoRE = ComputeKinematics(c3dFiles, TrialSCoRE);
TrialSCoRE = ComputeThoraxPosture(TrialSCoRE);

dR = DistanceMM(TrialRab.Vmarker(11).Trajectory.full, TrialSCoRE.Vmarker(11).Trajectory.full);
dL = DistanceMM(TrialRab.Vmarker(13).Trajectory.full, TrialSCoRE.Vmarker(13).Trajectory.full);

disp('  1) Ecart Rab vs SCoRE sur cet essai (mm) :');
PrintCoRStats('RGJC (droit)',  dR);
PrintCoRStats('LGJC (gauche)', dL);
disp(' ');

% -------------------------------------------------------------------------
% 2) IMAGERIE (CT) + STA scapulaire — patient 558792 (Jurg Muller) uniquement
% -------------------------------------------------------------------------
if contains(TrialOne.file, '558792')
    ctFolder    = ['C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\', ...
                   '01_Data\01_Etudes\E02_Classification_rTSA\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data\Muller_Jurg_558792\CT'];
    ctMocapData = ['C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\', ...
                   '01_Data\01_Etudes\E02_Classification_rTSA\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data\Muller_Jurg_558792\20260324'];

    CTGold = ValidateCoRvsCT(TrialRab, TrialSCoRE, Session, ctFolder, ctMocapData);
    PlotScapularMeshSTA(TrialRab, Session, CTGold, ctFolder);
else
    disp('  2) Section imagerie (CT) ignoree : essai non associe au patient 558792.');
    disp(' ');
end

% -------------------------------------------------------------------------
% 3) PLOTS
% -------------------------------------------------------------------------
plotDistance(dR, dL, TrialOne.file);
plotJointComparison(TrialRab, TrialSCoRE, 1, 6, 'HT (Humero-thoracique)');
plotJointComparison(TrialRab, TrialSCoRE, 2, 7, 'GH (Gleno-humeral)');
plotJointComparison(TrialRab, TrialSCoRE, 3, 8, 'ST (Scapulo-thoracique)');

end

% -------------------------------------------------------------------------
function plotDistance(dR, dL, fileName)
figure('Name', 'RGJC/LGJC distance - Rab vs SCoRE', 'NumberTitle', 'off');
subplot(2,1,1); plot(dR, 'b-'); ylabel('Distance (mm)'); title('RGJC (droit) - |Rab - SCoRE|');
subplot(2,1,2); plot(dL, 'r-'); ylabel('Distance (mm)'); xlabel('Frame'); title('LGJC (gauche) - |Rab - SCoRE|');
sgtitle(['Rab vs SCoRE - ', fileName], 'Interpreter', 'none');
end

% -------------------------------------------------------------------------
function plotJointComparison(TrialRab, TrialSCoRE, idxR, idxL, jointName)
figure('Name', [jointName, ' - Rab vs SCoRE'], 'NumberTitle', 'off');
sides     = {'Droit', 'Gauche'};
jointIdx  = [idxR, idxL];
dofLabels = {'DOF1', 'DOF2', 'DOF3'};
for is = 1:2
    for id = 1:3
        subplot(3, 2, (id-1)*2 + is);
        eR = squeeze(TrialRab.Joint(jointIdx(is)).Euler.full(1, id, :));
        eS = squeeze(TrialSCoRE.Joint(jointIdx(is)).Euler.full(1, id, :));
        plot(eR, 'b-', 'DisplayName', 'Rab'); hold on;
        plot(eS, 'r--', 'DisplayName', 'SCoRE');
        if id == 1, title(sides{is}); end
        if is == 1, ylabel([dofLabels{id}, ' (deg)']); end
        if id == 3, xlabel('Frame'); end
        if id == 1 && is == 1, legend('Location', 'best'); end
    end
end
sgtitle([jointName, ' - Rab vs SCoRE (', TrialRab.file, ')'], 'Interpreter', 'none');
end
