% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Lecture d'une feuille de Data_posture.xlsx (article E02_01
%                posture), quel que soit son format :
%                  - ancien format (data_posture.py, jusqu'au 27.11.2026) :
%                    feuilles Posture, Cinematique, Cinematique_pics,
%                    Cinematique_thorax, leurs versions _Asym, Cote_retenu ;
%                    lues telles quelles ;
%                  - fichier de sortie du registre (Registre_Epaule, carte
%                    « Fichiers de sortie », depuis le 27.11.2026) : une
%                    feuille Analyse, une ligne par épaule (Numéro, ID
%                    dossier, Côté, Dans la cohorte), une colonne par
%                    variable (HT_deg_ANALYTIC1_PRE...) ; les feuilles de
%                    l'ancien format sont reconstruites avec leurs noms de
%                    colonnes (analytic1_ROM_Humerothoracique_Pre...), pour
%                    que les analyses restent inchangées.
%                Correspondance (fichier du registre -> ancien format) :
%                  Posture      Inclination_deg / SIR_deg / Moroder ANALYTIC2
%                               PRE, Inclination_deg CALIBRATION3 PRE
%                  Cinematique  <ART>_deg (HG : Fonctionnel ; HT, GH, ST, TX,
%                               TXlat : Clinique) -> <tâche>_ROM_<joint>_<Pre|Post>
%                  Cinematique_pics  <ART>_max_deg -> <tâche>_MAX_<joint>_...
%                  Cinematique_thorax  TXflex_<S>, TXlat_<S> (source Thorax,
%                               Posture_Summary.xlsx) -> <tâche>_TXflex_<S>_...
%                  _Asym        mêmes variables de l'épaule saine (<ART>_ASYM_deg,
%                               Inclination_deg_ASYM, TXflex_<S>_ASYM), séance
%                               PRE ou POST où elle a des valeurs ; Cote = côté
%                               opposé à l'épaule opérée
%                  Cote_retenu  Numéro et côté de l'épaule opérée (L / R)
%                Lignes : épaules « Dans la cohorte » pour les feuilles de
%                l'épaule opérée ; épaules avec des valeurs de l'épaule saine
%                pour les feuilles _Asym. Une colonne absente du fichier n'est
%                pas créée (erreur de getCol si une analyse la demande).
%                Une colonne présente dans deux sources porte le nom de la
%                source en suffixe (HT_deg_ANALYTIC1_PRE_Clinique) : les deux
%                noms sont acceptés.
% -------------------------------------------------------------------------
% Inputs  : DataFile (char) Data_posture.xlsx, l'un ou l'autre format
%           sheet    (char) feuille de l'ancien format
% Outputs : T (table) en-têtes de l'ancien format, lignes vides retirées
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function T = ReadPostureSheet(DataFile, sheet)

