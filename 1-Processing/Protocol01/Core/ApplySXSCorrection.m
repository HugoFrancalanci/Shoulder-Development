% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Rebuilds the virtual xiphoid landmark (SXS) of one trial
%                from the local position found by DetectSXSCorrection.m,
%                frame by frame, in the thorax technical frame used by the
%                K-LAB toolbox (AddPointedLandmarks.m): origin SJN,
%                Y = SJN - SME, Z = (SME - TV5) x (CV7 - TV5).
%                Frames where SJN, SME, CV7 or TV5 is missing are NaN.
% -------------------------------------------------------------------------
% Inputs  : Marker (struct) btkGetMarkers output of the trial (raw units)
%           Fix    (struct) DetectSXSCorrection output (Fix.local_mm)
%           Units  (struct) SetUnits output (.input, .ratio)
% Outputs : traj   [3 x 1 x N] SXS trajectory, same convention and units
%                  as Trial.Marker(i).Trajectory.full
%                  (InitialiseMarkerTrajectories.m)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function traj = ApplySXSCorrection(Marker, Fix, Units)

toMM = 1;
if strcmpi(Units.input, 'm'), toMM = 1000; end

sjn = Marker.SJN; sme = Marker.SME; cv7 = Marker.CV7; tv5 = Marker.TV5;
N   = size(sjn, 1);
out = NaN(N, 3);
for t = 1:N
    if any(all([sjn(t, :); sme(t, :); cv7(t, :); tv5(t, :)] == 0, 2)), continue; end
    Y = sjn(t, :) - sme(t, :);                  Y = Y / norm(Y);
    Z = cross(sme(t, :) - tv5(t, :), cv7(t, :) - tv5(t, :));  Z = Z / norm(Z);
    X = cross(Y, Z);                            X = X / norm(X);
    Z = cross(X, Y);
    out(t, :) = sjn(t, :) + ([X' Y' Z'] * Fix.local_mm)' / toMM;   % raw C3D units
end
% Same convention as InitialiseMarkerTrajectories.m : [3 x 1 x N], output units
traj = permute(out, [2, 3, 1]) * Units.ratio;
end
