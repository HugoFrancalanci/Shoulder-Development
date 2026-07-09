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
% Description:   Drop frames where either transform could not be built
%                (missing marker -> NaN, see BuildTechnicalTransform.m). A
%                single NaN frame would otherwise corrupt the whole pinv
%                solution in SCoRE_array3.m, not just that frame.
% -------------------------------------------------------------------------
% Inputs  : Ti, Tj [4x4xN] homogeneous transforms (same N)
% Outputs : Ti, Tj [4x4xM] with invalid frames removed (M <= N)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Ti, Tj] = DropNanFrames(Ti, Tj)
valid = ~squeeze(any(any(isnan(Ti(1:3, :, :)), 1), 2)) & ...
        ~squeeze(any(any(isnan(Tj(1:3, :, :)), 1), 2));
Ti = Ti(:, :, valid);
Tj = Tj(:, :, valid);
end
