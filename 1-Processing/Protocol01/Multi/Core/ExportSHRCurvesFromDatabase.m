% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Export point par point des courbes HT, GH et ST (PRE et
%                POST) pour le calcul des formules de SHR (scapulohumeral
%                rhythm) de la scoping review. Première étape : vérifier
%                que les courbes extraites des .mat sont les bonnes avant
%                d'y appliquer les formules (GH:ST, HT:ST, HT:GH...).
%
%                Courbes = celles de ComputeClinicalContributionsFromDatabase
%                (aucun recalcul ici) : cycle retenu par BestCycle (meilleur
%                des cycles valides), 101 points (0 à 100 % du cycle,
%                montée puis descente du bras), abs() de l'angle, courbes
%                ST inversées corrigées (ApplyInversionCorrectionSTTX). Ce
%                sont donc les courbes dont viennent les amplitudes et pics
%                de Data_posture.xlsx.
%
%                DOF (même convention que Clinical) :
%                  HT Joint(1/6), GH Joint(2/7) : ANALYTIC1 DOF3 Z (flexion,
%                    ZXY), ANALYTIC2 DOF1 X (élévation, XZY)
%                  ST Joint(3/8) : DOF1 X (rotation vers le haut)
%                GH en flexion (ZXY) : élévation en partie dans l'angle du
%                milieu (blocage de cardan proche de 90 deg), à interpréter
%                avec prudence (voir CheckCurvesFromDatabase).
%                GH et ST sont aussi exportés SANS abs (feuilles
%                *_Glenohumerale_signe et *_ST_signe, même cycle ; ST signé =
%                brut non corrigé ST_<C>_raw de Clinical) : abs() replie la
%                courbe quand l'angle traverse zéro ou part du côté opposé au
%                mouvement (GH:ST négatifs ; ST en scaption : 77 / 326
%                sessions passent par zéro) ; TestSHRFormulas les oriente
%                dans le sens du mouvement.
%
%                Patients et côtés : ceux de PostureDataFile (feuille
%                Cinematique pour l'ordre des lignes, Cote_retenu pour le
%                côté), même mise en page que le template (Numero en
%                colonne A, mêmes lignes).
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile    (char) Database_..._Posture_rTSA.mat (parties
%                           _partXofY détectées automatiquement)
%           PostureDataFile (char) Data_posture.xlsx (template : Numero et
%                           côté retenu)
%           OutputFile      (char) Excel de sortie : une feuille par tâche
%                           et articulation (analytic1_Humerothoracique...),
%                           une ligne par patient, colonnes
%                           <tâche>_<articulation>_<Pre|Post>_000 à _100
%                           (% du cycle) ; feuille Cycle_retenu (cycle,
%                           alerte, correction ST)
% Outputs : SHR (struct, un champ par tâche, ex. SHR.ANALYTIC1) : Numero,
%           Side, HT_PRE, HT_POST, GH_PRE, GH_POST, ST_PRE, ST_POST,
%           GHs_PRE, GHs_POST (GH signé), STs_PRE, STs_POST (ST signé)
%           ([patients x 101], NaN si absent) - entrée des formules de SHR
% -------------------------------------------------------------------------
% Dependencies : ComputeClinicalContributionsFromDatabase, BestCycle,
%                ApplyInversionCorrectionSTTX
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function SHR = ExportSHRCurvesFromDatabase(DatabaseFile, PostureDataFile, OutputFile)

tasks      = {'ANALYTIC1', 'ANALYTIC2'};
joints     = {'HT', 'GH', 'ST', 'GHs', 'STs'};
jointNames = {'Humerothoracique', 'Glenohumerale', 'Scapulothoracique', 'Glenohumerale_signe', 'ST_signe'};
curveFld   = {'HT_%s', 'GH_%s', 'ST_%s', 'GH_%s_signed', 'ST_%s_raw'};   % champ de Curves (Clinical)
% (ST_signe et non Scapulothoracique_signe : nom de feuille Excel <= 31 caractères)
conds      = {'PRE', 'POST'};
condNames  = {'Pre', 'Post'};
nPts       = 101;

% Courbes du cycle retenu, sans export ni figure de Clinical
[Res, ~, Cur] = ComputeClinicalContributionsFromDatabase(DatabaseFile, '', '', ...
    struct('Export', false, 'Plot', false));

