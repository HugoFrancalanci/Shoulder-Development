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
% Description:   Visual configuration for PlotResults_Main.
%                Centralises colours and style parameters shared across
%                all figure functions.
%
%                Colour convention:
%                  COL_PRE  = Red  [0.86 0.15 0.15]
%                  COL_POST = Blue [0.15 0.39 0.92]
%                  COL_GH / COL_ST / COL_TX = segment-specific colours
%
% Outputs : cfg (struct) with fields:
%             COL_PRE, COL_POST, COL_GH, COL_ST, COL_TX,
%             ALPHA_SD, ALPHA_LINE, LW, FONT_SIZE, TITLE_SIZE
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function cfg = PR_Config()

% PRE / POST group colours
cfg.COL_PRE   = [0.86 0.15 0.15];   % Red  = PRE
cfg.COL_POST  = [0.15 0.39 0.92];   % Blue = POST

% Segment-specific colours
cfg.COL_GH    = [0.20 0.55 0.85];   % Gleno-humeral
cfg.COL_ST    = [0.55 0.25 0.75];   % Scapulo-thoracic
cfg.COL_TX    = [0.25 0.70 0.50];   % Thorax/ICS

% Style parameters
cfg.ALPHA_SD   = 0.15;
cfg.ALPHA_LINE = 0.85;
cfg.LW         = 2.0;
cfg.FONT_SIZE  = 9;
cfg.TITLE_SIZE = 13;
end
