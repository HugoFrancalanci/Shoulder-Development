% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Deux analyses sur l'inclinaison thoracique PRE, à partir de
%                l'Excel trié à la main (Data_posture.xlsx, mêmes feuilles que
%                CorrelatePostureROM.m), pour proposer une classification
%                posturale simplifiée face à celle de Moroder.
%
%                1) STRATIFICATION (inclinaison debout et assis)
%                   a) Construction « à la Moroder » : ses seuils A | B | C
%                      (36 et 46°) correspondent à la moyenne ± 1 SD de la SIR
%                      de sa cohorte (Moroder 2020, Fig. 7). Même construction
%                      sur l'inclinaison : I-A < moyenne - SD ≤ I-B ≤
%                      moyenne + SD < I-C.
%                   b) Vérification par les données : k-means 1D exact
%                      (programmation dynamique), % de variance expliquée pour
%                      k = 2 à 5 (coude) et seuils pour k = 3 ; mélange de
%                      gaussiennes 1D (EM) pour k = 1 à 4, choix par BIC (une
%                      seule composante = continuum, pas de groupes naturels).
%                   c) Concordance avec Moroder : proportions, kappa de Cohen
%                      entre types d'inclinaison et types A/B/C (SIR).
%                   d) Élévation POST par type (pic et ROM, HG et HT,
%                      flexion et scaption) : moyenne ± SD par type, Kruskal-
%                      Wallis (p, epsilon²), écart moyen type 3 - type 1 (comme
%                      C - A chez Moroder). Classifications comparées :
%                      inclinaison debout et assis (moyenne ± SD), k-means
%                      k = 3 (debout), Moroder A/B/C.
%
%                2) SEUIL CRITIQUE (inclinaison debout et assis, SIR en
%                   comparaison)
%                   Mauvais résultat = pic d'élévation HG POST < 90° (bras sous
%                   l'horizontale ; HG est mesuré par rapport à la gravité).
%                   a) ROC : AUC (Mann-Whitney) et IC 95 % bootstrap, seuil de
%                      Youden et IC 95 % bootstrap, sensibilité, spécificité,
%                      VPP, VPN.
%                   b) Régression segmentée HG POST ~ inclinaison (charnière
%                      y = a + b x + c max(0, x - tau), tau par grille entre les
%                      percentiles 10 et 90) : test F approché contre la droite,
%                      IC 95 % bootstrap de tau.
%                   c) % de mauvais résultats par tranche de 5° d'inclinaison.
%
%                Sans Statistics Toolbox (EM, k-means, ROC, Kruskal-Wallis et
%                bootstrap codés ici). Bootstrap : 2000 tirages, rng(1).
%                Textes des figures sans tiret ni tiret long.
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie ; '' = pas d'export
% Outputs : Out (struct) .Clusters .Types .Kappa .Outcomes .ROC .Hinge .Bins
%           (tables) + 2 figures (stratification, seuil critique, sur
%           l'inclinaison debout)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Out = InclinationClassification(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end
rng(1);
NBOOT  = 2000;
BAD    = 90;     % deg : pic HG POST sous l'horizontale = mauvais résultat
MAG    = [0.894 0.173 0.463];
TYPCOL = [0.10 0.10 0.70; 0.40 0.85 0.10; 0.75 0.10 0.10];   % comme la Figure 7 de Moroder

% ------------------------------------------------------------------ lecture
P    = readSheet(DataFile, 'Posture');
num  = getCol(P, 'Numero');
post = struct('name',  {'InclinaisonDebout', 'InclinaisonAssis'}, ...
              'col',   {'Inclinaison_thoracique_Pre_Calibration3', 'Inclinaison_thoracique_Pre'}, ...
              'label', {'Inclinaison thoracique debout PRE (deg)', 'Inclinaison thoracique assis PRE (deg)'});
for i = 1:numel(post), post(i).x = getCol(P, post(i).col); end
sir = getCol(P, 'Rotation_scapulaire_interne_Pre');
mor = getText(P, 'Moroder_type_pre');
morType = NaN(size(num));
morType(strcmpi(mor, 'A')) = 1; morType(strcmpi(mor, 'B')) = 2; morType(strcmpi(mor, 'C')) = 3;

Kr = readSheet(DataFile, 'Cinematique');
Kp = readSheet(DataFile, 'Cinematique_pics');
tasks = struct('key', {'analytic1', 'analytic2'}, 'label', {'flexion', 'scaption'});
outc = struct('name', {'Pic HG POST', 'Pic HT POST', 'ROM HG POST', 'ROM HT POST'}, ...
              'sheet', {'pics', 'pics', 'rom', 'rom'}, 'key', {'MAX', 'MAX', 'ROM', 'ROM'}, ...
              'joint', {'Humerogravitaire', 'Humerothoracique', 'Humerogravitaire', 'Humerothoracique'});
Y = struct();
for t = 1:numel(tasks)
    for o = 1:numel(outc)
        if strcmp(outc(o).sheet, 'pics'), K = Kp; else, K = Kr; end
        Y.(sprintf('%s_%d', tasks(t).key, o)) = alignCol(K, sprintf('%s_%s_%s_Post', tasks(t).key, outc(o).key, outc(o).joint), num);
    end
end

% ------------------------------------------------------------------ 1) stratification
Clusters = table(); Types = table(); Kappa = table();
clsf = struct('name', {}, 'type', {});
for i = 1:numel(post)
    x = post(i).x; v = ~isnan(x);
    mu = mean(x(v)); sd = std(x(v));
    thr = [mu - sd, mu + sd];
    ty = NaN(size(x)); ty(v) = 1 + (x(v) >= thr(1)) + (x(v) > thr(2));
    % k-means 1D exact et mélange de gaussiennes
    [wss, cuts3] = kmeans1d(x(v), 5);
    tss = sum((x(v) - mu).^2);
    bic = NaN(1, 4);
    for k = 1:4, bic(k) = gmm1dBIC(x(v), k); end
    [~, kBIC] = min(bic);
    for k = 1:5
        Clusters = [Clusters; table(string(post(i).name), k, 100 * (1 - wss(k) / tss), ...
            iff(k <= 4, bic(min(k, 4)), NaN), k == kBIC, ...
            'VariableNames', {'Variable', 'k', 'KMeans_VarianceExpliquee_pct', 'GMM_BIC', 'GMM_BIC_min'})]; %#ok<AGROW>
    end
    tyK = NaN(size(x)); tyK(v) = 1 + (x(v) > cuts3(1)) + (x(v) > cuts3(2));
    Types = [Types; table(string(post(i).name), mu, sd, thr(1), thr(2), cuts3(1), cuts3(2), ...
        100 * mean(ty(v) == 1), 100 * mean(ty(v) == 2), 100 * mean(ty(v) == 3), kBIC, ...
        'VariableNames', {'Variable', 'Moyenne', 'SD', 'Seuil_1_moyenne_moins_SD', 'Seuil_2_moyenne_plus_SD', ...
                          'KMeans3_seuil_1', 'KMeans3_seuil_2', 'Pct_type1', 'Pct_type2', 'Pct_type3', 'GMM_k_BIC'})]; %#ok<AGROW>
    [kap, cm] = cohenKappa(ty, morType);
    Kappa = [Kappa; table(string(post(i).name), "moyenne ± SD", kap, {cm}, ...
        'VariableNames', {'Variable', 'Construction', 'Kappa_vs_Moroder', 'Tableau_lignes_incl_colonnes_Moroder'})]; %#ok<AGROW>
    post(i).mu = mu; post(i).sd = sd; post(i).thr = thr; post(i).ty = ty; post(i).cuts3 = cuts3;
    post(i).tyK = tyK; post(i).wss = wss; post(i).tss = tss; post(i).bic = bic; post(i).kap = kap; post(i).cm = cm;
    clsf(end+1) = struct('name', sprintf('%s (moyenne ± SD)', post(i).name), 'type', ty); %#ok<AGROW>
    if i == 1
        clsf(end+1) = struct('name', sprintf('%s (k-means k=3)', post(i).name), 'type', tyK); %#ok<AGROW>
    end
