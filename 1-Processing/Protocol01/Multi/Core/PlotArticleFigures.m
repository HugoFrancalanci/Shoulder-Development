% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Figures de l'article posture (JSES), une figure par
%                fichier et par tâche (flexion = ANALYTIC1, scaption =
%                ANALYTIC2), textes en anglais sans tiret. Toutes les
%                comparaisons portent sur l'AMPLITUDE (max moins min sur le
%                cycle ; colonnes _ROM_ de la feuille 'Cinematique', le terme
%                ROM n'est plus utilisé dans les figures) :
%                  Fig2 (H1) : amplitude du thorax (flexion / extension et
%                        inclinaison latérale, signal signé), PRE et POST
%                        (points individuels, moyenne ± SD)
%                  Fig3 (H1) : part du thorax dans l'amplitude HG (amplitude
%                        du thorax / amplitude HG x 100, par patient ;
%                        médiane et IC 95 % bootstrap), PRE et POST ;
%                        tableau affiché dans la console (pas d'Excel)
%                  Fig4 (H1) : amplitude du thorax x amplitude HG, PRE et POST
%                        (composante principale de la tâche : flexion /
%                        extension en flexion, inclinaison latérale en
%                        scaption)
%                  Fig5 (H1) : contribution du thorax à l'amplitude HG à
%                        épaule égale : régression HG ~ HT + thorax flexion /
%                        extension + thorax inclinaison latérale ; figure de
%                        régression partielle de la composante principale,
%                        coefficient, IC 95 % et p sur la figure ; tableau
%                        dans la console
%                  Fig6 (H2) : inclinaison thoracique debout PRE x amplitude
%                        HG, un fichier PRE et un fichier POST
%                Format : 8.5 cm de large (une colonne), Arial 8 pt, palette
%                Okabe-Ito (PRE orange, POST bleu, lisible par les
%                daltoniens) ; export PDF vectoriel, SVG (Inkscape) et PNG
%                600 dpi. Les fichiers existants du même nom sont remplacés
%                (jamais les *_inkscape.svg).
% -------------------------------------------------------------------------
% Inputs  : DataFile      (char) chemin vers Data_posture.xlsx
%           OutputFolder  (char) dossier des figures (créé si absent)
% Outputs : Info          (struct array) une ligne par figure et groupe :
%                         fichier, tâche, n, moyenne, r, p, pente
%           Share         (struct array) part du thorax (Fig3) : médiane,
%                         IC 95 %, Q1, Q3, % > 25 %
%           Decomp        (struct array) décomposition (Fig5) : R², ΔR²,
%                         coefficients, IC 95 %, p
% -------------------------------------------------------------------------
% Dependencies : PostureUtils
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Info, Share, Decomp] = PlotArticleFigures(DataFile, OutputFolder)

if ~isfolder(OutputFolder), mkdir(OutputFolder); end
U = PostureUtils;
D = U.defs();

% Style
S.col  = [0.90 0.62 0.00; 0.00 0.45 0.70];   % PRE orange, POST bleu (Okabe-Ito)
S.font = 'Arial'; S.size = 8;
S.grp  = {'PRE', 'POST'};

P     = U.readSheet(DataFile, 'Posture');
numP  = U.getCol(P, 'Numero');
K     = U.readSheet(DataFile, 'Cinematique');      % amplitudes (max moins min)
stand = U.getCol(P, 'Inclinaison_thoracique_Pre_Calibration3');

Info = struct('File', {}, 'Figure', {}, 'Task', {}, 'Group', {}, 'n', {}, 'Mean', {}, 'r', {}, 'p', {}, 'Slope', {});
Share = struct('Task', {}, 'Component', {}, 'Group', {}, 'n', {}, 'Median', {}, 'CI95_low', {}, 'CI95_high', {}, ...
    'Q1', {}, 'Q3', {}, 'Pct_gt25', {});
Decomp = struct('Task', {}, 'Group', {}, 'n', {}, 'R2_shoulder', {}, 'R2_shoulder_thorax', {}, 'dR2', {}, ...
    'b_shoulder', {}, 'b_FlexExt', {}, 'b_FlexExt_CI95_low', {}, 'b_FlexExt_CI95_high', {}, 'p_FlexExt', {}, ...
    'b_Lat', {}, 'b_Lat_CI95_low', {}, 'b_Lat_CI95_high', {}, 'p_Lat', {});
