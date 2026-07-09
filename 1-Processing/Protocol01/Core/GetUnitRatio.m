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
% Description:   Unit ratio (input units -> 'm'), for a raw btk acquisition
%                not yet wrapped in a Trial struct. Thin wrapper around the
%                existing SetUnits.m convention.
% -------------------------------------------------------------------------
% Inputs  : acq (btk acquisition handle)
% Outputs : ratio (double) multiply raw marker coordinates by this to get meters
% -------------------------------------------------------------------------
% Dependencies : SetUnits.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function ratio = GetUnitRatio(acq)
tmpTrial(1).btk = acq;
Units            = SetUnits(tmpTrial);
ratio            = Units.ratio;
end