end
clsf(end+1) = struct('name', 'Moroder A/B/C (SIR)', 'type', morType);

Outcomes = table();
for c = 1:numel(clsf)
    for t = 1:numel(tasks)
        for o = 1:numel(outc)
            y = Y.(sprintf('%s_%d', tasks(t).key, o));
            g = clsf(c).type; v = ~isnan(g) & ~isnan(y);
            m = NaN(1, 3); s = NaN(1, 3); nn = zeros(1, 3);
            for k = 1:3, yy = y(v & g == k); nn(k) = numel(yy); m(k) = mean(yy); s(k) = std(yy); end
            [H, pKW, eps2] = kruskalWallis(y(v), g(v));
            Outcomes = [Outcomes; table(string(clsf(c).name), string(tasks(t).label), string(outc(o).name), ...
                nn(1), nn(2), nn(3), m(1), s(1), m(2), s(2), m(3), s(3), m(3) - m(1), H, pKW, eps2, ...
                'VariableNames', {'Classification', 'Tache', 'Outcome', 'n1', 'n2', 'n3', 'Moy1', 'SD1', 'Moy2', 'SD2', ...
                                  'Moy3', 'SD3', 'Ecart_3_moins_1', 'KW_H', 'KW_p', 'Epsilon2'})]; %#ok<AGROW>
        end
    end
