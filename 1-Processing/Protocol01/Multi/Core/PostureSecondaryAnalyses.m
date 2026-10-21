% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026 (repris de CorrelatePostureROM)
% -------------------------------------------------------------------------
% Description:   Analyses secondaires de l'article posture (résultats
%                secondaires ou matériel supplémentaire), sur la posture PRE
%                de Data_posture.xlsx :
%                  1) types de Moroder (A / B / C, en %) vs la cohorte
%                     rétrospective de Moroder et al. 2024 (681 rTSA, 33 /
%                     48 / 19 %), chi² 2 x 3 ; corrélation inclinaison x SIR
%                  2) inclinaison assis vs debout : Bland-Altman, ICC(A,1)
%                     (McGraw et Wong 1996), t apparié, % de changement de
%                     type d'inclinaison (moyenne ± 1 SD par position)
%                  3) HG moins HT vs posture (ROM et pic) : pente (IC 95 %,
%                     p vs 0 et vs -1 ; -1 = artefact géométrique du thorax
%                     incliné), ROM du thorax vs posture, comparaison
%                     r(posture, HG) vs r(posture, HT) (Meng, Rosenthal et
%                     Rubin 1992)
%                Une figure par analyse (inclinaison seulement pour 3).
%                Textes des figures sans tiret ni tiret long.
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie, feuilles
%                       'Moroder_Distribution', 'Correlation_Incl_SIR',
%                       'Seated_vs_Standing', 'HG_minus_HT' ; '' = pas
%                       d'export
% Outputs : MoroderDist, CorrInclSIR, SitStand, HGHT (struct)
% -------------------------------------------------------------------------
% Dependencies : PostureUtils
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [MoroderDist, CorrInclSIR, SitStand, HGHT] = PostureSecondaryAnalyses(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end
U = PostureUtils;
D = U.defs();
P = U.readSheet(DataFile, 'Posture');

[MoroderDist, CorrInclSIR] = posturePRE(U, P, DataFile);
SitStand = seatedStanding(U, P, DataFile);
HGHT = [];
Kthx = U.readSheet(DataFile, 'Cinematique');
for md = D.metric
    HGHT = [HGHT, testHGminusHT(U, D, P, U.readSheet(DataFile, md.sheet), Kthx, md, DataFile)]; %#ok<AGROW>
end

if ~isempty(OutputFile)
    writetable(struct2table(MoroderDist), OutputFile, 'Sheet', 'Moroder_Distribution');
    writetable(struct2table(CorrInclSIR), OutputFile, 'Sheet', 'Correlation_Incl_SIR');
    if ~isempty(SitStand), writetable(struct2table(SitStand), OutputFile, 'Sheet', 'Seated_vs_Standing'); end
    writetable(struct2table(HGHT), OutputFile, 'Sheet', 'HG_minus_HT');
    disp(['Feuilles Moroder_Distribution, Correlation_Incl_SIR, Seated_vs_Standing, HG_minus_HT écrites : ', OutputFile]);
end
end

% =========================================================================
%  1) TYPES DE MORODER vs MORODER 2024, INCLINAISON x SIR
% =========================================================================
function [MoroderDist, CorrInclSIR] = posturePRE(U, P, DataFile)
SIRAxisMax = 70;                                     % deg : affichage seulement
incl = U.getCol(P, 'Inclinaison_thoracique_Pre');
sir  = U.getCol(P, 'Rotation_scapulaire_interne_Pre');
mor  = upper(strtrim(U.getText(P, 'Moroder_type_pre')));

isEmpty = cellfun(@isempty, mor);
present = unique(mor(~isEmpty));
types   = [intersect({'A', 'B', 'C'}, present, 'stable'), setdiff(present, {'A', 'B', 'C'})];
nT      = cellfun(@(t) sum(strcmp(mor, t)), types);
nTot    = sum(nT);
pct     = 100 * nT / max(nTot, 1);
MoroderDist = struct('Type', types, 'n', num2cell(nT), 'Pct', num2cell(pct));