sag = cell(1, 2); lat = sag; hg = sag; ht = sag;
for td = D.task
    col = @(name, g) U.alignCol(K, sprintf('%s_ROM_%s%s', td.key, name, D.grpSuffix{g}), numP);
    for g = 1:2
        sag{g} = col('Thoracique', g);           % flexion / extension du thorax
        lat{g} = col('ThoraciqueLateral', g);    % inclinaison latérale du thorax
        hg{g}  = col('Humerogravitaire', g);
        ht{g}  = col('Humerothoracique', g);     % épaule (composante de la décomposition)
    end
    % Composante principale du thorax pour la tâche
    if strcmp(td.label, 'flexion')
        thx = sag; thxLabel = 'Thoracic flexion and extension amplitude (°)';
    else
        thx = lat; thxLabel = 'Thoracic lateral tilt amplitude (°)';
    end
    hgLabel = sprintf('HG elevation amplitude, %s (°)', td.label);

    % ---------- Fig2 : amplitude du thorax, PRE et POST ----------
    fig = newFig(S, 8.5, 7);
    ax = axes('Parent', fig); hold(ax, 'on');
    rng(1);
    vars = {sag, lat}; varName = {'Flexion and extension', 'Lateral tilt'};
    for iv = 1:2
        for g = 1:2
            y = vars{iv}{g}; y = y(~isnan(y));
            x0 = iv + (g - 1.5) * 0.36;
            scatter(ax, x0 + (rand(size(y)) - 0.5) * 0.22, y, 8, S.col(g, :), 'filled', 'MarkerFaceAlpha', 0.35, ...
                'HandleVisibility', 'off');
            errorbar(ax, x0, mean(y), std(y), 'o', 'Color', S.col(g, :) * 0.6, 'MarkerFaceColor', S.col(g, :), ...
                'MarkerSize', 5, 'LineWidth', 1.2, 'CapSize', 6, 'HandleVisibility', 'off');
            Info(end + 1) = row(['Fig2_' varName{iv}], td.label, S.grp{g}, numel(y), NaN, NaN, NaN, mean(y)); %#ok<AGROW>
        end
    end
    legendGroups(ax, S);
    set(ax, 'XTick', 1:2, 'XTickLabel', varName, 'XLim', [0.4 2.6]);
    ylim(ax, [0, ax.YLim(2)]);
    ylabel(ax, sprintf('Thoracic amplitude, %s (°)', td.label));
    Info = saveFig(fig, ax, S, OutputFolder, sprintf('Fig2_ThoracicAmplitude_%s', td.label), Info);

    % ---------- Fig3 : part du thorax dans l'amplitude HG, PRE et POST ----------
    % Amplitude du thorax / amplitude HG x 100, par patient (indicatif : le
    % maximum du thorax ne tombe pas forcément au même instant que celui du
    % bras). Point = médiane, barre = IC 95 % de la médiane (bootstrap, 2000
    % tirages). Axe borné à 100 % (affichage seulement) : les rapports
    % au-delà (amplitude HG très faible) sont comptés en haut de la colonne.
    fig = newFig(S, 8.5, 7);
    ax = axes('Parent', fig); hold(ax, 'on');
    rng(1);
    for iv = 1:2
        for g = 1:2
            sh = 100 * vars{iv}{g} ./ hg{g};
            sh(~(hg{g} > 0)) = NaN;
            y = sh(~isnan(sh));
            q = quartiles(y);
            [m, lo, hi] = U.bootMedianCI(y, 2000);
            x0 = iv + (g - 1.5) * 0.36;
            scatter(ax, x0 + (rand(size(y)) - 0.5) * 0.22, y, 8, S.col(g, :), 'filled', 'MarkerFaceAlpha', 0.35, ...
                'HandleVisibility', 'off');
            errorbar(ax, x0, m, m - lo, hi - m, 'o', 'Color', S.col(g, :) * 0.6, 'MarkerFaceColor', S.col(g, :), ...
                'MarkerSize', 5, 'LineWidth', 1.2, 'CapSize', 6, 'HandleVisibility', 'off');
            if any(y > 100)
                text(ax, x0, 99, sprintf('%d > 100', sum(y > 100)), 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'top', 'FontName', S.font, 'FontSize', S.size - 1);
            end
            Share(end + 1) = struct('Task', td.label, 'Component', varName{iv}, 'Group', S.grp{g}, 'n', numel(y), ...
                'Median', m, 'CI95_low', lo, 'CI95_high', hi, 'Q1', q(1), 'Q3', q(2), ...
                'Pct_gt25', 100 * mean(y > 25)); %#ok<AGROW>
        end
    end
    legendGroups(ax, S);
    set(ax, 'XTick', 1:2, 'XTickLabel', varName, 'XLim', [0.4 2.6]);
    ylim(ax, [0 100]);
    ylabel(ax, sprintf('Thoracic share of HG amplitude, %s (%%)', td.label));
    Info = saveFig(fig, ax, S, OutputFolder, sprintf('Fig3_ThoracicShare_%s', td.label), Info);

    % ---------- Fig4 : amplitude du thorax x amplitude HG ----------
    fig = newFig(S, 8.5, 7.5);
    ax = axes('Parent', fig); hold(ax, 'on');
    txt = cell(1, 2);
    for g = 1:2
        [n, r, p, b] = scatterFit(ax, thx{g}, hg{g}, S.col(g, :), U);
        txt{g} = sprintf('%s: r = %.2f, %s', S.grp{g}, r, fmtPen(p));
        Info(end + 1) = row('Fig4', td.label, S.grp{g}, n, r, p, b, NaN); %#ok<AGROW>
    end
    legendGroups(ax, S, txt);
    xlabel(ax, thxLabel); ylabel(ax, hgLabel);
    Info = saveFig(fig, ax, S, OutputFolder, sprintf('Fig4_ThoracicAmplitude_vs_HG_%s', td.label), Info);

    % ---------- Fig5 : contribution du thorax à l'amplitude HG, à épaule égale ----------
    % Décomposition HG ~ HT (épaule) + thorax flexion / extension + thorax
    % inclinaison latérale, par groupe. Figure de régression partielle
    % (added variable plot) pour la composante principale de la tâche :
    % résidus de HG et du thorax après ajustement sur HT et l'autre
    % composante ; la pente est le coefficient du thorax dans le modèle
    % complet (degrés d'élévation HG par degré de thorax, à épaule égale).
    % Tableau dans la console : R² épaule seule, R² complet, coefficients.
    fig = newFig(S, 8.5, 7.5);
    ax = axes('Parent', fig); hold(ax, 'on');
    txt = cell(1, 2);
    iMain = 1 + strcmp(td.label, 'scaption');          % 1 = flexion / extension, 2 = inclinaison latérale
    for g = 1:2
        X = [ht{g}(:), sag{g}(:), lat{g}(:)];
        [b, ~, pb, lo, hi, R2, n] = U.olsFit(hg{g}, X);
        [~, ~, ~, ~, ~, R2s] = U.olsFit(hg{g}, ht{g}(:));
        Decomp(end + 1) = struct('Task', td.label, 'Group', S.grp{g}, 'n', n, 'R2_shoulder', R2s, ...
            'R2_shoulder_thorax', R2, 'dR2', R2 - R2s, 'b_shoulder', b(1), ...
            'b_FlexExt', b(2), 'b_FlexExt_CI95_low', lo(2), 'b_FlexExt_CI95_high', hi(2), 'p_FlexExt', pb(2), ...
            'b_Lat', b(3), 'b_Lat_CI95_low', lo(3), 'b_Lat_CI95_high', hi(3), 'p_Lat', pb(3)); %#ok<AGROW>
        % Régression partielle de la composante principale
        others = X(:, setdiff(1:3, iMain + 1));
        v  = ~isnan(hg{g}(:)) & all(~isnan(X), 2);
        Z  = [ones(sum(v), 1), others(v, :)];
        ry = hg{g}(v)'; ry = ry - Z * (Z \ ry);
        rx = X(v, iMain + 1); rx = rx - Z * (Z \ rx);
        scatter(ax, rx, ry, 10, S.col(g, :), 'filled', 'MarkerFaceAlpha', 0.45, 'HandleVisibility', 'off');
        xx = [min(rx) max(rx)];
        plot(ax, xx, b(iMain + 1) * xx, '-', 'Color', S.col(g, :) * 0.75, 'LineWidth', 1.5, 'HandleVisibility', 'off');
        txt{g} = sprintf('%s: %.2f °/° [%.2f ; %.2f], %s', S.grp{g}, b(iMain + 1), lo(iMain + 1), hi(iMain + 1), ...
            fmtPen(pb(iMain + 1)));
        Info(end + 1) = row('Fig5', td.label, S.grp{g}, n, NaN, pb(iMain + 1), b(iMain + 1), NaN); %#ok<AGROW>
    end
    legendGroups(ax, S, txt);
    xlabel(ax, strrep(thxLabel, ' (°)', ', adjusted (°)'));
    ylabel(ax, strrep(hgLabel, ' (°)', ', adjusted (°)'));
    Info = saveFig(fig, ax, S, OutputFolder, sprintf('Fig5_ThoracicContribution_%s', td.label), Info);

    % ---------- Fig6 : inclinaison debout PRE x amplitude HG, PRE et POST ----------
    grpLabel = {'Preoperative', 'Postoperative'};
    for g = 1:2
        fig = newFig(S, 8.5, 7.5);
        ax = axes('Parent', fig); hold(ax, 'on');
        [n, r, p, b] = scatterFit(ax, stand, hg{g}, S.col(g, :), U);
        text(ax, 0.97, 0.97, sprintf('n = %d\nr = %.2f, %s\nslope = %.2f °/°', n, r, fmtPen(p), b), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontName', S.font, 'FontSize', S.size);
        Info(end + 1) = row('Fig6', td.label, S.grp{g}, n, r, p, b, NaN); %#ok<AGROW>
        xlabel(ax, 'Preoperative standing thoracic inclination (°)');
        ylabel(ax, sprintf('%s %s', grpLabel{g}, hgLabel));
        Info = saveFig(fig, ax, S, OutputFolder, sprintf('Fig6_Inclination_vs_HG_%s_%s', S.grp{g}, td.label), Info);
    end
end
disp(['Figures de l''article écrites dans : ', OutputFolder]);
fprintf('\nPart du thorax dans l''amplitude HG (%%, médiane, IC 95 %% bootstrap, Q1, Q3, %% > 25 %%) :\n');
disp(struct2table(Share));
fprintf(['\nDécomposition de l''amplitude HG : HG ~ épaule (HT) + thorax flexion / extension + thorax ', ...
         'inclinaison latérale (coefficients en degrés HG par degré, IC 95 %%) :\n']);
disp(struct2table(Decomp));
end

% =========================================================================
%  OUTILS DE FIGURE
% =========================================================================
function fig = newFig(S, wCm, hCm)
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 wCm hCm]);
if exist('theme', 'file'), theme(fig, 'light'); end   % R2025a+ : thème sombre par défaut
set(fig, 'DefaultAxesFontName', S.font, 'DefaultAxesFontSize', S.size, ...
    'DefaultTextFontName', S.font, 'DefaultTextFontSize', S.size);
