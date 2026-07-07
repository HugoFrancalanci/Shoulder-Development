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
% Description:   Main script for results plotting — Posture classification and
%                kinematic contributions (PRE vs POST rTSA).
%
%                Toggle each figure on/off using the RUN_* flags below.
%                All data is loaded once and passed as a struct (D) to each
%                figure function. Visual parameters are centralised in
%                PR_Config.m.
%
%                Figures available:
%                  RUN_CONSOLE  : Descriptive statistics and statistical
%                                 tests printed to the console
%                  RUN_FIG1A    : Thoracic posture type distribution
%                                 (stacked bar — Moroder classification)
%                  RUN_FIG1B    : Posture angle seated vs standing
%                                 (paired dotplot — PRE and POST panels)
%                  RUN_FIG1BBIS : Posture angle PRE vs POST
%                                 (paired dotplot — seated and standing panels)
%                  RUN_FIG1C    : Posture angle vs TX% and HG range
%                                 (scatter + linear regression)
%                  RUN_FIG2A    : HG range and segmental contributions
%                                 (grouped bar plot — mean +/- SD)
%                  RUN_FIG2B    : HG range and segmental contributions
%                                 (boxplot + individual data points)
%                  RUN_FIG3     : Thoracic compensation analysis
%                                 (scatter TX% vs HG/GH/ST + paired boxplots)
%
% Inputs  : Posture_PRE_POST.xlsx          Posture angles and posture types
%           Contributions_PRE_POST.xlsx  HG range and segmental contributions
%
% Outputs : Console summary + figures (one per RUN_* flag set to true)
% -------------------------------------------------------------------------
% Dependencies : PR_Config.m, PR_Console.m, PR_Helpers.m,
%                Fig_PostureDistribution.m, Fig_PostureSeatedStanding.m,
%                Fig_PosturePrePost.m, Fig_PostureCorrKin.m,
%                Fig_ContributionsBar.m, Fig_ContributionsBox.m,
%                Fig_ThoraxCompensation.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

clearvars; close all; clc;

% -------------------------------------------------------------------------
% FIGURE SELECTION
% -------------------------------------------------------------------------
RUN_CONSOLE  = true;
RUN_FIG1A    = true;
RUN_FIG1B    = true;
RUN_FIG1BBIS = true;
RUN_FIG1C    = true;
RUN_FIG2A    = true;
RUN_FIG2B    = true;
RUN_FIG3     = true;

% -------------------------------------------------------------------------
% LOAD DATA
% -------------------------------------------------------------------------
filePosture  = 'Posture_PRE_POST.xlsx';
fileContr = 'Contributions_PRE_POST.xlsx';

T_Posture  = readtable(filePosture);
T_contr = readtable(fileContr);

% Posture angles (deg)
Posture_assis_pre   = T_Posture.Cobb_Assis_PRE;
Posture_assis_post  = T_Posture.Cobb_Assis_POST;
Posture_debout_pre  = T_Posture.Cobb_Debout_PRE;
Posture_debout_post = T_Posture.Cobb_Debout_POST;
% Change with angle for further analysis

% Posture type labels (Moroder classification)
type_assis_pre   = T_Posture.Type_Assis_PRE;
type_debout_pre  = T_Posture.Type_Debout_PRE;
type_assis_post  = T_Posture.Type_Assis_POST;
type_debout_post = T_Posture.Type_Debout_POST;

% HG range and segmental contributions (%)
hg_pre  = T_contr.HG_PRE_deg;    hg_post  = T_contr.HG_POST_deg;
gh_pre  = T_contr.GH_PRE_pct;    gh_post  = T_contr.GH_POST_pct;
st_pre  = T_contr.ST_PRE_pct;    st_post  = T_contr.ST_POST_pct;
tx_pre  = T_contr.TX_PRE_pct;    tx_post  = T_contr.TX_POST_pct;

% Segmental contributions — absolute amplitudes (deg)
gh_pre_deg  = T_contr.GH_PRE_deg;   gh_post_deg = T_contr.GH_POST_deg;
st_pre_deg  = T_contr.ST_PRE_deg;   st_post_deg = T_contr.ST_POST_deg;
tx_pre_deg  = T_contr.TX_PRE_deg;   tx_post_deg = T_contr.TX_POST_deg;

n = height(T_Posture);

% -------------------------------------------------------------------------
% VISUAL CONFIG
% -------------------------------------------------------------------------
cfg = PR_Config();

% -------------------------------------------------------------------------
% DATA STRUCT — passed to all figure functions
% -------------------------------------------------------------------------
D = struct(...
    'Posture_assis_pre',   Posture_assis_pre,    ...
    'Posture_assis_post',  Posture_assis_post,   ...
    'Posture_debout_pre',  Posture_debout_pre,   ...
    'Posture_debout_post', Posture_debout_post,  ...
    'type_assis_pre',   {type_assis_pre},  ...
    'type_debout_pre',  {type_debout_pre}, ...
    'type_assis_post',  {type_assis_post}, ...
    'type_debout_post', {type_debout_post},...
    'hg_pre',  hg_pre,  'hg_post',  hg_post,  ...
    'gh_pre',  gh_pre,  'gh_post',  gh_post,  ...
    'st_pre',  st_pre,  'st_post',  st_post,  ...
    'tx_pre',  tx_pre,  'tx_post',  tx_post,  ...
    'gh_pre_deg',  gh_pre_deg,  'gh_post_deg', gh_post_deg, ...
    'st_pre_deg',  st_pre_deg,  'st_post_deg', st_post_deg, ...
    'tx_pre_deg',  tx_pre_deg,  'tx_post_deg', tx_post_deg, ...
    'n', n);

% -------------------------------------------------------------------------
% RUN
% -------------------------------------------------------------------------
if RUN_CONSOLE,  PR_Console(D);                 end
if RUN_FIG1A,    Fig_PostureDistribution(D, cfg);  end
if RUN_FIG1B,    Fig_PostureSeatedStanding(D, cfg);end
if RUN_FIG1BBIS, Fig_PosturePrePost(D, cfg);       end
if RUN_FIG1C,    Fig_PostureCorrKin(D, cfg);       end
if RUN_FIG2A,    Fig_ContributionsBar(D, cfg);  end
if RUN_FIG2B,    Fig_ContributionsBox(D, cfg);  end
if RUN_FIG3,     Fig_ThoraxCompensation(D, cfg);end