% Moroder et al. (2024), J Shoulder Elbow Surg 33:2159-2170 : 681 rTSA,
% A / B / C = 33 / 48 / 19 % ; chi² 2 x 3 (effectifs reconstruits)
morRefPct = [33 48 19]; morRefN = 681;
morCols   = [0.10 0.10 0.70; 0.40 0.85 0.10; 0.75 0.10 0.10];
O = [cellfun(@(t) sum(strcmp(mor, t)), {'A', 'B', 'C'}); round(morRefN * morRefPct / 100)];
E = sum(O, 2) * sum(O, 1) / sum(O(:));
chi2 = sum((O(:) - E(:)).^2 ./ E(:));
pChi = gammainc(chi2 / 2, 1, 'upper');               % ddl = 2
[MoroderDist.Pct_Moroder2024] = deal(NaN);
for k = 1:numel(MoroderDist)
    j = find(strcmp({'A', 'B', 'C'}, MoroderDist(k).Type));
    if ~isempty(j), MoroderDist(k).Pct_Moroder2024 = morRefPct(j); end
end
[MoroderDist.Chi2_vs_Moroder2024] = deal(chi2);
[MoroderDist.p_vs_Moroder2024]    = deal(pChi);

v = ~isnan(incl) & ~isnan(sir);
x = incl(v); y = sir(v); n = numel(x);
[r, pr]     = U.pearsonP(x, y);
[rho, prho] = U.spearmanP(x, y);
c = [NaN NaN];
if n >= 2 && std(x) > 0, c = polyfit(x, y, 1); end
CorrInclSIR = struct('n', n, 'Pearson_r', r, 'Pearson_p', pr, 'Spearman_rho', rho, 'Spearman_p', prho, ...
    'Slope_degSIR_per_degIncl', c(1), 'Intercept_deg', c(2));

