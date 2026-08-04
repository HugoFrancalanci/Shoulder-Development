% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Console print of mean/max/std (mm) for a distance vector.
%                Shared by Tests/CoR/CompareScoreRab.m, ValidateCoRvsCT.m.
% -------------------------------------------------------------------------

function PrintCoRStats(label, d_mm)
fprintf('  %-16s  mean=%6.2f mm   max=%6.2f mm   std=%6.2f mm\n', ...
        label, mean(d_mm, 'omitnan'), max(d_mm), std(d_mm, 'omitnan'));
end
