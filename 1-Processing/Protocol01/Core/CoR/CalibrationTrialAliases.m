% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Alias table for the calibration/static trials, whose file
%                name depends on the protocol year : Calibration1-3 can
%                also be named Static1-3, Calibration5-6 can also be named
%                Isometric1-2 (Calibration4 has no alias). Single source of
%                truth for this mapping, shared by every Core/CoR function
%                that looks up a calibration trial by name (previously only
%                known to Multi/Core/ComputeDataAvailability.m, which has
%                its own copy for its own reporting purposes and is left
%                untouched here).
% -------------------------------------------------------------------------
% Outputs : aliases (cell array of cellstr) — one row per canonical name,
%                    each row lists every name variant that trial can have
%                    on disk (canonical name listed first)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function aliases = CalibrationTrialAliases()
aliases = { ...
    {'CALIBRATION1', 'STATIC1'}; ...
    {'CALIBRATION2', 'STATIC2'}; ...
    {'CALIBRATION3', 'STATIC3'}; ...
    {'CALIBRATION4'}; ...
    {'CALIBRATION5', 'ISOMETRIC1'}; ...
    {'CALIBRATION6', 'ISOMETRIC2'}; ...
};
end
