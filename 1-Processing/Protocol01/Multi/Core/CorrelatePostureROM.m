% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Corrélation entre la posture PRÉ-opératoire (inclinaison
%                thoracique, SIR de Moroder) et le ROM du bras (HT et HG,
%                valeurs telles que dans l'Excel), PRE et POST :
%                  1) inclinaison x ROM HT   et   inclinaison x ROM HG
%                  2) SIR (Moroder) x ROM HT et   SIR x ROM HG
%                Et sur la posture PRE seule (feuille 'Posture') :
%                  3) histogramme des types de Moroder (Moroder_type_pre)
%                  4) corrélation inclinaison x SIR
%                Axe SIR borné à 70° sur toutes les figures (SIRAxisMax,
%                affichage seulement : points au-delà comptés dans le
%                titre, gardés dans les calculs).
%
%                Rien n'est recalculé et aucun .mat n'est chargé : lit
%                l'Excel déjà trié à la main (Data_posture.xlsx), qui contient
%                uniquement les patients retenus :
%                  feuille 'Posture'     : Numero, Inclinaison_thoracique_Pre,
%                                          Rotation_scapulaire_interne_Pre, ...
%                  feuille 'Cinematique' : Numero, ROM_Humerothoracique_Pre/_Post,
%                                          ROM_Humerogravitaire_Pre/_Post, ...
%                Appariement par Numero. Aucune exclusion (ni plage, ni
%                outlier) : le tri est fait dans l'Excel. Les lignes vides
%                (Numero vide) sont ignorées.
%
%                Groupe PRE  = posture PRE x ROM PRE
%                Groupe POST = posture PRE x ROM POST
%
%                Pearson r, Spearman rho (ex-aequo au rang moyen), p
%                bilatéral (loi de Student, df = n-2, sans Statistics
%                Toolbox), régression ROM ~ posture.
%
%                Réserves : 2 postures x 2 ROM x 2 groupes = 8 tests (pas
%                de correction pour comparaisons multiples) ; PRE et POST =
%                mêmes patients ; SIR cinématique non validée vs SIR CT de
%                Moroder.
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie (feuilles
%                       'Correlation_ROM', 'Correlation_Incl_SIR',
%                       'Moroder_Distribution') ; '' = pas d'export
% Outputs : Corr        (struct array) une ligne par posture/ROM/groupe
%           CorrInclSIR (struct) corrélation inclinaison x SIR
%           MoroderDist (struct array) effectif et % par type de Moroder
%           Feuilles Excel + 2 figures ({inclinaison, SIR}) 2x2 (lignes
%           ROM HT / HG, colonnes PRE / POST) + 1 figure posture PRE 1x2
%           (histogramme Moroder, inclinaison x SIR)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Corr, CorrInclSIR, MoroderDist] = CorrelatePostureROM(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end

SIRAxisMax = 70;   % deg : borne haute de l'axe SIR sur toutes les figures (affichage seulement)

groups = {'PRE', 'POST'};
labels = {'ROM PRE', 'ROM POST'};
cols   = [0.8500 0.3250 0.0980; 0 0.4470 0.7410];

% Posture (PRE) : colonne de la feuille 'Posture' / libellé
postDef = struct('name',  {'Inclination', 'SIR'}, ...
                 'col',   {'Inclinaison_thoracique_Pre', 'Rotation_scapulaire_interne_Pre'}, ...
                 'label', {'Inclinaison thoracique PRE (deg)', 'SIR - Moroder PRE (deg)'});
% ROM : préfixe des colonnes de la feuille 'Cinematique' (+ '_Pre' / '_Post')
romDef  = struct('name',  {'HT', 'HG'}, ...
                 'col',   {'ROM_Humerothoracique', 'ROM_Humerogravitaire'}, ...
                 'label', {'ROM HT (deg)', 'ROM HG (deg)'});
romSuffix = {'_Pre', '_Post'};

% -------------------------------------------------------------------------
% LECTURE ET APPARIEMENT PAR NUMERO
% -------------------------------------------------------------------------
P = readSheet(DataFile, 'Posture');
K = readSheet(DataFile, 'Cinematique');
numP = getCol(P, 'Numero');
numK = getCol(K, 'Numero');
[~, iP, iK] = intersect(numP, numK, 'stable');
disp(['Patients appariés (Posture & Cinematique) : ', num2str(numel(iP)), ...
      ' (Posture : ', num2str(numel(numP)), ', Cinematique : ', num2str(numel(numK)), ')']);

% -------------------------------------------------------------------------
% POSTURE SEULE (feuille 'Posture', tous ses patients) : distribution des
% types de Moroder + corrélation inclinaison x SIR
% -------------------------------------------------------------------------
[MoroderDist, CorrInclSIR] = PlotPosturePRE(getCol(P, postDef(1).col), getCol(P, postDef(2).col), ...
    getText(P, 'Moroder_type_pre'), DataFile, SIRAxisMax);

Corr = struct('Posture', {}, 'ROM', {}, 'Group', {}, 'n', {}, ...
    'Pearson_r', {}, 'Pearson_p', {}, 'Spearman_rho', {}, 'Spearman_p', {}, ...
    'Slope_degROM_per_degPosture', {}, 'Intercept_deg', {});

for iPo = 1:numel(postDef)
    pd = postDef(iPo);
    xAll = getCol(P, pd.col);
    xAll = xAll(iP);

    figure('Name', ['Posture vs ROM — ', pd.name], 'Color', 'w');
    for iR = 1:numel(romDef)
        rd = romDef(iR);
        yG = cell(1, numel(groups));
        for g = 1:numel(groups)
            yG{g} = getCol(K, [rd.col, romSuffix{g}]);
            yG{g} = yG{g}(iK);
        end
        allY = [yG{:}];
        allY = allY(~isnan(allY));
        if isempty(allY), yl = [0 180]; else, yl = [max(0, min(allY) - 5), max(allY) + 5]; end
        xv = xAll(~isnan(xAll));
        if isempty(xv), xl = [0 1]; else, xl = [min(xv) - 2, max(xv) + 2]; end
        isSIR = strcmp(pd.name, 'SIR');
        if isSIR, xl(2) = SIRAxisMax; end

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
            Corr(ci).Posture = pd.name;   Corr(ci).ROM = rd.name;
            Corr(ci).Group   = groups{g}; Corr(ci).n   = n;
            Corr(ci).Pearson_r    = r;    Corr(ci).Pearson_p  = pr;
            Corr(ci).Spearman_rho = rho;  Corr(ci).Spearman_p = prho;
            Corr(ci).Slope_degROM_per_degPosture = slope;
            Corr(ci).Intercept_deg = icpt;

            subplot(numel(romDef), numel(groups), (iR - 1) * numel(groups) + g); hold on;
            if n > 0
                scatter(x, y, 18, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.6);
                if ~isnan(slope)
                    xx = [min(x) max(x)];
                    plot(xx, slope * xx + icpt, '-', 'Color', cols(g, :) * 0.7, 'LineWidth', 2);
                end
            end
            if strcmp(pd.name, 'Inclination')
                xline(32, ':k');
            else
                xline(36, ':k'); xline(46, ':k');
            end
            hold off;
            xlim(xl); ylim(yl);
            xlabel(pd.label); ylabel(rd.label);
            offTxt = '';
            if isSIR && any(x > SIRAxisMax)
                offTxt = sprintf(', %d hors axe > %d°', sum(x > SIRAxisMax), SIRAxisMax);
            end
            title({sprintf('%s %s (n=%d%s)', rd.name, labels{g}, n, offTxt), ...
                   sprintf('r=%.2f (p=%s) | \\rho=%.2f (p=%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
                  'FontSize', 8);
            box on;
        end
    end
    sgtitle([pd.name, ' PRE vs ROM HT / HG (PRE et POST)']);
    annotation('textbox', [0 0 1 0.04], 'String', ...
        sprintf(['Données : %s (patients déjà triés, aucune exclusion ici). ', ...
                 '%d tests au total (pas de correction pour comparaisons multiples).'], ...
                getFileName(DataFile), numel(postDef) * numel(romDef) * numel(groups)), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 8, 'Interpreter', 'none');
end

if ~isempty(OutputFile)
    if ~isempty(Corr)
        writetable(struct2table(Corr), OutputFile, 'Sheet', 'Correlation_ROM');
    end
    writetable(struct2table(CorrInclSIR), OutputFile, 'Sheet', 'Correlation_Incl_SIR');
    writetable(struct2table(MoroderDist), OutputFile, 'Sheet', 'Moroder_Distribution');
    disp(['Feuilles Correlation_ROM, Correlation_Incl_SIR, Moroder_Distribution écrites : ', OutputFile]);
end

end

% =========================================================================
%  POSTURE PRE : DISTRIBUTION MORODER + CORRELATION INCLINAISON x SIR
% =========================================================================
% Une figure 1x3 :
%   gauche : histogramme des types de Moroder (A, B, C, puis tout autre
%            type présent), effectif et % au-dessus de chaque barre ;
%            types vides comptés dans le titre
%   milieu : distribution gaussienne de la SIR (cf. Moroder Figure 7),
%            colorée par type, sur l'histogramme des SIR mesurées
%   droite : inclinaison (x) vs SIR (y), droite de régression, Pearson /
%            Spearman, seuils 32° (Erect/Slouched) et 36/46° (Moroder
%            A/B/C) ; axe SIR borné à SIRAxisMax (points au-delà comptés
%            dans le titre, pas exclus du calcul)
% Outputs : MoroderDist (struct array) une ligne par type : Type, n, Pct
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

figure('Name', 'Posture PRE — Moroder et inclinaison x SIR', 'Color', 'w');
subplot(1, 3, 1);
if ~isempty(types)
    b = bar(categorical(types, types), nT, 0.6, 'FaceColor', 'flat');
    for k = 1:numel(types)
        if k <= size(morCols, 1), b.CData(k, :) = morCols(k, :); else, b.CData(k, :) = [0.6 0.6 0.6]; end
    end
    text(1:numel(types), nT, compose('%d (%.0f %%)', nT(:), pct(:)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    ylim([0, max(nT) * 1.15]);
end
xlabel('Type de Moroder (PRE)'); ylabel('Nombre de patients');
title({sprintf('Classification de Moroder (n=%d)', nTot), ...
       sprintf('A : SIR < 36° | B : 36-46° | C : > 46° — %d sans type', sum(isEmpty))}, 'FontSize', 9);
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
           sprintf('moyenne = %.1f° | SD = %.1f° (± 1 SD : %.1f - %.1f°)', mu, sd, mu - sd, mu + sd)}, ...
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
xline(32, ':k'); yline(36, ':k'); yline(46, ':k');
hold off;
if n > 0
    xlim([min(x) - 2, max(x) + 2]);
    ylim([max(0, min(y) - 2), SIRAxisMax]);
end
xlabel('Inclinaison thoracique PRE (deg)'); ylabel('SIR - Moroder PRE (deg)');
offTxt = '';
if any(y > SIRAxisMax), offTxt = sprintf(', %d hors axe > %d°', sum(y > SIRAxisMax), SIRAxisMax); end
title({sprintf('Inclinaison vs SIR (n=%d%s)', n, offTxt), ...
       sprintf('Pearson r=%.2f (p=%s) | Spearman \\rho=%.2f (p=%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
      'FontSize', 9);
box on;

sgtitle('Posture PRE — distribution de Moroder et corrélation inclinaison x SIR');
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

function s = fmtP(p)
if isnan(p),       s = 'NA';
elseif p < 0.001,  s = '<0.001';
else,              s = sprintf('%.3f', p);
end
end
