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
% Description:   Standalone diagnostic (read-only, no modifications): for
%                each of the 182 rows of PatientSelection (userCommands_
%                Multi.m) - one row per number (see the "% N" comment on
%                each PatientSelection line) - counts the subfolders
%                directly inside the patient's root folder (e.g. session
%                date folders 20220523, 20221213, ...), excluding any
%                folder named 'CT'. Expected count is 2 (one PRE session
%                folder + one POST session folder); if it exceeds 2, the
%                actual folder names are printed so the extra ones can be
%                identified (e.g. more sessions than configured in
%                PatientSelection, or other unexpected folders).
%
%                NOT deduplicated: bilateral patients (same ID
%                Cinésiologie on 2 rows of PatientSelection, different
%                côté/dates) share the same physical patient folder and
%                are checked twice, once per row - kept this way on
%                purpose so the "No" column here lines up with the "% N"
%                row comments in PatientSelection.
% -------------------------------------------------------------------------
% Inputs  : None (reads DataFolder/PatientSelection from
%           Multi/userCommands_Multi.m directly)
% Outputs : Console table (No, PatientID, folder name, subfolder count),
%           with the subfolder names printed below any row whose count
%           exceeds 2
% -------------------------------------------------------------------------
% Dependencies : EnsureShortDataPath.m, userCommands_Multi.m
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function CheckPatientFolderCounts()

Folder.toolbox = fileparts(fileparts(fileparts(mfilename('fullpath')))); % .../Protocol01
addpath(Folder.toolbox);
addpath(fullfile(Folder.toolbox, 'Core'));
addpath(fullfile(Folder.toolbox, 'Multi'));

run(fullfile(Folder.toolbox, 'Multi', 'userCommands_Multi.m')); % DataFolder, PatientSelection

DataFolder = EnsureShortDataPath(DataFolder);

dataDirList = dir(DataFolder);
dataDirList = dataDirList([dataDirList.isdir] & ~startsWith({dataDirList.name}, '.'));

EXPECTED_COUNT = 2;
nRows = size(PatientSelection, 1); % 182 - matches the "% N" comments in PatientSelection

fprintf('%4s %-12s %-40s %6s\n', 'No', 'PatientID', 'Dossier', 'Nb');
fprintf('%s\n', repmat('-', 1, 70));

for i = 1:nRows
    patientID = num2str(PatientSelection{i, 1});
    matchIdx  = find(contains({dataDirList.name}, patientID));
    if isempty(matchIdx)
        fprintf('%4d %-12s %-40s %6s\n', i, patientID, '(dossier introuvable)', '-');
        continue;
    end
    patientName   = dataDirList(matchIdx(1)).name;
    patientFolder = fullfile(DataFolder, patientName);

    sub = dir(patientFolder);
    sub = sub([sub.isdir] & ~startsWith({sub.name}, '.'));
    subNames = {sub.name};
    subNames = subNames(~strcmpi(subNames, 'CT')); % exclude CT folder

    n = length(subNames);
    fprintf('%4d %-12s %-40s %6d\n', i, patientID, patientName, n);

    if n > EXPECTED_COUNT
        for j = 1:length(subNames)
            fprintf('    -> %s\n', subNames{j});
        end
    end
end

if ispc, system('subst S: /d'); end

end
