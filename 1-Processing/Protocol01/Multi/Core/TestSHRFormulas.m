% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Formules de SHR (scapulohumeral rhythm) de la scoping review
%                appliquées aux courbes HT, GH et ST exportées par
%                ExportSHRCurvesFromDatabase (SHR_Curves.xlsx, validé).
%                Première version : une formule par famille (A, B, C), pour
%                vérifier que tout est cohérent avant d'ajouter les variantes
%                (GH par soustraction, angle fixe, incréments, régression...).
%
%                Phase analysée : montée du bras, du repos au pic HT
%                individuel (le cycle exporté contient la montée puis la
%                descente). Mêmes conventions que BestCycle :
%                  repos = moyenne des NStart (3) premiers points ;
%                  pic   = moyenne de Win (10) points autour du maximum de HT
%                          (BestCycle.window), pris aux MÊMES points pour HT,
%                          GH et ST (le pic HT est donc celui de Data_posture).
%                GH mesuré directement (Joint 2/7), pas par soustraction,
%                SIGNÉ ET ORIENTÉ (feuilles *_Glenohumerale_signe) : abs()
%                repliait GH quand l'angle de repos est du côté de zéro
%                opposé au mouvement (16 des 18 GH:ST négatifs en scaption,
%                novembre 2026). Sens = sens majoritaire de la variation
%                repos -> pic du GH signé sur la cohorte, par tâche et par
%                côté (fixé par groupe, pas par patient : un vrai mouvement
%                inverse reste négatif).
%                ST aussi SIGNÉ ET ORIENTÉ (feuilles *_ST_signe, brut non
%                corrigé) : en scaption, ST signé diminue chez tous les
%                patients mais part légèrement positif au repos et traverse
%                zéro dans 77 / 326 sessions ; abs() réduisait alors ΔST
%                (B négatifs à 60 deg, B > 90 au pic). Même règle de sens
%                que GH. HT reste en abs, comme Data_posture (colonnes
%                GHabs_* et STabs_* gardées pour contrôle).
%                Sessions exclues si HT monte de moins de MinElevation
%                (15 deg) entre le repos et le pic : ratio de bruit.
%
%                Familles :
%                  A  GH:ST          = (GH_pic - GH_repos) / (ST_pic - ST_repos)
%                  B  TH:ST          = (HT_pic - HT_repos) / (ST_pic - ST_repos)
%                  C  TH:GH au pic   =  HT_pic / GH_pic (angles au pic, pas
%                                       des variations ; GH orienté)
%                Format : un ratio global par patient (whole arc). Ratio
%                vide si le dénominateur est inférieur à MinDelta (1 deg)
%                en valeur absolue.
%
%                Plages d'élévation (Opts.Ranges, [début fin] en HT ; début
%                NaN = repos, fin NaN = maximum individuel), A et B :
%                  rest–individual max (_rest_max), rest–90° (_rest_90),
%                  rest–120° (_rest_120), 20–90° (_20_90), 20–120° (_20_120).
%                  À un angle, GH et ST sont pris quand HT franchit l'angle
%                  sur la montée (interpolation linéaire) et HT = l'angle ;
%                  vide si HT part au-dessus de l'angle de début ou
%                  n'atteint pas l'angle de fin (limite des épaules raides,
%                  surtout PRE). C reste au pic (« at peak » par définition).
%                  « Varied » (figure de la review) n'est pas une règle à
%                  part : non testé.
% -------------------------------------------------------------------------
% Inputs  : DataFolder (char) dossier contenant SHR_Curves.xlsx ; la sortie
%           SHR_Formulas.xlsx y est écrite
%           Opts (struct, optionnel) : InputFile ('SHR_Curves.xlsx'),
%           OutputFile ('SHR_Formulas.xlsx'), MinDelta (1 deg), Plot (true :
%           figure A, B, C exportée en PNG et PDF à côté de l'Excel), Tasks
%           ({'analytic2'} : scaption seule, choix de l'abstract ;
%           {'analytic1', 'analytic2'} pour ajouter la flexion), MinElevation
%           (15 deg), Ranges ([NaN NaN; NaN 90; NaN 120; 20 90; 20 120;
%           30 90]), FigureFolder (dossier des figures ; DataFolder par
%           défaut, Abstract 3/Figures depuis MAIN)
% Outputs : SHR (table) une ligne par patient, tâche et condition : repos et
%           pic de HT, GH (signé orienté), ST, GH en abs (contrôle), sens
%           GH, exclusion, ratios A, B, C
%           Excel : feuille SHR (mêmes lignes que le template, colonnes
%           <tâche>_<famille>_<Pre|Post>), feuille Composantes (repos, pic),
%           feuille Resume (n, exclues, médiane, Q1, Q3, moyenne,
%           écart-type, négatifs)
% -------------------------------------------------------------------------
% Dependencies : BestCycle
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function SHR = TestSHRFormulas(DataFolder, Opts)

if nargin < 2, Opts = struct(); end
if ~isfield(Opts, 'InputFile')  || isempty(Opts.InputFile),  Opts.InputFile  = 'SHR_Curves.xlsx';   end
if ~isfield(Opts, 'OutputFile') || isempty(Opts.OutputFile), Opts.OutputFile = 'SHR_Formulas.xlsx'; end
if ~isfield(Opts, 'MinDelta')   || isempty(Opts.MinDelta),   Opts.MinDelta   = 1;                   end
if ~isfield(Opts, 'Plot')       || isempty(Opts.Plot),       Opts.Plot       = true;                end
if ~isfield(Opts, 'Tasks')      || isempty(Opts.Tasks),      Opts.Tasks      = {'analytic2'};       end
if ~isfield(Opts, 'MinElevation') || isempty(Opts.MinElevation), Opts.MinElevation = 15;            end
if ~isfield(Opts, 'FigureFolder') || isempty(Opts.FigureFolder), Opts.FigureFolder = DataFolder;    end
% Plages d'élévation [début fin] en HT : début NaN = repos, fin NaN =
% maximum individuel
if ~isfield(Opts, 'Ranges') || isempty(Opts.Ranges)
    Opts.Ranges = [NaN NaN; NaN 90; NaN 120; 20 90; 20 120; 30 90];   % 30–90 = fixed window
end
% Intervalles d'analyse sur la montée complète (rest–individual max)
if ~isfield(Opts, 'IncEdges')  || isempty(Opts.IncEdges),  Opts.IncEdges  = 20:10:170;           end
if ~isfield(Opts, 'Brackets')  || isempty(Opts.Brackets),  Opts.Brackets  = [30 60 90 120 150];  end
if ~isfield(Opts, 'Grid')      || isempty(Opts.Grid),      Opts.Grid      = 30:10:170;           end
if ~isfield(Opts, 'ContDegree')   || isempty(Opts.ContDegree),   Opts.ContDegree   = 3;          end
if ~isfield(Opts, 'ContMinSlope') || isempty(Opts.ContMinSlope), Opts.ContMinSlope = 0.1;        end
[rngSfx, rngLbl] = rangeNames(Opts.Ranges);
% Colonnes A / B : plages, puis intervalles à une valeur par patient
allSfx = [rngSfx, {'_reg', '_incmean'}];
allLbl = [rngLbl, {'regression slope', 'increments 10° (mean)'}];
angles = unique(Opts.Ranges(~isnan(Opts.Ranges)))';   % angles HT où lire GH et ST

inFile  = fullfile(DataFolder, Opts.InputFile);
outFile = fullfile(DataFolder, Opts.OutputFile);

allTasks  = {'analytic1', 'analytic2'};
allLabels = {'Flexion', 'Scaption'};
[ok, iTk] = ismember(Opts.Tasks, allTasks);
if ~all(ok), error('TestSHRFormulas:tasks', 'Tâches attendues : analytic1 et/ou analytic2'); end
tasks      = allTasks(iTk);
taskLabel  = allLabels(iTk);
joints     = {'HT', 'GH', 'ST', 'GHs', 'STs'};
jointNames = {'Humerothoracique', 'Glenohumerale', 'Scapulothoracique', 'Glenohumerale_signe', 'ST_signe'};
conds      = {'Pre', 'Post'};
% Familles x plages : A et B pour chaque plage (suffixe _<début>_<fin>,
% ex. _rest_max, _20_90) ; C au pic seulement (« at peak »)
angLbl     = arrayfun(@(a) sprintf('_%d', a), angles, 'UniformOutput', false);
famCol     = [strcat('A_GHST', allSfx), strcat('B_THST', allSfx), {'C_THGH'}];
nPts       = 101;

% Côté de chaque patient (sens du GH signé propre au côté)
cyc = readtable(inFile, 'Sheet', 'Cycle_retenu');

% -------------------------------------------------------------------------
% CALCUL
% -------------------------------------------------------------------------
% 1) Repos et pic de chaque session (HT, ST : abs comme Data_posture ; GH :
%    signé, orienté ensuite)
rows = {};
asc  = {};   % courbes de la montée {HT, GH signé, ST signé} (1 à pic), même ordre que rows
for iT = 1:numel(tasks)
    D = struct();
    for iJ = 1:numel(joints)
        [numeros, D.(joints{iJ}), rowNum] = readCurves(inFile, [tasks{iT}, '_', jointNames{iJ}], nPts);
        if iJ == 1
            numRef = numeros;
        elseif ~isequal(numeros, numRef)
            error('TestSHRFormulas:rows', 'Numero différents entre les feuilles de %s', tasks{iT});
        end
    end
    for k = 1:numel(numeros)
        s = cyc.Side(cyc.Numero == numeros(k));
        if isempty(s), error('TestSHRFormulas:side', 'n°%d absent de Cycle_retenu', numeros(k)); end
        for iC = 1:numel(conds)
            cols = (iC - 1) * nPts + (1:nPts);
            ht = D.HT(k, cols); gh = D.GH(k, cols); st = D.ST(k, cols);
            ghs = D.GHs(k, cols); sts = D.STs(k, cols);
            if any(isnan([ht, gh, st, ghs, sts])), continue; end

            % Montée : du début au maximum de HT ; pic = même fenêtre pour tous
            [~, ip] = max(ht);
            w  = BestCycle.window(ip, nPts);
            r0 = 1:min(BestCycle.NStart, nPts);
            v  = [mean(ht(r0)), mean(ht(w)), mean(ghs(r0)), mean(ghs(w)), mean(sts(r0)), mean(sts(w)), ...
                  mean(gh(r0)), mean(gh(w)), mean(st(r0)), mean(st(w))];
            % Angles fixes : GH signé et ST quand HT franchit l'angle sur la
            % montée (interpolation linéaire) ; vide si HT part au-dessus de
            % l'angle ou ne l'atteint pas avant le pic
            va = NaN(1, 2 * numel(angles));
            for a = 1:numel(angles)
                va(2 * a - 1) = atAngle(ht, ghs, angles(a), ip);
                va(2 * a)     = atAngle(ht, sts, angles(a), ip);
            end
            rows(end + 1, :) = [{numeros(k), s{1}, taskLabel{iT}, upper(conds{iC}), ip}, num2cell([v, va])]; %#ok<AGROW>
            asc{end + 1, 1} = {ht(1:ip), ghs(1:ip), sts(1:ip)}; %#ok<AGROW>
        end
    end
