% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Reference  :   To be defined
% Date       :   May 2026
% -------------------------------------------------------------------------
% Description:   Computes 3D joint kinematics for the shoulder complex using
%                Euler/Cardan angle decompositions following ISB recommendations
%                (Wu et al. 2005).
%
%                Joints computed :
%                  Joint  1 — Right humerothoracic (HT_R)
%                  Joint  2 — Right glenohumeral   (GH_R)
%                  Joint  3 — Right scapulothoracic (ST_R)
%                  Joint  6 — Left humerothoracic  (HT_L)
%                  Joint  7 — Left glenohumeral    (GH_L)
%                  Joint  8 — Left scapulothoracic (ST_L)
%                  Joint 11 — Thorax / patient-ICS
%                  Joint 12 — Right humerus / patient-ICS
%                  Joint 13 — Left humerus  / patient-ICS
%
%                Euler sequences are task-dependent (ANALYTIC1-5) to avoid
%                gimbal lock. Left-side DOFs include selective sign inversions
%                to fulfil ISB sagittal-plane symmetry convention.
%
%                Outputs are stored in Trial.Joint(i).Euler.full [1 x 3 x N]
%                and Trial.Joint(i).ElevationPlane.full [1 x 1 x N] where
%                applicable.
% -------------------------------------------------------------------------
% Dependencies : - 3D Kinematics and Inverse Dynamics toolbox by Raphael Dumas: 
% https://fr.mathworks.com/matlabcentral/fileexchange/58021-3d-kinematics-and-inverse-dynamics?s_tid=prof_contriblnk
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Trial = ComputeKinematics(c3dFiles,Trial)

n = fix(Trial.n1);

% -------------------------------------------------------------------------
% RIGHT HUMEROTHORACIC JOINT
% -------------------------------------------------------------------------
% Homogenous matrix of the rigid transformation between segments
Trial.Joint(1).T.full = Mprod_array3(Tinv_array3(Trial.Segment(4).T.full),...
                                     Trial.Segment(1).T.full);
% JCS and motion for the humerus relative to the thorax (XZY order)     
% (Senk and Cheze 2006, Creveaux et al. 2018, Phadke et al. 2011)

%    DOF1 (pos 3) = Z : flexion/extension    (+= extension, -= flexion)    [sagittal plan]
%    DOF2 (pos 1) = X : elevation            (-= elevation)                [relative to the trunk]
%    DOF3 (pos 2) = Y : axial rotation       (+= internal, -= external)
if contains(c3dFiles.name,'ANALYTIC1') || contains(c3dFiles.name,'FUNCTIONAL1') || contains(c3dFiles.name,'FUNCTIONAL2') || contains(c3dFiles.name,'FUNCTIONAL4') % Sagittal elevation
    Trial.Joint(1).sequence            = 'ZXY';
    Euler                              = R2mobileZXY_array3(Trial.Joint(1).T.full(1:3,1:3,:));
    Trial.Joint(1).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(1).Euler.full(1,2,:)   = rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(1).Euler.full(1,3,:)   = rad2deg(Euler(:,1,:)); % Z             
    Trial.Joint(1).dj.full             = [];          
    Euler2                             = R2mobileYXY_array3(Trial.Joint(1).T.full(1:3,1:3,:));
    Trial.Joint(1).ElevationPlane.full = 180+rad2deg(unwrap(atan2(Trial.Joint(1).T.full(1,2,:),Trial.Joint(1).T.full(3,2,:))));
    % Elevation plane : angle of the humerus longitudinal axis (Yh) projected onto the 
    % thorax transverse plane (XZ). 0e = coronal plane, 90e = sagittal plane.
    clear Euler dj x y p x1 y1;

