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
% Description:   Compute thorax posture summary (PostureSummary) relative to
%                the patient-referenced ICS.
%
%                Joint(11).Euler.full is read directly from ComputeKinematics
%                (computed via Segment(8) ICS defined in DefineSegments),
%                so this function focuses exclusively on :
%                  - Statistical summary of thorax kinematics
%                  - Thoracic curvature angle (Cobb approach)
%                  - Moroder classification (scapular internal rotation)
%
% Inputs  : Trial   (struct)  with Joint(11).Euler.full, Segment(4).T.full,
%                             Marker and Joint(3), Joint(8) populated

% Outputs : Trial   (struct)  Joint(11).PostureSummary populated
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Trial = ComputeThoraxPosture(Trial)

% Joint(11) must be populated by ComputeKinematics
if isempty(Trial.Joint(11).Euler.full)
    warning('Joint(11).Euler.full is empty');
    return;
end

% -------------------------------------------------------------------------
% READ EULER ANGLES FROM Joint(11)
%   (1,1,:) X — lateral tilt    
%   (1,2,:) Y — axial rotation   
%   (1,3,:) Z — kyphosis/flexion 
% -------------------------------------------------------------------------
euler_X = squeeze(Trial.Joint(11).Euler.full(1,1,:))'; 
euler_Y = squeeze(Trial.Joint(11).Euler.full(1,2,:))'; 
euler_Z = squeeze(Trial.Joint(11).Euler.full(1,3,:))';

% -------------------------------------------------------------------------
% STATISTICAL SUMMARY
% -------------------------------------------------------------------------
Trial.Joint(11).PostureSummary.axialRotation_mean  = mean(euler_Y, 'omitnan');
Trial.Joint(11).PostureSummary.lateralTilt_mean    = mean(euler_X, 'omitnan');
Trial.Joint(11).PostureSummary.kyphosis_mean       = mean(euler_Z, 'omitnan');
Trial.Joint(11).PostureSummary.axialRotation_range = range(euler_Y);
Trial.Joint(11).PostureSummary.lateralTilt_range   = range(euler_X);
Trial.Joint(11).PostureSummary.kyphosis_range      = range(euler_Z);

% -------------------------------------------------------------------------
% THORACIC INCLINATION
% -------------------------------------------------------------------------
% Estimated from spinal marker geometry relative to the gravitational
% vertical, independent of the thoracic segment frame.
% Computed over the first 100 frames (patient at rest before movement).
%
% Markers used :
%   CV7: 7th cervical spinous process
%   TV8: 8th thoracic spinous process 
%
% Approach : angle between vector TV8->CV7 and gravitational vertical
%   [0;0;1] (Qualisys Z_ICS = calibrated vertical axis).
%   Computed in 3D (no sagittal plane projection).
%   0 deg = perfectly upright thorax
%   Larger values = more inclined / kyphotic thorax
%
% Functional classification : To be determined
%
% References :
%   Wu G et al. ISB recommendation on definitions of joint coordinate
%   systems — Part II. J Biomech, 2005;38(5):981-92.
%   Moissenet F et al. JSES Reviews, Reports, and Techniques, 2025.
%   DOI : 10.1016/j.xrrt.2025.05.022

nPostural = min(100, Trial.n1);

CV7_pos = getMarkerMean(Trial.Marker, 'CV7', nPostural);
TV8_pos = getMarkerMean(Trial.Marker, 'TV8', nPostural);

% 3D vector T8 → C7
v_thorax = CV7_pos - TV8_pos;  % [3x1]

% Gravitational vertical
v_grav = [0; 0; 1];

% Inclination angle from vertical
thoracic_curvature_angle = acosd(max(-1, min(1, ...
    dot(v_thorax, v_grav) / (norm(v_thorax) + 1e-10))));

