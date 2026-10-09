% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Épaules asymptomatiques (controlatérales saines, une seule
%                session PRE ou POST par épaule) comparées aux épaules rTSA,
%                à partir de Data_posture.xlsx (rien n'est recalculé) :
%                  1) valeurs de référence : HG, HT, HG moins HT, thorax
%                     (ROM et pic) et changement du thorax pendant le geste,
%                     épaules saines vs rTSA PRE et POST (Welch, Hedges g)
%                  2) comparaison dans le même patient : côté opéré moins
%                     côté sain, même session, t apparié, et élévation
%                     opérée en % du côté sain
%                  3) posture et épaule saine : inclinaison assis, debout
%                     et SIR de la session asymptomatique x HG / HT du côté
%                     sain (Pearson, IC 95 % de Fisher), à comparer aux
%                     rTSA POST ; et inclinaison x déficit opéré moins sain
%                Élévations bilatérales (les deux bras en même temps) : le
%                thorax est commun aux deux côtés d'une session. Les
%                variables du thorax de l'épaule saine ne sont donc pas
%                une référence « saine » de la compensation par le tronc ;
%                dans la comparaison appariée, elles servent de contrôle
%                (écart attendu nul).
%                Feuilles lues : Posture, Cinematique, Cinematique_pics,
%                Cinematique_thorax et leurs versions _Asym (colonnes
%                <tâche>_<ROM|MAX>_<joint>_Asym, Session, Cote...).
%                ANALYTIC1 = flexion, ANALYTIC2 = scaption.
%                Textes des figures sans tiret ni tiret long.
%
%                Réserves : 26 épaules (puissance faible : |r| détectable
%                environ 0.5) ; controlatéral asymptomatique ne veut pas
%                dire sain ; sessions PRE et POST mélangées ; résultats
%                exploratoires.
% -------------------------------------------------------------------------
% Inputs  : DataFile   (char) chemin vers Data_posture.xlsx
%           OutputFile (char, optionnel) Excel de sortie (feuilles
%                      Asym_Reference, Asym_Paired, Asym_Posture) ; '' =
%                      pas d'export
% Outputs : Ref, Pair, Post (struct arrays, une ligne par test)
%           + 3 figures (valeurs de référence, même patient opéré vs
%           sain, posture et épaule saine)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Ref, Pair, Post] = AsymptomaticComparison(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end
rng(1);   % jitter des points reproductible

taskDef = struct('key', {'analytic1', 'analytic2'}, 'label', {'flexion', 'scaption'});
metricDef = struct('name', {'ROM', 'Pic'}, 'key', {'ROM', 'MAX'});
grpName = {'PRE', 'POST', 'ASYM'};
grpLbl  = {'rTSA PRE', 'rTSA POST', 'Saines'};
cols    = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

% -------------------------------------------------------------------------
% LECTURE
% -------------------------------------------------------------------------
P   = readSheet(DataFile, 'Posture');            numP = getCol(P, 'Numero');
Pa  = readSheet(DataFile, 'Posture_Asym');       numA = getCol(Pa, 'Numero');
K   = {readSheet(DataFile, 'Cinematique'),      readSheet(DataFile, 'Cinematique_pics')};
Ka  = {readSheet(DataFile, 'Cinematique_Asym'), readSheet(DataFile, 'Cinematique_pics_Asym')};
Kt  = readSheet(DataFile, 'Cinematique_thorax');
Kta = readSheet(DataFile, 'Cinematique_thorax_Asym');
sessA = getText(Pa, 'Session');                  % 'PRE' / 'POST' de l'épaule saine
sfx   = struct('PRE', '_Pre', 'POST', '_Post');

postP = {getCol(P, 'Inclinaison_thoracique_Pre'), getCol(P, 'Inclinaison_thoracique_Pre_Calibration3'), ...
         getCol(P, 'Rotation_scapulaire_interne_Pre')};
postA = {getCol(Pa, 'Inclinaison_thoracique_Asym'), getCol(Pa, 'Inclinaison_thoracique_Asym_Calibration3'), ...
         getCol(Pa, 'Rotation_scapulaire_interne_Asym')};
postLbl = {'Inclinaison assis', 'Inclinaison debout', 'SIR'};

% Valeur d'un joint, par groupe : vecteur sur les patients (PRE, POST) ou
% sur les épaules saines (ASYM)
kin = @(iM, td, joint, g) kinValue(K, Ka, numP, metricDef(iM), td, joint, grpName{g});
txc = @(td, g) txValue(Kt, Kta, numP, td, grpName{g});

% -------------------------------------------------------------------------
% 1) VALEURS DE RÉFÉRENCE
% -------------------------------------------------------------------------
Ref = struct('Task', {}, 'Movement', {}, 'Variable', {}, 'n_ASYM', {}, 'ASYM_mean', {}, 'ASYM_SD', {}, ...
    'PRE_mean', {}, 'PRE_SD', {}, 'POST_mean', {}, 'POST_SD', {}, ...
    'Diff_ASYMminusPOST', {}, 'p_Welch_vs_POST', {}, 'g_vs_POST', {}, ...
    'Diff_ASYMminusPRE', {}, 'p_Welch_vs_PRE', {}, 'g_vs_PRE', {});