end

% ------------------------------------------------------------------ 2) seuil critique
preds = struct('name', {'InclinaisonDebout', 'InclinaisonAssis', 'SIR'}, 'x', {post(1).x, post(2).x, sir});
ROC = table(); Hinge = table(); Bins = table(); rocCurves = struct();
for t = 1:numel(tasks)
    y = Y.(sprintf('%s_1', tasks(t).key));       % pic HG POST
    for p = 1:numel(preds)
        x = preds(p).x; v = ~isnan(x) & ~isnan(y);
        bad = y(v) < BAD; xv = x(v);
        [auc, thr, se, sp, fpr, tpr] = rocYouden(xv, bad);
        bA = NaN(NBOOT, 1); bT = NaN(NBOOT, 1); nv = numel(xv);
        for b = 1:NBOOT
            ii = randi(nv, nv, 1);
            if all(bad(ii)) || ~any(bad(ii)), continue; end
            [bA(b), bT(b)] = rocYouden(xv(ii), bad(ii));
        end
        ciA = prctile_(bA, [2.5 97.5]); ciT = prctile_(bT, [2.5 97.5]);
        ppv = mean(bad(xv >= thr)); npv = mean(~bad(xv < thr));
        ROC = [ROC; table(string(tasks(t).label), string(preds(p).name), nv, sum(bad), 100 * mean(bad), ...
            auc, ciA(1), ciA(2), thr, ciT(1), ciT(2), se, sp, ppv, npv, ...
            'VariableNames', {'Tache', 'Predicteur', 'n', 'n_mauvais', 'Prevalence_pct', 'AUC', 'AUC_IC_bas', 'AUC_IC_haut', ...
                              'Seuil_Youden', 'Seuil_IC_bas', 'Seuil_IC_haut', 'Sensibilite', 'Specificite', 'VPP', 'VPN'})]; %#ok<AGROW>
        rocCurves.(sprintf('%s_%d', tasks(t).key, p)) = struct('fpr', fpr, 'tpr', tpr, 'auc', auc, 'thr', thr);
        if p == 3, continue; end
        % régression segmentée
        yv = y(v);
        [tau, cf, Fst, pF, sse0, sse1] = hingeFit(xv, yv);
        bTau = NaN(NBOOT, 1);
        for b = 1:NBOOT
            ii = randi(nv, nv, 1); bTau(b) = hingeFit(xv(ii), yv(ii));
        end
        ciTau = prctile_(bTau, [2.5 97.5]);
        Hinge = [Hinge; table(string(tasks(t).label), string(preds(p).name), nv, tau, ciTau(1), ciTau(2), ...
            cf(2), cf(2) + cf(3), Fst, pF, 1 - sse1 / sse0, ...
            'VariableNames', {'Tache', 'Predicteur', 'n', 'Cassure_deg', 'Cassure_IC_bas', 'Cassure_IC_haut', ...
                              'Pente_avant_deg_par_deg', 'Pente_apres_deg_par_deg', 'F_vs_droite', 'p_F_approche', ...
                              'Reduction_SSE'})]; %#ok<AGROW>
        % tranches de 5°
        edges = 0:5:50;
        for e = 1:numel(edges) - 1
            in = xv >= edges(e) & xv < edges(e + 1);
            if ~any(in), continue; end
            Bins = [Bins; table(string(tasks(t).label), string(preds(p).name), edges(e), edges(e + 1), sum(in), ...
                100 * mean(bad(in)), mean(yv(in)), ...
                'VariableNames', {'Tache', 'Predicteur', 'De_deg', 'A_deg', 'n', 'Pct_mauvais', 'Pic_HG_POST_moyen'})]; %#ok<AGROW>
        end
        if p == 1
            post(1).hinge.(tasks(t).key) = struct('tau', tau, 'cf', cf, 'pF', pF, 'ciTau', ciTau);
        end
    end