%    DOF1 (pos 1) = X : elevation            (-= elevation)               
%    DOF2 (pos 3) = Z : flexion/extension    (+= extension, -= flexion)    
%    DOF3 (pos 2) = Y : axial rotation       (+= internal, -= external)
elseif contains(c3dFiles.name,'ANALYTIC2') || contains(c3dFiles.name,'ANALYTIC5') || contains(c3dFiles.name,'FUNCTIONAL3') || contains(c3dFiles.name,'STATIC') || contains(c3dFiles.name,'ISOMETRIC') % Coronal elevation
    Trial.Joint(1).sequence            = 'XZY';
    Euler                              = R2mobileXZY_array3(Trial.Joint(1).T.full(1:3,1:3,:));
    Trial.Joint(1).Euler.full(1,1,:)   = rad2deg(Euler(:,1,:)); % X
    Trial.Joint(1).Euler.full(1,2,:)   = rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(1).Euler.full(1,3,:)   = rad2deg(Euler(:,2,:)); % Z              
    Trial.Joint(1).dj.full             = [];        
    Trial.Joint(1).ElevationPlane.full = 180+rad2deg(unwrap(atan2(Trial.Joint(1).T.full(1,2,:),Trial.Joint(1).T.full(3,2,:))));
    clear Euler dj x y p x1 y1; 
elseif contains(c3dFiles.name,'ANALYTIC3') % External rotation
    Trial.Joint(1).sequence            = 'YXZ';
    Euler                              = R2mobileYXZ_array3(Trial.Joint(1).T.full(1:3,1:3,:));
    Trial.Joint(1).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(1).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 120
        Trial.Joint(1).Euler.full(1,2,:) = unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y  
    else
        Trial.Joint(1).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    end
    Trial.Joint(1).Euler.full(1,3,:)   = rad2deg(Euler(:,3,:)); % Z 
    Trial.Joint(1).dj.full             = [];   
    Trial.Joint(1).ElevationPlane.full = [];     
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(1).Euler.full(1,2,:))');
elseif contains(c3dFiles.name,'ANALYTIC4') % Internal rotation
    Trial.Joint(1).sequence            = 'YXZ';
    Euler                              = R2mobileYXZ_array3(Trial.Joint(1).T.full(1:3,1:3,:));
    Trial.Joint(1).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(1).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap((rad2deg(Euler(:,1,:))))) > 120
        Trial.Joint(1).Euler.full(1,2,:) = unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y  
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) > 160
        Trial.Joint(1).Euler.full(1,2,:) = unwrap(squeeze(-180+rad2deg(Euler(:,1,:))))-180; % Y 
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) < -120
        Trial.Joint(1).Euler.full(1,2,:) = unwrap(squeeze(180+rad2deg(Euler(:,1,:)))); % Y 
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) < -160
        Trial.Joint(1).Euler.full(1,2,:) = unwrap(squeeze(180+rad2deg(Euler(:,1,:))))+180; % Y 
    else
        Trial.Joint(1).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    end
    Trial.Joint(1).Euler.full(1,3,:)   = rad2deg(Euler(:,3,:)); % Z              
    Trial.Joint(1).dj.full             = [];        
    Trial.Joint(1).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1; 
    figure; plot(squeeze(Trial.Joint(1).Euler.full(1,2,:))');
end

% -------------------------------------------------------------------------
% RIGHT GLENOHUMERAL JOINT
% -------------------------------------------------------------------------
% Homogenous matrix of the rigid transformation between segments
Trial.Joint(2).T.full = Mprod_array3(Tinv_array3(Trial.Segment(2).T.full),...
                                     Trial.Segment(1).T.full);
% JCS and motion for the humerus relative to the scapula (XZY order)     
% (Senk and Cheze 2006, Creveaux et al. 2018, Phadke et al. 2011)

%   DOF1 (pos 3) = Z : flexion/extension    (+= extension, -= flexion)    
%   DOF2 (pos 1) = X : elevation            (-= elevation)               
%   DOF3 (pos 2) = Y : axial rotation       (+= internal, -= external)
if contains(c3dFiles.name,'ANALYTIC1') || contains(c3dFiles.name,'FUNCTIONAL1') || contains(c3dFiles.name,'FUNCTIONAL2') || contains(c3dFiles.name,'FUNCTIONAL4') % Sagittal elevation
    Trial.Joint(2).sequence          = 'ZXY';
    Euler                            = R2mobileZXY_array3(Trial.Joint(2).T.full(1:3,1:3,:));
    Trial.Joint(2).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(2).Euler.full(1,2,:) = rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(2).Euler.full(1,3,:) = rad2deg(Euler(:,1,:)); % Z             
    Trial.Joint(2).dj.full           = [];        
    clear Euler dj x y p x1 y1; 

%   DOF1 (pos 1) = X : elevation            (-= elevation)                
%   DOF2 (pos 3) = Z : flexion/extension    (+= extension, -= flexion)   
%   DOF3 (pos 2) = Y : axial rotation       (+= internal, -= external)
elseif contains(c3dFiles.name,'ANALYTIC2') || contains(c3dFiles.name,'ANALYTIC5') || contains(c3dFiles.name,'FUNCTIONAL3') || contains(c3dFiles.name,'STATIC') || contains(c3dFiles.name,'ISOMETRIC') % Coronal elevation
    Trial.Joint(2).sequence          = 'XZY';
    Euler                            = R2mobileXZY_array3(Trial.Joint(2).T.full(1:3,1:3,:));
    Trial.Joint(2).Euler.full(1,1,:) = rad2deg(Euler(:,1,:)); % X
    Trial.Joint(2).Euler.full(1,2,:) = rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(2).Euler.full(1,3,:) = rad2deg(Euler(:,2,:)); % Z              
    Trial.Joint(2).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
elseif contains(c3dFiles.name,'ANALYTIC3') % External rotation
    Trial.Joint(2).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(2).T.full(1:3,1:3,:));
    Trial.Joint(2).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(2).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 100
        Trial.Joint(2).Euler.full(1,2,:) = unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y  
    else
        Trial.Joint(2).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    end
    Trial.Joint(2).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Z     
    Trial.Joint(2).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(2).Euler.full(1,2,:))');