figR = figure('Name', 'Épaules asymptomatiques : valeurs de référence', 'Color', 'w');
panels = {'Pic HG', 'Pic HT', 'HG moins HT (ROM)', 'Changement thorax'};
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    for v = {'ROM HG', 'ROM HT', 'ROM HG moins HT', 'ROM thorax', 'Pic HG', 'Pic HT', 'Pic HG moins HT', 'Changement thorax'}
        vals = cell(1, 3);
        for g = 1:3, vals{g} = refVar(v{1}, kin, txc, td, g); end
        k = numel(Ref) + 1;
        Ref(k).Task = upper(td.key); Ref(k).Movement = td.label; Ref(k).Variable = v{1};
        a = vals{3}(~isnan(vals{3}));
        Ref(k).n_ASYM = numel(a); Ref(k).ASYM_mean = mean(a); Ref(k).ASYM_SD = std(a);
        Ref(k).PRE_mean  = mean(vals{1}, 'omitnan'); Ref(k).PRE_SD  = std(vals{1}, 'omitnan');
        Ref(k).POST_mean = mean(vals{2}, 'omitnan'); Ref(k).POST_SD = std(vals{2}, 'omitnan');
        [Ref(k).Diff_ASYMminusPOST, Ref(k).p_Welch_vs_POST, Ref(k).g_vs_POST] = welchT(vals{3}, vals{2});
        [Ref(k).Diff_ASYMminusPRE,  Ref(k).p_Welch_vs_PRE,  Ref(k).g_vs_PRE]  = welchT(vals{3}, vals{1});

        c = find(strcmp(panels, regexprep(v{1}, '^ROM (HG moins HT)$', '$1 (ROM)')));
        if isempty(c), continue; end
        figure(figR); subplot(numel(taskDef), numel(panels), (iT - 1) * numel(panels) + c); hold on;
        drawDots(vals, cols);
        set(gca, 'XTick', 1:3, 'XTickLabel', arrayfun(@(g) sprintf('%s (n=%d)', grpLbl{g}, sum(~isnan(vals{g}))), ...
            1:3, 'UniformOutput', false), 'XTickLabelRotation', 20);
        xlim([0.4 3.6]); box on; hold off;
        ylabel(sprintf('%s, %s (deg)', panels{c}, td.label));
        title({sprintf('Saines %.0f ± %.0f° | POST %.0f ± %.0f°', Ref(k).ASYM_mean, Ref(k).ASYM_SD, ...
               Ref(k).POST_mean, Ref(k).POST_SD), sprintf('Saines vs POST : %+.1f° (%s), g = %.2f', ...
               Ref(k).Diff_ASYMminusPOST, fmtP(Ref(k).p_Welch_vs_POST), Ref(k).g_vs_POST)}, 'FontSize', 8);
    end