end
angCols = reshape([strcat('GH_at', angLbl); strcat('ST_at', angLbl)], 1, []);
SHR = cell2table(rows, 'VariableNames', [{'Numero', 'Side', 'Task', 'Condition', 'PeakIndex', ...
    'HT_rest', 'HT_peak', 'GH_rest', 'GH_peak', 'ST_rest', 'ST_peak', 'GHabs_rest', 'GHabs_peak', ...
    'STabs_rest', 'STabs_peak'}, angCols]);
dHT = SHR.HT_peak - SHR.HT_rest;
SHR.Exclu = repmat({''}, height(SHR), 1);
SHR.Exclu(dHT < Opts.MinElevation) = {sprintf('élévation HT < %g deg', Opts.MinElevation)};

% 2) Sens de GH et de ST par tâche et par côté : sens majoritaire de la
%    variation du signal signé (repos -> pic) sur la cohorte, PRE et POST
%    confondus, sessions retenues seulement ; fixé par groupe et non par
%    patient, pour que les vrais mouvements inverses restent négatifs
for J = {'GH', 'ST'}
    j = J{1};
    SHR.([j, '_sign']) = NaN(height(SHR), 1);
    fprintf('\nSens du %s signé (variation repos -> pic, sessions retenues) :\n', j);
    for iT = 1:numel(tasks)
        for sd = {'R', 'L'}
            g = strcmp(SHR.Task, taskLabel{iT}) & strcmp(SHR.Side, sd{1});
            d = SHR.([j, '_peak'])(g & cellfun(@isempty, SHR.Exclu)) - SHR.([j, '_rest'])(g & cellfun(@isempty, SHR.Exclu));
            if isempty(d), continue; end
            sg = sign(median(d)); if sg == 0, sg = 1; end
            SHR.([j, '_sign'])(g) = sg;
            fprintf('  %-8s %s : %+d (%d / %d sessions dans ce sens)\n', taskLabel{iT}, sd{1}, sg, sum(sign(d) == sg), numel(d));
        end
    end
    SHR.([j, '_rest']) = SHR.([j, '_sign']) .* SHR.([j, '_rest']);
    SHR.([j, '_peak']) = SHR.([j, '_sign']) .* SHR.([j, '_peak']);
    for a = 1:numel(angles)
        SHR.([j, '_at', angLbl{a}]) = SHR.([j, '_sign']) .* SHR.([j, '_at', angLbl{a}]);
    end