% Functional classification
% Based on Kebaetse et al. (1999) two-posture comparison :
%   Erect posture   : 26.4 +/- 11.5 deg
%   Slouched posture: 38.5 +/- 10.8 deg
% Reference : Kebaetse M, McClure P, Pratt NA.
%   Thoracic position effect on shoulder range of motion, strength,
%   and three-dimensional scapular kinematics.
%   Arch Phys Med Rehabil 1999;80:945-50.
% Note : method differs but are close (TV8->CV7 vs T2-T11).
if thoracic_curvature_angle < 32
    thorax_posture_type = 'Erect-like posture (<32 deg)';
else
    thorax_posture_type = 'Slouched-like posture (>=32 deg)';
end

Trial.Joint(11).PostureSummary.thoracic_curvature_angle = round(thoracic_curvature_angle, 1);
Trial.Joint(11).PostureSummary.thorax_posture_type      = thorax_posture_type;

% -------------------------------------------------------------------------
% MORODER CLASSIFICATION — scapular internal rotation (SIR)
% -------------------------------------------------------------------------
% Moroder (2024) classifies patients in 3 types based on scapular
% internal rotation (SIR) measured on CT axial view lay down:
%   Type A (upright, retracted scapulae) : SIR <= 36 deg
%   Type B (intermediate)                : 36 < SIR <= 46 deg
%   Type C (kyphotic, protracted scapulae): SIR > 46 deg

% Approximation from kinematics :
%   RST Joint(3) DOF2 Y ~ SIR right
%   LST Joint(8) DOF2 Y ~ SIR left
%   Averaged over the first 100 frames (patient at rest).

% Reference :
%   Moroder P et al. J Shoulder Elbow Surg, 2024.

% Notes : SIR estimated from ST DOF2 Y. This is an approximation of the true Moroder SIR
% (measured on CT axial view as scapular axis vs vertebral sagittal axis).
% Direct correspondence is not validated. Results should be interpreted
% with caution and compared to CT-based classification when available.

nMoroder = min(100, Trial.n1);

% SIR right --> Joint(3), DOF2 Y
if length(Trial.Joint) >= 3 && ~isempty(Trial.Joint(3).Euler.full)
    SIR_R = mean(abs(squeeze(Trial.Joint(3).Euler.full(1,2,1:nMoroder))), 'omitnan');
else
    SIR_R = NaN;
end

% SIR left --> Joint(8), DOF2 Y
if length(Trial.Joint) >= 8 && ~isempty(Trial.Joint(8).Euler.full)
    SIR_L = mean(abs(squeeze(Trial.Joint(8).Euler.full(1,2,1:nMoroder))), 'omitnan');
else
    SIR_L = NaN;
end

moroder_R = getMoroderType(SIR_R);
moroder_L = getMoroderType(SIR_L);

Trial.Joint(11).PostureSummary.SIR_R     = round(SIR_R, 1);
Trial.Joint(11).PostureSummary.SIR_L     = round(SIR_L, 1);
Trial.Joint(11).PostureSummary.moroder_R = moroder_R;
Trial.Joint(11).PostureSummary.moroder_L = moroder_L;

end

%  MEAN POSITION OF A MARKER OVER nRef FRAMES
function pos = getMarkerMean(MarkerArray, label, nRef)
pos = [];
for i = 1:length(MarkerArray)
    if strcmp(MarkerArray(i).label, label)
        traj = MarkerArray(i).Trajectory.full;
        pos  = mean(traj(:,1,1:min(nRef,size(traj,3))), 3);
        return;
    end
end
if isempty(pos)
    error('Marker ''%s'' not found.', label);
end
end

%  MORODER CLASSIFICATION
function type = getMoroderType(SIR)
if isnan(SIR)
    type = 'N/A';
elseif SIR <= 36
    type = 'Type A — Upright (SIR <=36 deg)';
elseif SIR <= 46
    type = 'Type B — Intermediate (36 < SIR <=46 deg)';
else
    type = 'Type C — Kyphotic (SIR >46 deg)';
end
end