elseif contains(c3dFiles.name,'ANALYTIC4') % Internal rotation
    Trial.Joint(2).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(2).T.full(1:3,1:3,:));    
    Trial.Joint(2).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(2).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 100
        Trial.Joint(2).Euler.full(1,2,:) = unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y  
    else
        Trial.Joint(2).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    end
    Trial.Joint(2).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Z  
    Trial.Joint(2).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(2).Euler.full(1,2,:))');
end

% -------------------------------------------------------------------------
% RIGHT SCAPULOTHORACIC JOINT
% -------------------------------------------------------------------------
% Homogenous matrix of the rigid transformation between segments
Trial.Joint(3).T.full = Mprod_array3(Tinv_array3(Trial.Segment(4).T.full),...
                                     Trial.Segment(2).T.full);
% JCS and motion for the scapula relative to the thorax (YXZ order) 
% (Wu et al. 2005)

%   DOF1 (pos 2) = Y : protraction/retraction     (+= protraction)
%   DOF2 (pos 1) = X : lateral/medial rotation    (+= medial rotation)
%   DOF3 (pos 3) = Z : anterior/posterior tilt    (+= posterior tilt)
if contains(c3dFiles.name,'ANALYTIC') || contains(c3dFiles.name,'FUNCTIONAL')
    Trial.Joint(3).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(3).T.full(1:3,1:3,:));
    Trial.Joint(3).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(3).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    Trial.Joint(3).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Z           
    Trial.Joint(3).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
end

% -------------------------------------------------------------------------
% LEFT HUMEROTHORACIC JOINT
% -------------------------------------------------------------------------
% For left side, selective sign inversions are applied to fulfil ISB sagittal-plane symmetry convention
% (Wu et al. 2005). Affected DOFs depend on the proximal segment coordinate system orientation.

