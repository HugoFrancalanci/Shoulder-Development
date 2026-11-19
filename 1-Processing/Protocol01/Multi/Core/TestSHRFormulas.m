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
%           (15 deg), Ranges ([NaN NaN; NaN 90; NaN 120; 20 90; 20 120])
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
% Plages d'élévation [début fin] en HT : début NaN = repos, fin NaN =
% maximum individuel
if ~isfield(Opts, 'Ranges') || isempty(Opts.Ranges)
    Opts.Ranges = [NaN NaN; NaN 90; NaN 120; 20 90; 20 120];
end
[rngSfx, rngLbl] = rangeNames(Opts.Ranges);
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
famCol     = [strcat('A_GHST', rngSfx), strcat('B_THST', rngSfx), {'C_THGH'}];
nPts       = 101;

% Côté de chaque patient (sens du GH signé propre au côté)
cyc = readtable(inFile, 'Sheet', 'Cycle_retenu');

% -------------------------------------------------------------------------
% CALCUL
% -------------------------------------------------------------------------
% 1) Repos et pic de chaque session (HT, ST : abs comme Data_posture ; GH :
%    signé, orienté ensuite)
rows = {};
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

% Tableau de l'abstract : une ligne par famille et plage, moyenne [IC 95 %]
% et n en PRE et en POST (toutes les sessions disponibles de la condition)
[famNames, rngNames] = famLabels(famCol, rngSfx, rngLbl);
tab = cell(0, 8);
for iT = 1:numel(tasks)
    for iF = 1:numel(famCol)
        r = {taskLabel{iT}, famNames{iF}, rngNames{iF}};
        for iC = 1:numel(conds)
            s = Summary(strcmp(Summary.Task, taskLabel{iT}) & strcmp(Summary.Family, famCol{iF}) & ...
                strcmp(Summary.Condition, upper(conds{iC})), :);
            r = [r, {sprintf('%.2f [%.2f ; %.2f]', s.Mean, s.CI95_low, s.CI95_high), s.n}]; %#ok<AGROW>
        end
        r{end + 1} = nPaired(SHR, taskLabel{iT}, famCol{iF}); %#ok<AGROW>
        tab(end + 1, :) = r; %#ok<AGROW>
    end
end
Table = cell2table(tab, 'VariableNames', {'Tache', 'Famille', 'Plage', 'PRE_moyenne_IC95', 'PRE_n', ...
    'POST_moyenne_IC95', 'POST_n', 'n_apparie'});
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
fprintf('Excel exporté : %s\n', outFile);

if Opts.Plot
    [~, base] = fileparts(Opts.OutputFile);
    plotSHR(SHR, fullfile(DataFolder, base), taskLabel, Opts.MinElevation, rngSfx, rngLbl);
    plotSHRMeanCI(Summary, fullfile(DataFolder, [base, '_moyenne_IC']), taskLabel, famCol, rngSfx, rngLbl);
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