end
sgtitle(figR, 'Épaules saines controlatérales vs épaules rTSA : flexion (ligne 1), scaption (ligne 2)', 'FontSize', 11);
footnote(figR, sprintf(['Données : %s. Changement thorax = thorax au pic d''élévation HG moins thorax au début du ', ...
    'cycle (> 0 = le tronc se redresse). Welch, g de Hedges. Trait noir : médiane, barre : écart interquartile.'], getFileName(DataFile)));

% -------------------------------------------------------------------------
% 2) DANS LE MÊME PATIENT : CÔTÉ OPÉRÉ vs CÔTÉ SAIN, MÊME SESSION
% -------------------------------------------------------------------------
% Élévations bilatérales (les deux bras en même temps) : le thorax est
% commun aux deux côtés. Thorax au repos et changement du thorax servent
% donc de contrôle d'appariement (écart attendu nul), pas de comparaison :
% l'épaule saine ne peut pas servir de référence pour la compensation par
% le tronc.
figC = figure('Name', 'Même patient : côté opéré vs côté sain', 'Color', 'w');
Pair = struct('Task', {}, 'Movement', {}, 'Variable', {}, 'Sessions', {}, 'n', {}, ...
    'Operated_mean', {}, 'Healthy_mean', {}, 'Diff_OperatedMinusHealthy', {}, 'Diff_CI95_low', {}, ...
    'Diff_CI95_high', {}, 'p_paired', {}, 'Operated_pct_of_healthy', {});
[inP, iP] = ismember(numA, numP);
pairVars = {'Pic HG', 2, 'Humerogravitaire'; 'Pic HT', 2, 'Humerothoracique'; 'ROM HG', 1, 'Humerogravitaire'; ...
            'ROM HT', 1, 'Humerothoracique'; 'ROM HG moins HT', 1, ''; 'Changement thorax', 0, ''; 'Thorax au repos', -1, ''};
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    for iv = 1:size(pairVars, 1)
        op = NaN(size(numA)); he = NaN(size(numA));
        for j = find(inP)
            op(j) = operatedValue(P, K, Kt, iP(j), td, pairVars(iv, :), sfx.(sessA{j}), metricDef);
        end
        he(:) = healthyValue(Ka, Kta, td, pairVars(iv, :), metricDef);
        for sc = {'Toutes', 'POST'}
            sel = inP & ~isnan(op) & ~isnan(he);
            if strcmp(sc{1}, 'POST'), sel = sel & strcmp(sessA, 'POST'); end
            k = numel(Pair) + 1;
            Pair(k).Task = upper(td.key); Pair(k).Movement = td.label; Pair(k).Variable = pairVars{iv, 1};
            Pair(k).Sessions = sc{1}; Pair(k).n = sum(sel);
            Pair(k).Operated_mean = mean(op(sel)); Pair(k).Healthy_mean = mean(he(sel));
            [Pair(k).Diff_OperatedMinusHealthy, Pair(k).Diff_CI95_low, Pair(k).Diff_CI95_high, Pair(k).p_paired] = ...
                meanCI(op(sel) - he(sel));
            Pair(k).Operated_pct_of_healthy = NaN;
            if startsWith(pairVars{iv, 1}, {'Pic', 'ROM HG', 'ROM HT'}) && ~contains(pairVars{iv, 1}, 'moins')
                Pair(k).Operated_pct_of_healthy = mean(100 * op(sel) ./ he(sel));
            end
        end
        % Figure : lignes appariées, pic HG, pic HT, HG moins HT
        c = find(strcmp(pairVars{iv, 1}, {'Pic HG', 'Pic HT', 'ROM HG moins HT'}));
        if isempty(c), continue; end
        figure(figC); subplot(numel(taskDef), 3, (iT - 1) * 3 + c); hold on;
        sel = inP & ~isnan(op) & ~isnan(he);
        for j = find(sel)
            plot([1 2], [he(j) op(j)], '-', 'Color', [0.6 0.6 0.6 0.6]);
        end
        scatter(ones(1, sum(sel)), he(sel), 22, cols(3, :), 'filled');
        isPost = strcmp(sessA, 'POST');
        scatter(2 * ones(1, sum(sel & isPost)), op(sel & isPost), 22, cols(2, :), 'filled');
        scatter(2 * ones(1, sum(sel & ~isPost)), op(sel & ~isPost), 22, cols(1, :), 'filled');
        r = Pair(numel(Pair) - 1);
        hold off; box on; xlim([0.6 2.4]);
        set(gca, 'XTick', [1 2], 'XTickLabel', {'côté sain', 'côté opéré (PRE ou POST)'});
        ylabel(sprintf('%s, %s (deg)', pairVars{iv, 1}, td.label));
        title({sprintf('Même patient, même session (n=%d) : opéré moins sain %+.1f° [%.1f ; %.1f] (%s)', ...
               r.n, r.Diff_OperatedMinusHealthy, r.Diff_CI95_low, r.Diff_CI95_high, fmtP(r.p_paired))}, 'FontSize', 7);
    end
