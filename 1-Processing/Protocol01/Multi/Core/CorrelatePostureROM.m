% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Corrélation entre la posture (inclinaison thoracique, SIR
%                de Moroder) et le pic d'élévation du bras (ROM HT et HG),
%                pour ANALYTIC1 et ANALYTIC2, PRE / POST / asymptomatique :
%                  1) inclinaison x ROM HT   et   inclinaison x ROM HG
%                  2) SIR (Moroder) x ROM HT et   SIR x ROM HG
%
%                Rien n'est recalculé : prend les Results déjà retournés par
%                ComputeClinicalContributionsFromDatabase (HT_<C>_max_deg),
%                ComputeFunctionalContributionsFromDatabase (HG_<C>_max_deg)
%                et ComputePostureFromDatabase (Inclination/SIR).
%
%                ROM = pic d'élévation (*_max_deg : moyenne des pics |angle|
%                par cycle), pas l'amplitude max-min.
%                Posture = MÊME essai que le ROM (100 premières frames de
%                l'essai ANALYTIC1/2, avant le mouvement), pas CALIBRATION3.
%                Appariement par Numero + Side + Task (+ Condition pour les
%                asymptomatiques).
%
%                Paires gardées : inclinaison dans [0 50] deg, SIR dans
%                [10 60] deg (même plage que CorrelatePosture dans
%                ComputePostureFromDatabase.m), ROM non NaN. Pearson r,
%                Spearman rho (ex-aequo au rang moyen), p bilatéral (loi de
%                Student, df = n-2, sans Statistics Toolbox), régression
%                ROM ~ posture.
%
%                Réserves : 2 tâches x 2 postures x 2 ROM x 3 groupes = 24
%                tests (pas de correction pour comparaisons multiples) ;
%                PRE et POST = mêmes patients ; SIR cinématique non validée
%                vs SIR CT de Moroder.
% -------------------------------------------------------------------------
% Inputs  : PostRes, PostAsym  sorties de ComputePostureFromDatabase
%           ClinRes, ClinAsym  sorties de ComputeClinicalContributionsFromDatabase
%           FuncRes, FuncAsym  sorties de ComputeFunctionalContributionsFromDatabase
%           OutputFile         (char) Excel où ajouter la feuille
%                              'Correlation_ROM' (Posture_Summary.xlsx)
% Outputs : Corr (struct array) une ligne par tâche/posture/ROM/groupe
%           Feuille Excel + 4 figures (2 tâches x {inclinaison, SIR}),
%           chacune 2x3 (lignes ROM HT / HG, colonnes PRE / POST / asympto.)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Corr = CorrelatePostureROM(PostRes, PostAsym, ClinRes, ClinAsym, FuncRes, FuncAsym, OutputFile)

InclRange = [0 50];   % deg
SIRRange  = [10 60];  % deg
tasks     = {'ANALYTIC1', 'ANALYTIC2'};
groups    = {'PRE', 'POST', 'ASYM'};
labels    = {'PRE', 'POST', 'Asympto.'};
cols      = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

% Posture : champ (Results patients, préfixe) / range / libellé
postDef = struct('name',  {'Inclination', 'SIR'}, ...
                 'range', {InclRange, SIRRange}, ...
                 'label', {'Inclinaison thoracique (deg)', 'SIR - Moroder (deg)'});
% ROM : Results patients / asymptomatiques / préfixe du champ
romDef  = struct('name', {'HT', 'HG'}, 'res', {ClinRes, FuncRes}, 'asym', {ClinAsym, FuncAsym}, ...
                 'label', {'Pic HT (deg)', 'Pic HG (deg)'});

Corr = struct('Task', {}, 'Posture', {}, 'ROM', {}, 'Group', {}, 'n', {}, 'nExcluded_OutOfRange', {}, ...
    'Pearson_r', {}, 'Pearson_p', {}, 'Spearman_rho', {}, 'Spearman_p', {}, ...
    'Slope_degROM_per_degPosture', {}, 'Intercept_deg', {});

for iT = 1:numel(tasks)
    task = tasks{iT};
    for iPo = 1:numel(postDef)
        pd = postDef(iPo);
        X = cell(numel(romDef), 3); Y = cell(numel(romDef), 3); nOut = zeros(numel(romDef), 3);

        for iR = 1:numel(romDef)
            rd = romDef(iR);
            for g = 1:3
                [x, y] = pairValues(PostRes, PostAsym, rd.res, rd.asym, task, groups{g}, pd.name, rd.name);
                valid   = ~isnan(x) & ~isnan(y);
                inRange = x >= pd.range(1) & x <= pd.range(2);
                nOut(iR, g) = sum(valid & ~inRange);
                X{iR, g} = x(valid & inRange);
                Y{iR, g} = y(valid & inRange);
            end
        end
        if all(cellfun(@isempty, X(:))), continue; end

        figure('Name', ['Posture vs ROM — ', pd.name, ' — ', task], 'Color', 'w');
        for iR = 1:numel(romDef)
            rd = romDef(iR);
            allY = [Y{iR, :}];
            if isempty(allY), yl = [0 180]; else, yl = [max(0, min(allY) - 5), max(allY) + 5]; end
            for g = 1:3
                x = X{iR, g}; y = Y{iR, g}; n = numel(x);
                [r, pr]     = pearsonP(x, y);
                [rho, prho] = pearsonP(rankTies(x), rankTies(y));
                slope = NaN; icpt = NaN;
                if n >= 2 && std(x) > 0
                    c = polyfit(x, y, 1); slope = c(1); icpt = c(2);
                end

                ci = length(Corr) + 1;
                Corr(ci).Task = task;        Corr(ci).Posture = pd.name;
                Corr(ci).ROM  = rd.name;     Corr(ci).Group   = groups{g};
                Corr(ci).n    = n;           Corr(ci).nExcluded_OutOfRange = nOut(iR, g);
                Corr(ci).Pearson_r    = r;   Corr(ci).Pearson_p  = pr;
                Corr(ci).Spearman_rho = rho; Corr(ci).Spearman_p = prho;
                Corr(ci).Slope_degROM_per_degPosture = slope;
                Corr(ci).Intercept_deg = icpt;

                subplot(numel(romDef), 3, (iR - 1) * 3 + g); hold on;
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
                xlim(pd.range); ylim(yl);
                xlabel(pd.label); ylabel(rd.label);
                title({sprintf('%s %s (n=%d, %d hors plage)', rd.name, labels{g}, n, nOut(iR, g)), ...
                       sprintf('r=%.2f (p=%s) | \\rho=%.2f (p=%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
                      'FontSize', 8);
                box on;
            end
        end
        sgtitle([pd.name, ' vs pic d''élévation HT / HG — ', task, ' (posture et ROM du même essai)']);
        annotation('textbox', [0 0 1 0.04], 'String', ...
            sprintf(['Paires avec %s dans [%d, %d]° uniquement (hors plage exclus, comptés dans chaque titre). ', ...
                     'ROM = pic d''élévation (*_max_deg). %d tests au total (pas de correction pour comparaisons multiples).'], ...
                    lower(pd.name), pd.range(1), pd.range(2), 24), ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
    end
end

if ~isempty(Corr) && ~isempty(OutputFile)
    writetable(struct2table(Corr), OutputFile, 'Sheet', 'Correlation_ROM');
    disp(['Feuille Correlation_ROM ajoutée : ', OutputFile]);
end

end

% =========================================================================
%  APPARIEMENT POSTURE / ROM
% =========================================================================
% x = posture (Inclination ou SIR), y = pic ROM (HT ou HG), une paire par
% ligne patient/côté (PRE, POST) ou par épaule asymptomatique (ASYM), pour
% la tâche donnée. Clé : Numero + Side + Task (+ Condition pour ASYM).
function [x, y] = pairValues(PostRes, PostAsym, RomRes, RomAsym, task, group, postName, romName)
x = []; y = [];
if strcmp(group, 'ASYM')
    P = PostAsym; Q = RomAsym;
    fX = [postName, '_deg'];
    fY = [romName, '_ASYM_max_deg'];
else
    P = PostRes; Q = RomRes;
    fX = [postName, '_', group, '_deg'];
    fY = [romName, '_', group, '_max_deg'];
end
if isempty(P) || isempty(Q) || ~isfield(P, fX) || ~isfield(Q, fY), return; end

P = P(strcmp({P.Task}, task));
Q = Q(strcmp({Q.Task}, task));
x = NaN(1, numel(P)); y = NaN(1, numel(P));
for k = 1:numel(P)
    sel = [Q.Numero] == P(k).Numero & strcmp({Q.Side}, P(k).Side);
    if strcmp(group, 'ASYM')
        sel = sel & strcmp({Q.Condition}, P(k).Condition);
    end
    j = find(sel, 1);
    if isempty(j), continue; end
    x(k) = P(k).(fX);
    y(k) = Q(j).(fY);
end
end

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
