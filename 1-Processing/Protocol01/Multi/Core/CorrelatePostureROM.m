% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Corrélation entre la posture PRÉ-opératoire (inclinaison
%                thoracique, SIR de Moroder) et la cinématique du bras (HT
%                et HG, valeurs telles que dans l'Excel), PRE et POST, par
%                tâche : ANALYTIC1 = flexion, ANALYTIC2 = scaption ; et pour
%                deux métriques : ROM (feuille 'Cinematique') et pic
%                (feuille 'Cinematique_pics') :
%                  1) inclinaison x HT   et   inclinaison x HG
%                  2) SIR (Moroder) x HT et   SIR x HG
%                Et sur la posture PRE seule (feuille 'Posture') :
%                  3) histogramme des types de Moroder (Moroder_type_pre),
%                     en %, avec en superposition la cohorte rétrospective
%                     de Moroder et al. 2024 (681 rTSA, A / B / C = 33 /
%                     48 / 19 %) et un chi² 2 x 3 entre les deux cohortes
%                  4) distribution gaussienne de la SIR (cf. Moroder Fig. 7)
%                  5) corrélation inclinaison x SIR
%                Et le test HG moins HT (part du thorax dans l'effet de la
%                posture, voir TestHGminusHT) : pente de HG moins HT vs
%                posture (IC 95 %, p vs 0 et vs -1), thorax vs posture,
%                comparaison r(posture, HG) vs r(posture, HT) (Meng 1992).
%                Axe SIR borné à 70° sur toutes les figures (SIRAxisMax,
%                affichage seulement : points au-delà comptés dans le
%                titre, gardés dans les calculs).
%                Textes des figures sans tiret ni tiret long.
%
%                Rien n'est recalculé et aucun .mat n'est chargé : lit
%                l'Excel déjà trié à la main (Data_posture.xlsx), qui contient
%                uniquement les patients retenus :
%                  feuille 'Posture'          : Numero, Inclinaison_thoracique_Pre,
%                                               Rotation_scapulaire_interne_Pre,
%                                               Moroder_type_pre
%                  feuille 'Cinematique'      : Numero, <tâche>_ROM_<joint>_Pre/_Post
%                  feuille 'Cinematique_pics' : Numero, <tâche>_MAX_<joint>_Pre/_Post
%                  <tâche> = analytic1 | analytic2,
%                  <joint> = Humerothoracique | Humerogravitaire | ...
%                Appariement par Numero. Aucune exclusion (ni plage, ni
%                outlier) : le tri est fait dans l'Excel. Les lignes vides
%                (Numero vide) sont ignorées.
%
%                Groupe PRE  = posture PRE x cinématique PRE
%                Groupe POST = posture PRE x cinématique POST
%
%                Pearson r, Spearman rho (ex-aequo au rang moyen), p
%                bilatéral (loi de Student, df = n-2, sans Statistics
%                Toolbox), régression cinématique ~ posture.
%
%                Réserves : 2 métriques x 2 tâches x 3 postures x 2 joints
%                x 2 groupes = 48 tests (pas de correction pour comparaisons
%                multiples) ; PRE et POST = mêmes patients ; SIR cinématique
%                non validée vs SIR CT de Moroder.
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie (feuilles
%                       'Correlation_ROM', 'Correlation_Incl_SIR',
%                       'Moroder_Distribution', 'HG_minus_HT') ; '' = pas
%                       d'export
% Outputs : Corr        (struct array) une ligne par métrique/tâche/
%                       posture/joint/groupe
%           CorrInclSIR (struct) corrélation inclinaison x SIR
%           MoroderDist (struct array) effectif et % par type de Moroder,
%                       % de Moroder et al. 2024, chi² et p de la
%                       comparaison des deux cohortes
%           HGHT       (struct array) test HG moins HT, une ligne par
%                       métrique/tâche/posture/groupe
%           Feuilles Excel + 8 figures (2 métriques x 2 tâches x {inclinaison,
%           SIR}), chacune 2x2 (lignes HT / HG, colonnes PRE / POST) + 1
%           figure posture PRE 1x3 (histogramme Moroder, gaussienne SIR,
%           inclinaison x SIR) + 2 figures HG moins HT (une par métrique)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Corr, CorrInclSIR, MoroderDist, HGHT, ThxDesc, SitStand, ThxFlex] = CorrelatePostureROM(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end

SIRAxisMax = 70;   % deg : borne haute de l'axe SIR sur toutes les figures (affichage seulement)

groups    = {'PRE', 'POST'};
grpSuffix = {'_Pre', '_Post'};
cols      = [0.8500 0.3250 0.0980; 0 0.4470 0.7410];

% Posture (PRE) : colonne de la feuille 'Posture' / libellé
% (inclinaison assis = début des essais ANALYTIC ; debout = CALIBRATION3)
postDef = struct('name',  {'Inclination', 'SIR', 'InclinationStanding'}, ...
                 'col',   {'Inclinaison_thoracique_Pre', 'Rotation_scapulaire_interne_Pre', ...
                           'Inclinaison_thoracique_Pre_Calibration3'}, ...
                 'title', {'Inclinaison thoracique assis', 'SIR (Moroder)', 'Inclinaison thoracique debout'}, ...
                 'label', {'Inclinaison thoracique assis PRE (deg)', 'SIR Moroder PRE (deg)', ...
                           'Inclinaison thoracique debout PRE (deg)'});
% Métrique : feuille Excel / clé dans le nom de colonne / libellé
metricDef = struct('name',  {'ROM', 'Pic'}, ...
                   'sheet', {'Cinematique', 'Cinematique_pics'}, ...
                   'key',   {'ROM', 'MAX'});
% Tâche : préfixe des colonnes / mouvement
taskDef = struct('name',  {'ANALYTIC1', 'ANALYTIC2'}, ...
                 'key',   {'analytic1', 'analytic2'}, ...
                 'label', {'flexion', 'scaption'});
% Joint : nom de colonne
jointDef = struct('name', {'HT', 'HG'}, ...
                  'col',  {'Humerothoracique', 'Humerogravitaire'});
% Colonne = <tâche>_<métrique>_<joint><_Pre|_Post>, ex. analytic1_ROM_Humerothoracique_Pre
nTests = numel(metricDef) * numel(taskDef) * numel(postDef) * numel(jointDef) * numel(groups);

% -------------------------------------------------------------------------
% LECTURE
% -------------------------------------------------------------------------
P    = readSheet(DataFile, 'Posture');
numP = getCol(P, 'Numero');

% -------------------------------------------------------------------------
% POSTURE SEULE (feuille 'Posture', tous ses patients) : distribution des
% types de Moroder + gaussienne SIR + corrélation inclinaison x SIR
% -------------------------------------------------------------------------
[MoroderDist, CorrInclSIR] = PlotPosturePRE(getCol(P, postDef(1).col), getCol(P, postDef(2).col), ...
    getText(P, 'Moroder_type_pre'), DataFile, SIRAxisMax);

Corr = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Posture', {}, 'Joint', {}, 'Group', {}, 'n', {}, ...
    'Pearson_r', {}, 'Pearson_p', {}, 'Spearman_rho', {}, 'Spearman_p', {}, ...
    'Slope_deg_per_degPosture', {}, 'Intercept_deg', {});
HGHT = [];
ThxDesc = [];