end
figure(figC);
sgtitle(figC, {'Même patient, même session : côté opéré vs côté sain, flexion (ligne 1), scaption (ligne 2)', ...
    'Pic HG | pic HT | HG moins HT (ROM)'}, 'FontSize', 10);
footnote(figC, sprintf(['Données : %s. Côté opéré PRE (orange) ou POST (bleu) de la session de l''épaule saine ', ...
    '(vert), t apparié. Élévations bilatérales : thorax commun aux deux côtés.'], getFileName(DataFile)));

% -------------------------------------------------------------------------
% 3) POSTURE ET ÉPAULE SAINE
% -------------------------------------------------------------------------
Post = struct('Task', {}, 'Movement', {}, 'Posture', {}, 'Outcome', {}, 'Group', {}, 'n', {}, ...
    'Pearson_r', {}, 'r_CI95_low', {}, 'r_CI95_high', {}, 'Pearson_p', {}, 'Slope_deg_per_deg', {});
figP = figure('Name', 'Posture et épaule saine', 'Color', 'w');
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    for ip = 1:numel(postLbl)
        for oc = {'Pic HG', 'Pic HT', 'ROM HG', 'ROM HT', 'Deficit pic HG'}
            for g = [2 3]
                if strcmp(oc{1}, 'Deficit pic HG')
                    if g == 2, continue; end
                    % opéré moins sain, même session, vs posture de la session
                    y = NaN(size(numA));
                    for j = find(inP)
                        y(j) = operatedValue(P, K, Kt, iP(j), td, {'', 2, 'Humerogravitaire'}, sfx.(sessA{j}), metricDef) ...
                             - healthyValue(Ka, Kta, td, {'', 2, 'Humerogravitaire'}, metricDef, j);
                    end
                    x = postA{ip};
                else
                    iM = 1 + startsWith(oc{1}, 'Pic');
                    joint = 'Humerothoracique'; if contains(oc{1}, 'HG'), joint = 'Humerogravitaire'; end
                    y = kin(iM, td, joint, g);
                    if g == 3, x = postA{ip}; else, x = postP{ip}; end
                end
                v = ~isnan(x) & ~isnan(y);
                k = numel(Post) + 1;
                Post(k).Task = upper(td.key); Post(k).Movement = td.label; Post(k).Posture = postLbl{ip};
                Post(k).Outcome = oc{1}; Post(k).Group = grpName{g}; Post(k).n = sum(v);
                [Post(k).Pearson_r, Post(k).Pearson_p] = pearsonP(x(v), y(v));
                [Post(k).r_CI95_low, Post(k).r_CI95_high] = fisherCI(Post(k).Pearson_r, sum(v));
                Post(k).Slope_deg_per_deg = NaN;
                if sum(v) > 2, cc = polyfit(x(v), y(v), 1); Post(k).Slope_deg_per_deg = cc(1); end
            end
        end
        % Figure : pic HG vs posture, rTSA POST et saines
        subplot(numel(taskDef), numel(postLbl), (iT - 1) * numel(postLbl) + ip); hold on;
        txt = {};
        for g = [2 3]
            y = kin(2, td, 'Humerogravitaire', g);
            if g == 3, x = postA{ip}; else, x = postP{ip}; end
            v = ~isnan(x) & ~isnan(y);
            scatter(x(v), y(v), 10 + 16 * (g == 3), cols(g, :), 'filled', 'MarkerFaceAlpha', 0.55, 'DisplayName', grpLbl{g});
            addFit(x(v), y(v), cols(g, :));
            r = Post(find(strcmpi({Post.Task}, td.key) & strcmp({Post.Posture}, postLbl{ip}) & ...
                strcmp({Post.Outcome}, 'Pic HG') & strcmp({Post.Group}, grpName{g}), 1));
            txt{end+1} = sprintf('%s : r=%.2f [%.2f ; %.2f] (%s), n=%d', grpLbl{g}, r.Pearson_r, ...
                r.r_CI95_low, r.r_CI95_high, fmtP(r.Pearson_p), r.n); %#ok<AGROW>
        end
        hold off; box on; legend('Location', 'southwest', 'FontSize', 7);
        xlabel(sprintf('%s (deg)', postLbl{ip})); ylabel(sprintf('Pic HG, %s (deg)', td.label));
        title(txt, 'FontSize', 7);
    end