end

% ------------------------------------------------------------------ figures
plotStratification(post(1), morType, Y, tasks, TYPCOL, MAG, DataFile);
plotThreshold(post(1), Y, tasks, BAD, ROC, Bins, rocCurves, MAG, DataFile);

% ------------------------------------------------------------------ export
Out = struct('Clusters', Clusters, 'Types', Types, 'Kappa', Kappa(:, 1:3), 'Outcomes', Outcomes, ...
             'ROC', ROC, 'Hinge', Hinge, 'Bins', Bins);
if ~isempty(OutputFile)
    if isfile(OutputFile), delete(OutputFile); end
    writetable(Clusters, OutputFile, 'Sheet', 'Strat_Clusters');
    writetable(Types,    OutputFile, 'Sheet', 'Strat_Types');
    writetable(Kappa(:, 1:3), OutputFile, 'Sheet', 'Strat_Kappa');
    writetable(Outcomes, OutputFile, 'Sheet', 'Strat_Outcomes');
    writetable(ROC,      OutputFile, 'Sheet', 'Seuil_ROC');
    writetable(Hinge,    OutputFile, 'Sheet', 'Seuil_Cassure');
    writetable(Bins,     OutputFile, 'Sheet', 'Seuil_Tranches');
    disp(['Classification de l''inclinaison exportée : ', OutputFile]);
end
end