for iM = 1:numel(metricDef)
    md = metricDef(iM);
    K    = readSheet(DataFile, md.sheet);
    numK = getCol(K, 'Numero');
    [~, iP, iK] = intersect(numP, numK, 'stable');
    disp(['Patients appariés (Posture et ', md.sheet, ') : ', num2str(numel(iP)), ...
          ' (Posture : ', num2str(numel(numP)), ', ', md.sheet, ' : ', num2str(numel(numK)), ')']);

    for iT = 1:numel(taskDef)
        td = taskDef(iT);
        for iPo = 1:numel(postDef)
            pd    = postDef(iPo);
            isSIR = strcmp(pd.name, 'SIR');
            xAll  = getCol(P, pd.col);
            xAll  = xAll(iP);

            figure('Name', sprintf('%s PRE vs %s HT et HG, %s (%s)', pd.title, md.name, td.label, td.name), ...
                   'Color', 'w');
            for iJ = 1:numel(jointDef)
                jd = jointDef(iJ);
                yG = cell(1, numel(groups));
                for g = 1:numel(groups)
                    yG{g} = getCol(K, sprintf('%s_%s_%s%s', td.key, md.key, jd.col, grpSuffix{g}));
                    yG{g} = yG{g}(iK);
                end
                allY = [yG{:}];
                allY = allY(~isnan(allY));
                if isempty(allY), yl = [0 180]; else, yl = [max(0, min(allY) - 5), max(allY) + 5]; end
                xv = xAll(~isnan(xAll));
                if isempty(xv), xl = [0 1]; else, xl = [min(xv) - 2, max(xv) + 2]; end
                if isSIR, xl(2) = SIRAxisMax; end
                yLabel = sprintf('%s %s %s (deg)', md.name, jd.name, td.label);

                for g = 1:numel(groups)
                    valid = ~isnan(xAll) & ~isnan(yG{g});
                    x = xAll(valid); y = yG{g}(valid); n = numel(x);
                    [r, pr]     = pearsonP(x, y);
                    [rho, prho] = pearsonP(rankTies(x), rankTies(y));
                    slope = NaN; icpt = NaN;
                    if n >= 2 && std(x) > 0
                        c = polyfit(x, y, 1); slope = c(1); icpt = c(2);
                    end

                    ci = length(Corr) + 1;
                    Corr(ci).Metric  = md.name;   Corr(ci).Task     = td.name;
                    Corr(ci).Movement = td.label; Corr(ci).Posture  = pd.name;
                    Corr(ci).Joint   = jd.name;   Corr(ci).Group    = groups{g};
                    Corr(ci).n       = n;
                    Corr(ci).Pearson_r    = r;    Corr(ci).Pearson_p  = pr;
                    Corr(ci).Spearman_rho = rho;  Corr(ci).Spearman_p = prho;
                    Corr(ci).Slope_deg_per_degPosture = slope;
                    Corr(ci).Intercept_deg = icpt;

                    subplot(numel(jointDef), numel(groups), (iJ - 1) * numel(groups) + g); hold on;
                    if n > 0
                        scatter(x, y, 18, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.6);
                        if ~isnan(slope)
                            xx = [min(x) max(x)];
                            plot(xx, slope * xx + icpt, 'Color', cols(g, :) * 0.7, 'LineWidth', 2);
                        end
                    end
                    if isSIR
                        xline(36, ':k'); xline(46, ':k');
                    end
                    hold off;
                    xlim(xl); ylim(yl);
                    xlabel(pd.label); ylabel(yLabel);
                    offTxt = '';
                    if isSIR && any(x > SIRAxisMax)
                        offTxt = sprintf(', %d hors axe > %d°', sum(x > SIRAxisMax), SIRAxisMax);
                    end
                    title({sprintf('%s %s %s (n=%d%s)', md.name, jd.name, groups{g}, n, offTxt), ...
                           sprintf('r=%.2f (%s) | \\rho=%.2f (%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
                          'FontSize', 8);
                    box on;
                end
            end
            sgtitle(sprintf('%s PRE vs %s HT et HG, %s (%s), PRE et POST', ...
                pd.title, md.name, td.label, td.name));
            annotation('textbox', [0 0 1 0.04], 'String', ...
                sprintf(['Données : %s, feuilles Posture et %s (patients déjà triés, aucune exclusion ici). ', ...
                         '%d tests au total (pas de correction pour comparaisons multiples).'], ...
                        getFileName(DataFile), md.sheet, nTests), ...
                'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 8, 'Interpreter', 'none');
        end
    end

    % Thorax : toujours son ROM (max moins min du signal signé, feuille
    % 'Cinematique'), quelle que soit la métrique ; pas de « pic » du thorax
    % (max |angle| mélangerait la flexion au repos et l'extension au pic)
    Kthx = readSheet(DataFile, metricDef(1).sheet);
    % Test HG moins HT (rôle du thorax), même métrique, flexion et scaption
    HGHT = [HGHT, TestHGminusHT(P, K, Kthx, iP, iK, md, taskDef, postDef, groups, grpSuffix, cols, DataFile)]; %#ok<AGROW>
    % Ampleur de la contribution du thorax (HG moins HT, ROM thorax), sans posture
    ThxDesc = [ThxDesc, DescribeThoraxContribution(K, Kthx, md, taskDef, groups, grpSuffix, cols, DataFile)]; %#ok<AGROW>
end

% Inclinaison assis vs debout (CALIBRATION3) et flexion thoracique signée
SitStand = AnalyseSeatedStanding(P, DataFile);
ThxFlex  = AnalyseThoraxFlexion(DataFile, P, metricDef, taskDef, groups, grpSuffix, cols);

if ~isempty(OutputFile)
    if ~isempty(Corr)
        writetable(struct2table(Corr), OutputFile, 'Sheet', 'Correlation_ROM');
    end
    writetable(struct2table(CorrInclSIR), OutputFile, 'Sheet', 'Correlation_Incl_SIR');
    writetable(struct2table(MoroderDist), OutputFile, 'Sheet', 'Moroder_Distribution');
    if ~isempty(HGHT)
        writetable(struct2table(HGHT), OutputFile, 'Sheet', 'HG_minus_HT');
    end
    if ~isempty(ThxDesc)
        writetable(struct2table(ThxDesc), OutputFile, 'Sheet', 'Thorax_Contribution');
    end
    if ~isempty(SitStand)
        writetable(struct2table(SitStand), OutputFile, 'Sheet', 'Seated_vs_Standing');
    end
    if ~isempty(ThxFlex)
        writetable(struct2table(ThxFlex), OutputFile, 'Sheet', 'Thorax_Flexion');
    end
    disp(['Feuilles Correlation_ROM, Correlation_Incl_SIR, Moroder_Distribution, HG_minus_HT, ', ...
          'Thorax_Contribution, Seated_vs_Standing, Thorax_Flexion écrites : ', OutputFile]);
end

end

% =========================================================================
%  INCLINAISON THORACIQUE ASSIS vs DEBOUT
% =========================================================================
% Inclinaison PRE assis (Inclinaison_thoracique_Pre, début des essais
% ANALYTIC) vs debout (Inclinaison_thoracique_Pre_Calibration3), mêmes
% patients. Concordance plutôt que simple test de différence (une absence
% de différence significative ne prouve pas l'équivalence) :
%   Bland-Altman : biais (assis moins debout), SD, limites d'accord à 95 %
%   ICC(A,1) : accord absolu, modèle à deux facteurs (McGraw et Wong 1996)
%   Pearson r, test t apparié, % de patients changeant de type
%   d'inclinaison I-A / I-B / I-C entre assis et debout (types construits
%   comme Moroder : moyenne ± 1 SD, propres à chaque position)
% Figure 1x2 : assis vs debout (droite d'identité), Bland-Altman.
% Vide (avec message) si la colonne debout est absente.
function S = AnalyseSeatedStanding(P, DataFile)
S = [];
names = P.Properties.VariableNames;
if ~any(strcmpi(names, 'Inclinaison_thoracique_Pre_Calibration3'))
    disp('Inclinaison debout (Inclinaison_thoracique_Pre_Calibration3) absente : analyse assis vs debout ignorée.');
    return;
end
sit   = getCol(P, 'Inclinaison_thoracique_Pre');
stand = getCol(P, 'Inclinaison_thoracique_Pre_Calibration3');
v = ~isnan(sit) & ~isnan(stand);
a = sit(v); b = stand(v); n = numel(a);
d = a - b;
[r, pr] = pearsonP(a, b);
[mD, loD, hiD, pD] = meanCI(d);
sdD = std(d);
icc = iccA1([a(:), b(:)]);
typeOf = @(v) 1 + (v >= mean(v) - std(v)) + (v > mean(v) + std(v));
classChange = 100 * mean(typeOf(a) ~= typeOf(b));

S = struct('n', n, 'Seated_mean', mean(a), 'Seated_SD', std(a), 'Standing_mean', mean(b), 'Standing_SD', std(b), ...
    'Bias_seated_minus_standing', mD, 'Bias_CI95_low', loD, 'Bias_CI95_high', hiD, 'p_paired_t', pD, ...
    'SD_diff', sdD, 'LoA_low', mD - 1.96 * sdD, 'LoA_high', mD + 1.96 * sdD, ...
    'Pearson_r', r, 'Pearson_p', pr, 'ICC_A1', icc, 'Pct_changement_type_inclinaison', classChange);

col = [0.30 0.30 0.60];
figure('Name', 'Inclinaison thoracique assis vs debout', 'Color', 'w');
subplot(1, 2, 1); hold on;
scatter(b, a, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
lim = [min([a, b]) - 2, max([a, b]) + 2];
plot(lim, lim, 'k--', 'LineWidth', 1);
hold off; axis equal; xlim(lim); ylim(lim); box on;
xlabel('Inclinaison debout, CALIBRATION3 (deg)'); ylabel('Inclinaison assis, ANALYTIC (deg)');
title({sprintf('n=%d | r=%.2f (%s) | ICC(A,1)=%.2f', n, r, fmtP(pr), icc), ...
       sprintf('%.0f %% des patients changent de type d''inclinaison (I-A, I-B, I-C)', classChange)}, 'FontSize', 9);

subplot(1, 2, 2); hold on;
m = (a + b) / 2;
scatter(m, d, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
yline(mD, 'k', 'LineWidth', 1.5);
yline(mD - 1.96 * sdD, 'k--'); yline(mD + 1.96 * sdD, 'k--');
yline(0, ':k');
hold off; box on;
xlabel('Moyenne assis et debout (deg)'); ylabel('Assis moins debout (deg)');
title({sprintf('Biais = %.1f° [IC95 %.1f ; %.1f], t apparié %s', mD, loD, hiD, fmtP(pD)), ...
       sprintf('Limites d''accord à 95 %% : %.1f à %.1f°', mD - 1.96 * sdD, mD + 1.96 * sdD)}, 'FontSize', 9);
sgtitle('Inclinaison thoracique PRE : assis (début des essais ANALYTIC) vs debout (CALIBRATION3)');
annotation('textbox', [0 0 1 0.04], 'String', ...
    sprintf('Données : %s, feuille Posture. Trait plein : biais ; tirets : limites d''accord (Bland-Altman).', getFileName(DataFile)), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 8, 'Interpreter', 'none');
end

% =========================================================================
%  FLEXION THORACIQUE SIGNÉE PENDANT LE GESTE
% =========================================================================
% Feuille 'Cinematique_thorax' (exportée par ComputePostureFromDatabase,
% feuille Thorax_Flexion_Signed) : <tâche>_TXflex_<Start|AtPeak|Change>_<Pre|Post>,
% thorax / verticale, négatif = flexion, positif = extension ; Change =
% thorax au pic d'élévation HG moins thorax au début du cycle (> 0 = le
% tronc se redresse pendant l'élévation). Appariement par Numero sur la
% feuille Posture. Par tâche (flexion, scaption) et groupe (PRE, POST) :
%   1) contrôle : Start vs inclinaison PRE (attendu : r fortement négatif,
%      plus incliné = thorax plus fléchi au repos)
%   2) stratégie du tronc : Change moyen (IC 95 %, t vs 0), % de patients
%      qui se redressent ; en POST, Change POST moins PRE apparié
%   3) HG moins HT (ROM et pic) vs Change : pente, r (attendu : pente
%      positive, le redressement du tronc s'ajoute à l'élévation
%      gravitaire)
%   4) Change vs inclinaison PRE : les patients inclinés se redressent-ils
%      davantage ?
% Figure 2x4 (lignes flexion / scaption ; HG moins HT en ROM).
function R = AnalyseThoraxFlexion(DataFile, P, metricDef, taskDef, groups, grpSuffix, cols)
R = [];
try
    Kt = readSheet(DataFile, 'Cinematique_thorax');
catch
    disp('Feuille Cinematique_thorax absente : analyse de la flexion thoracique signée ignorée.');
    return;
end
numP = getCol(P, 'Numero');
incl = getCol(P, 'Inclinaison_thoracique_Pre');
Km = cell(1, numel(metricDef));
for iM = 1:numel(metricDef), Km{iM} = readSheet(DataFile, metricDef(iM).sheet); end
mkKey = @(md, td, joint, g) sprintf('%s_%s_%s%s', td.key, md.key, joint, grpSuffix{g});

R = struct('Task', {}, 'Movement', {}, 'Group', {}, 'n', {}, ...
    'Start_mean', {}, 'Start_SD', {}, 'r_Start_incl', {}, 'p_Start_incl', {}, ...
    'Change_mean', {}, 'Change_CI95_low', {}, 'Change_CI95_high', {}, 'p_Change_vs0', {}, 'Pct_extension', {}, ...
    'ChangePOSTminusPRE_mean', {}, 'ChangePOSTminusPRE_CI95_low', {}, 'ChangePOSTminusPRE_CI95_high', {}, ...
    'p_ChangePOSTminusPRE', {}, ...
    'ROM_slope_HGminusHT_per_degChange', {}, 'ROM_r_HGminusHT_Change', {}, 'ROM_p_HGminusHT_Change', {}, ...
    'Pic_slope_HGminusHT_per_degChange', {}, 'Pic_r_HGminusHT_Change', {}, 'Pic_p_HGminusHT_Change', {}, ...
    'slope_Change_per_degIncl', {}, 'r_Change_incl', {}, 'p_Change_incl', {});

fig = figure('Name', 'Flexion thoracique signée pendant le geste', 'Color', 'w');
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    chg = cell(1, numel(groups));
    txt = repmat({{}}, 1, 4);
    for g = 1:numel(groups)
        st = alignCol(Kt, sprintf('%s_TXflex_Start%s', td.key, grpSuffix{g}), numP);
        ch = alignCol(Kt, sprintf('%s_TXflex_Change%s', td.key, grpSuffix{g}), numP);
        chg{g} = ch;

        k = numel(R) + 1;
        R(k).Task = td.name; R(k).Movement = td.label; R(k).Group = groups{g};
        v = ~isnan(ch); R(k).n = sum(v);
        R(k).Start_mean = mean(st, 'omitnan'); R(k).Start_SD = std(st, 'omitnan');
        vs = ~isnan(st) & ~isnan(incl);
        [R(k).r_Start_incl, R(k).p_Start_incl] = pearsonP(incl(vs), st(vs));
        [R(k).Change_mean, R(k).Change_CI95_low, R(k).Change_CI95_high, R(k).p_Change_vs0] = meanCI(ch(v));
        R(k).Pct_extension = 100 * mean(ch(v) > 0);
        R(k).ChangePOSTminusPRE_mean = NaN; R(k).ChangePOSTminusPRE_CI95_low = NaN;
        R(k).ChangePOSTminusPRE_CI95_high = NaN; R(k).p_ChangePOSTminusPRE = NaN;
        if g == numel(groups)
            vp = ~isnan(chg{1}) & ~isnan(chg{end});
            [R(k).ChangePOSTminusPRE_mean, R(k).ChangePOSTminusPRE_CI95_low, ...
             R(k).ChangePOSTminusPRE_CI95_high, R(k).p_ChangePOSTminusPRE] = meanCI(chg{end}(vp) - chg{1}(vp));
        end

        % HG moins HT vs Change, ROM et pic
        for iM = 1:numel(metricDef)
            md = metricDef(iM);
            hg = alignCol(Km{iM}, mkKey(md, td, 'Humerogravitaire', g), numP);
            ht = alignCol(Km{iM}, mkKey(md, td, 'Humerothoracique', g), numP);
            D  = hg - ht;
            vd = ~isnan(D) & ~isnan(ch);
            b  = slopeTest(ch(vd), D(vd));
            [r, p] = pearsonP(ch(vd), D(vd));
            R(k).([md.name, '_slope_HGminusHT_per_degChange']) = b;
            R(k).([md.name, '_r_HGminusHT_Change'])            = r;
            R(k).([md.name, '_p_HGminusHT_Change'])            = p;
            if iM == 1, Dplot = D; vdPlot = vd; end
        end

        vi = ~isnan(ch) & ~isnan(incl);
        R(k).slope_Change_per_degIncl = slopeTest(incl(vi), ch(vi));
        [R(k).r_Change_incl, R(k).p_Change_incl] = pearsonP(incl(vi), ch(vi));

        % --- Figure ---
        figure(fig);
        c0 = (iT - 1) * 4;
        subplot(numel(taskDef), 4, c0 + 1); hold on;
        scatter(incl(vs), st(vs), 12, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
        addFit(incl(vs), st(vs), cols(g, :));
        txt{1}{end+1} = sprintf('%s : r=%.2f (%s)', groups{g}, R(k).r_Start_incl, fmtP(R(k).p_Start_incl));

        subplot(numel(taskDef), 4, c0 + 2); hold on;
        histogram(ch(v), 'BinWidth', 2.5, 'FaceColor', cols(g, :), 'FaceAlpha', 0.45, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
        xline(R(k).Change_mean, 'Color', cols(g, :) * 0.7, 'LineWidth', 2, 'HandleVisibility', 'off');
        txt{2}{end+1} = sprintf('%s : %.1f° [%.1f ; %.1f], %.0f %% se redressent', groups{g}, ...
            R(k).Change_mean, R(k).Change_CI95_low, R(k).Change_CI95_high, R(k).Pct_extension);

        subplot(numel(taskDef), 4, c0 + 3); hold on;
        scatter(ch(vdPlot), Dplot(vdPlot), 12, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
        addFit(ch(vdPlot), Dplot(vdPlot), cols(g, :));
        txt{3}{end+1} = sprintf('%s : pente %.2f, r=%.2f (%s)', groups{g}, R(k).ROM_slope_HGminusHT_per_degChange, ...
            R(k).ROM_r_HGminusHT_Change, fmtP(R(k).ROM_p_HGminusHT_Change));

        subplot(numel(taskDef), 4, c0 + 4); hold on;
        scatter(incl(vi), ch(vi), 12, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
        addFit(incl(vi), ch(vi), cols(g, :));
        txt{4}{end+1} = sprintf('%s : r=%.2f (%s)', groups{g}, R(k).r_Change_incl, fmtP(R(k).p_Change_incl));
    end
    txt{2}{end+1} = sprintf('POST moins PRE : %.1f° (%s)', R(end).ChangePOSTminusPRE_mean, fmtP(R(end).p_ChangePOSTminusPRE));

    xl = {'Inclinaison thoracique PRE (deg)', sprintf('Changement thorax, %s (deg)', td.label), ...
          sprintf('Changement thorax, %s (deg)', td.label), 'Inclinaison thoracique PRE (deg)'};
    yl = {sprintf('Thorax au repos, %s (deg)', td.label), 'Nombre de patients', ...
          sprintf('HG moins HT, ROM %s (deg)', td.label), sprintf('Changement thorax, %s (deg)', td.label)};
    for c = 1:4
        subplot(numel(taskDef), 4, (iT - 1) * 4 + c);
        if c == 2 || c == 3, xline(0, ':k', 'HandleVisibility', 'off'); end
        if c == 3 || c == 4, yline(0, ':k', 'HandleVisibility', 'off'); end
        hold off; box on; groupLegend(groups, cols);
        xlabel(xl{c}); ylabel(yl{c}); title(txt{c}, 'FontSize', 7);
    end
end
sgtitle({'Flexion thoracique signée (négatif = flexion, positif = extension) : flexion (ligne 1), scaption (ligne 2)', ...
         'Thorax au repos vs inclinaison | changement pendant le geste | HG moins HT vs changement | changement vs inclinaison'}, ...
        'FontSize', 10);
annotation(fig, 'textbox', [0 0 1 0.03], 'String', ...
    sprintf(['Données : %s, feuilles Posture, Cinematique_thorax, Cinematique. Changement = thorax au pic ', ...
             'd''élévation HG moins thorax au début du cycle (> 0 = le tronc se redresse).'], getFileName(DataFile)), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 7, 'Interpreter', 'none');
end

% Droite de régression y ~ x (couleur du groupe), sans entrée de légende
function addFit(x, y, col)
if numel(x) < 2 || std(x) == 0, return; end
c = polyfit(x, y, 1); xx = [min(x) max(x)];
plot(xx, polyval(c, xx), 'Color', col * 0.7, 'LineWidth', 2, 'HandleVisibility', 'off');
end

% Colonne 'name' de T réalignée sur les Numero numRef (NaN si absent)
function v = alignCol(T, name, numRef)
num = getCol(T, 'Numero');
x   = getCol(T, name);
[tf, loc] = ismember(numRef, num);
v = NaN(size(numRef));
v(tf) = x(loc(tf));
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
SSE = sum((X - mean(X, 2) - mean(X, 1) + gm).^2, 'all');
MSE = SSE / ((n - 1) * (k - 1));
icc = (MSR - MSE) / (MSR + (k - 1) * MSE + k * (MSC - MSE) / n);
end

% =========================================================================
%  AMPLEUR DE LA CONTRIBUTION DU THORAX : DESCRIPTION DE HG MOINS HT
% =========================================================================
% Point 1 de l'argument « HG intègre la flexion thoracique » : la part du
% thorax est-elle négligeable ? Pour une métrique (ROM ou pic), chaque
% tâche (flexion, scaption) et chaque groupe (PRE, POST), sur tous les
% patients de la feuille cinématique (sans posture) :
%   HG, HT, D = HG moins HT (par patient) et thorax (colonne Thoracique) :
%   moyenne, SD, médiane, IQR, min, max ; |D| moyen ; % de patients avec
%   |D| > 5° et > 10° ; r(D, thorax) en indication.
% Réserves : D contient aussi la différence de définition des angles (HT
% Cardan dans le plan du thorax, HG YXY élévation 3D) ; thorax = ROM (max
% moins min du signal signé, feuille Cinematique, le même pour les deux
% métriques), amplitude sans sens (flexion ou extension), donc r(D, thorax)
% est seulement indicatif (voir la flexion thoracique signée).
% Figure : 2x2, lignes flexion / scaption ; colonnes distribution de D et
% distribution du thorax, PRE et POST superposés.
function R = DescribeThoraxContribution(K, Kthx, md, taskDef, groups, grpSuffix, cols, DataFile)

R = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Group', {}, 'n', {}, ...
    'HT_mean', {}, 'HT_SD', {}, 'HG_mean', {}, 'HG_SD', {}, ...
    'D_mean', {}, 'D_SD', {}, 'D_median', {}, 'D_Q1', {}, 'D_Q3', {}, 'D_min', {}, 'D_max', {}, ...
    'absD_mean', {}, 'Pct_absD_gt5', {}, 'Pct_absD_gt10', {}, ...
    'TX_mean', {}, 'TX_SD', {}, 'TX_median', {}, 'TX_Q1', {}, 'TX_Q3', {}, 'TX_min', {}, 'TX_max', {}, ...
    'r_D_TX', {}, 'p_D_TX', {});

fig = figure('Name', sprintf('Contribution du thorax, %s, flexion et scaption', md.name), 'Color', 'w');
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    Dg = cell(1, numel(groups)); Tg = cell(1, numel(groups));
    dTxt = cell(1, numel(groups)); tTxt = cell(1, numel(groups));
    for g = 1:numel(groups)
        colOf = @(joint) sprintf('%s_%s_%s%s', td.key, md.key, joint, grpSuffix{g});
        hg = getCol(K, colOf('Humerogravitaire'));
        ht = getCol(K, colOf('Humerothoracique'));
        tx = alignCol(Kthx, sprintf('%s_ROM_Thoracique%s', td.key, grpSuffix{g}), getCol(K, 'Numero'));
        v  = ~isnan(hg) & ~isnan(ht);
        d  = hg(v) - ht(v);
        vt = ~isnan(tx);
        vd = v & vt;
        [rDT, pDT] = pearsonP(hg(vd) - ht(vd), tx(vd));
        qd = quartiles(d); qt = quartiles(tx(vt));

        k = numel(R) + 1;
        R(k).Metric = md.name; R(k).Task = td.name; R(k).Movement = td.label; R(k).Group = groups{g};
        R(k).n = sum(v);
        R(k).HT_mean = mean(ht(v)); R(k).HT_SD = std(ht(v));
        R(k).HG_mean = mean(hg(v)); R(k).HG_SD = std(hg(v));
        R(k).D_mean = mean(d); R(k).D_SD = std(d); R(k).D_median = median(d);
        R(k).D_Q1 = qd(1); R(k).D_Q3 = qd(2); R(k).D_min = min(d); R(k).D_max = max(d);
        R(k).absD_mean = mean(abs(d));
        R(k).Pct_absD_gt5  = 100 * mean(abs(d) > 5);
        R(k).Pct_absD_gt10 = 100 * mean(abs(d) > 10);
        R(k).TX_mean = mean(tx(vt)); R(k).TX_SD = std(tx(vt)); R(k).TX_median = median(tx(vt));
        R(k).TX_Q1 = qt(1); R(k).TX_Q3 = qt(2); R(k).TX_min = min(tx(vt)); R(k).TX_max = max(tx(vt));
        R(k).r_D_TX = rDT; R(k).p_D_TX = pDT;

        Dg{g} = d; Tg{g} = tx(vt);
        dTxt{g} = sprintf('%s : %.1f ± %.1f° (%.0f %% des patients à plus de 10°)', ...
            groups{g}, R(k).D_mean, R(k).D_SD, R(k).Pct_absD_gt10);
        tTxt{g} = sprintf('%s : %.1f ± %.1f° | r(HG moins HT, thorax)=%.2f (%s)', ...
            groups{g}, R(k).TX_mean, R(k).TX_SD, rDT, fmtP(pDT));
    end

    figure(fig);
    subplot(numel(taskDef), 2, (iT - 1) * 2 + 1); hold on;
    edges = floor(min([Dg{:}]) / 5) * 5 : 5 : ceil(max([Dg{:}]) / 5) * 5;
    for g = 1:numel(groups)
        histogram(Dg{g}, edges, 'FaceColor', cols(g, :), 'FaceAlpha', 0.45, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
    xline(0, 'k', 'HandleVisibility', 'off');
    hold off; box on; groupLegend(groups, cols);
    xlabel(sprintf('HG moins HT, %s %s (deg)', md.name, td.label)); ylabel('Nombre de patients');
    title(dTxt, 'FontSize', 8);

    subplot(numel(taskDef), 2, (iT - 1) * 2 + 2); hold on;
    edges = 0 : 2.5 : ceil(max([Tg{:}]) / 2.5) * 2.5;
    for g = 1:numel(groups)
        histogram(Tg{g}, edges, 'FaceColor', cols(g, :), 'FaceAlpha', 0.45, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
    hold off; box on; groupLegend(groups, cols);
    xlabel(sprintf('ROM thorax %s (deg, max moins min du signal signé)', td.label)); ylabel('Nombre de patients');
    title(tTxt, 'FontSize', 8);
end
sgtitle(sprintf('Ampleur de la contribution du thorax, %s : flexion (ligne 1) et scaption (ligne 2)', md.name));
annotation(fig, 'textbox', [0 0 1 0.04], 'String', ...
    sprintf(['Données : %s, feuille %s, tous les patients. HG moins HT contient aussi la différence de ', ...
             'définition des angles (HT Cardan plan du thorax, HG YXY élévation 3D). Thorax : ROM ', ...
             '(max moins min du signal signé, feuille Cinematique), r indicatif.'], getFileName(DataFile), md.sheet), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 7, 'Interpreter', 'none');
end

% Légende PRE / POST par marqueurs carrés pleins (les icônes d'histogrammes
% transparents ne s'affichent pas toujours à l'export)
function groupLegend(groups, cols)
hold on;
hs = gobjects(1, numel(groups));
for g = 1:numel(groups)
    hs(g) = plot(NaN, NaN, 's', 'MarkerFaceColor', cols(g, :), 'MarkerEdgeColor', 'none', ...
        'MarkerSize', 9, 'DisplayName', groups{g});
end
hold off;
legend(hs, 'Location', 'northeast', 'FontSize', 7);
end

% Quartiles Q1 / Q3 (interpolation linéaire, sans Statistics Toolbox)
function q = quartiles(v)
v = sort(v(~isnan(v)));
n = numel(v);
if n == 0, q = [NaN NaN]; return; end
if n == 1, q = [v v]; return; end
pos = 1 + [0.25 0.75] * (n - 1);
q = interp1(1:n, v, pos);
end

% =========================================================================
%  TEST HG MOINS HT : PART DU THORAX DANS L'EFFET DE LA POSTURE
% =========================================================================
% HG = élévation / verticale, HT = élévation / thorax. En simplifiant au
% plan sagittal, un thorax incliné de theta donne HG ~ HT - theta : la
% différence D = HG - HT porte l'orientation du thorax (statique et
% mouvement du tronc pendant le geste). Pour une métrique (ROM ou pic),
% chaque tâche (flexion, scaption), chaque posture (inclinaison, SIR) et
% chaque groupe (PRE, POST) :
%   1) régression D ~ posture : pente, IC 95 %, p vs 0 et p vs -1
%      (pente -1 = le déficit d'élévation gravitaire égale l'inclinaison :
%      aucune compensation ; entre -1 et 0 = compensation partielle)
%   2) ROM du thorax (colonne Thoracique de la feuille Cinematique, quelle
%      que soit la métrique) ~ posture : Pearson, Spearman (le tronc
%      bouge-t-il différemment selon la posture ?)
%   3) comparaison de r(posture, HG) et r(posture, HT), corrélations
%      dépendantes (variable commune = posture) : test Z de Meng, Rosenthal
%      et Rubin (1992), qui utilise aussi r(HG, HT). Répond à « l'effet est-il
%      plus fort en HG qu'en HT ? » au lieu de comparer deux p.
% Réserve : HT (Cardan ZXY flexion / XZY scaption, plan du thorax) et HG
% (YXY, élévation 3D totale) ne sont pas définis de la même façon : D
% contient aussi un effet de définition des angles, a priori plus marqué en
% scaption.
% Figure (inclinaison seulement, la SIR est dans l'Excel) : 2x3, lignes
% flexion / scaption ; colonnes D vs inclinaison (référence pente moins 1),
% thorax vs inclinaison, r(inclinaison, HT) vs r(inclinaison, HG).
function R = TestHGminusHT(P, K, Kthx, iP, iK, md, taskDef, postDef, groups, grpSuffix, cols, DataFile)

R = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Posture', {}, 'Group', {}, 'n', {}, ...
    'Slope_HGminusHT_per_deg', {}, 'Slope_CI95_low', {}, 'Slope_CI95_high', {}, ...
    'p_slope_vs_0', {}, 'p_slope_vs_minus1', {}, ...
    'r_posture_HG', {}, 'r_posture_HT', {}, 'r_HG_HT', {}, 'Z_Meng', {}, 'p_Meng', {}, ...
    'TX_Pearson_r', {}, 'TX_Pearson_p', {}, 'TX_Spearman_rho', {}, 'TX_Spearman_p', {});
colHT = [0.65 0.65 0.65];
colHG = [0.10 0.45 0.45];

fig = figure('Name', sprintf('HG moins HT, %s, flexion et scaption', md.name), 'Color', 'w');
for iT = 1:numel(taskDef)
    td = taskDef(iT);
    for iPo = 1:numel(postDef)
        pd   = postDef(iPo);
        xAll = getCol(P, pd.col);
        xAll = xAll(iP);
        isIncl = strcmp(pd.name, 'Inclination');
        rBar = NaN(numel(groups), 2); pBar = NaN(1, numel(groups));
        slopeTxt = cell(1, numel(groups)); txTxt = cell(1, numel(groups));

        for g = 1:numel(groups)
            colOf = @(joint) sprintf('%s_%s_%s%s', td.key, md.key, joint, grpSuffix{g});
            hg = getCol(K, colOf('Humerogravitaire')); hg = hg(iK);
            ht = getCol(K, colOf('Humerothoracique')); ht = ht(iK);
            tx = alignCol(Kthx, sprintf('%s_ROM_Thoracique%s', td.key, grpSuffix{g}), getCol(K, 'Numero'));
            tx = tx(iK);

            valid = ~isnan(xAll) & ~isnan(hg) & ~isnan(ht);
            x = xAll(valid); d = hg(valid) - ht(valid); n = numel(x);
            [b, a, lo, hi, p0, p1] = slopeTest(x, d);
            rHG  = pearsonP(x, hg(valid));
            rHT  = pearsonP(x, ht(valid));
            rHH  = pearsonP(hg(valid), ht(valid));
            [zM, pM] = mengZ(rHG, rHT, rHH, n);

            vT = ~isnan(xAll) & ~isnan(tx);
            [rT, pT]     = pearsonP(xAll(vT), tx(vT));
            [rhoT, prhoT] = pearsonP(rankTies(xAll(vT)), rankTies(tx(vT)));

            k = numel(R) + 1;
            R(k).Metric = md.name;   R(k).Task  = td.name;  R(k).Movement = td.label;
            R(k).Posture = pd.name;  R(k).Group = groups{g}; R(k).n = n;
            R(k).Slope_HGminusHT_per_deg = b;
            R(k).Slope_CI95_low = lo; R(k).Slope_CI95_high = hi;
            R(k).p_slope_vs_0 = p0;   R(k).p_slope_vs_minus1 = p1;
            R(k).r_posture_HG = rHG;  R(k).r_posture_HT = rHT; R(k).r_HG_HT = rHH;
            R(k).Z_Meng = zM;         R(k).p_Meng = pM;
            R(k).TX_Pearson_r = rT;   R(k).TX_Pearson_p = pT;
            R(k).TX_Spearman_rho = rhoT; R(k).TX_Spearman_p = prhoT;

            if ~isIncl, continue; end
            rBar(g, :) = [rHT, rHG]; pBar(g) = pM;
            slopeTxt{g} = sprintf('%s : pente %.2f [%.2f ; %.2f], %s vs 0, %s vs moins 1', ...
                groups{g}, b, lo, hi, fmtP(p0), fmtP(p1));
            txTxt{g} = sprintf('%s : r=%.2f (%s) | \\rho=%.2f (%s)', groups{g}, rT, fmtP(pT), rhoT, fmtP(prhoT));

            % Col 1 : HG moins HT vs inclinaison
            figure(fig); subplot(numel(taskDef), 3, (iT - 1) * 3 + 1); hold on;
            scatter(x, d, 14, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', groups{g});
            if ~isnan(b)
                xx = [min(x) max(x)];
                plot(xx, b * xx + a, 'Color', cols(g, :) * 0.7, 'LineWidth', 2, 'HandleVisibility', 'off');
            end
            if g == numel(groups) && n > 0
                xx = [min(x) max(x)];
                plot(xx, -(xx - mean(x)) + mean(d), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, ...
                    'DisplayName', 'pente moins 1 (sans compensation)');
            end

            % Col 2 : thorax vs inclinaison
            subplot(numel(taskDef), 3, (iT - 1) * 3 + 2); hold on;
            xt = xAll(vT); yt = tx(vT);
            scatter(xt, yt, 14, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName', groups{g});
            if numel(xt) >= 2 && std(xt) > 0
                c = polyfit(xt, yt, 1); xx = [min(xt) max(xt)];
                plot(xx, polyval(c, xx), 'Color', cols(g, :) * 0.7, 'LineWidth', 2, 'HandleVisibility', 'off');
            end
        end
        if ~isIncl, continue; end

        subplot(numel(taskDef), 3, (iT - 1) * 3 + 1);
        hold off; box on; legend('Location', 'best', 'FontSize', 7);
        xlabel(pd.label); ylabel(sprintf('HG moins HT, %s %s (deg)', md.name, td.label));
        title(slopeTxt, 'FontSize', 7);

        subplot(numel(taskDef), 3, (iT - 1) * 3 + 2);
        hold off; box on; legend('Location', 'best', 'FontSize', 7);
        xlabel(pd.label); ylabel(sprintf('ROM thorax %s (deg)', td.label));
        title(txTxt, 'FontSize', 7);

        subplot(numel(taskDef), 3, (iT - 1) * 3 + 3);
        hb = bar(categorical(groups, groups), rBar, 'grouped');
        hb(1).FaceColor = colHT; hb(2).FaceColor = colHG;
        yline(0, 'k', 'HandleVisibility', 'off');
        ymin = min([rBar(:); 0]) * 1.35 - 0.02;
        ylim([ymin, max([rBar(:); 0]) + 0.15]);   % place pour la légende au-dessus de 0
        for g = 1:numel(groups)
            text(g, ymin * 0.92, sprintf('Meng %s', fmtP(pBar(g))), 'HorizontalAlignment', 'center', 'FontSize', 8);
        end
        legend({'r(inclinaison, HT)', 'r(inclinaison, HG)'}, 'Location', 'northeast', 'FontSize', 7);
        ylabel('Pearson r'); box on;
        title(sprintf('Effet de l''inclinaison : HT vs HG (%s %s)', md.name, td.label), 'FontSize', 8);
    end
end
figure(fig);
sgtitle(sprintf('Part du thorax dans l''effet de l''inclinaison : HG moins HT, %s, flexion (ligne 1) et scaption (ligne 2)', md.name));
annotation(fig, 'textbox', [0 0 1 0.04], 'String', ...
    sprintf(['Données : %s, feuilles Posture et %s. HT (Cardan, plan du thorax) et HG (YXY, élévation 3D) ', ...
             'ne sont pas définis de la même façon : la différence contient aussi un effet de définition. ', ...
             'Comparaison des r : test Z de Meng, Rosenthal et Rubin (1992). Résultats SIR dans l''Excel (feuille HG_minus_HT).'], ...
            getFileName(DataFile), md.sheet), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 7, 'Interpreter', 'none');
end

% Régression y ~ b*x + a : pente, ordonnée, IC 95 % de la pente, p
% bilatéral de la pente vs 0 et vs -1 (Student, df = n-2). NaN si n < 3.
function [b, a, lo, hi, p0, p1] = slopeTest(x, y)
b = NaN; a = NaN; lo = NaN; hi = NaN; p0 = NaN; p1 = NaN;
n = numel(x);
if n < 3 || std(x) == 0, return; end
x = x(:); y = y(:);
Sxx = sum((x - mean(x)).^2);
b   = sum((x - mean(x)) .* (y - mean(y))) / Sxx;
a   = mean(y) - b * mean(x);
df  = n - 2;
se  = sqrt(sum((y - (a + b * x)).^2) / df) / sqrt(Sxx);
tc  = tInv975(df);
lo  = b - tc * se;  hi = b + tc * se;
p0  = tPval(b / se, df);
p1  = tPval((b + 1) / se, df);
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


% =========================================================================
%  POSTURE PRE : DISTRIBUTION MORODER + CORRELATION INCLINAISON x SIR
% =========================================================================
% Une figure 1x3 :
%   gauche : histogramme des types de Moroder (A, B, C, puis tout autre
%            type présent), en %, effectif et % au-dessus de chaque barre ;
%            types vides comptés dans le titre ; superposé (hold on) :
%            Moroder et al. 2024 (barres vides tiretées) et chi² 2 x 3
%   milieu : distribution gaussienne de la SIR (cf. Moroder Figure 7),
%            colorée par type, sur l'histogramme des SIR mesurées
%   droite : inclinaison (x) vs SIR (y), droite de régression, Pearson /
%            Spearman, seuils 36/46° (Moroder A/B/C) ; axe SIR borné à SIRAxisMax (points au-delà comptés
%            dans le titre, pas exclus du calcul)
% Outputs : MoroderDist (struct array) une ligne par type : Type, n, Pct,
%                       Pct_Moroder2024, Chi2_vs_Moroder2024, p_vs_Moroder2024
%           CorrInclSIR (struct) une ligne : n, Pearson, Spearman, régression
function [MoroderDist, CorrInclSIR] = PlotPosturePRE(incl, sir, mor, DataFile, SIRAxisMax)

col = [0.8500 0.3250 0.0980];

% --- Distribution des types de Moroder ---
mor     = upper(strtrim(mor));
isEmpty = cellfun(@isempty, mor);
present = unique(mor(~isEmpty));
types   = [intersect({'A', 'B', 'C'}, present, 'stable'), setdiff(present, {'A', 'B', 'C'})];
nT      = cellfun(@(t) sum(strcmp(mor, t)), types);
nTot    = sum(nT);
pct     = 100 * nT / max(nTot, 1);
MoroderDist = struct('Type', types, 'n', num2cell(nT), 'Pct', num2cell(pct));

% Couleurs A / B / C comme la Figure 7 de Moroder (bleu, vert, rouge)
morCols = [0.10 0.10 0.70; 0.40 0.85 0.10; 0.75 0.10 0.10];
SIRThresh = [36 46];   % deg : seuils A|B et B|C
% Référence : cohorte rétrospective de Moroder et al. (2024), J Shoulder
% Elbow Surg 33:2159-2170 : 681 rTSA, types A / B / C = 33 / 48 / 19 %
% (SIR sur imagerie en coupe, patient couché)
morRefPct = [33 48 19]; morRefN = 681;

% Comparaison des proportions A / B / C (tableau 2 x 3, chi² de Pearson ;
% effectifs de Moroder reconstruits à partir des % publiés)
nABC = cellfun(@(t) sum(strcmp(mor, t)), {'A', 'B', 'C'});
refN = round(morRefN * morRefPct / 100);
O = [nABC; refN]; E = sum(O, 2) * sum(O, 1) / sum(O(:));
chi2 = sum((O(:) - E(:)).^2 ./ E(:));
pChi = gammainc(chi2 / 2, 1, 'upper');                 % ddl = 2
[MoroderDist.Pct_Moroder2024] = deal(NaN);
for k = 1:numel(MoroderDist)
    j = find(strcmp({'A', 'B', 'C'}, MoroderDist(k).Type));
    if ~isempty(j), MoroderDist(k).Pct_Moroder2024 = morRefPct(j); end
end
[MoroderDist.Chi2_vs_Moroder2024] = deal(chi2);
[MoroderDist.p_vs_Moroder2024]    = deal(pChi);

figure('Name', 'Posture PRE, Moroder et inclinaison x SIR', 'Color', 'w');
subplot(1, 3, 1); hold on;
if ~isempty(types)
    xc = categorical(types, types);
    b = bar(xc, pct, 0.6, 'FaceColor', 'flat', 'DisplayName', sprintf('Notre cohorte (n=%d)', nTot));
    for k = 1:numel(types)
        if k <= size(morCols, 1), b.CData(k, :) = morCols(k, :); else, b.CData(k, :) = [0.6 0.6 0.6]; end
    end
    text(1:numel(types), pct, compose('%d (%.0f %%)', nT(:), pct(:)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    % Moroder et al. (2024) superposé : barres vides à contour noir
    iRef = find(ismember(types, {'A', 'B', 'C'}));
    refPct = arrayfun(@(k) morRefPct(strcmp({'A', 'B', 'C'}, types{k})), iRef);
    bar(xc(iRef), refPct, 0.8, 'FaceColor', 'none', 'EdgeColor', 'k', 'LineWidth', 1.8, 'LineStyle', '--', ...
        'DisplayName', sprintf('Moroder et al. 2024 (n=%d)', morRefN));
    text(iRef + 0.42, refPct, compose('%.0f %%', refPct(:)), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontSize', 9, 'FontAngle', 'italic');
    ylim([0, max([pct, morRefPct]) * 1.25]);
    legend('Location', 'northeast', 'FontSize', 8);
end
hold off;
xlabel('Type de Moroder (PRE)'); ylabel('Patients (%)');
title({sprintf('Classification de Moroder (n=%d, %d sans type)', nTot, sum(isEmpty)), ...
       'A : SIR < 36° | B : 36 à 46° | C : > 46°', ...
       sprintf('vs Moroder et al. 2024 : \\chi^2 = %.1f, %s', chi2, fmtP(pChi))}, 'FontSize', 9);
box on;

% --- Distribution gaussienne de la SIR (cf. Moroder, Figure 7) ---
% Gaussienne N(moyenne, SD) ajustée sur les SIR de la cohorte, en nombre de
% cas par classe de BinW degrés (n * BinW * densité) pour être comparable
% à l'histogramme des SIR (barres grises, données réelles). Courbe colorée
% par type selon les seuils 36/46° (traits tiretés) ; moyenne ± SD dans le
% titre (chez Moroder les tiretés sont les ± 1 SD de leur cohorte).
subplot(1, 3, 2); hold on;
s  = sir(~isnan(sir));
nS = numel(s);
if nS >= 2
    BinW = 2.5;
    mu = mean(s); sd = std(s);
    histogram(s, 'BinWidth', BinW, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', [0.7 0.7 0.7], ...
        'DisplayName', sprintf('SIR mesurées (classes de %.1f°)', BinW));
    xs = linspace(max(0, mu - 4 * sd), min(SIRAxisMax, mu + 4 * sd), 500);
    ys = nS * BinW * exp(-0.5 * ((xs - mu) / sd).^2) / (sd * sqrt(2 * pi));
    seg = {xs <= SIRThresh(1), xs >= SIRThresh(1) & xs <= SIRThresh(2), xs >= SIRThresh(2)};
    segName = {'Type A', 'Type B', 'Type C'};
    for k = 1:3
        plot(xs(seg{k}), ys(seg{k}), '-', 'Color', morCols(k, :), 'LineWidth', 3, 'DisplayName', segName{k});
    end
    yTop = max([ys, histcounts(s, 'BinWidth', BinW)]) * 1.15;
    xline(SIRThresh(1), '--k', 'HandleVisibility', 'off');
    xline(SIRThresh(2), '--k', 'HandleVisibility', 'off');
    xr = [max(0, mu - 4 * sd), min(SIRAxisMax, mu + 4 * sd)];
    xlim(xr); ylim([0 yTop]);
    tx = [mean([xr(1) SIRThresh(1)]), mean(SIRThresh), mean([SIRThresh(2) xr(2)])];
    for k = 1:3
        text(tx(k), yTop * 0.95, segName{k}, 'HorizontalAlignment', 'center', 'FontSize', 10);
    end
    title({sprintf('Distribution gaussienne de la SIR (n=%d, gris : SIR mesurées par %.1f°)', nS, BinW), ...
           sprintf('moyenne = %.1f° | SD = %.1f° (± 1 SD : %.1f à %.1f°)', mu, sd, mu - sd, mu + sd)}, ...
          'FontSize', 9);
end
hold off;
xlabel('Scapula Internal Rotation (SIR) PRE (deg)'); ylabel('Nombre de cas');
box on;

% --- Corrélation inclinaison x SIR ---
valid = ~isnan(incl) & ~isnan(sir);
x = incl(valid); y = sir(valid); n = numel(x);
[r, pr]     = pearsonP(x, y);
[rho, prho] = pearsonP(rankTies(x), rankTies(y));
slope = NaN; icpt = NaN;
if n >= 2 && std(x) > 0
    c = polyfit(x, y, 1); slope = c(1); icpt = c(2);
end
CorrInclSIR = struct('n', n, 'Pearson_r', r, 'Pearson_p', pr, ...
    'Spearman_rho', rho, 'Spearman_p', prho, ...
    'Slope_degSIR_per_degIncl', slope, 'Intercept_deg', icpt);

subplot(1, 3, 3); hold on;
if n > 0
    scatter(x, y, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
    if ~isnan(slope)
        xx = [min(x) max(x)];
        plot(xx, slope * xx + icpt, '-', 'Color', col * 0.7, 'LineWidth', 2);
    end
end
yline(36, ':k'); yline(46, ':k');
hold off;
if n > 0
    xlim([min(x) - 2, max(x) + 2]);
    ylim([max(0, min(y) - 2), SIRAxisMax]);
end
xlabel('Inclinaison thoracique PRE (deg)'); ylabel('SIR Moroder PRE (deg)');
offTxt = '';
if any(y > SIRAxisMax), offTxt = sprintf(', %d hors axe > %d°', sum(y > SIRAxisMax), SIRAxisMax); end
title({sprintf('Inclinaison vs SIR (n=%d%s)', n, offTxt), ...
       sprintf('Pearson r=%.2f (%s) | Spearman \\rho=%.2f (%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
      'FontSize', 9);
box on;

sgtitle('Posture PRE : distribution de Moroder et corrélation inclinaison x SIR');
annotation('textbox', [0 0 1 0.04], 'String', ...
    sprintf('Données : %s, feuille Posture (patients déjà triés, aucune exclusion ici).', getFileName(DataFile)), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', 8, 'Interpreter', 'none');
end

% =========================================================================
%  LECTURE EXCEL
% =========================================================================
% Lit une feuille (en-têtes préservés) et retire les lignes vides
% (Numero vide ou non numérique : lignes d'espacement entre les valeurs).
function T = readSheet(DataFile, sheet)
T = readtable(DataFile, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
num = getCol(T, 'Numero');
T = T(~isnan(num), :);
end

% Colonne numérique (ligne) par nom, insensible à la casse. Une colonne lue
% comme texte (cellule vide, virgule décimale) est convertie, non numérique
% -> NaN.
function v = getCol(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('CorrelatePostureROM:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', ...
        name, strjoin(names, ', '));
end
v = T.(names{j});
if iscell(v) || isstring(v)
    v = str2double(strrep(string(v), ',', '.'));
end
v = double(v(:)');
end

% Colonne texte (cellule ligne de char) par nom, insensible à la casse.
% Cellule vide / NaN -> ''.
function v = getText(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('CorrelatePostureROM:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', ...
        name, strjoin(names, ', '));
end
v = T.(names{j});
if isnumeric(v)
    v = arrayfun(@(x) num2str(x), v, 'UniformOutput', false);
    v(strcmp(v, 'NaN')) = {''};
else
    v = cellstr(string(v));
    v(strcmp(v, '<missing>')) = {''};
end
v = v(:)';
end

function s = getFileName(f)
[~, nm, ext] = fileparts(f);
s = [nm, ext];
end

% =========================================================================
%  STATISTIQUES
% =========================================================================
% Corrélation de Pearson + p bilatéral (Student, df = n-2) via betainc
% (MATLAB de base). NaN si n < 3 ou variance nulle. Même calcul que dans
% ComputePostureFromDatabase.m.
function [r, p] = pearsonP(x, y)
r = NaN; p = NaN;
n = numel(x);
if n < 3 || std(x) == 0 || std(y) == 0, return; end
cc = corrcoef(x, y);
r  = cc(1, 2);
df = n - 2;
if abs(r) >= 1, p = 0; return; end
t  = r * sqrt(df / (1 - r^2));
p  = betainc(df / (df + t^2), df / 2, 0.5);
end

% Rangs avec ex-aequo au rang moyen (pour Spearman)
function rk = rankTies(v)
[s, idx] = sort(v(:));
rk = zeros(numel(v), 1);
i = 1;
while i <= numel(s)
    j = i;
    while j < numel(s) && s(j + 1) == s(i), j = j + 1; end
    rk(idx(i:j)) = (i + j) / 2;
    i = j + 1;
end
rk = reshape(rk, size(v));
end

% Texte "p..." prêt à afficher : 'p=0.040', 'p<0.001' ou 'p=NA'
function s = fmtP(p)
if isnan(p),       s = 'p=NA';
elseif p < 0.001,  s = 'p<0.001';
else,              s = sprintf('p=%.3f', p);
end
end
