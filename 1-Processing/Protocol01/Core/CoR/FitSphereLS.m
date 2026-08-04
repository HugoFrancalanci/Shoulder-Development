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
% Description:   Closed-form linear least-squares sphere fit. Solves the
%                algebraic form x^2+y^2+z^2 = 2ax+2by+2cz+d (linear in
%                a,b,c,d) — center = (a,b,c), radius = sqrt(d+a^2+b^2+c^2).
%                Used to extract the CT-based centre of a digitised
%                spherical surface (e.g. a glenosphere implant), from a
%                point cloud sampled on that surface.
% -------------------------------------------------------------------------
% Inputs  : points (Nx3 double) surface point cloud, any consistent unit
% Outputs : center      (3x1) sphere centre, same unit as points
%           radius      (scalar) sphere radius, same unit as points
%           residual_mm (scalar) RMS of (distance to center - radius),
%                       same unit as points despite the name (kept as
%                       "_mm" since points are expected in mm in this toolbox)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [center, radius, residual_mm] = FitSphereLS(points)

x = points(:,1); y = points(:,2); z = points(:,3);

A   = [2*x, 2*y, 2*z, ones(size(x))];
b   = x.^2 + y.^2 + z.^2;
sol = A \ b;

center = sol(1:3);
radius = sqrt(sol(4) + sum(center.^2));

d           = sqrt(sum((points - center').^2, 2)) - radius;
residual_mm = sqrt(mean(d.^2));

end
