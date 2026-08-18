% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Sequence-free (quaternion / axis-angle) complement to the
%                Euler decomposition in ComputeKinematics.m. Given the
%                same relative rotation matrix already used to compute
%                Euler angles, returns the single equivalent rotation
%                (total angle + axis) describing that same orientation --
%                no rotation sequence to choose, so no sequence-dependent
%                gimbal lock.
%
%                q is R2q_array3's output, CANONICALISED (q(1) >= 0 on
%                every frame independently). R2q_array3 enforces
%                frame-to-frame CONTINUITY of sign instead (Lee's method),
%                which is correct when q is going to be differentiated
%                into an angular velocity, but wrong for reading a
%                per-frame rotation magnitude: q and -q encode the same
%                rotation matrix, yet qlog(q) and qlog(-q) report
%                complementary angles (theta vs 360-theta), so a
%                continuity-flipped frame would read a spurious angle
%                above 180 deg. Canonicalising drops the continuity,
%                which this per-frame use does not need.
%
% Inputs  : T (rotation-only [3,3,n] or homogeneous [4,4,n] transform array)
% Outputs : q          canonical quaternion, [4,1,n], q(1,:,:)=cos(theta/2)
%           TotalAngle total equivalent rotation, [1,1,n], degrees, bounded [0,180]
%           Axis       unit rotation axis, [3,1,n] (NaN at frames where TotalAngle=0)
% -------------------------------------------------------------------------
% Dependencies : R2q_array3.m, qlog_array3.m
%                (3D Kinematics and Inverse Dynamics toolbox, R. Dumas --
%                locally patched, see R2q_array3.m header)
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [q, TotalAngle, Axis] = ComputeQuaternionKinematics(T)

if size(T,1) == 4
    R = T(1:3,1:3,:);
else
    R = T;
end

q = R2q_array3(R);

% Canonicalise q(1) >= 0 per frame (see header)
q1   = squeeze(q(1,1,:));
flip = q1 < 0;
q(:,1,flip) = -q(:,1,flip);

halfktheta = qlog_array3(q);                              % k*(theta/2), [3x1xn]
normHkt    = sqrt(sum(halfktheta.^2,1));                  % [1x1xn]
TotalAngle = rad2deg(2*normHkt);                           % [1x1xn]
Axis       = halfktheta ./ normHkt;                         % [3x1xn]

end