end
sgtitle(figP, {'Posture et élévation : épaules rTSA POST (posture PRE) vs épaules saines (posture de la session)', ...
    'flexion (ligne 1), scaption (ligne 2)'}, 'FontSize', 10);
footnote(figP, sprintf(['Données : %s. Pearson, IC 95 %% de Fisher. Avec 26 épaules saines, seules des ', ...
    'corrélations d''environ 0.5 ou plus sont détectables : résultats exploratoires.'], getFileName(DataFile)));

% -------------------------------------------------------------------------
% EXPORT
% -------------------------------------------------------------------------
if ~isempty(OutputFile)
    writetable(struct2table(Ref),  OutputFile, 'Sheet', 'Asym_Reference');
    writetable(struct2table(Pair), OutputFile, 'Sheet', 'Asym_Paired');
    writetable(struct2table(Post), OutputFile, 'Sheet', 'Asym_Posture');
    disp(['Feuilles Asym_Reference, Asym_Paired, Asym_Posture écrites : ', OutputFile]);
end

end

% =========================================================================
%  ACCÈS AUX VALEURS
% =========================================================================
% Joint d'une tâche/métrique : patients (g = PRE/POST, alignés sur numP)
% ou épaules saines (g = ASYM, ordre de la feuille _Asym)
function v = kinValue(K, Ka, numP, md, td, joint, g)
iM = 1 + strcmp(md.key, 'MAX');
if strcmp(g, 'ASYM')
    v = getCol(Ka{iM}, sprintf('%s_%s_%s_Asym', td.key, md.key, joint));
else
    sf = '_Pre'; if strcmp(g, 'POST'), sf = '_Post'; end
    v = alignCol(K{iM}, sprintf('%s_%s_%s%s', td.key, md.key, joint, sf), numP);
end
end

% Changement du thorax pendant le geste (> 0 = le tronc se redresse)
function v = txValue(Kt, Kta, numP, td, g)
if strcmp(g, 'ASYM')
    v = getCol(Kta, sprintf('%s_TXflex_Change_Asym', td.key));
else
    sf = '_Pre'; if strcmp(g, 'POST'), sf = '_Post'; end
    v = alignCol(Kt, sprintf('%s_TXflex_Change%s', td.key, sf), numP);
end
end