% Homogenous matrix of the rigid transformation between segments
Trial.Joint(6).T.full = Mprod_array3(Tinv_array3(Trial.Segment(4).T.full),...
                                     Trial.Segment(5).T.full);
% JCS and motion for the humerus relative to the thorax (XZY order)     
% (Senk and Cheze 2006, Creveaux et al. 2018, Phadke et al. 2011)

%   DOF1 (pos 3) = Z : flexion/extension    (-= extension, += flexion)    [sign inverted vs R]
%   DOF2 (pos 1) = X : elevation            (-= elevation)
%   DOF3 (pos 2) = Y : axial rotation       (-= internal, += external)    [sign inverted vs R]
if contains(c3dFiles.name,'ANALYTIC1') || contains(c3dFiles.name,'FUNCTIONAL1') || contains(c3dFiles.name,'FUNCTIONAL2') || contains(c3dFiles.name,'FUNCTIONAL4') % Sagittal elevation
    Trial.Joint(6).sequence            = 'ZXY';
    Euler                              = R2mobileZXY_array3(Trial.Joint(6).T.full(1:3,1:3,:));
    Trial.Joint(6).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(6).Euler.full(1,2,:)   = -rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(6).Euler.full(1,3,:)   = -rad2deg(Euler(:,1,:)); % Z             
    Trial.Joint(6).dj.full             = [];                           
    Trial.Joint(6).ElevationPlane.full = -rad2deg(unwrap(atan2(Trial.Joint(6).T.full(1,2,:),Trial.Joint(6).T.full(3,2,:))));
    clear Euler dj x y p x1 y1; 

%   DOF1 (pos 1) = X : elevation            (-= elevation)                
%   DOF2 (pos 3) = Z : flexion/extension    (-= extension, += flexion)    [sign inverted vs R]
%   DOF3 (pos 2) = Y : axial rotation       (-= internal, += external)    [sign inverted vs R]
elseif contains(c3dFiles.name,'ANALYTIC2') || contains(c3dFiles.name,'ANALYTIC5') || contains(c3dFiles.name,'FUNCTIONAL3') || contains(c3dFiles.name,'STATIC') || contains(c3dFiles.name,'ISOMETRIC') % Coronal elevation
    Trial.Joint(6).sequence            = 'XZY';
    Euler                              = R2mobileXZY_array3(Trial.Joint(6).T.full(1:3,1:3,:));
    Trial.Joint(6).Euler.full(1,1,:)   = -rad2deg(Euler(:,1,:)); % X % Sign adaptation to fullfill ISB convention  
    Trial.Joint(6).Euler.full(1,2,:)   = rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(6).Euler.full(1,3,:)   = rad2deg(Euler(:,2,:)); % Z              
    Trial.Joint(6).dj.full             = [];                         
    Trial.Joint(6).ElevationPlane.full = -rad2deg(unwrap(atan2(Trial.Joint(6).T.full(1,2,:),Trial.Joint(6).T.full(3,2,:))));
    clear Euler dj x y p x1 y1; 
elseif contains(c3dFiles.name,'ANALYTIC3') % External rotation
    Trial.Joint(6).sequence            = 'YXZ';
    Euler                              = R2mobileYXZ_array3(Trial.Joint(6).T.full(1:3,1:3,:));
    Trial.Joint(6).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(6).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 100
        Trial.Joint(6).Euler.full(1,2,:) = -unwrap(squeeze(180+rad2deg(Euler(:,1,:)))); % Y % Sign adaptation to fullfill ISB convention 
    else
        Trial.Joint(6).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:)); % Y % Sign adaptation to fullfill ISB convention 
    end
    Trial.Joint(6).Euler.full(1,3,:)   = rad2deg(Euler(:,3,:)); % Z          
    Trial.Joint(6).dj.full             = [];                         
    Trial.Joint(6).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(6).Euler.full(1,2,:))');