end

% 3) Ratios (vides pour les sessions exclues)
for iF = 1:numel(famCol), SHR.(famCol{iF}) = NaN(height(SHR), 1); end
for i = find(cellfun(@isempty, SHR.Exclu))'
    SHR.C_THGH(i) = ratio(SHR.HT_peak(i), SHR.GH_peak(i), Opts.MinDelta); % TH:GH au pic (angles)
    % A et B pour chaque plage : HT, GH, ST au début (repos ou point où HT
    % franchit l'angle) et à la fin (pic ou point où HT franchit l'angle)
    for r = 1:size(Opts.Ranges, 1)
        p0 = rangePoint(SHR, i, Opts.Ranges(r, 1), 'rest');
        p1 = rangePoint(SHR, i, Opts.Ranges(r, 2), 'peak');
        if any(isnan([p0, p1])), continue; end
        dST = p1(3) - p0(3);
        SHR.(['A_GHST', rngSfx{r}])(i) = ratio(p1(2) - p0(2), dST, Opts.MinDelta);   % GH:ST
        SHR.(['B_THST', rngSfx{r}])(i) = ratio(p1(1) - p0(1), dST, Opts.MinDelta);   % TH:ST
    end
end

% 4) Intervalles d'analyse sur la montée complète (rest–individual max) :
%    une valeur par patient (pente de régression, moyenne des incréments)
%    et des valeurs par angle (incréments, brackets, cumulatif, continu)
disc = cell(0, 7);
for i = find(cellfun(@isempty, SHR.Exclu))'
    h = asc{i}{1}; g = SHR.GH_sign(i) * asc{i}{2}; s = SHR.ST_sign(i) * asc{i}{3};
    I = shrIntervals(h, g, s, SHR.HT_rest(i), SHR.GH_rest(i), SHR.ST_rest(i), Opts);
    SHR.A_GHST_reg(i) = I.Areg;     SHR.B_THST_reg(i) = I.Breg;
    SHR.A_GHST_incmean(i) = I.Ainc; SHR.B_THST_incmean(i) = I.Binc;
    if ~isempty(I.rows)
        disc = [disc; [repmat({SHR.Numero(i), SHR.Condition{i}}, size(I.rows, 1), 1), I.rows]]; %#ok<AGROW>
    end
end
Disc = cell2table(disc, 'VariableNames', {'Numero', 'Condition', 'Interval', 'Family', 'From', 'To', 'Value'});

% Résumé par intervalle, famille, angle et condition
fr = Disc.From; fr(isnan(fr)) = -1;   % -1 = repos (findgroups ignore les NaN)
[gk, gI, gF, gFr, gTo, gC] = findgroups(Disc.Interval, Disc.Family, fr, Disc.To, Disc.Condition);
gFr(gFr == -1) = NaN;
ds = cell(max(gk), 12);
for k = 1:max(gk)
    x = Disc.Value(gk == k); x = x(~isnan(x));
    if isempty(x), ci = [NaN NaN]; q = NaN(1, 3); else
        ci = mean(x) + [-1 1] * tq975(numel(x) - 1) * std(x) / sqrt(numel(x)); q = quantile7(x, [0.25 0.5 0.75]); end
    ds(k, :) = {gI{k}, gF{k}, gFr(k), gTo(k), gC{k}, numel(x), mean(x), ci(1), ci(2), q(2), q(1), q(3)};
end
DiscSum = cell2table(ds, 'VariableNames', {'Interval', 'Family', 'From', 'To', 'Condition', 'n', ...
    'Mean', 'CI95_low', 'CI95_high', 'Median', 'Q1', 'Q3'});

% -------------------------------------------------------------------------
% RESUME (console + feuille)
% -------------------------------------------------------------------------
sumRows = {};
fprintf('\nSHR - médiane [Q1 ; Q3] (n, ratios vides)\n');
for iT = 1:numel(tasks)
    for iC = 1:numel(conds)
        sel = strcmp(SHR.Task, taskLabel{iT}) & strcmp(SHR.Condition, upper(conds{iC}));
        nExcl = sum(sel & ~cellfun(@isempty, SHR.Exclu));
        line = sprintf('  %-8s %-4s (exclues %d)', taskLabel{iT}, upper(conds{iC}), nExcl);
        for iF = 1:numel(famCol)
            x = SHR.(famCol{iF})(sel & cellfun(@isempty, SHR.Exclu));
            nNaN = sum(isnan(x)); x = x(~isnan(x));
            q = quantile7(x, [0.25 0.5 0.75]);
            nPair = nPaired(SHR, taskLabel{iT}, famCol{iF});
            ci = mean(x) + [-1 1] * tq975(numel(x) - 1) * std(x) / sqrt(numel(x));   % IC 95 % (t de Student)
            sumRows(end + 1, :) = {taskLabel{iT}, upper(conds{iC}), famCol{iF}, numel(x), nPair, nExcl, nNaN, ...
                q(2), q(1), q(3), mean(x), std(x), ci(1), ci(2), sum(x < 0)}; %#ok<AGROW>
            line = [line, sprintf('\n      %-12s %5.2f [%5.2f ; %5.2f]  n %3d (apparié %3d), <0 %d', ...
                famCol{iF}, q(2), q(1), q(3), numel(x), nPair, sum(x < 0))]; %#ok<AGROW>
        end
        disp(line);
    end
end
Summary = cell2table(sumRows, 'VariableNames', {'Task', 'Condition', 'Family', 'n', 'n_apparie', 'n_exclu', 'n_vide', ...
    'Median', 'Q1', 'Q3', 'Mean', 'SD', 'CI95_low', 'CI95_high', 'n_negatif'});

% Tests (une ligne par tâche et colonne de ratio) :
%   PRE vs POST : Wilcoxon signé apparié (patients avec PRE et POST),
%     exact si n <= 50 sans ex aequo, sinon approximation normale avec
%     correction des ex aequo (comme scipy.stats.wilcoxon par défaut) ;
%     correction de Holm sur toutes les colonnes de la tâche ;
%   Spearman : rho entre la méthode et la référence rest–individual max de
%     la même famille, sur les mêmes sessions, par condition (descriptif,
%     sans p) ; pas de référence pour C
tst = cell(0, 14);
for iT = 1:numel(tasks)
    S  = SHR(strcmp(SHR.Task, taskLabel{iT}), :);
    pr = S(strcmp(S.Condition, 'PRE'), :); po = S(strcmp(S.Condition, 'POST'), :);
    [~, ia, ib] = intersect(pr.Numero, po.Numero);
    pv = NaN(numel(famCol), 1); first = size(tst, 1);
    for iF = 1:numel(famCol)
        f = famCol{iF};
        x = pr.(f)(ia); y = po.(f)(ib); ok = ~isnan(x) & ~isnan(y);
        [p, W, z, meth] = wilcoxonSigned(y(ok) - x(ok));
        pv(iF) = p;
        ref = refColumn(f);
        rho = NaN(1, 2); nr = zeros(1, 2);
        for iC = 1:2
            C = S(strcmp(S.Condition, upper(conds{iC})), :);
            if isempty(ref), continue; end
            u = C.(f); v = C.(ref); okr = ~isnan(u) & ~isnan(v);
            nr(iC) = sum(okr); rho(iC) = spearmanRho(u(okr), v(okr));
        end
        tst(end + 1, :) = {taskLabel{iT}, f, sum(ok), median(y(ok) - x(ok)), W, z, p, meth, NaN, ...
            rho(1), nr(1), rho(2), nr(2), ~isempty(ref) && strcmp(f, ref)}; %#ok<AGROW>
    end
    ph = holm(pv);
    for iF = 1:numel(famCol), tst{first + iF, 9} = ph(iF); end
