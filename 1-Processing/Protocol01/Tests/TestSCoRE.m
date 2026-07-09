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
% Description:   Unit test for the SCoRE glenohumeral CoR calibration
%                (Session.SCoRE, computed by Core/ComputeSCoRE.m).
%
%                CoR residual (mm) : agreement, on the calibration frames
%                (default ANALYTIC2+ANALYTIC4+FUNCTIONAL1+FUNCTIONAL3, see
%                Core/ComputeSCoRE.m header for why this combo was chosen
%                over the earlier ANALYTIC1-4 pool), between the CoR estimated via the
%                scapula technical frame and via the humerus technical
%                frame (Ehrig et al. 2006 quality metric — a true ball
%                joint gives near-zero residual).
%                Cluster RMS (mm)  : Soderkvist rigid-fit residual of the
%                scapula/humerus clusters against their CALIBRATION1
%                reference pose (cluster rigidity quality).
%
% Inputs  : Session (struct) with Session.SCoRE populated by ComputeSCoRE
% Outputs : Console report
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function TestSCoRE(Session)

disp(' ');
disp('------------------------------------------------------------------');
disp('Test unitaire (calibration SCoRE - centre glenohumeral)');
disp('Reference : residu de coincidence du CoR (Ehrig et al. 2006), ANALYTIC2+ANALYTIC4+FUNCTIONAL1+FUNCTIONAL3');
disp(' ');

if ~isfield(Session, 'SCoRE') || isempty(Session.SCoRE)
    disp('  Session.SCoRE absent -> ComputeSCoRE n''a pas ete execute.');
    return;
end

% Thresholds (mm)
% CoR residual : scapula skin markers are affected by substantial soft
% tissue artefact (STA) during humeral elevation, which is the dominant
% error source for a functional GH calibration on skin markers (vs.
% bone-pin/fluoroscopy studies). 10-20mm residuals are commonly reported
% in the literature for this reason -> thresholds set accordingly.
PASS_tol_residual = 15.0;
WARN_tol_residual = 25.0;
% Cluster RMS : purely a rigid-cluster tracking quality metric (soder fit
% vs CALIBRATION1), not affected by STA -> kept tight.
PASS_tol_rms      = 3.0;
WARN_tol_rms      = 6.0;

printSideResults('Droit',  Session.SCoRE.R, PASS_tol_residual, WARN_tol_residual, PASS_tol_rms, WARN_tol_rms);
printSideResults('Gauche', Session.SCoRE.L, PASS_tol_residual, WARN_tol_residual, PASS_tol_rms, WARN_tol_rms);

disp(' ');
end

function printSideResults(label, S, pass_res, warn_res, pass_rms, warn_rms)

fprintf('  --- %s ---\n', label);
fprintf('  %-28s  %8s  %8s  %s\n', 'Metrique', 'mean', 'max', 'Status');
disp(repmat('-', 1, 62));

m = mean(S.residual_mm, 'omitnan');
x = max(S.residual_mm);
fprintf('  %-28s  %8.2f  %8.2f  %s\n', 'CoR residual (mm)', m, x, getStatus(m, pass_res, warn_res));

fprintf('  %-28s  %8.2f  %8s  %s\n', 'Scapula cluster RMS (mm)', S.clusterRMS.scapula_mm, '-', ...
        getStatus(S.clusterRMS.scapula_mm, pass_rms, warn_rms));
fprintf('  %-28s  %8.2f  %8s  %s\n', 'Humerus cluster RMS (mm)', S.clusterRMS.humerus_mm, '-', ...
        getStatus(S.clusterRMS.humerus_mm, pass_rms, warn_rms));
disp(repmat('-', 1, 62));
end

function status = getStatus(val, pass_tol, warn_tol)
if val < pass_tol
    status = sprintf('[+] PASS');
elseif val < warn_tol
    status = sprintf('[~] WARN');
else
    status = sprintf('[!] FAIL');
end
end
