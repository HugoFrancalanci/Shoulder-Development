% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   May 2026
% -------------------------------------------------------------------------
% Description:   Console summary of descriptive statistics and statistical
%                tests for all outcome variables.
%
%                Sections printed:
%                  1. Posture angle (deg)        — mean, SD, min, max
%                  2. Segmental contributions — absolute amplitudes (deg)
%                  3. Segmental contributions — proportions (%)
%                  4. Paired t-tests          — PRE vs POST and
%                                               seated vs standing
%                  5. Pearson correlations    — TX% vs HG/GH/ST
%                  6. Pearson correlations    — Posture (seated) vs
%                                               TX%, HG, GH%, ST%
%
%                Statistical notation: *** p<0.001 / ** p<0.01 / * p<0.05
%
% Inputs  : D   (struct)  data struct from PlotResults_Main
% Outputs : Console display only
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PR_Console(D)

disp(' ');
disp('------------------------------------------------------------------');
disp('  DESCRIPTIVE STATISTICS SUMMARY');
disp('------------------------------------------------------------------');

% --- Posture ---
disp(' ');
disp('  --- Posture angle (deg) ---');
fprintf('  %-22s  %7s  %7s  %7s  %7s\n','Condition','Mean','SD','Min','Max');
disp(repmat('-',1,58));
pDesc('Seated PRE',    D.Posture_assis_pre);
pDesc('Seated POST',   D.Posture_assis_post);
pDesc('Standing PRE',  D.Posture_debout_pre);
pDesc('Standing POST', D.Posture_debout_post);
disp(repmat('-',1,58));

% --- Contributions — deg ---
disp(' ');
disp('  --- Segmental contributions — absolute amplitudes (deg) ---');
fprintf('  %-22s  %7s  %7s  %7s  %7s\n','Metric','Mean','SD','Min','Max');
disp(repmat('-',1,58));
pDesc('HG PRE (deg)',  D.hg_pre);    pDesc('HG POST (deg)', D.hg_post);
pDesc('GH PRE (deg)',  D.gh_pre_deg);pDesc('GH POST (deg)', D.gh_post_deg);
pDesc('ST PRE (deg)',  D.st_pre_deg);pDesc('ST POST (deg)', D.st_post_deg);
pDesc('TX PRE (deg)',  D.tx_pre_deg);pDesc('TX POST (deg)', D.tx_post_deg);
disp(repmat('-',1,58));

% --- Contributions — % ---
disp(' ');
disp('  --- Segmental contributions — proportions (%) ---');
fprintf('  %-22s  %7s  %7s  %7s  %7s\n','Metric','Mean','SD','Min','Max');
disp(repmat('-',1,58));
pDesc('GH PRE (%)',  D.gh_pre);  pDesc('GH POST (%)', D.gh_post);
pDesc('ST PRE (%)',  D.st_pre);  pDesc('ST POST (%)', D.st_post);
pDesc('TX PRE (%)',  D.tx_pre);  pDesc('TX POST (%)', D.tx_post);
disp(repmat('-',1,58));

% --- Paired t-tests ---
disp(' ');
disp('  --- Paired t-tests ---');
fprintf('  %-26s  %8s  %5s\n','Comparison','p-value','Stars');
disp(repmat('-',1,46));
pTest('Posture seated PRE/POST',   D.Posture_assis_pre,  D.Posture_assis_post);
pTest('Posture standing PRE/POST', D.Posture_debout_pre, D.Posture_debout_post);
pTest('Seated vs Standing PRE', D.Posture_assis_pre,  D.Posture_debout_pre);
pTest('Seated vs Standing POST',D.Posture_assis_post, D.Posture_debout_post);
disp(repmat('-',1,46));
pTest('HG range PRE/POST',      D.hg_pre,     D.hg_post);
pTest('GH % PRE/POST',          D.gh_pre,     D.gh_post);
pTest('ST % PRE/POST',          D.st_pre,     D.st_post);
pTest('TX % PRE/POST',          D.tx_pre,     D.tx_post);
pTest('TX deg PRE/POST',        D.tx_pre_deg, D.tx_post_deg);
disp(repmat('-',1,46));

% --- Pearson correlations — TX% ---
disp(' ');
disp('  --- Pearson correlations (TX% vs ...) ---');
fprintf('  %-28s  %7s  %8s  %5s\n','Comparison','r','p-value','Stars');
disp(repmat('-',1,56));
pCorr('TX% vs HG range  PRE',  D.hg_pre,  D.tx_pre);
pCorr('TX% vs HG range  POST', D.hg_post, D.tx_post);
pCorr('TX% vs GH%       PRE',  D.gh_pre,  D.tx_pre);
pCorr('TX% vs GH%       POST', D.gh_post, D.tx_post);
pCorr('TX% vs ST%       PRE',  D.st_pre,  D.tx_pre);
pCorr('TX% vs ST%       POST', D.st_post, D.tx_post);
disp(repmat('-',1,56));

% --- Pearson correlations — Posture ---
disp(' ');
disp('  --- Pearson correlations (Posture seated vs ...) ---');
fprintf('  %-28s  %7s  %8s  %5s\n','Comparison','r','p-value','Stars');
disp(repmat('-',1,56));
pCorr('Posture vs TX%  PRE',  D.Posture_assis_pre,  D.tx_pre);
pCorr('Posture vs TX%  POST', D.Posture_assis_post, D.tx_post);
pCorr('Posture vs HG   PRE',  D.Posture_assis_pre,  D.hg_pre);
pCorr('Posture vs HG   POST', D.Posture_assis_post, D.hg_post);
pCorr('Posture vs GH%  PRE',  D.Posture_assis_pre,  D.gh_pre);
pCorr('Posture vs GH%  POST', D.Posture_assis_post, D.gh_post);
pCorr('Posture vs ST%  PRE',  D.Posture_assis_pre,  D.st_pre);
pCorr('Posture vs ST%  POST', D.Posture_assis_post, D.st_post);
disp(repmat('-',1,56));
disp('  Note: seated Posture used as reference (analytical tasks performed seated)');
end

% -------------------------------------------------------------------------
% LOCAL FUNCTIONS
% -------------------------------------------------------------------------
function pDesc(label, v)
fprintf('  %-22s  %7.1f  %7.1f  %7.1f  %7.1f\n', ...
    label, mean(v,'omitnan'), std(v,'omitnan'), min(v), max(v));
end

function pTest(label, v1, v2)
[~,p] = ttest(v1, v2);
fprintf('  %-26s  p=%.4f  %s\n', label, p, pToStars(p));
end

function pCorr(label, x, y)
[r,p] = corr(x, y, 'Type','Pearson');
fprintf('  %-28s  %7.3f  p=%.4f  %s\n', label, r, p, pToStars(p));
end

function s = pToStars(p)
if     p < 0.001, s = '*';
elseif p < 0.01,  s = '*';
elseif p < 0.05,  s = '*';
else,             s = 'ns';
end
end