% Variable de la feuille de référence (libellé -> valeurs)
function v = refVar(name, kin, txc, td, g)
iM = 1 + startsWith(name, 'Pic');
switch regexprep(name, '^(ROM|Pic) ', '')
    case 'HG',          v = kin(iM, td, 'Humerogravitaire', g);
    case 'HT',          v = kin(iM, td, 'Humerothoracique', g);
    case 'HG moins HT', v = kin(iM, td, 'Humerogravitaire', g) - kin(iM, td, 'Humerothoracique', g);
    case 'thorax',      v = kin(iM, td, 'Thoracique', g);
    otherwise,          v = txc(td, g);   % 'Changement thorax'
end
end

% Côté opéré (ligne iRow de Data_posture), session de l'épaule saine.
% spec = {libellé, métrique (2 = pic, 1 = ROM, 0 = changement thorax,
% -1 = thorax au repos), joint}
function v = operatedValue(P, K, Kt, iRow, td, spec, sf, metricDef) %#ok<INUSL>
switch spec{2}
    case 0,  v = getCol(Kt, sprintf('%s_TXflex_Change%s', td.key, sf));
    case -1, v = getCol(Kt, sprintf('%s_TXflex_Start%s', td.key, sf));
    otherwise
        md = metricDef(spec{2});
        if isempty(spec{3})
            v = getCol(K{spec{2}}, sprintf('%s_%s_Humerogravitaire%s', td.key, md.key, sf)) ...
              - getCol(K{spec{2}}, sprintf('%s_%s_Humerothoracique%s', td.key, md.key, sf));
        else
            v = getCol(K{spec{2}}, sprintf('%s_%s_%s%s', td.key, md.key, spec{3}, sf));
        end
end
v = v(iRow);
end

% Côté sain (toutes les épaules, ou la j-ième si j est donné)
function v = healthyValue(Ka, Kta, td, spec, metricDef, j)
switch spec{2}
    case 0,  v = getCol(Kta, sprintf('%s_TXflex_Change_Asym', td.key));
    case -1, v = getCol(Kta, sprintf('%s_TXflex_Start_Asym', td.key));
    otherwise
        md = metricDef(spec{2});
        if isempty(spec{3})
            v = getCol(Ka{spec{2}}, sprintf('%s_%s_Humerogravitaire_Asym', td.key, md.key)) ...
              - getCol(Ka{spec{2}}, sprintf('%s_%s_Humerothoracique_Asym', td.key, md.key));
        else
            v = getCol(Ka{spec{2}}, sprintf('%s_%s_%s_Asym', td.key, md.key, spec{3}));
        end
end
if nargin > 5, v = v(j); end
end

% =========================================================================
%  STATISTIQUES
% =========================================================================
% Welch : différence a moins b, p bilatéral (df de Satterthwaite), g de
% Hedges (écart-type poolé, correction des petits effectifs)
function [d, p, g] = welchT(a, b)
a = a(~isnan(a)); b = b(~isnan(b));
d = NaN; p = NaN; g = NaN;
na = numel(a); nb = numel(b);
if na < 2 || nb < 2, return; end
d  = mean(a) - mean(b);
va = var(a) / na; vb = var(b) / nb;
df = (va + vb)^2 / (va^2 / (na - 1) + vb^2 / (nb - 1));
p  = tPval(d / sqrt(va + vb), df);
sp = sqrt(((na - 1) * var(a) + (nb - 1) * var(b)) / (na + nb - 2));
g  = d / sp * (1 - 3 / (4 * (na + nb) - 9));
end

% IC 95 % d'une corrélation (transformation de Fisher)
function [lo, hi] = fisherCI(r, n)
lo = NaN; hi = NaN;
if isnan(r) || n < 4, return; end
z = atanh(r); se = 1 / sqrt(n - 3);
lo = tanh(z - 1.959964 * se); hi = tanh(z + 1.959964 * se);
end

