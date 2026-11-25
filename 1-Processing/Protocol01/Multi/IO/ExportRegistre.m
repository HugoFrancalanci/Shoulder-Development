% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Export des résultats du pipeline multi-patients vers le
%                registre local (Registre_Epaule), dans un format unique et
%                stable, indépendant de la mise en page des Excel :
%                  - resultats.csv : une ligne par valeur (format long) :
%                    source, numero, patient_id, cote, tache, moment,
%                    variable, valeur. Le moment (pre / post) est lu dans le
%                    champ Condition s'il existe, sinon dans le nom du champ
%                    (HT_PRE_deg -> moment pre, variable HT_deg). Le champ
%                    Metric, s'il existe, préfixe la variable (HT_Verdict).
%                  - courbes.csv : une ligne par courbe de 101 points
%                    (source, numero, patient_id, cote, tache, moment,
%                    articulation, p0..p100), lue dans les champs
%                    <ARTICULATION>_<PRE|POST>, ou <ARTICULATION>_ASYM
%                    pour les épaules asymptomatiques (moment lu dans le
%                    champ Condition). Données brutes (source « Brut »,
%                    ComputeRawCurvesFromDatabase) : articulation et axe
%                    dans le nom, HTX_PRE -> articulation HTX.
%                  Les sources « ...Asym » et « Eligibilite » concernent
%                  l'épaule controlatérale : le registre les rattache à
%                  l'épaule opérée par numéro et ID patient.
%                  - run.json : date, machine, commit Git du code, taille
%                    de la cohorte, sources exportées.
%                Puis prévient le site (POST <URL>/api/matlab/run). Si le
%                site ne répond pas (fermé, autre machine), le pipeline
%                continue : le site relira le dossier à sa mise à jour.
% -------------------------------------------------------------------------
% Inputs  : Dossier  (char) dossier de sortie, créé si besoin
%                    (ResultsFolder/Registre dans userCommands_Multi.m)
%           Tables   (struct) un champ par source, chacun un struct array
%                    avec Numero, PatientID, Side et éventuellement Task,
%                    Condition, Metric (ex. sorties de
%                    ComputeClinicalContributionsFromDatabase)
%           Courbes  (struct) un champ par source, chacun un struct array
%                    Numero/PatientID/Side/Task + champs <ART>_<PRE|POST> de
%                    101 points (ex. 3e sortie de
%                    ComputeClinicalContributionsFromDatabase)
%           Infos    (struct, optionnel) URL (adresse du site, '' = pas de
%                    notification), NbEpaules, CodeFolder (dossier Git)
% Outputs : Run (struct) contenu de run.json
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Run = ExportRegistre(Dossier, Tables, Courbes, Infos)

if nargin < 3 || isempty(Courbes), Courbes = struct(); end
if nargin < 4, Infos = struct(); end
if ~isfield(Infos, 'URL'), Infos.URL = ''; end
if ~isfield(Infos, 'NbEpaules'), Infos.NbEpaules = NaN; end
if ~isfield(Infos, 'CodeFolder'), Infos.CodeFolder = fileparts(mfilename('fullpath')); end
if ~isfolder(Dossier), mkdir(Dossier); end

% -------------------------------------------------------------------------
% resultats.csv
% -------------------------------------------------------------------------
fid = fopen(fullfile(Dossier, 'resultats.csv'), 'w', 'n', 'UTF-8');
fprintf(fid, 'source,numero,patient_id,cote,tache,moment,variable,valeur\n');
nValeurs = 0;
sources = fieldnames(Tables);
for is = 1:numel(sources)
    S = Tables.(sources{is});
    if isempty(S) || ~isstruct(S), continue; end
    champs = fieldnames(S);
    for k = 1:numel(S)
        [num, pid, cote, tache] = cle(S(k));
        momentFixe = '';
        if isfield(S, 'Condition'), momentFixe = lower(texte(S(k).Condition)); end
        prefixe = '';
        if isfield(S, 'Metric') && ~isempty(S(k).Metric), prefixe = [texte(S(k).Metric), '_']; end
        for ic = 1:numel(champs)
            ch = champs{ic};
            if any(strcmp(ch, {'Numero', 'PatientID', 'Side', 'Task', 'Condition', 'Metric'})), continue; end
            v = S(k).(ch);
            if ~(ischar(v) || isstring(v) || (isnumeric(v) && isscalar(v)) || (islogical(v) && isscalar(v))), continue; end
            val = valeur(v);
            if isempty(val), continue; end % NaN ou texte vide : rien à transmettre
            [moment, variable] = momentVariable(ch);
            if ~isempty(momentFixe), moment = momentFixe; end
            fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s\n', sources{is}, num, csv(pid), cote, csv(tache), moment, ...
                csv([prefixe, variable]), csv(val));
            nValeurs = nValeurs + 1;
        end
    end