end

% Nuage + droite de régression ; renvoie n, Pearson r, p, pente
function [n, r, p, b] = scatterFit(ax, x, y, col, U)
v = ~isnan(x) & ~isnan(y);
x = x(v); y = y(v); n = numel(x);
[r, p] = U.pearsonP(x, y);
[b, a] = U.slopeTest(x, y);
scatter(ax, x, y, 10, col, 'filled', 'MarkerFaceAlpha', 0.45, 'HandleVisibility', 'off');
if ~isnan(b)
    xx = [min(x) max(x)];
    plot(ax, xx, a + b * xx, '-', 'Color', col * 0.75, 'LineWidth', 1.5, 'HandleVisibility', 'off');
end
end

% Légende PRE / POST (marqueurs pleins), libellés optionnels
function legendGroups(ax, S, labels, keepOthers)
if nargin < 3 || isempty(labels), labels = S.grp; end
if nargin < 4, keepOthers = false; end
h = gobjects(1, 2);
for g = 1:2
    h(g) = plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', S.col(g, :), 'MarkerEdgeColor', 'none', ...
        'MarkerSize', 5, 'DisplayName', labels{g});
end
if keepOthers
    legend(ax, 'Location', 'best', 'Box', 'off');
else
    legend(ax, h, 'Location', 'best', 'Box', 'off');