end
Tests = cell2table(tst, 'VariableNames', {'Task', 'Family', 'n_pairs', 'Median_diff_POST_PRE', 'W', 'z', ...
    'p', 'p_method', 'p_Holm', 'rho_PRE', 'n_rho_PRE', 'rho_POST', 'n_rho_POST', 'is_reference'});

% Tableau de l'abstract : une ligne par famille et plage, moyenne [IC 95 %]
% et n en PRE et en POST (toutes les sessions disponibles de la condition),
% p de Holm (PRE vs POST) et rho de Spearman avec la référence
[famNames, rngNames] = famLabels(famCol, allSfx, allLbl);
tab = cell(0, 10);
for iT = 1:numel(tasks)
    for iF = 1:numel(famCol)
        r = {taskLabel{iT}, famNames{iF}, rngNames{iF}};
        for iC = 1:numel(conds)
            s = Summary(strcmp(Summary.Task, taskLabel{iT}) & strcmp(Summary.Family, famCol{iF}) & ...
                strcmp(Summary.Condition, upper(conds{iC})), :);
            r = [r, {sprintf('%.2f [%.2f ; %.2f]', s.Mean, s.CI95_low, s.CI95_high), s.n}]; %#ok<AGROW>
        end
        r{end + 1} = nPaired(SHR, taskLabel{iT}, famCol{iF}); %#ok<AGROW>
        t = Tests(strcmp(Tests.Task, taskLabel{iT}) & strcmp(Tests.Family, famCol{iF}), :);
        r{end + 1} = fmtP(t.p_Holm); %#ok<AGROW>
        if t.is_reference, r{end + 1} = 'référence'; %#ok<AGROW>
        elseif isnan(t.rho_PRE) && isnan(t.rho_POST), r{end + 1} = '—'; %#ok<AGROW>
        else, r{end + 1} = sprintf('%.2f / %.2f', t.rho_PRE, t.rho_POST); end %#ok<AGROW>
        tab(end + 1, :) = r; %#ok<AGROW>
    end
end
Table = cell2table(tab, 'VariableNames', {'Tache', 'Famille', 'Plage', 'PRE_moyenne_IC95', 'PRE_n', ...
    'POST_moyenne_IC95', 'POST_n', 'n_apparie', 'p_Holm_PRE_POST', 'Spearman_rho_PRE_POST'});
fprintf('\nTableau (moyenne [IC 95 %%]) :\n'); disp(Table);

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if isfile(outFile), delete(outFile); end

% Feuille SHR : mêmes lignes que le template (Numero en colonne A)
head = {'Numero'};
for iT = 1:numel(tasks)
    for iF = 1:numel(famCol)
        for iC = 1:numel(conds)
            head{end + 1} = [tasks{iT}, '_', famCol{iF}, '_', conds{iC}]; %#ok<AGROW>
        end
    end
end
W = cell(numel(rowNum), numel(head));
W(1, :) = head;
for r = 2:numel(rowNum)
    if isnan(rowNum(r)), continue; end
    W{r, 1} = rowNum(r);
    col = 2;
    for iT = 1:numel(tasks)
        for iF = 1:numel(famCol)
            for iC = 1:numel(conds)
                i = find(SHR.Numero == rowNum(r) & strcmp(SHR.Task, taskLabel{iT}) & ...
                         strcmp(SHR.Condition, upper(conds{iC})), 1);
                if ~isempty(i) && ~isnan(SHR.(famCol{iF})(i)), W{r, col} = SHR.(famCol{iF})(i); end
                col = col + 1;
            end
        end
    end
end
writecell(W, outFile, 'Sheet', 'SHR');
writetable(SHR, outFile, 'Sheet', 'Composantes');
writetable(Summary, outFile, 'Sheet', 'Resume');
writetable(Table, outFile, 'Sheet', 'Tableau_abstract');
writetable(Tests, outFile, 'Sheet', 'Tests');
writetable(DiscSum, outFile, 'Sheet', 'Intervalles_resume');
writetable(Disc, outFile, 'Sheet', 'Intervalles');
fprintf('Excel exporté : %s\n', outFile);

if Opts.Plot
    [~, base] = fileparts(Opts.OutputFile);
    if ~isfolder(Opts.FigureFolder), mkdir(Opts.FigureFolder); end
    plotSHR(SHR, fullfile(Opts.FigureFolder, base), taskLabel, Opts.MinElevation, allSfx, allLbl);
    plotSHRMeanCI(Summary, fullfile(Opts.FigureFolder, [base, '_moyenne_IC']), taskLabel, famCol, allSfx, allLbl);
    plotSHRIntervals(DiscSum, fullfile(Opts.FigureFolder, [base, '_intervalles']));
end

end

% =========================================================================
% Figure (une par tâche) : un panneau par famille (A, B, C), une position
% par plage d'élévation (maximum individuel, puis angles fixes pour A et
% B), PRE (orange) et POST (bleu) : points individuels, boîte = Q1-Q3,
% trait = médiane ; sous chaque plage, nombre de patients appariés PRE /
% POST. Axe borné aux percentiles 2-98 % du panneau (0 inclus) ; valeurs
% au-delà dessinées en triangle sur le bord, nombre indiqué.
% Ligne pointillée : rythme 2:1 d'Inman (GH:ST = 2 <=> TH:ST = 3 <=> TH:GH
% = 1.5 en variations ; pour C, angles au pic, repère indicatif).
function plotSHR(SHR, outBase, taskLabel, minElev, rngSfx, rngLbl)
panels = struct('cols',  {strcat('A_GHST', rngSfx), strcat('B_THST', rngSfx), {'C_THGH'}}, ...
                'lbl',   {rngLbl, rngLbl, {'peak'}}, ...
                'title', {'A  GH:ST', 'B  TH:ST', 'C  TH:GH au pic'}, 'ref', {2, 3, 1.5});
span   = cellfun(@numel, {panels.cols});
col    = [0.90 0.62 0.00; 0.00 0.45 0.70];   % PRE orange, POST bleu (Okabe-Ito)
ink    = [0.25 0.25 0.25];
conds  = {'PRE', 'POST'};