end
fclose(fid);

% -------------------------------------------------------------------------
% courbes.csv
% -------------------------------------------------------------------------
fid = fopen(fullfile(Dossier, 'courbes.csv'), 'w', 'n', 'UTF-8');
fprintf(fid, 'source,numero,patient_id,cote,tache,moment,articulation%s\n', sprintf(',p%d', 0:100));
nCourbes = 0;
sources = fieldnames(Courbes);
for is = 1:numel(sources)
    C = Courbes.(sources{is});
    if isempty(C) || ~isstruct(C), continue; end
    champs = fieldnames(C);
    for k = 1:numel(C)
        [num, pid, cote, tache] = cle(C(k));
        for ic = 1:numel(champs)
            tok = regexp(champs{ic}, '^([A-Za-z]+)_(PRE|POST|ASYM)$', 'tokens', 'once');
            if isempty(tok), continue; end
            y = C(k).(champs{ic});
            if ~isnumeric(y) || numel(y) ~= 101 || all(isnan(y(:))), continue; end
            moment = lower(tok{2});
            if strcmp(tok{2}, 'ASYM') && isfield(C, 'Condition'), moment = lower(texte(C(k).Condition)); end
            fprintf(fid, '%s,%s,%s,%s,%s,%s,%s%s\n', sources{is}, num, csv(pid), cote, csv(tache), moment, ...
                tok{1}, sprintf(',%.4f', y(:)'));
            nCourbes = nCourbes + 1;
        end
    end
end
fclose(fid);

% -------------------------------------------------------------------------
% run.json
% -------------------------------------------------------------------------
commit = '';
try
    [st, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', Infos.CodeFolder));
    if st == 0, commit = strtrim(out); end
catch
end
Run = struct('date', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')), ...
    'machine', getenv('COMPUTERNAME'), 'commit', commit, 'nb_epaules', Infos.NbEpaules, ...
    'sources_resultats', {fieldnames(Tables)'}, 'sources_courbes', {fieldnames(Courbes)'}, ...
    'nb_valeurs', nValeurs, 'nb_courbes', nCourbes, 'dossier', Dossier);
fid = fopen(fullfile(Dossier, 'run.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(Run, 'PrettyPrint', true));
fclose(fid);
fprintf('Registre : %d valeurs, %d courbes écrites dans %s\n', nValeurs, nCourbes, Dossier);

% -------------------------------------------------------------------------
% Notification du site (sans effet si le site ne répond pas)
% -------------------------------------------------------------------------
if ~isempty(Infos.URL)
    try
        webwrite([Infos.URL, '/api/matlab/run'], Run, weboptions('MediaType', 'application/json', 'Timeout', 3));
        fprintf('Registre : site prévenu (%s), mise à jour lancée\n', Infos.URL);
    catch
        fprintf('Registre : site injoignable (%s), il relira le dossier à sa prochaine mise à jour\n', Infos.URL);
    end
end
end

% =========================================================================
function [num, pid, cote, tache] = cle(s)
num = ''; pid = ''; cote = ''; tache = '';
if isfield(s, 'Numero') && ~isempty(s.Numero), num = sprintf('%d', s.Numero); end
if isfield(s, 'PatientID'), pid = texte(s.PatientID); end
if isfield(s, 'Side'), cote = texte(s.Side); end
if isfield(s, 'Task'), tache = texte(s.Task); end
end

function [moment, variable] = momentVariable(ch)
% HT_PRE_deg -> ('pre', 'HT_deg') ; Flag_POST -> ('post', 'Flag') ; Nombre -> ('', 'Nombre')
moment = ''; variable = ch;
p = strsplit(ch, '_');
i = find(strcmp(p, 'PRE') | strcmp(p, 'POST'), 1);
if ~isempty(i)
    moment = lower(p{i});
    p(i) = [];
    variable = strjoin(p, '_');
end
end

function t = texte(v)
if isstring(v), v = char(v); end
if isnumeric(v), v = num2str(v); end
t = char(v);
end

function t = valeur(v)
if ischar(v) || isstring(v)
    t = char(v);
elseif islogical(v)
    t = sprintf('%d', v);
elseif isnan(v)
    t = '';
else
    t = sprintf('%.6g', v);
end
end

function t = csv(s)
% Champ CSV : entre guillemets s'il contient une virgule, un guillemet ou un retour
t = char(s);
if any(t == ',' | t == '"' | t == newline | t == sprintf('\r'))
    t = ['"', strrep(t, '"', '""'), '"'];
end
end