elseif contains(c3dFiles.name,'ANALYTIC4') % Internal rotation
    Trial.Joint(6).sequence            = 'YXZ';
    Euler                              = R2mobileYXZ_array3(Trial.Joint(6).T.full(1:3,1:3,:));
    Trial.Joint(6).Euler.full(1,1,:)   = rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(6).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap((rad2deg(Euler(:,1,:))))) > 120
        Trial.Joint(6).Euler.full(1,2,:) = -unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y  
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) > 160
        Trial.Joint(6).Euler.full(1,2,:) = -unwrap(squeeze(-180+rad2deg(Euler(:,1,:))))-180; % Y 
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) < -120
        Trial.Joint(6).Euler.full(1,2,:) = -unwrap(squeeze(180+rad2deg(Euler(:,1,:)))); % Y 
    elseif mean(unwrap((rad2deg(Euler(:,1,:))))) < -160
        Trial.Joint(6).Euler.full(1,2,:) = -unwrap(squeeze(180+rad2deg(Euler(:,1,:))))+180; % Y 
    else
        Trial.Joint(6).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:)); % Y
    end    
    Trial.Joint(6).Euler.full(1,3,:)   = rad2deg(Euler(:,3,:)); % Z              
    Trial.Joint(6).dj.full             = [];                           
    Trial.Joint(6).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1; 
    figure; plot(squeeze(Trial.Joint(6).Euler.full(1,2,:))');
end

% -------------------------------------------------------------------------
% LEFT GLENOHUMERAL JOINT
% -------------------------------------------------------------------------
% Homogenous matrix of the rigid transformation between segments
Trial.Joint(7).T.full = Mprod_array3(Tinv_array3(Trial.Segment(6).T.full),...
                                     Trial.Segment(5).T.full);
% JCS and motion for the humerus relative to the scapula (XZY order)     
% (Senk and Cheze 2006, Creveaux et al. 2018, Phadke et al. 2011)

%   DOF1 (pos 3) = Z : flexion/extension    (-= extension, += flexion)    [sign inverted vs R]
%   DOF2 (pos 1) = X : elevation            (-= elevation)
%   DOF3 (pos 2) = Y : axial rotation       (-= internal, += external)    [sign inverted vs R]
if contains(c3dFiles.name,'ANALYTIC1') || contains(c3dFiles.name,'FUNCTIONAL1') || contains(c3dFiles.name,'FUNCTIONAL2') || contains(c3dFiles.name,'FUNCTIONAL4') % Sagittal elevation
    Trial.Joint(7).sequence          = 'ZXY';
    Euler                            = R2mobileZXY_array3(Trial.Joint(7).T.full(1:3,1:3,:));
    Trial.Joint(7).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(7).Euler.full(1,2,:) = -rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(7).Euler.full(1,3,:) = -rad2deg(Euler(:,1,:)); % Z              
    Trial.Joint(7).dj.full           = [];        
    clear Euler dj x y p x1 y1; 

%   DOF1 (pos 1) = X : elevation            (-= elevation)          
%   DOF2 (pos 3) = Z : flexion/extension    (-= extension, += flexion)    [sign inverted vs R]
%   DOF3 (pos 2) = Y : axial rotation       (-= internal, += external)    [sign inverted vs R]
elseif contains(c3dFiles.name,'ANALYTIC2') || contains(c3dFiles.name,'ANALYTIC5') || contains(c3dFiles.name,'FUNCTIONAL3') || contains(c3dFiles.name,'STATIC') || contains(c3dFiles.name,'ISOMETRIC') % Coronal elevation
    Trial.Joint(7).sequence          = 'XZY';
    Euler                            = R2mobileXZY_array3(Trial.Joint(7).T.full(1:3,1:3,:));
    Trial.Joint(7).Euler.full(1,1,:) = rad2deg(Euler(:,1,:)); % X % Sign adaptation to fullfill ISB convention  
    Trial.Joint(7).Euler.full(1,2,:) = -rad2deg(Euler(:,3,:)); % Y
    Trial.Joint(7).Euler.full(1,3,:) = -rad2deg(Euler(:,2,:)); % Z    
    Trial.Joint(7).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
elseif contains(c3dFiles.name,'ANALYTIC3') % External rotation
    Trial.Joint(7).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(7).T.full(1:3,1:3,:));
    Trial.Joint(7).Euler.full(1,1,:) = -rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(7).Euler.full(1,2,:)   = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 120
        Trial.Joint(7).Euler.full(1,2,:) = -unwrap(squeeze(180+rad2deg(Euler(:,1,:)))); % Y % Sign adaptation to fullfill ISB convention 
    else
        Trial.Joint(7).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:)); % Y % Sign adaptation to fullfill ISB convention 
    end
    Trial.Joint(7).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Z         
    Trial.Joint(7).dj.full           = [];       
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(7).Euler.full(1,2,:))');
elseif contains(c3dFiles.name,'ANALYTIC4') % Internal rotation
    Trial.Joint(7).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(7).T.full(1:3,1:3,:));
    Trial.Joint(7).Euler.full(1,1,:) = -rad2deg(Euler(:,2,:)); % X
