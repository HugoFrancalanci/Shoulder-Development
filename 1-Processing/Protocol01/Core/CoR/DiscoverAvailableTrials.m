% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Lists which ANALYTIC/FUNCTIONAL trials actually exist for
%                a patient — used to build the SCoRE calibration taskList
%                when Processing.GJC.calibTrials = 'all' (Core/CoR/ComputeSCoRE.m),
%                instead of the default 4-trial combo. Same discovery
%                pattern as Tests/CoR/ExploreSCoRECombos.m.
% -------------------------------------------------------------------------
% Inputs  : folderData (char) patient folder containing 'Processed\*.c3d'
% Outputs : taskList (cell) trial name substrings found on disk, e.g.
%                     {'ANALYTIC1','ANALYTIC2','FUNCTIONAL1',...}
% -------------------------------------------------------------------------

function taskList = DiscoverAvailableTrials(folderData)

oldDir  = cd(fullfile(folderData, 'Processed'));
cleanUp = onCleanup(@() cd(oldDir)); %#ok<NASGU>
c3dFiles = dir('*.c3d');

candidatePool = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4', 'ANALYTIC5', ...
                  'FUNCTIONAL1', 'FUNCTIONAL2', 'FUNCTIONAL3', 'FUNCTIONAL4'};

taskList = {};
for i = 1:numel(candidatePool)
    if any(contains({c3dFiles.name}, candidatePool{i}))
        taskList{end+1} = candidatePool{i}; %#ok<AGROW>
    end
end

end