% Template : lignes (Numero en colonne A, lignes vides comprises) et côté
colA = readcell(PostureDataFile, 'Sheet', 'Cinematique', 'Range', 'A:A');
isNum = cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), colA);
rowNum = NaN(size(colA));
rowNum(isNum) = cell2mat(colA(isNum));
side = readtable(PostureDataFile, 'Sheet', 'Cote_retenu');
numeros = rowNum(isNum);
fprintf('Template : %d patients (%s)\n', numel(numeros), PostureDataFile);

SHR = struct();
for iT = 1:numel(tasks)
    SHR.(tasks{iT}).Numero = numeros;
    SHR.(tasks{iT}).Side   = repmat({''}, numel(numeros), 1);
    for iJ = 1:numel(joints)
        for iC = 1:numel(conds)
            SHR.(tasks{iT}).([joints{iJ}, '_', conds{iC}]) = NaN(numel(numeros), nPts);
        end
    end
end

% Feuille de contrôle : cycle retenu, alerte, correction ST
ctrlHead = {'Numero', 'Side'};
for iT = 1:numel(tasks)
    for iC = 1:numel(conds)
        p = [lower(tasks{iT}), '_'];
        ctrlHead = [ctrlHead, {[p, 'Cycle_', condNames{iC}], [p, 'Alerte_', condNames{iC}], ...
                               [p, 'ST_corrige_', condNames{iC}]}]; %#ok<AGROW>
    end
end
ctrl = cell(numel(numeros), numel(ctrlHead));

nMissing = 0;
for k = 1:numel(numeros)
    n = numeros(k);
    s = side.Side(side.Numero == n);
    if isempty(s), warning('Numero %d absent de Cote_retenu', n); continue; end
    s = s{1};
    ctrl(k, 1:2) = {n, s};
    col = 3;
    for iT = 1:numel(tasks)
        SHR.(tasks{iT}).Side{k} = s;
        ri = find([Res.Numero] == n & strcmp({Res.Side}, s) & strcmp({Res.Task}, tasks{iT}), 1);
        if isempty(ri)
            nMissing = nMissing + 1;
            fprintf('  Absent de la base : n°%d %s %s\n', n, s, tasks{iT});
            col = col + 3 * numel(conds);
            continue;
        end
        for iC = 1:numel(conds)
            c = conds{iC};
            for iJ = 1:numel(joints)
                f  = sprintf(curveFld{iJ}, c);
                fo = [joints{iJ}, '_', c];
                if ri <= numel(Cur) && isfield(Cur, f) && numel(Cur(ri).(f)) == nPts
                    SHR.(tasks{iT}).(fo)(k, :) = Cur(ri).(f)(:)';
                end
            end
            stCorr = NaN;
            if isfield(Res, ['ST_', c, '_corrected']), stCorr = Res(ri).(['ST_', c, '_corrected']); end
            ctrl(k, col:col + 2) = {Res(ri).(['Cycle_', c]), Res(ri).(['CycleAlert_', c]), stCorr};
            col = col + 3;
        end
    end
end
if nMissing > 0, fprintf('%d tâche(s) absente(s) de la base\n', nMissing); end

% -------------------------------------------------------------------------
% EXPORT EXCEL (mêmes lignes que le template)
% -------------------------------------------------------------------------
if isfile(OutputFile), delete(OutputFile); end
ptLabel = arrayfun(@(p) sprintf('%03d', p), 0:nPts - 1, 'UniformOutput', false);
for iT = 1:numel(tasks)
    for iJ = 1:numel(joints)
        head = {'Numero'};
        for iC = 1:numel(conds)
            head = [head, strcat(lower(tasks{iT}), '_', jointNames{iJ}, '_', condNames{iC}, '_', ptLabel)]; %#ok<AGROW>
        end
        C = cell(numel(colA), numel(head));
        C(1, :) = head;
        for r = 2:numel(colA)
            if isnan(rowNum(r)), continue; end
            k = find(numeros == rowNum(r), 1);
            v = [SHR.(tasks{iT}).([joints{iJ}, '_PRE'])(k, :), SHR.(tasks{iT}).([joints{iJ}, '_POST'])(k, :)];
            C(r, 1) = {rowNum(r)};
            C(r, 2:end) = num2cell(v);
            C(r, [false, isnan(v)]) = {[]};   % cellule vide plutôt que NaN
        end
        writecell(C, OutputFile, 'Sheet', [lower(tasks{iT}), '_', jointNames{iJ}]);
    end
end
writecell([ctrlHead; ctrl], OutputFile, 'Sheet', 'Cycle_retenu');
fprintf('Excel exporté : %s\n', OutputFile);

end