%     Trial.Joint(7).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y
    if mean(unwrap(abs(rad2deg(Euler(:,1,:))))) > 120
        Trial.Joint(7).Euler.full(1,2,:) = -unwrap(squeeze(-180+rad2deg(Euler(:,1,:)))); % Y % Sign adaptation to fullfill ISB convention   
    else
        Trial.Joint(7).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:)); % Y % Sign adaptation to fullfill ISB convention 
    end    
    Trial.Joint(7).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Z                  
    Trial.Joint(7).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
%     figure; plot(squeeze(Trial.Joint(7).Euler.full(1,2,:))');
end

% -------------------------------------------------------------------------
% LEFT SCAPULOTHORACIC JOINT
% -------------------------------------------------------------------------
% Homogenous matrix of the rigid transformation between segments
Trial.Joint(8).T.full = Mprod_array3(Tinv_array3(Trial.Segment(4).T.full),...
                                     Trial.Segment(6).T.full);
% JCS and motion for the scapula relative to the thorax (YXZ order) 
% (Wu et al. 2005) 

%   DOF1 (pos 2) = Y : protraction/retraction     (-= protraction)  [sign inverted vs R]
%   DOF2 (pos 1) = X : lateral/medial rotation    (+= medial rotation)
%   DOF3 (pos 3) = Z : anterior/posterior tilt    (-= posterior tilt) [sign inverted vs R]
if contains(c3dFiles.name,'ANALYTIC') || contains(c3dFiles.name,'FUNCTIONAL')
    Trial.Joint(8).sequence          = 'YXZ';
    Euler                            = R2mobileYXZ_array3(Trial.Joint(8).T.full(1:3,1:3,:));
    Trial.Joint(8).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(8).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:))+180; % Y % Rotation adaptation to fullfill ISB convention 
    Trial.Joint(8).Euler.full(1,3,:) = -rad2deg(Euler(:,3,:)); % Z % Sign adaptation to fullfill ISB convention   
    Trial.Joint(8).dj.full           = [];        
    clear Euler dj x y p x1 y1; 
end

% -------------------------------------------------------------------------
% THORAX/PATIENT-ICS JOINT  
% -------------------------------------------------------------------------
% Quantifies thorax posture dynamics relative to the patient-referenced ICS
% expressed as motion relative to the neutral resting posture captured in 
% the first 50 frames of each trial (ZXY order).
% (Wu et al. 2005)

%   DOF1 Z (pos 3) : flexion/extension     (-= flexion, += extension)
%   DOF2 X (pos 1) : lateral tilt          (+= tilt toward right)
%   DOF3 Y (pos 2) : axial rotation        (+= rotation toward right)

