% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Finds a trial's index in a c3dFiles listing (dir('*.c3d')
%                output) by name, accepting the known calibration/static
%                naming aliases (see CalibrationTrialAliases.m) — e.g. a
%                patient's CALIBRATION1.c3d can be named STATIC1.c3d on
%                older sessions. Falls through to a plain contains() match
%                on taskName itself for anything not in the alias table
%                (ANALYTIC*/FUNCTIONAL*, which have no known alias).
% -------------------------------------------------------------------------
% Inputs  : c3dFiles (struct array) dir('*.c3d') output
%           taskName (char) canonical trial name to look for, e.g. 'CALIBRATION1'
% Outputs : idx (double) index into c3dFiles, or [] if not found
% -------------------------------------------------------------------------
% Dependencies : CalibrationTrialAliases.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function idx = FindTrialFileIndex(c3dFiles, taskName)

names   = {taskName};
aliases = CalibrationTrialAliases();
for ia = 1:numel(aliases)
    if any(strcmpi(aliases{ia}, taskName))
        names = aliases{ia};
        break;
    end
end

idx = [];
for in = 1:numel(names)
    idx = find(contains({c3dFiles.name}, names{in}), 1);
    if ~isempty(idx), return; end
end

end