% Moyenne, IC 95 % et p bilatéral vs 0 (t à un échantillon / apparié)
function [m, lo, hi, p] = meanCI(d)
d = d(~isnan(d)); n = numel(d);
m = NaN; lo = NaN; hi = NaN; p = NaN;
if n < 2, return; end
m  = mean(d); se = std(d) / sqrt(n);
tc = tInv975(n - 1);
lo = m - tc * se; hi = m + tc * se;
if se > 0, p = tPval(m / se, n - 1); end
end

% Corrélation de Pearson + p bilatéral (Student, df = n-2)
function [r, p] = pearsonP(x, y)
r = NaN; p = NaN;
n = numel(x);
if n < 3 || std(x) == 0 || std(y) == 0, return; end
cc = corrcoef(x, y);
r  = cc(1, 2);
df = n - 2;
if abs(r) >= 1, p = 0; return; end
p  = tPval(r * sqrt(df / (1 - r^2)), df);
end

% p bilatéral d'une statistique t (Student, df), via betainc
function p = tPval(t, df)
p = betainc(df / (df + t^2), df / 2, 0.5);
end

% Quantile 97.5 % de la loi de Student (df), par dichotomie sur tPval
function t = tInv975(df)
lo = 0; hi = 50;
for it = 1:100
    t = (lo + hi) / 2;
    if tPval(t, df) > 0.05, lo = t; else, hi = t; end
end
end

function s = fmtP(p)
if isnan(p),       s = 'p=NA';
elseif p < 0.001,  s = 'p<0.001';
else,              s = sprintf('p=%.3f', p);
end
end

% =========================================================================
%  FIGURES
% =========================================================================
% Points individuels (jitter) + médiane (trait épais) + écart interquartile
function drawDots(vals, cols)
for g = 1:numel(vals)
    v = vals{g}(~isnan(vals{g}));
    if isempty(v), continue; end
    x = g + 0.15 * (rand(size(v)) - 0.5) * 2;
    scatter(x, v, 10 + 14 * (g == numel(vals)), cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5);
    q = quartiles(v);
    plot([g g], q([1 3]), '-k', 'LineWidth', 2);
    plot(g + [-0.25 0.25], [q(2) q(2)], '-k', 'LineWidth', 3);
end
end

function q = quartiles(v)
v = sort(v(:));
if isscalar(v), q = [v v v]; return; end
p = ((1:numel(v)) - 0.5) / numel(v);
q = interp1(p, v, [0.25 0.5 0.75], 'linear', 'extrap');
q = min(max(q, v(1)), v(end));
end

function addFit(x, y, col)
if numel(x) < 2 || std(x) == 0, return; end
c = polyfit(x, y, 1); xx = [min(x) max(x)];
plot(xx, polyval(c, xx), 'Color', col * 0.7, 'LineWidth', 2, 'HandleVisibility', 'off');
end

function footnote(fig, s)
annotation(fig, 'textbox', [0 0 1 0.03], 'String', s, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontSize', 7, 'Interpreter', 'none');
end

% =========================================================================
%  LECTURE EXCEL (mêmes règles que CorrelatePostureROM.m)
% =========================================================================
function T = readSheet(DataFile, sheet)
T = readtable(DataFile, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
T = T(~isnan(getCol(T, 'Numero')), :);
end

function v = getCol(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('AsymptomaticComparison:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', ...
        name, strjoin(names, ', '));
end
v = T.(names{j});
if iscell(v) || isstring(v)
    v = str2double(strrep(string(v), ',', '.'));
end
v = double(v(:)');
end

function v = getText(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('AsymptomaticComparison:missingColumn', 'Colonne "%s" introuvable.', name);
end
v = cellstr(string(T.(names{j})));
v = v(:)';
end

function v = alignCol(T, name, numRef)
num = getCol(T, 'Numero');
x   = getCol(T, name);
[tf, loc] = ismember(numRef, num);
v = NaN(size(numRef));
v(tf) = x(loc(tf));
end

function s = getFileName(f)
[~, nm, ext] = fileparts(f);
s = [nm, ext];
end
