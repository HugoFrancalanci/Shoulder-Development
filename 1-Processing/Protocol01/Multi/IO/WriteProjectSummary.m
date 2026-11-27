% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Stockage par projet : écrit <ProjectFolder>\projet.json, le
%                résumé qui permet de comprendre plus tard comment les .mat
%                du projet ont été calculés : date, machine, commit du code
%                (et code modifié non commité), version de MATLAB,
%                réglages du centre de rotation gléno-huméral (lus dans
%                userCommands.txt : méthode, essais de calibration, vue),
%                épaules passées en repli sur Rab (cluster absent), liste des
%                épaules traitées et erreurs du run.
% -------------------------------------------------------------------------
% Inputs  : ProjectFolder (char) dossier du projet
%           Info          (struct) Projet, Toolbox (dossier Protocol01),
%                         DataFolder, Epaules (struct array Numero, ID,
%                         Cote, Pre, Post, Dossier), ReplisRab (struct array
%                         Numero, ID, Cote, Examen, ScapulaAbsente,
%                         HumerusAbsent : calibration SCoRE manquante),
%                         Erreurs (cellstr), DureeMinutes
% Outputs : Resume (struct) contenu écrit dans projet.json
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Resume = WriteProjectSummary(ProjectFolder, Info)

% Réglages du centre de rotation, tels que runProtocol01 les lit
Processing = struct(); %#ok<NASGU>
try
    eval(fileread(fullfile(Info.Toolbox, 'userCommands.txt')));
catch ME
    warning('WriteProjectSummary : userCommands.txt illisible (%s)', ME.message);
end
gjc = struct('methode', '', 'essais_calibration', '', 'vue', '');
if exist('Processing', 'var') && isfield(Processing, 'GJC')
    if isfield(Processing.GJC, 'method'),      gjc.methode = Processing.GJC.method; end
    if isfield(Processing.GJC, 'calibTrials'), gjc.essais_calibration = Processing.GJC.calibTrials; end
    if isfield(Processing.GJC, 'view'),        gjc.vue = Processing.GJC.view; end
end

% Replis sur Rab : cluster utilisé par la vue du run absent (vue humérus :
% rCsj ; vue scapula : rCsi), comme dans Core/DefineSegments.m
replis = {};
if strcmpi(gjc.methode, 'SCoRE')
    for r = Info.ReplisRab(:)'
        if (strcmpi(gjc.vue, 'scapula') && r.ScapulaAbsente) || (~strcmpi(gjc.vue, 'scapula') && r.HumerusAbsent)
            replis{end+1} = sprintf('n°%d %s %s %s', r.Numero, r.ID, r.Cote, r.Examen); %#ok<AGROW>
        end
    end
end

% Commit du code (dépôt Shoulder_Dev)
commit = '';
[st, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', Info.Toolbox));
if st == 0, commit = strtrim(out); end
[st, out] = system(sprintf('git -C "%s" status --porcelain', Info.Toolbox));
modifie = st == 0 && ~isempty(strtrim(out));

Resume = struct( ...
    'projet', Info.Projet, ...
    'date', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')), ...
    'machine', getenv('COMPUTERNAME'), ...
    'commit_code', commit, ...
    'code_modifie_non_commite', modifie, ...
    'matlab', ['R', version('-release'), ' (', version, ')'], ...
    'dossier_donnees', Info.DataFolder, ...
    'centre_rotation', gjc, ...
    'nb_epaules', numel(Info.Epaules), ...
    'replis_rab', {replis}, ...
    'erreurs', {Info.Erreurs(:)'}, ...
    'duree_minutes', round(Info.DureeMinutes, 1), ...
    'epaules', Info.Epaules);

fid = fopen(fullfile(ProjectFolder, 'projet.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(Resume, 'PrettyPrint', true));
fclose(fid);
fprintf('Résumé du projet écrit : %s\n', fullfile(ProjectFolder, 'projet.json'));

end