% Homogenous matrix of the rigid transformation between segments
    Trial.Joint(11).T.full            = Mprod_array3(Tinv_array3(Trial.Segment(8).T.full), ...
                                                     Trial.Segment(4).T.full);

if contains(c3dFiles.name,'ANALYTIC') || contains(c3dFiles.name,'FUNCTIONAL') || contains(c3dFiles.name,'CALIBRATION3') % Add for unitary test
   Trial.Joint(11).sequence          = 'ZXY';
   Euler                             = R2mobileZXY_array3(Trial.Joint(11).T.full(1:3,1:3,:));
   Trial.Joint(11).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
   Trial.Joint(11).Euler.full(1,2,:) = rad2deg(Euler(:,3,:)); % Y
   Trial.Joint(11).Euler.full(1,3,:) = rad2deg(Euler(:,1,:)); % Z
   Trial.Joint(11).Euler.units       = 'deg';
   Trial.Joint(11).dj.full           = [];
   Trial.Joint(11).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1;
end

% -------------------------------------------------------------------------
% RIGHT HUMERUS / PATIENT-ICS JOINT 
% -------------------------------------------------------------------------
% Quantifies the absolute orientation of the right humerus in the
% patient-referenced gravitational frame (YXY order).
% (Wu et al. 2005)

%   DOF1 X (pos 1) : Elevation              (about X floating axis)
%   DOF2 Y1 (pos 2) : Elevation plane        (about Y proximal axis)
%   DOF3 Y2 (pos 3) : Axial rotation         (about Y distal axis)

% Homogenous matrix of the rigid transformation between segments
Trial.Joint(12).T.full = Mprod_array3(Tinv_array3(Trial.Segment(8).T.full), ...
                                      Trial.Segment(1).T.full);
if contains(c3dFiles.name,'ANALYTIC') || contains(c3dFiles.name,'CALIBRATION3') % Add for unitary test
    Trial.Joint(12).sequence          = 'YXY';
    Euler                             = R2mobileYXY_array3(Trial.Joint(12).T.full(1:3,1:3,:));
    Trial.Joint(12).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(12).Euler.full(1,2,:) = rad2deg(Euler(:,1,:)); % Y1
    Trial.Joint(12).Euler.full(1,3,:) = rad2deg(Euler(:,3,:)); % Y2
    Trial.Joint(12).Euler.units       = 'deg';
    Trial.Joint(12).dj.full           = [];
    Trial.Joint(12).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1;
end

% -------------------------------------------------------------------------
% LEFT HUMERUS / PATIENT-ICS JOINT
% -------------------------------------------------------------------------

%   DOF1 X (pos 1) : Elevation              (about X floating axis)
%   DOF2 Y1 (pos 2) : Elevation plane        (about Y proximal axis) [sign inverted vs R]
%   DOF3 Y2 (pos 3) : Axial rotation         (about Y distal axis)   [sign inverted vs R]

% Homogenous matrix of the rigid transformation between segments
Trial.Joint(13).T.full = Mprod_array3(Tinv_array3(Trial.Segment(8).T.full), ...
                                      Trial.Segment(5).T.full);
if contains(c3dFiles.name,'ANALYTIC') || contains(c3dFiles.name,'CALIBRATION3') % Add for unitary test
    Trial.Joint(13).sequence          = 'YXY';
    Euler                             = R2mobileYXY_array3(Trial.Joint(13).T.full(1:3,1:3,:));
    Trial.Joint(13).Euler.full(1,1,:) = rad2deg(Euler(:,2,:)); % X
    Trial.Joint(13).Euler.full(1,2,:) = -rad2deg(Euler(:,1,:)); % Y1
    Trial.Joint(13).Euler.full(1,3,:) = -rad2deg(Euler(:,3,:)); % Y2
    Trial.Joint(13).Euler.units       = 'deg';
    Trial.Joint(13).dj.full           = [];
    Trial.Joint(13).ElevationPlane.full = [];
    clear Euler dj x y p x1 y1;
end