figure('Name', 'Posture PRE, Moroder et inclinaison x SIR', 'Color', 'w');
subplot(1, 2, 1); hold on;
if ~isempty(types)
    xc = categorical(types, types);
    b = bar(xc, pct, 0.6, 'FaceColor', 'flat', 'DisplayName', sprintf('Notre cohorte (n=%d)', nTot));
    for k = 1:numel(types)
        if k <= 3, b.CData(k, :) = morCols(k, :); else, b.CData(k, :) = [0.6 0.6 0.6]; end
    end
    text(1:numel(types), pct, compose('%d (%.0f %%)', nT(:), pct(:)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    iRef = find(ismember(types, {'A', 'B', 'C'}));
    refPct = arrayfun(@(k) morRefPct(strcmp({'A', 'B', 'C'}, types{k})), iRef);
    bar(xc(iRef), refPct, 0.8, 'FaceColor', 'none', 'EdgeColor', 'k', 'LineWidth', 1.8, 'LineStyle', '--', ...
        'DisplayName', sprintf('Moroder et al. 2024 (n=%d)', morRefN));
    ylim([0, max([pct, morRefPct]) * 1.25]);
    legend('Location', 'northeast', 'FontSize', 8);
end
hold off; box on;
xlabel('Type de Moroder (PRE)'); ylabel('Patients (%)');
title({sprintf('Classification de Moroder (n=%d, %d sans type)', nTot, sum(isEmpty)), ...
       sprintf('vs Moroder et al. 2024 : \\chi^2 = %.1f, %s', chi2, U.fmtP(pChi))}, 'FontSize', 9);

subplot(1, 2, 2); hold on;
scatter(x, y, 22, [0.85 0.325 0.098], 'filled', 'MarkerFaceAlpha', 0.6);
if ~isnan(c(1)), xx = [min(x) max(x)]; plot(xx, polyval(c, xx), 'Color', [0.6 0.23 0.07], 'LineWidth', 2); end
yline(36, ':k'); yline(46, ':k');
hold off; box on;
if n > 0, xlim([min(x) - 2, max(x) + 2]); ylim([max(0, min(y) - 2), SIRAxisMax]); end
xlabel('Inclinaison thoracique PRE (deg)'); ylabel('SIR Moroder PRE (deg)');
title({sprintf('Inclinaison vs SIR (n=%d, %d hors axe)', n, sum(y > SIRAxisMax)), ...
       sprintf('Pearson r=%.2f (%s) | Spearman \\rho=%.2f (%s)', r, U.fmtP(pr), rho, U.fmtP(prho))}, 'FontSize', 9);
sgtitle(sprintf('Posture PRE (%s)', U.fileName(DataFile)), 'Interpreter', 'none');
end

% =========================================================================
%  2) INCLINAISON ASSIS vs DEBOUT
% =========================================================================
function S = seatedStanding(U, P, DataFile)
S = [];
if ~U.hasCol(P, 'Inclinaison_thoracique_Pre_Calibration3')
    disp('Inclinaison debout absente : analyse assis vs debout ignorée.');
    return;
end
sit   = U.getCol(P, 'Inclinaison_thoracique_Pre');
stand = U.getCol(P, 'Inclinaison_thoracique_Pre_Calibration3');
v = ~isnan(sit) & ~isnan(stand);
a = sit(v); b = stand(v); d = a - b;
[r, pr] = U.pearsonP(a, b);
[mD, loD, hiD, pD] = U.meanCI(d);
sdD = std(d);
icc = iccA1([a(:), b(:)]);
typeOf = @(v) 1 + (v >= mean(v) - std(v)) + (v > mean(v) + std(v));
classChange = 100 * mean(typeOf(a) ~= typeOf(b));
S = struct('n', numel(a), 'Seated_mean', mean(a), 'Seated_SD', std(a), 'Standing_mean', mean(b), 'Standing_SD', std(b), ...
    'Bias_seated_minus_standing', mD, 'Bias_CI95_low', loD, 'Bias_CI95_high', hiD, 'p_paired_t', pD, ...
    'SD_diff', sdD, 'LoA_low', mD - 1.96 * sdD, 'LoA_high', mD + 1.96 * sdD, ...
    'Pearson_r', r, 'Pearson_p', pr, 'ICC_A1', icc, 'Pct_changement_type_inclinaison', classChange);

col = [0.30 0.30 0.60];
figure('Name', 'Inclinaison thoracique assis vs debout', 'Color', 'w');
subplot(1, 2, 1); hold on;
scatter(b, a, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
lim = [min([a, b]) - 2, max([a, b]) + 2];
plot(lim, lim, 'k--');
hold off; axis equal; xlim(lim); ylim(lim); box on;
xlabel('Inclinaison debout (deg)'); ylabel('Inclinaison assis (deg)');
title({sprintf('n=%d | r=%.2f (%s) | ICC(A,1)=%.2f', S.n, r, U.fmtP(pr), icc), ...
       sprintf('%.0f %% changent de type d''inclinaison', classChange)}, 'FontSize', 9);
subplot(1, 2, 2); hold on;
scatter((a + b) / 2, d, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
yline(mD, 'k', 'LineWidth', 1.5); yline(S.LoA_low, 'k--'); yline(S.LoA_high, 'k--'); yline(0, ':k');
hold off; box on;
xlabel('Moyenne assis et debout (deg)'); ylabel('Assis moins debout (deg)');
title({sprintf('Biais = %.1f° [IC95 %.1f ; %.1f], %s', mD, loD, hiD, U.fmtP(pD)), ...
       sprintf('Limites d''accord à 95 %% : %.1f à %.1f°', S.LoA_low, S.LoA_high)}, 'FontSize', 9);
sgtitle(sprintf('Inclinaison thoracique PRE : assis vs debout (%s)', U.fileName(DataFile)), 'Interpreter', 'none');
end

% ICC(A,1) : accord absolu, deux facteurs, mesure unique (McGraw et Wong
% 1996) ; X = [n sujets x k mesures]
function icc = iccA1(X)
X = X(all(~isnan(X), 2), :);
[n, k] = size(X);
icc = NaN;
if n < 2, return; end
gm  = mean(X(:));
MSR = k * sum((mean(X, 2) - gm).^2) / (n - 1);
MSC = n * sum((mean(X, 1) - gm).^2) / (k - 1);
MSE = sum((X - mean(X, 2) - mean(X, 1) + gm).^2, 'all') / ((n - 1) * (k - 1));
icc = (MSR - MSE) / (MSR + (k - 1) * MSE + k * (MSC - MSE) / n);
end

% =========================================================================
%  3) HG MOINS HT vs POSTURE
% =========================================================================
% Un thorax incliné de theta donnerait HG ~ HT - theta (pente de HG moins
% HT vs posture = -1) : test de l'artefact géométrique. Réserve : HT
% (Cardan, plan du thorax) et HG (YXY, élévation 3D) ne sont pas définis de
% la même façon. Figure : inclinaison assis seulement, lignes flexion /
% scaption, colonnes HG moins HT vs inclinaison, ROM thorax vs
% inclinaison, r(inclinaison, HT) vs r(inclinaison, HG).
function R = testHGminusHT(U, D, P, K, Kthx, md, DataFile)
R = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Posture', {}, 'Group', {}, 'n', {}, ...
    'Slope_HGminusHT_per_deg', {}, 'Slope_CI95_low', {}, 'Slope_CI95_high', {}, ...
    'p_slope_vs_0', {}, 'p_slope_vs_minus1', {}, ...
    'r_posture_HG', {}, 'r_posture_HT', {}, 'r_HG_HT', {}, 'Z_Meng', {}, 'p_Meng', {}, ...
    'TX_Pearson_r', {}, 'TX_Pearson_p', {}, 'TX_Spearman_rho', {}, 'TX_Spearman_p', {});
[~, iP, iK] = intersect(U.getCol(P, 'Numero'), U.getCol(K, 'Numero'), 'stable');
cols = D.cols;
fig = figure('Name', sprintf('HG moins HT, %s, flexion et scaption', md.name), 'Color', 'w');
for iT = 1:numel(D.task)
    td = D.task(iT);
    for pd = D.post
        xAll = U.getCol(P, pd.col); xAll = xAll(iP);
        isIncl = strcmp(pd.name, 'Inclination');
        rBar = NaN(numel(D.groups), 2); pBar = NaN(1, numel(D.groups));
        for g = 1:numel(D.groups)
            colOf = @(joint) sprintf('%s_%s_%s%s', td.key, md.key, joint, D.grpSuffix{g});
            hg = U.getCol(K, colOf('Humerogravitaire')); hg = hg(iK);
            ht = U.getCol(K, colOf('Humerothoracique')); ht = ht(iK);
            tx = U.alignCol(Kthx, sprintf('%s_ROM_Thoracique%s', td.key, D.grpSuffix{g}), U.getCol(K, 'Numero'));
            tx = tx(iK);
            v = ~isnan(xAll) & ~isnan(hg) & ~isnan(ht);
            x = xAll(v); d = hg(v) - ht(v); n = numel(x);
            [b, a, lo, hi, p0, p1] = U.slopeTest(x, d);
            rHG = U.pearsonP(x, hg(v)); rHT = U.pearsonP(x, ht(v)); rHH = U.pearsonP(hg(v), ht(v));
            [zM, pM] = mengZ(rHG, rHT, rHH, n);
            vT = ~isnan(xAll) & ~isnan(tx);
            [rT, pT] = U.pearsonP(xAll(vT), tx(vT));
            [rhoT, prhoT] = U.spearmanP(xAll(vT), tx(vT));
            R(end + 1) = struct('Metric', md.name, 'Task', td.name, 'Movement', td.label, 'Posture', pd.name, ...
                'Group', D.groups{g}, 'n', n, 'Slope_HGminusHT_per_deg', b, 'Slope_CI95_low', lo, ...
                'Slope_CI95_high', hi, 'p_slope_vs_0', p0, 'p_slope_vs_minus1', p1, ...
                'r_posture_HG', rHG, 'r_posture_HT', rHT, 'r_HG_HT', rHH, 'Z_Meng', zM, 'p_Meng', pM, ...
                'TX_Pearson_r', rT, 'TX_Pearson_p', pT, 'TX_Spearman_rho', rhoT, 'TX_Spearman_p', prhoT); %#ok<AGROW>
            if ~isIncl, continue; end
            rBar(g, :) = [rHT, rHG]; pBar(g) = pM;
            figure(fig);
            subplot(numel(D.task), 3, (iT - 1) * 3 + 1); hold on;
            scatter(x, d, 14, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', ...
                sprintf('%s : pente %.2f [%.2f ; %.2f]', D.groups{g}, b, lo, hi));
            if ~isnan(b), plot([min(x) max(x)], b * [min(x) max(x)] + a, 'Color', cols(g, :) * 0.7, ...
                    'LineWidth', 2, 'HandleVisibility', 'off'); end
            if g == numel(D.groups)
                xx = [min(x) max(x)];
                plot(xx, -(xx - mean(x)) + mean(d), '--', 'Color', [0.3 0.3 0.3], 'DisplayName', 'pente moins 1');
            end
            subplot(numel(D.task), 3, (iT - 1) * 3 + 2); hold on;
            scatter(xAll(vT), tx(vT), 14, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', ...
                sprintf('%s : r=%.2f (%s)', D.groups{g}, rT, U.fmtP(pT)));
        end
        if ~isIncl, continue; end
        subplot(numel(D.task), 3, (iT - 1) * 3 + 1);
        hold off; box on; legend('Location', 'best', 'FontSize', 7);
        xlabel(pd.label); ylabel(sprintf('HG moins HT, %s %s (deg)', md.name, td.label));
        subplot(numel(D.task), 3, (iT - 1) * 3 + 2);
        hold off; box on; legend('Location', 'best', 'FontSize', 7);
        xlabel(pd.label); ylabel(sprintf('ROM thorax %s (deg)', td.label));
        subplot(numel(D.task), 3, (iT - 1) * 3 + 3);
        hb = bar(categorical(D.groups, D.groups), rBar, 'grouped');
        hb(1).FaceColor = [0.65 0.65 0.65]; hb(2).FaceColor = [0.10 0.45 0.45];
        yline(0, 'k', 'HandleVisibility', 'off');
        ymin = min([rBar(:); 0]) * 1.35 - 0.02;
        ylim([ymin, max([rBar(:); 0]) + 0.15]);
        for g = 1:numel(D.groups)
            text(g, ymin * 0.92, sprintf('Meng %s', U.fmtP(pBar(g))), 'HorizontalAlignment', 'center', 'FontSize', 8);
        end
        legend({'r(inclinaison, HT)', 'r(inclinaison, HG)'}, 'Location', 'northeast', 'FontSize', 7);
        ylabel('Pearson r'); box on;
    end
end
figure(fig);
sgtitle(sprintf('HG moins HT vs inclinaison assis, %s : flexion (ligne 1) et scaption (ligne 2) (%s)', ...
    md.name, U.fileName(DataFile)), 'Interpreter', 'none');
end

% Comparaison de deux corrélations dépendantes partageant une variable
% (r1 = r(x, y1), r2 = r(x, y2), r12 = r(y1, y2)) : Meng, Rosenthal et
% Rubin (1992), Psychol Bull 111:172-175. Z > 0 si r1 > r2 ; p bilatéral.
function [Z, p] = mengZ(r1, r2, r12, n)
Z = NaN; p = NaN;
if any(isnan([r1 r2 r12])) || n < 4, return; end
rm2 = (r1^2 + r2^2) / 2;
f   = min(1, (1 - r12) / (2 * (1 - rm2)));
h   = (1 - f * rm2) / (1 - rm2);
Z   = (atanh(r1) - atanh(r2)) * sqrt((n - 3) / (2 * (1 - r12) * h));
p   = erfc(abs(Z) / sqrt(2));
end