for iT = 1:numel(taskLabel)
    S = SHR(strcmp(SHR.Task, taskLabel{iT}), :);
    nExcl = sum(~cellfun(@isempty, S.Exclu));   % sessions exclues (PRE + POST)
    base = outBase;
    if numel(taskLabel) > 1, base = [outBase, '_', taskLabel{iT}]; end

    fig = figure('Color', 'w', 'Position', [50 100 330 * sum(span) / 2 + 300 500], ...
        'Name', ['SHR - ', taskLabel{iT}]);
    if exist('theme', 'file'), theme(fig, 'light'); end
    rng(1);   % jitter reproductible
    tl = tiledlayout(fig, 1, sum(span), 'TileSpacing', 'compact', 'Padding', 'compact');
    for p = 1:numel(panels)
        P  = panels(p);
        ax = nexttile(tl, [1 span(p)]); hold(ax, 'on');
        allv = cell2mat(cellfun(@(c) S.(c), P.cols, 'UniformOutput', false));
        allv = allv(~isnan(allv));
        lim = quantile7(allv, [0.02 0.98]);
        lim(1) = min(lim(1), 0);
        pad = 0.04 * diff(lim); lim = [lim(1) - pad, lim(2) + pad];   % bornes de coupe
        axLim = lim + [-1 1] * 0.03 * diff(lim);                      % marge pour les triangles
        yline(ax, P.ref, ':', sprintf('%g:1', P.ref), 'Color', [0.55 0.55 0.55], 'LineWidth', 1, ...
            'LabelHorizontalAlignment', 'left', 'FontSize', 8, 'HandleVisibility', 'off');
        yline(ax, 0, '-', 'Color', [0.85 0.85 0.85], 'HandleVisibility', 'off');
        gx = 2.6 * (1:numel(P.cols));   % centre de chaque plage ; PRE à gauche, POST à droite
        tick = cell(1, numel(P.cols));
        for g = 1:numel(P.cols)
            for iC = 1:2
                v  = S.(P.cols{g})(strcmp(S.Condition, conds{iC}));
                v  = v(~isnan(v));
                if isempty(v), continue; end
                c  = col(iC, :);
                x0 = gx(g) + (iC - 1.5);
                x  = x0 + (rand(size(v)) - 0.5) * 0.32;
                in = v >= lim(1) & v <= lim(2);
                scatter(ax, x(in), v(in), 10, c, 'filled', 'MarkerFaceAlpha', 0.35, ...
                    'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
                hi = v > lim(2); lo = v < lim(1);
                if any(hi)
                    scatter(ax, x(hi), repmat(lim(2), sum(hi), 1), 16, c, '^', 'filled', 'HandleVisibility', 'off');
                    text(ax, x0 + 0.22, lim(2), sprintf('%d>', sum(hi)), 'Color', ink, 'FontSize', 7, ...
                        'VerticalAlignment', 'middle');
                end
                if any(lo)
                    scatter(ax, x(lo), repmat(lim(1), sum(lo), 1), 16, c, 'v', 'filled', 'HandleVisibility', 'off');
                    text(ax, x0 + 0.22, lim(1), sprintf('%d<', sum(lo)), 'Color', ink, 'FontSize', 7, ...
                        'VerticalAlignment', 'middle');
                end
                q = quantile7(v, [0.25 0.5 0.75]);
                rectangle(ax, 'Position', [x0 - 0.21, q(1), 0.42, max(q(3) - q(1), eps)], ...
                    'EdgeColor', c, 'LineWidth', 1.4);
                plot(ax, x0 + [-0.21 0.21], [q(2) q(2)], '-', 'Color', c, 'LineWidth', 2.5, 'HandleVisibility', 'off');
                text(ax, x0 + 0.24, q(2), sprintf('%.2f', q(2)), 'Color', ink, 'FontSize', 7, ...
                    'VerticalAlignment', 'middle');
            end
            tick{g} = sprintf('%s\\newline(n = %d)', P.lbl{g}, nPaired(S, taskLabel{iT}, P.cols{g}));
        end
        ylim(ax, axLim); xlim(ax, [gx(1) - 1.3, gx(end) + 1.3]);
        set(ax, 'XTick', gx, 'XTickLabel', tick, 'TickDir', 'out', ...
            'XColor', ink, 'YColor', ink, 'FontSize', 9, 'Box', 'off', 'YGrid', 'on', ...
            'GridColor', [0.9 0.9 0.9], 'GridAlpha', 1);
        title(ax, P.title, 'FontWeight', 'bold', 'FontSize', 11, 'Color', ink);
        if p == 1
            ylabel(ax, 'Ratio');
            xlabel(ax, 'Plage d''élévation HT (n = patients appariés PRE / POST)', 'FontSize', 9, 'Color', ink);
            h1 = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', col(1, :), 'MarkerEdgeColor', 'none');
            h2 = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', col(2, :), 'MarkerEdgeColor', 'none');
            lg = legend(ax, [h1 h2], {'PRE', 'POST'}, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 10);
            lg.Layout.Tile = 'north';   % au-dessus des panneaux, hors des données
        end
    end
    title(tl, {sprintf('SHR en %s par plage d''élévation HT : points, médiane et Q1-Q3', ...
        lower(taskLabel{iT})), sprintf('GH et ST signés orientés ; sessions avec élévation HT \\geq %g° (exclues : %d)', ...
        minElev, nExcl)}, 'FontSize', 11, 'Color', ink);
    exportgraphics(fig, [base, '.png'], 'Resolution', 300);
    exportgraphics(fig, [base, '.pdf'], 'ContentType', 'vector');
    fprintf('Figure exportée : %s (.png, .pdf)\n', base);
end
end

% =========================================================================
% Figure moyenne [IC 95 %] (une par tâche, pour le diapo, équivalent du
% tableau de l'abstract) : un panneau par famille, une ligne par plage
% d'élévation, PRE (orange) et POST (bleu) : point = moyenne, trait = IC
% 95 % ; valeurs et n écrits à droite ; pointillé = repère 2:1 d'Inman.
function plotSHRMeanCI(Summary, outBase, taskLabel, famCol, rngSfx, rngLbl)
[~, rngNames] = famLabels(famCol, rngSfx, rngLbl);
pref   = {'A_', 'B_', 'C_'};
titles = {'A  GH:ST', 'B  TH:ST', 'C  TH:GH au pic'};
ref    = [2 3 1.5];
col    = [0.90 0.62 0.00; 0.00 0.45 0.70];   % PRE orange, POST bleu (Okabe-Ito)
ink    = [0.25 0.25 0.25];
conds  = {'PRE', 'POST'};
for iT = 1:numel(taskLabel)
    S = Summary(strcmp(Summary.Task, taskLabel{iT}), :);
    base = outBase;
    if numel(taskLabel) > 1, base = [outBase, '_', taskLabel{iT}]; end
    nRows = cellfun(@(p) sum(startsWith(famCol, p)), pref);
    tileH = max(nRows, 2);   % hauteur des panneaux (au moins 2 lignes pour C)
    fig = figure('Color', 'w', 'Position', [50 50 1000 120 + 80 * sum(tileH)], ...
        'Name', ['SHR moyenne IC - ', taskLabel{iT}]);
    if exist('theme', 'file'), theme(fig, 'light'); end
    tl = tiledlayout(fig, sum(tileH), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for p = 1:numel(pref)
        idx  = find(startsWith(famCol, pref{p}));
        ax   = nexttile(tl, [tileH(p) 1]); hold(ax, 'on');
        rows = S(ismember(S.Family, famCol(idx)), :);
        lo = min(rows.CI95_low); hi = max(rows.CI95_high); w = hi - lo;
        xlim(ax, [lo - 0.08 * w, hi + 0.9 * w]);
        xline(ax, ref(p), ':', sprintf('%g:1', ref(p)), 'Color', [0.55 0.55 0.55], 'LineWidth', 1, ...
            'LabelVerticalAlignment', 'bottom', 'FontSize', 8, 'HandleVisibility', 'off');
        for g = 1:numel(idx)
            y = numel(idx) - g + 1;
            for iC = 1:2
                s  = rows(strcmp(rows.Family, famCol{idx(g)}) & strcmp(rows.Condition, conds{iC}), :);
                yy = y + 0.17 * (1.5 - iC) * 2;
                plot(ax, [s.CI95_low s.CI95_high], [yy yy], '-', 'Color', col(iC, :), 'LineWidth', 2, 'HandleVisibility', 'off');
                plot(ax, s.Mean, yy, 'o', 'MarkerSize', 7, 'MarkerFaceColor', col(iC, :), 'MarkerEdgeColor', 'w', ...
                    'HandleVisibility', 'off');
                text(ax, hi + 0.06 * w, yy, sprintf('%.2f [%.2f ; %.2f]   n = %d', s.Mean, s.CI95_low, s.CI95_high, s.n), ...
                    'Color', ink, 'FontSize', 8, 'VerticalAlignment', 'middle');
            end
        end
        set(ax, 'YTick', 1:numel(idx), 'YTickLabel', flip(rngNames(idx)), 'YLim', [0.45, numel(idx) + 0.55], ...
            'TickDir', 'out', 'XColor', ink, 'YColor', ink, 'FontSize', 9, 'Box', 'off', 'XGrid', 'on', ...
            'GridColor', [0.9 0.9 0.9], 'GridAlpha', 1);
        title(ax, titles{p}, 'FontWeight', 'bold', 'FontSize', 11, 'Color', ink);
        if p == numel(pref), xlabel(ax, 'Ratio (moyenne et IC 95 %)'); end
        if p == 1
            h1 = plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', col(1, :), 'MarkerEdgeColor', 'w', 'MarkerSize', 7);
            h2 = plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', col(2, :), 'MarkerEdgeColor', 'w', 'MarkerSize', 7);
            lg = legend(ax, [h1 h2], {'PRE', 'POST'}, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 10);
            lg.Layout.Tile = 'north';
        end
    end
    title(tl, sprintf('SHR en %s : moyenne et IC 95 %% par famille et plage d''élévation (GH et ST signés orientés)', ...
        lower(taskLabel{iT})), 'FontSize', 11, 'Color', ink);
    exportgraphics(fig, [base, '.png'], 'Resolution', 300);
    exportgraphics(fig, [base, '.pdf'], 'ContentType', 'vector');
    fprintf('Figure exportée : %s (.png, .pdf)\n', base);
end
end

% Intervalles d'analyse d'une session sur la montée (h : HT, g : GH et s :
% ST signés orientés, du repos au pic ; h0, g0, s0 : valeurs au repos) :
%   regression : pente de g sur s (A) et de h sur s (B), toute la montée ;
%   increments : ratio dans chaque tranche [e(k) e(k+1)] de IncEdges (A :
%     ΔGH/ΔST, B : ΔHT/ΔST), + moyenne des tranches du patient (Ainc, Binc) ;
%   brackets   : idem sur les tranches de Brackets ;
%   cumulative : ratio du repos jusqu'à chaque angle de Grid ;
%   continuous : rapport des dérivées de GH(HT) et ST(HT) (polynômes de degré
%     ContDegree ajustés sur la montée) à chaque angle de Grid ; vide si
%     |dST/dHT| < ContMinSlope.
% Angles lus là où HT franchit l'angle sur la montée (atAngle, règle
% stricte). rows : {Interval, Family, From, To, Value} (From NaN = repos).
function I = shrIntervals(h, g, s, h0, g0, s0, Opts)
I = struct('Areg', NaN, 'Breg', NaN, 'Ainc', NaN, 'Binc', NaN, 'rows', {cell(0, 5)});
ip = numel(h);
if max(s) - min(s) >= Opts.MinDelta
    pA = polyfit(s, g, 1); pB = polyfit(s, h, 1);
    I.Areg = pA(1); I.Breg = pB(1);
end
allAng = unique([Opts.IncEdges, Opts.Brackets, Opts.Grid]);
G = arrayfun(@(a) atAngle(h, g, a, ip), allAng);
S = arrayfun(@(a) atAngle(h, s, a, ip), allAng);
at = @(a) find(allAng == a, 1);
R = cell(0, 5);
% Incréments et brackets
specs = {'increments', Opts.IncEdges; 'brackets', Opts.Brackets};
inc = NaN(0, 2);
for sp = 1:size(specs, 1)
    e = specs{sp, 2};
    for k = 1:numel(e) - 1
        i0 = at(e(k)); i1 = at(e(k + 1));
        if isnan(S(i0)) || isnan(S(i1)), continue; end
        dS = S(i1) - S(i0);
        a = ratio(G(i1) - G(i0), dS, Opts.MinDelta); b = ratio(e(k + 1) - e(k), dS, Opts.MinDelta);
        R(end + 1, :) = {specs{sp, 1}, 'A', e(k), e(k + 1), a}; %#ok<AGROW>
        R(end + 1, :) = {specs{sp, 1}, 'B', e(k), e(k + 1), b}; %#ok<AGROW>
        if sp == 1, inc(end + 1, :) = [a b]; end %#ok<AGROW>
    end
end
if ~isempty(inc), I.Ainc = mean(inc(:, 1), 'omitnan'); I.Binc = mean(inc(:, 2), 'omitnan'); end
% Cumulatif depuis le repos
for a = Opts.Grid
    ia = at(a);
    if isnan(S(ia)), continue; end
    R(end + 1, :) = {'cumulative', 'A', NaN, a, ratio(G(ia) - g0, S(ia) - s0, Opts.MinDelta)}; %#ok<AGROW>
    R(end + 1, :) = {'cumulative', 'B', NaN, a, ratio(a - h0, S(ia) - s0, Opts.MinDelta)}; %#ok<AGROW>
end
% Continu : dérivées des polynômes GH(HT) et ST(HT)
if ip >= Opts.ContDegree + 2 && max(h) - min(h) >= 10
    [pg, ~, mu] = polyfit(h, g, Opts.ContDegree);
    [ps, ~, ~]  = polyfit(h, s, Opts.ContDegree);   % même centrage mu (même h)
    for a = Opts.Grid
        if a <= h(1) || a > max(h), continue; end
        z  = (a - mu(1)) / mu(2);
        dg = polyval(polyder(pg), z) / mu(2);
        dsv = polyval(polyder(ps), z) / mu(2);
        if abs(dsv) < Opts.ContMinSlope, va = NaN; vb = NaN; else, va = dg / dsv; vb = 1 / dsv; end
        R(end + 1, :) = {'continuous', 'A', a, a, va}; %#ok<AGROW>
        R(end + 1, :) = {'continuous', 'B', a, a, vb}; %#ok<AGROW>
    end
end
I.rows = R;
end

% Figure des intervalles par angle (pour le diapo) : lignes A (GH:ST) et B
% (TH:ST), colonnes increments, brackets, cumulative, continuous ; moyenne
% et IC 95 % en fonction de HT (centre de la tranche, ou angle), PRE orange
% et POST bleu ; points avec n >= 10 seulement ; pointillé = repère d'Inman
function plotSHRIntervals(DiscSum, outBase)
ints   = {'increments', 'brackets', 'cumulative', 'continuous'};
iLbl   = {'Increments 10°', 'Brackets 30°', 'Cumulative from rest', 'Continuous curve'};
fams   = {'A', 'B'}; fLbl = {'A  GH:ST', 'B  TH:ST'}; ref = [2 3];
col    = [0.90 0.62 0.00; 0.00 0.45 0.70];
ink    = [0.25 0.25 0.25];
conds  = {'PRE', 'POST'};
fig = figure('Color', 'w', 'Position', [50 50 1600 750], 'Name', 'SHR - intervalles d''analyse');
if exist('theme', 'file'), theme(fig, 'light'); end
tl = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
for f = 1:2
    for k = 1:numel(ints)
        ax = nexttile(tl); hold(ax, 'on');
        yline(ax, ref(f), ':', sprintf('%g:1', ref(f)), 'Color', [0.55 0.55 0.55], 'LabelHorizontalAlignment', 'left', ...
            'FontSize', 8, 'HandleVisibility', 'off');
        for iC = 1:2
            D = DiscSum(strcmp(DiscSum.Interval, ints{k}) & strcmp(DiscSum.Family, fams{f}) & ...
                strcmp(DiscSum.Condition, conds{iC}) & DiscSum.n >= 10, :);
            if isempty(D), continue; end
            x = D.To; if ismember(ints{k}, {'increments', 'brackets'}), x = (D.From + D.To) / 2; end
            [x, o] = sort(x); D = D(o, :);
            x = x + (iC - 1.5) * 1.5;   % léger décalage PRE / POST
            errorbar(ax, x, D.Mean, D.Mean - D.CI95_low, D.CI95_high - D.Mean, 'o-', 'Color', col(iC, :), ...
                'MarkerFaceColor', col(iC, :), 'MarkerEdgeColor', 'w', 'MarkerSize', 5, 'LineWidth', 1.3, 'CapSize', 3);
        end
        xlim(ax, [15 175]);
        set(ax, 'XTick', 20:20:160, 'XTickLabel', arrayfun(@num2str, 20:20:160, 'UniformOutput', false), ...
            'TickLabelInterpreter', 'none', 'FontName', 'Arial', 'TickDir', 'out', 'XColor', ink, 'YColor', ink, 'FontSize', 9, 'Box', 'off', 'YGrid', 'on', ...
            'GridColor', [0.9 0.9 0.9], 'GridAlpha', 1);
        if f == 1, title(ax, iLbl{k}, 'FontWeight', 'bold', 'FontSize', 10, 'Color', ink); end
        if k == 1, ylabel(ax, sprintf('%s (moyenne, IC 95 %%)', fLbl{f}), 'FontWeight', 'bold'); end
        if f == 2, xlabel(ax, 'HT (°)'); end
        if f == 1 && k == 1
            lg = legend(ax, {'PRE', 'POST'}, 'Orientation', 'horizontal', 'Box', 'off', 'FontSize', 10);
            lg.Layout.Tile = 'north';
        end
    end
end
title(tl, {'SHR en scaption par intervalle d''analyse (montée rest–individual max ; GH et ST signés orientés)', ...
    'Increments / brackets : centre de la tranche ; cumulative : du repos à l''angle ; continuous : à l''angle ; n \geq 10'}, ...
    'FontSize', 11, 'Color', ink);
% Note : MATLAB R2026a superpose parfois les chiffres d'un libellé d'axe
% dans le PNG selon sa position en pixels (« 60 » rendu « 6 », objets
% corrects ; reproduit hors de ce code, dépend de la largeur et de la
% résolution) : préférer le PDF vectoriel pour le diapo
exportgraphics(fig, [outBase, '.png'], 'Resolution', 300);
exportgraphics(fig, [outBase, '.pdf'], 'ContentType', 'vector');
fprintf('Figure exportée : %s (.png, .pdf)\n', outBase);
end

% Libellés famille et plage de chaque colonne de ratio
% (A_GHST_20_90 -> 'A GH:ST', '20–90°' ; C_THGH -> 'C TH:GH au pic', 'peak')
function [famNames, rngNames] = famLabels(famCol, rngSfx, rngLbl)
famNames = cell(size(famCol)); rngNames = repmat({'peak'}, size(famCol));
for i = 1:numel(famCol)
    switch famCol{i}(1)
        case 'A', famNames{i} = 'A GH:ST';
        case 'B', famNames{i} = 'B TH:ST';
        case 'C', famNames{i} = 'C TH:GH au pic';
    end
    k = find(cellfun(@(s) endsWith(famCol{i}, s), rngSfx), 1);   % suffixe par suffixe
    if ~isempty(k), rngNames{i} = rngLbl{k}; end
end
end

% Suffixe de colonne et libellé de chaque plage [début fin] (NaN = repos /
% maximum individuel) : [NaN NaN] -> '_rest_max', 'rest–individual max' ;
% [NaN 90] -> '_rest_90', 'rest–90°' ; [20 120] -> '_20_120', '20–120°'
function [sfx, lbl] = rangeNames(R)
sfx = cell(1, size(R, 1)); lbl = sfx;
for r = 1:size(R, 1)
    if isnan(R(r, 1)), s0 = 'rest'; l0 = 'rest'; else, s0 = sprintf('%d', R(r, 1)); l0 = s0; end
    if isnan(R(r, 2)), s1 = 'max'; l1 = 'individual max'; else, s1 = sprintf('%d', R(r, 2)); l1 = [s1, '°']; end
    sfx{r} = ['_', s0, '_', s1];
    lbl{r} = [l0, '–', l1];
end
end

% Point de début ou de fin d'une plage pour la session i : [HT GH ST] (GH
% et ST orientés). theta NaN : repos (which = 'rest') ou pic ('peak') ;
% sinon point où HT franchit theta sur la montée (HT = theta), NaN si non
% atteint ou si HT part au-dessus
function p = rangePoint(SHR, i, theta, which)
if isnan(theta)
    p = [SHR.(['HT_', which])(i), SHR.(['GH_', which])(i), SHR.(['ST_', which])(i)];
else
    a = sprintf('_%d', theta);
    p = [theta, SHR.(['GH_at', a])(i), SHR.(['ST_at', a])(i)];
end
end

% Test de Wilcoxon signé (deux côtés) sur les différences appariées d (zéros
% retirés). Exact si n <= 50 sans ex aequo (distribution de W+ par
% dénombrement), sinon approximation normale avec correction des ex aequo,
% sans correction de continuité (comme scipy.stats.wilcoxon par défaut).
% W = somme des rangs des différences positives.
function [p, W, z, meth] = wilcoxonSigned(d)
p = NaN; W = NaN; z = NaN; meth = '';
d = d(d ~= 0 & ~isnan(d)); n = numel(d);
if n < 2, return; end
r  = avgRank(abs(d));
W  = sum(r(d > 0));
mu = n * (n + 1) / 4;
[~, ~, g] = unique(abs(d)); t = accumarray(g, 1);
sd = sqrt(n * (n + 1) * (2 * n + 1) / 24 - sum(t .^ 3 - t) / 48);
z  = (W - mu) / sd;
if n <= 50 && all(t == 1)
    N = n * (n + 1) / 2; c = zeros(1, N + 1); c(1) = 1;
    for k = 1:n, c(k + 1:end) = c(k + 1:end) + c(1:end - k); end   % sous-ensembles de {1..n}
    P = c / 2 ^ n; w = round(W);
    p = min(1, 2 * min(sum(P(1:w + 1)), sum(P(w + 1:end))));
    meth = 'exact';
else
    p = erfc(abs(z) / sqrt(2));
    meth = 'normal';
end
end

% Rangs moyens (ex aequo : moyenne des rangs), sans Statistics Toolbox
function r = avgRank(x)
x = x(:); [s, o] = sort(x); r = zeros(size(x)); n = numel(x); i = 1;
while i <= n
    j = i; while j < n && s(j + 1) == s(i), j = j + 1; end
    r(o(i:j)) = (i + j) / 2; i = j + 1;
end
end

% Rho de Spearman = corrélation de Pearson des rangs moyens
function rho = spearmanRho(a, b)
rho = NaN;
if numel(a) < 3, return; end
ra = avgRank(a); rb = avgRank(b);
c = corrcoef(ra, rb); rho = c(1, 2);
end

% Correction de Holm (p ajustées, NaN ignorés)
function ph = holm(p)
ph = NaN(size(p)); ok = find(~isnan(p)); m = numel(ok);
[ps, o] = sort(p(ok)); adj = min(1, (m - (1:m)' + 1) .* ps(:));
adj = cummax(adj);
ph(ok(o)) = adj;
end

% Référence de la famille d'une colonne (rest–individual max) ; '' pour C
function ref = refColumn(f)
switch f(1)
    case 'A', ref = 'A_GHST_rest_max';
    case 'B', ref = 'B_THST_rest_max';
    otherwise, ref = '';
end
end

% p formatée pour le tableau
function s = fmtP(p)
if isnan(p), s = '—'; elseif p < 0.001, s = '< 0.001'; else, s = sprintf('%.3f', p); end
end

% Quantile 0.975 de la loi de Student à df degrés de liberté (IC 95 %
% bilatéral), sans Statistics Toolbox : t = sqrt(df (1 - x) / x) avec
% x = betaincinv(0.05, df/2, 1/2)
function t = tq975(df)
if df < 1, t = NaN; return; end
x = betaincinv(0.05, df / 2, 0.5);
t = sqrt(df * (1 - x) / x);
end

% =========================================================================
% Valeur de x quand HT franchit l'angle theta sur la montée (points 1 à ip),
% interpolation linéaire entre les deux points encadrants ; NaN si HT part
% déjà au-dessus de theta ou ne l'atteint pas avant le pic
function v = atAngle(ht, x, theta, ip)
v = NaN;
i = find(ht(1:ip) >= theta, 1);
if isempty(i) || i == 1, return; end
f = (theta - ht(i - 1)) / (ht(i) - ht(i - 1));
v = x(i - 1) + f * (x(i) - x(i - 1));
end

% Nombre de patients avec une valeur en PRE et en POST pour une colonne
function n = nPaired(SHR, task, fam)
s  = strcmp(SHR.Task, task) & ~isnan(SHR.(fam));
n  = numel(intersect(SHR.Numero(s & strcmp(SHR.Condition, 'PRE')), SHR.Numero(s & strcmp(SHR.Condition, 'POST'))));
end

% Ratio num / den, NaN si |den| < minDelta
function r = ratio(num, den, minDelta)
if abs(den) < minDelta, r = NaN; else, r = num / den; end
end

% Courbes d'une feuille de SHR_Curves.xlsx : Numero, matrice [patients x
% 2*nPts] (Pre puis Post) et colonne A complète (lignes du template)
function [numeros, M, rowNum] = readCurves(file, sheet, nPts)
C = readcell(file, 'Sheet', sheet);
head = C(1, :);
if numel(head) ~= 1 + 2 * nPts || ~endsWith(head{2}, '_Pre_000') || ~endsWith(head{2 + nPts}, '_Post_000')
    error('TestSHRFormulas:format', 'Colonnes inattendues dans la feuille %s', sheet);
end
isNum  = cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), C(:, 1));
isNum(1) = false;
rowNum = NaN(size(C, 1), 1);
rowNum(isNum) = cell2mat(C(isNum, 1));
numeros = rowNum(isNum);
vals = C(isNum, 2:end);
ok   = cellfun(@(x) isnumeric(x) && isscalar(x), vals);
M    = NaN(size(vals));
M(ok) = cell2mat(vals(ok));
end

% Quantiles (type 7, interpolation linéaire, comme R / numpy par défaut),
% sans Statistics Toolbox
function q = quantile7(x, p)
q = NaN(size(p));
x = sort(x(:));
n = numel(x);
if n == 0, return; end
for i = 1:numel(p)
    h  = (n - 1) * p(i) + 1;
    lo = floor(h); hi = min(lo + 1, n);
    q(i) = x(lo) + (h - lo) * (x(hi) - x(lo));
end
end