end
end

% p sans tiret, format JSES (p exact, sinon p < 0.001)
function s = fmtPen(p)
if isnan(p), s = 'p = NA';
elseif p < 0.001, s = 'p < 0.001';
else, s = sprintf('p = %.3f', p);
end
end

function r = row(figName, task, grp, n, rr, p, b, m)
r = struct('File', '', 'Figure', figName, 'Task', task, 'Group', grp, 'n', n, 'Mean', m, 'r', rr, 'p', p, 'Slope', b);
end

% Quartiles Q1 / Q3 (interpolation linéaire, sans Statistics Toolbox)
function q = quartiles(v)
v = sort(v(~isnan(v)));
n = numel(v);
if n == 0, q = [NaN NaN]; return; end
if n == 1, q = [v v]; return; end
q = interp1(1:n, v, 1 + [0.25 0.75] * (n - 1));
end

% Mise en forme commune puis export PDF (vectoriel), SVG et PNG 600 dpi
function Info = saveFig(fig, ax, S, folder, name, Info)
set(ax, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 0.75, 'FontName', S.font, 'FontSize', S.size, ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
grid(ax, 'off');
base = fullfile(folder, name);
exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
exportgraphics(fig, [base '.png'], 'Resolution', 600);
print(fig, [base '.svg'], '-dsvg');
for k = find(cellfun(@isempty, {Info.File})), Info(k).File = name; end
close(fig);
end
