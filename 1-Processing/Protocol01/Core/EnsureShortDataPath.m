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
% Description:   Ensures a short root path for DataFolder, via a virtual
%                drive (subst), to avoid btkReadAcquisition "File doesn't
%                exist" failures when a .c3d's full path exceeds the
%                Windows MAX_PATH limit (260 characters) - common with
%                nested OneDrive paths (accented characters + several
%                subfolders).
%
%                Since the subst mapping is NOT persistent across a
%                reboot, this function redoes it on every call (unmap then
%                remap, unconditionally) rather than trying to detect
%                whether it already exists - simpler and more robust than
%                comparing accented paths returned by subst. Negligible
%                cost (near-instant), so no issue redoing it on every
%                script run.
%
%                Does not require admin rights (subst is a standard user
%                mapping, not a system setting).
% -------------------------------------------------------------------------
% Inputs  : longPath   (char) actual (potentially long) path
%           shortDrive (char, optional) drive letter to use, default 'S:'
% Outputs : dataFolder (char) '<shortDrive>\' if the mapping succeeded,
%                       otherwise longPath (silent fallback - the script
%                       continues with the original path)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function dataFolder = EnsureShortDataPath(longPath, shortDrive)

if nargin < 2 || isempty(shortDrive), shortDrive = 'S:'; end

dataFolder = longPath;

if ~ispc
    return; % subst: Windows only
end

system(sprintf('subst %s /d', shortDrive)); % ignored if nothing was mapped

[mkStatus, mkOut] = system(sprintf('subst %s "%s"', shortDrive, longPath));
if mkStatus == 0
    dataFolder = [shortDrive, '\'];
    disp(['Path shortened via subst: ', shortDrive, ' -> ', longPath]);
else
    warning('EnsureShortDataPath:substFailed', ...
        'Could not map %s to %s (%s). Original DataFolder kept - risk of failures on paths > 260 characters.', ...
        shortDrive, longPath, strtrim(mkOut));
end

disp(' ');

end