% =========================================================================
%  FIGURES
% =========================================================================
function plotStratification(pd, morType, Y, tasks, TYPCOL, MAG, DataFile)
x = pd.x; v = ~isnan(x); xv = x(v);
fig = figure('Name', 'Stratification de l''inclinaison thoracique debout', 'Color', 'w');
% 1 : distribution, construction moyenne ± SD (cf. Moroder Fig. 7) et seuils k-means
subplot(2, 3, 1); hold on;
BinW = 2.5; histogram(xv, 'BinWidth', BinW, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', [0.7 0.7 0.7], 'HandleVisibility', 'off');
xs = linspace(max(0, pd.mu - 4 * pd.sd), pd.mu + 4 * pd.sd, 500);
ys = numel(xv) * BinW * exp(-0.5 * ((xs - pd.mu) / pd.sd).^2) / (pd.sd * sqrt(2 * pi));
seg = {xs <= pd.thr(1), xs >= pd.thr(1) & xs <= pd.thr(2), xs >= pd.thr(2)};
nm = {'I-A', 'I-B', 'I-C'};
for k = 1:3, plot(xs(seg{k}), ys(seg{k}), 'Color', TYPCOL(k, :), 'LineWidth', 3, 'DisplayName', nm{k}); end
xline(pd.thr(1), '--k', 'HandleVisibility', 'off'); xline(pd.thr(2), '--k', 'HandleVisibility', 'off');
xline(pd.cuts3(1), ':', 'Color', MAG, 'LineWidth', 1.5, 'DisplayName', 'seuils k-means (k=3)');
xline(pd.cuts3(2), ':', 'Color', MAG, 'LineWidth', 1.5, 'HandleVisibility', 'off');
hold off; box on; legend('Location', 'northeast', 'FontSize', 7);
xlabel(pd.label); ylabel('Nombre de patients');
pct = 100 * [mean(pd.ty(v) == 1), mean(pd.ty(v) == 2), mean(pd.ty(v) == 3)];
title({sprintf('Moyenne ± SD : %.1f ± %.1f° (seuils %.1f et %.1f°)', pd.mu, pd.sd, pd.thr(1), pd.thr(2)), ...
       sprintf('I-A %.0f %% | I-B %.0f %% | I-C %.0f %% ; k-means : %.1f et %.1f°', pct, pd.cuts3(1), pd.cuts3(2))}, 'FontSize', 8);
% 2 : nombre de groupes
subplot(2, 3, 2);
yyaxis left; plot(1:5, 100 * (1 - pd.wss / pd.tss), '-o', 'LineWidth', 1.5); ylabel('Variance expliquée k-means (%)'); ylim([0 100]);
yyaxis right; plot(1:4, pd.bic, '-s', 'LineWidth', 1.5); ylabel('BIC mélange de gaussiennes');
xlabel('Nombre de groupes k'); xticks(1:5); box on; grid on;
[~, kb] = min(pd.bic);
title({'Combien de groupes ?', sprintf('BIC minimal pour k = %d (1 = continuum, pas de groupes naturels)', kb)}, 'FontSize', 8);
% 3 : concordance avec Moroder
subplot(2, 3, 3);
imagesc(pd.cm); colormap(gca, [linspace(1, MAG(1), 64)' linspace(1, MAG(2), 64)' linspace(1, MAG(3), 64)']);
for i = 1:3
    for j = 1:3
        text(j, i, sprintf('%d', pd.cm(i, j)), 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end
xticks(1:3); xticklabels({'A', 'B', 'C'}); yticks(1:3); yticklabels(nm);
xlabel('Type de Moroder (SIR)'); ylabel('Type d''inclinaison debout'); axis square;
title({'Concordance avec Moroder', sprintf('kappa de Cohen = %.2f', pd.kap)}, 'FontSize', 8);
% 4 à 6 : pic HG POST par type
lab = {sprintf('%s, flexion', 'Pic HG POST'), sprintf('%s, scaption', 'Pic HG POST'), 'Pic HG POST, scaption'};
grp = {pd.ty, pd.ty, morType}; gn = {nm, nm, {'A', 'B', 'C'}};
tk = {tasks(1).key, tasks(2).key, tasks(2).key};
for s = 1:3
    subplot(2, 3, 3 + s); hold on;
    y = Y.(sprintf('%s_1', tk{s})); g = grp{s}; vv = ~isnan(g) & ~isnan(y);
    tl = gn{s};
    for k = 1:3
        yy = y(vv & g == k);
        if isempty(yy), continue; end
        scatter(k + 0.18 * (rand(size(yy)) - 0.5), yy, 14, TYPCOL(k, :), 'filled', 'MarkerFaceAlpha', 0.45);
        plot(k + [-0.25 0.25], median(yy) * [1 1], 'k', 'LineWidth', 2.5);
        tl{k} = sprintf('%s (n=%d, %.0f°)', tl{k}, numel(yy), mean(yy));
    end
    yline(90, ':k'); hold off; box on; xlim([0.5 3.5]); xticks(1:3); xticklabels(tl);
    [~, pKW] = kruskalWallis(y(vv), g(vv));
    m1 = mean(y(vv & g == 1)); m3 = mean(y(vv & g == 3));
    if s < 3, ttl = 'Par type d''inclinaison debout'; else, ttl = 'Par type de Moroder (SIR)'; end
    ylabel([lab{s}, ' (deg)']);
    title({ttl, sprintf('Kruskal-Wallis %s ; écart type 3 vs 1 : %.0f°', fmtP(pKW), m3 - m1)}, 'FontSize', 8);
end
sgtitle('Stratification de l''inclinaison thoracique debout : construction à la Moroder (moyenne ± 1 SD) et vérification par les données');
annotation(fig, 'textbox', [0 0 1 0.03], 'String', sprintf(['Données : %s. Moroder 2020 : types A | B | C ', ...
    'aux seuils 36 et 46°, soit la moyenne ± 1 SD de la SIR (Figure 7). Trait noir : médiane ; valeur : moyenne.'], getFileName(DataFile)), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 7, 'Interpreter', 'none');
end

function plotThreshold(pd, Y, tasks, BAD, ROC, Bins, rocCurves, MAG, DataFile)
fig = figure('Name', 'Seuil critique d''inclinaison thoracique', 'Color', 'w');
pc = {MAG, [0.45 0.45 0.45], [0.10 0.45 0.70]}; pn = {'Inclinaison debout', 'Inclinaison assis', 'SIR'};
for t = 1:numel(tasks)
    y = Y.(sprintf('%s_1', tasks(t).key)); x = pd.x; v = ~isnan(x) & ~isnan(y);
    R = ROC(ROC.Tache == tasks(t).label & ROC.Predicteur == "InclinaisonDebout", :);
    h = pd.hinge.(tasks(t).key);
    % nuage + charnière
    subplot(2, 3, (t - 1) * 3 + 1); hold on;
    bad = y(v) < BAD;
    scatter(x(v & y >= BAD), y(v & y >= BAD), 14, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', 'élévation ≥ 90°');
    scatter(x(v & y < BAD), y(v & y < BAD), 16, MAG, 'filled', 'MarkerFaceAlpha', 0.7, 'DisplayName', 'élévation < 90°');
    xx = linspace(min(x(v)), max(x(v)), 200);
    plot(xx, h.cf(1) + h.cf(2) * xx + h.cf(3) * max(0, xx - h.tau), 'k', 'LineWidth', 2, 'DisplayName', 'régression segmentée');
    yline(BAD, ':k', 'HandleVisibility', 'off');
    xline(R.Seuil_Youden, '--', 'Color', MAG, 'LineWidth', 1.5, 'DisplayName', 'seuil de Youden');
    hold off; box on; legend('Location', 'southwest', 'FontSize', 7);
    xlabel(pd.label); ylabel(sprintf('Pic HG POST, %s (deg)', tasks(t).label));
    title({sprintf('%d patients sur %d sous 90° (%.0f %%)', sum(bad), numel(bad), 100 * mean(bad)), ...
           sprintf('Cassure à %.1f° [IC95 %.1f ; %.1f], %s vs droite', h.tau, h.ciTau(1), h.ciTau(2), fmtP(h.pF))}, 'FontSize', 8);
    % ROC
    subplot(2, 3, (t - 1) * 3 + 2); hold on;
    plot([0 1], [0 1], ':k', 'HandleVisibility', 'off');
    for p = 1:3
        rc = rocCurves.(sprintf('%s_%d', tasks(t).key, p));
        plot(rc.fpr, rc.tpr, 'Color', pc{p}, 'LineWidth', 2, 'DisplayName', sprintf('%s : AUC %.2f', pn{p}, rc.auc));
    end
    hold off; box on; axis square; legend('Location', 'southeast', 'FontSize', 7);
    xlabel('1 moins spécificité'); ylabel('Sensibilité');
    title({sprintf('ROC, élévation < 90° en %s', tasks(t).label), ...
           sprintf('Debout : AUC %.2f [%.2f ; %.2f], seuil %.1f° [%.1f ; %.1f]', R.AUC, R.AUC_IC_bas, R.AUC_IC_haut, ...
                   R.Seuil_Youden, R.Seuil_IC_bas, R.Seuil_IC_haut)}, 'FontSize', 8);
    % tranches
    subplot(2, 3, (t - 1) * 3 + 3);
    B = Bins(Bins.Tache == tasks(t).label & Bins.Predicteur == "InclinaisonDebout", :);
    bar(B.De_deg + 2.5, B.Pct_mauvais, 0.9, 'FaceColor', MAG, 'EdgeColor', 'none');
    for b = 1:height(B)
        text(B.De_deg(b) + 2.5, B.Pct_mauvais(b) + 2, sprintf('n=%d', B.n(b)), 'HorizontalAlignment', 'center', 'FontSize', 7);
    end
    xline(R.Seuil_Youden, '--', 'Color', [0.3 0.3 0.3]); box on; ylim([0, max(B.Pct_mauvais) + 12]);
    xlabel(pd.label); ylabel('Patients sous 90° (%)');
    title({sprintf('Risque par tranche de 5°, %s', tasks(t).label), sprintf('Seuil de Youden %.1f° : sensibilité %.2f, spécificité %.2f', ...
           R.Seuil_Youden, R.Sensibilite, R.Specificite)}, 'FontSize', 8);
end
sgtitle('Seuil critique d''inclinaison thoracique debout : mauvais résultat = pic d''élévation HG POST sous 90° (bras sous l''horizontale)');
annotation(fig, 'textbox', [0 0 1 0.03], 'String', sprintf(['Données : %s. IC 95 %% par bootstrap (2000 tirages). ', ...
    'Régression segmentée : y = a + b x + c max(0, x moins cassure), test F approché.'], getFileName(DataFile)), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 7, 'Interpreter', 'none');
end

% =========================================================================
%  MÉTHODES
% =========================================================================
% k-means 1D exact (programmation dynamique) : SSE intra-groupes pour k = 1..K
% et seuils de la partition à 3 groupes (milieux entre groupes adjacents)
function [wss, cuts3] = kmeans1d(x, K)
x = sort(x(:)); n = numel(x);
s1 = [0; cumsum(x)]; s2 = [0; cumsum(x.^2)];
cost = @(i, j) (s2(j + 1) - s2(i)) - (s1(j + 1) - s1(i))^2 / (j - i + 1);
D = Inf(K, n); B = zeros(K, n);
for j = 1:n, D(1, j) = cost(1, j); end
for k = 2:K
    for j = k:n
        for i = k:j
            c = D(k - 1, i - 1) + cost(i, j);
            if c < D(k, j), D(k, j) = c; B(k, j) = i; end
        end
    end
end
wss = D(:, n)';
% partition à 3 groupes
j = n; st = zeros(1, 3);
for k = 3:-1:2, st(k) = B(k, j); j = st(k) - 1; end
st(1) = 1;
cuts3 = [(x(st(2) - 1) + x(st(2))) / 2, (x(st(3) - 1) + x(st(3))) / 2];
end

% BIC d'un mélange de k gaussiennes 1D (EM, plusieurs initialisations)
function bic = gmm1dBIC(x, k)
x = x(:); n = numel(x); best = -Inf; vfloor = 0.01 * var(x);
for rep = 1:20
    if rep == 1
        mu = quantile_(x, ((1:k) - 0.5) / k);
    else
        mu = x(randperm(n, k))';
    end
    sg = repmat(var(x), 1, k); w = ones(1, k) / k;
    for it = 1:500
        pdfs = w .* exp(-0.5 * (x - mu).^2 ./ sg) ./ sqrt(2 * pi * sg);
        tot = sum(pdfs, 2); r = pdfs ./ tot;
        nk = sum(r, 1) + eps;
        w = nk / n; mu = sum(r .* x, 1) ./ nk;
        sg = max(sum(r .* (x - mu).^2, 1) ./ nk, vfloor);
    end
    ll = sum(log(sum(w .* exp(-0.5 * (x - mu).^2 ./ sg) ./ sqrt(2 * pi * sg), 2)));
    best = max(best, ll);
end
bic = -2 * best + (3 * k - 1) * log(n);
end

% Kappa de Cohen entre deux classements 1..3 (NaN ignorés)
function [kap, cm] = cohenKappa(a, b)
v = ~isnan(a) & ~isnan(b); a = a(v); b = b(v); n = numel(a);
cm = zeros(3);
for i = 1:3, for j = 1:3, cm(i, j) = sum(a == i & b == j); end, end
po = trace(cm) / n; pe = sum(sum(cm, 2) .* sum(cm, 1)') / n^2;
kap = (po - pe) / (1 - pe);
end

% Kruskal-Wallis (rangs moyens, correction des ex-aequo), p via chi2
function [H, p, eps2] = kruskalWallis(y, g)
y = y(:); g = g(:); N = numel(y); r = rankTies(y);
gs = unique(g); H = 0;
for k = 1:numel(gs), rk = r(g == gs(k)); H = H + sum(rk)^2 / numel(rk); end
H = 12 / (N * (N + 1)) * H - 3 * (N + 1);
[~, ~, ic] = unique(y); t = accumarray(ic, 1);
H = H / (1 - sum(t.^3 - t) / (N^3 - N));
df = numel(gs) - 1;
p = 1 - gammainc(H / 2, df / 2);
eps2 = H / (N - 1);
end

% ROC pour « x élevé = mauvais résultat » : AUC (Mann-Whitney), seuil de
% Youden (sensibilité = P(x ≥ seuil | mauvais), spécificité = P(x < seuil | bon))
function [auc, thr, se, sp, fpr, tpr] = rocYouden(x, bad)
x = x(:); bad = logical(bad(:));
xb = x(bad); xg = x(~bad);
auc = (sum(xb > xg', 'all') + 0.5 * sum(xb == xg', 'all')) / (numel(xb) * numel(xg));
t = unique(x);
tpr = arrayfun(@(c) mean(xb >= c), t); fpr = arrayfun(@(c) mean(xg >= c), t);
[~, i] = max(tpr - fpr);
thr = t(i); se = tpr(i); sp = 1 - fpr(i);
tpr = [1; tpr; 0]; fpr = [1; fpr; 0];
end

% Régression segmentée (charnière) par grille sur tau
function [tau, cf, F, p, sse0, sse1] = hingeFit(x, y)
x = x(:); y = y(:); n = numel(x);
X0 = [ones(n, 1) x]; b0 = X0 \ y; sse0 = sum((y - X0 * b0).^2);
grid = prctile_(x, 10):0.25:prctile_(x, 90);
sse1 = Inf; tau = NaN; cf = NaN(3, 1);
for tg = grid
    X1 = [ones(n, 1) x max(0, x - tg)]; b1 = X1 \ y; s = sum((y - X1 * b1).^2);
    if s < sse1, sse1 = s; tau = tg; cf = b1; end
end
F = ((sse0 - sse1) / 2) / (sse1 / (n - 4));
p = 1 - fcdf_(F, 2, n - 4);
end

% =========================================================================
%  OUTILS
% =========================================================================
function q = prctile_(x, pct)
x = sort(x(~isnan(x))); n = numel(x); q = NaN(size(pct));
if n == 0, return; end
for i = 1:numel(pct)
    pos = 1 + (n - 1) * pct(i) / 100;
    q(i) = interp1(1:n, x, min(max(pos, 1), n));
end
end

function q = quantile_(x, f)
q = prctile_(x, 100 * f);
end

function c = fcdf_(F, d1, d2)
c = betainc(d1 * F / (d1 * F + d2), d1 / 2, d2 / 2);
end

function rk = rankTies(v)
[s, idx] = sort(v(:)); rk = zeros(numel(v), 1); i = 1;
while i <= numel(s)
    j = i;
    while j < numel(s) && s(j + 1) == s(i), j = j + 1; end
    rk(idx(i:j)) = (i + j) / 2; i = j + 1;
end
end

function out = iff(c, a, b)
if c, out = a; else, out = b; end
end

function T = readSheet(DataFile, sheet)
T = readtable(DataFile, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
T = T(~isnan(getCol(T, 'Numero')), :);
end

function v = getCol(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('InclinationClassification:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', name, strjoin(names, ', '));
end
v = T.(names{j});
if iscell(v) || isstring(v), v = str2double(strrep(string(v), ',', '.')); end
v = double(v(:)');
end

function v = getText(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
v = cellstr(string(T.(names{j})));
v(strcmp(v, '<missing>')) = {''};
v = upper(strtrim(v(:)'));
end

function v = alignCol(T, name, numRef)
num = getCol(T, 'Numero'); x = getCol(T, name);
[tf, loc] = ismember(numRef, num);
v = NaN(size(numRef)); v(tf) = x(loc(tf));
end

function s = getFileName(f)
[~, nm, ext] = fileparts(f); s = [nm, ext];
end

function s = fmtP(p)
if isnan(p), s = 'p=NA'; elseif p < 0.001, s = 'p<0.001'; else, s = sprintf('p=%.3f', p); end
end