feuilles = sheetnames(DataFile);
if any(strcmp(feuilles, sheet))   % ancien format : feuille telle quelle
    T = readtable(DataFile, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
    num = T.Numero;
    if iscell(num) || isstring(num), num = str2double(string(num)); end
    T = T(~isnan(num), :);
    return;
end
if ~any(strcmp(feuilles, 'Analyse'))
    error('ReadPostureSheet:format', 'Feuille %s absente de %s (ni ancien format, ni feuille Analyse du registre)', sheet, DataFile);
end
A = lireAnalyse(DataFile);

taches = {'analytic1', 'analytic2'};
conds  = {'Pre', 'Post'};
% joint de l'ancien format -> (variable du registre, source si doublon)
ROM = {'Humerogravitaire', 'HG', 'Fonctionnel'; 'Humerothoracique', 'HT', 'Clinique'; 'Glenohumerale', 'GH', 'Clinique'; ...
       'Scapulothoracique', 'ST', 'Clinique'; 'Thoracique', 'TX', 'Clinique'; 'ThoraciqueLateral', 'TXlat', 'Clinique'};
PIC = ROM(1:4, :);
THX = {'TXflex', {'Start', 'AtPeak', 'Change', 'Min', 'Max', 'nCycles'}; 'TXlat', {'Start', 'AtPeak', 'Change', 'Min', 'Max'}};
asymSheet = endsWith(sheet, '_Asym');

if asymSheet
    lig = find(A.asym);
    sess = A.session(lig);
else
    lig = find(A.dans);
end
T = table(A.num(lig), 'VariableNames', {'Numero'});

switch sheet
    case 'Posture'
        T = ajoute(T, A, lig, 'Inclinaison_thoracique_Pre', {'Inclination_deg_ANALYTIC2_PRE'});
        T = ajoute(T, A, lig, 'Rotation_scapulaire_interne_Pre', {'SIR_deg_ANALYTIC2_PRE'});
        T = ajoute(T, A, lig, 'Moroder_type_pre', {'Moroder_ANALYTIC2_PRE'});
        T = ajoute(T, A, lig, 'Inclinaison_thoracique_Pre_Calibration3', {'Inclination_deg_CALIBRATION3_PRE'});
    case 'Posture_Asym'
        cote = A.cote(lig);
        T.Cote = cellfun(@(c) ternaire(strcmp(c, 'G'), 'R', 'L'), cote, 'UniformOutput', false);
        T.Session = sess;
        T = ajouteAsym(T, A, lig, sess, 'Inclinaison_thoracique_Asym', 'Inclination_deg_ASYM_ANALYTIC2');
        T = ajouteAsym(T, A, lig, sess, 'Rotation_scapulaire_interne_Asym', 'SIR_deg_ASYM_ANALYTIC2');
        T = ajouteAsym(T, A, lig, sess, 'Moroder_type_asym', 'Moroder_ASYM_ANALYTIC2');
        T = ajouteAsym(T, A, lig, sess, 'Inclinaison_thoracique_Asym_Calibration3', 'Inclination_deg_ASYM_CALIBRATION3');
    case {'Cinematique', 'Cinematique_pics'}
        J = ternaire(strcmp(sheet, 'Cinematique'), ROM, PIC); m = ternaire(strcmp(sheet, 'Cinematique'), {'ROM', 'deg'}, {'MAX', 'max_deg'});
        [jj, cc, tt] = ndgrid(1:size(J, 1), 1:2, 1:2);   % ordre : tâche, examen, joint
        for q = 1:numel(jj)
            t = tt(q); c = cc(q); j = jj(q);
            reg = sprintf('%s_%s_%s_%s', J{j, 2}, m{2}, upper(taches{t}), upper(conds{c}));
            T = ajoute(T, A, lig, sprintf('%s_%s_%s_%s', taches{t}, m{1}, J{j, 1}, conds{c}), {reg, [reg, '_', J{j, 3}]});
        end
    case {'Cinematique_Asym', 'Cinematique_pics_Asym'}
        J = ternaire(strcmp(sheet, 'Cinematique_Asym'), ROM, PIC); m = ternaire(strcmp(sheet, 'Cinematique_Asym'), {'ROM', 'deg'}, {'MAX', 'max_deg'});
        [jj, tt] = ndgrid(1:size(J, 1), 1:2);
        for q = 1:numel(jj)
            t = tt(q); j = jj(q);
            T = ajouteAsym(T, A, lig, sess, sprintf('%s_%s_%s_Asym', taches{t}, m{1}, J{j, 1}), ...
                sprintf('%s_ASYM_%s_%s', J{j, 2}, m{2}, upper(taches{t})), [J{j, 3}, 'Asym']);
        end
    case 'Cinematique_thorax'
        for q = combinaisons(THX, 2)'
            t = q(1); c = q(2); k = q(3); s = q(4);
            T = ajoute(T, A, lig, sprintf('%s_%s_%s_%s', taches{t}, THX{k, 1}, THX{k, 2}{s}, conds{c}), ...
                {sprintf('%s_%s_%s_%s', THX{k, 1}, THX{k, 2}{s}, upper(taches{t}), upper(conds{c}))});
        end
    case 'Cinematique_thorax_Asym'
        for q = combinaisons(THX, 1)'
            t = q(1); k = q(3); s = q(4);
            T = ajouteAsym(T, A, lig, sess, sprintf('%s_%s_%s_Asym', taches{t}, THX{k, 1}, THX{k, 2}{s}), ...
                sprintf('%s_%s_ASYM_%s', THX{k, 1}, THX{k, 2}{s}, upper(taches{t})));
        end
    case 'Cote_retenu'
        T.Side = cellfun(@(c) ternaire(strcmp(c, 'G'), 'L', 'R'), A.cote(lig), 'UniformOutput', false);
    otherwise
        error('ReadPostureSheet:feuille', 'Feuille inconnue : %s', sheet);
end
end

% ---- Combinaisons [tâche, examen, signal, statistique] des colonnes du thorax
% (nExamens = 2 : pré et post ; 1 : épaule saine, une seule séance)
function Q = combinaisons(THX, nExamens)
Q = zeros(0, 4);
for t = 1:2
    for c = 1:nExamens
        for k = 1:size(THX, 1)
            for s = 1:numel(THX{k, 2})
                Q(end + 1, :) = [t, c, k, s]; %#ok<AGROW>
            end
        end
    end
end
end

% ---- Feuille Analyse du registre, gardée en mémoire tant que le fichier ne change pas
function A = lireAnalyse(DataFile)
persistent fichier date cache
d = dir(DataFile);
if ~isempty(fichier) && strcmp(fichier, DataFile) && date == d.datenum
    A = cache; return;
end
C = readcell(DataFile, 'Sheet', 'Analyse');
h = find(cellfun(@(x) (ischar(x) || isstring(x)) && any(strcmp(char(x), {'Numéro', 'Numero'})), C(:, 1)), 1);
if isempty(h), error('ReadPostureSheet:entete', 'Ligne d''en-tête (Numéro) introuvable dans %s', DataFile); end
noms = cellfun(@(x) ternaire(ischar(x) || isstring(x), char(x), ''), C(h, :), 'UniformOutput', false);
V = C(h + 1:end, :);
A.noms = noms; A.V = V;
A.num = cellfun(@nombre, V(:, 1));
garde = ~isnan(A.num);
A.V = V(garde, :); A.num = A.num(garde);
A.cote = cellfun(@(x) ternaire(ischar(x) || isstring(x), char(x), ''), A.V(:, colonne(A, 'Côté')), 'UniformOutput', false);
jd = find(strcmp(noms, 'Dans la cohorte'), 1);
if isempty(jd), A.dans = true(size(A.num)); else, A.dans = cellfun(@nombre, A.V(:, jd)) == 1; end
% Épaule saine : colonnes _ASYM_ ; séance = PRE ou POST où elle a des valeurs
ja = find(contains(noms, '_ASYM_'));
pre = false(size(A.num)); post = pre;
for j = ja
    plein = ~cellfun(@vide, A.V(:, j));
    if endsWith(noms{j}, '_PRE') || contains(noms{j}, '_PRE_'), pre = pre | plein; end
    if endsWith(noms{j}, '_POST') || contains(noms{j}, '_POST_'), post = post | plein; end
end
A.asym = pre | post;
A.session = repmat({''}, size(A.num));
A.session(post) = {'POST'}; A.session(pre) = {'PRE'};
fichier = DataFile; date = d.datenum; cache = A;
end

% ---- Ajout d'une colonne de l'épaule opérée (premier nom trouvé parmi les candidats)
function T = ajoute(T, A, lig, ancien, candidats)
j = 0;
for k = 1:numel(candidats)
    j = find(strcmp(A.noms, candidats{k}), 1);
    if ~isempty(j), break; end
end
if isempty(j) || j == 0, return; end
T.(ancien) = valeurs(A.V(lig, j));
end

% ---- Ajout d'une colonne de l'épaule saine : base + _<séance de la ligne> (et suffixe de source si doublon)
function T = ajouteAsym(T, A, lig, sess, ancien, base, source)
if nargin < 7, source = ''; end
out = cell(numel(lig), 1); trouve = false;
for i = 1:numel(lig)
    cand = {[base, '_', sess{i}]};
    if ~isempty(source), cand{end + 1} = [base, '_', sess{i}, '_', source]; end %#ok<AGROW>
    j = [];
    for k = 1:numel(cand)
        j = find(strcmp(A.noms, cand{k}), 1);
        if ~isempty(j), break; end
    end
    if isempty(j), out{i} = NaN; continue; end
    trouve = true; out{i} = A.V{lig(i), j};
end
if ~trouve, return; end
T.(ancien) = valeurs(out);
end

% Colonne numérique si toutes les cellules sont des nombres ou vides, sinon texte (Moroder)
function v = valeurs(c)
if all(cellfun(@(x) (isnumeric(x) && isscalar(x)) || vide(x), c))
    v = cellfun(@nombre, c);
else
    v = cellfun(@(x) ternaire(vide(x), '', char(string(x))), c, 'UniformOutput', false);
end
end

function j = colonne(A, nom)
j = find(strcmp(A.noms, nom), 1);
if isempty(j), error('ReadPostureSheet:colonne', 'Colonne %s absente', nom); end
end

function x = nombre(v)
if isnumeric(v) && isscalar(v), x = double(v); else, x = NaN; end
end

function tf = vide(x)
tf = (isnumeric(x) && (isempty(x) || all(isnan(x)))) || isa(x, 'missing') || ((ischar(x) || isstring(x)) && strlength(string(x)) == 0);
end

function r = ternaire(c, a, b)
if c, r = a; else, r = b; end
end
