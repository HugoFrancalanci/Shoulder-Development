% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Outils communs aux analyses de l'article posture
%                (CorrelatePostureROM, AnalyseThoraxContribution,
%                PostureSecondaryAnalyses, PlotArticleFigures) : définitions
%                (postures, métriques, tâches), lecture de Data_posture.xlsx
%                et statistiques sans Statistics Toolbox.
%                Méthodes statiques : PostureUtils.getCol(T, 'Numero'), etc.
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

classdef PostureUtils

methods (Static)

% =========================================================================
%  DÉFINITIONS
% =========================================================================
% D.post   : postures PRE (feuille 'Posture') ; assis = début des essais
%            ANALYTIC, debout = CALIBRATION3
% D.metric : ROM (feuille 'Cinematique') et pic (feuille 'Cinematique_pics')
% D.task   : ANALYTIC1 = flexion, ANALYTIC2 = scaption
% D.joint  : HT et HG
% Colonne cinématique = <tâche>_<métrique>_<joint><_Pre|_Post>,
% ex. analytic1_ROM_Humerothoracique_Pre
function D = defs()
D.post = struct('name',  {'Inclination', 'SIR', 'InclinationStanding'}, ...
                'col',   {'Inclinaison_thoracique_Pre', 'Rotation_scapulaire_interne_Pre', ...
                          'Inclinaison_thoracique_Pre_Calibration3'}, ...
                'title', {'Inclinaison thoracique assis', 'SIR (Moroder)', 'Inclinaison thoracique debout'}, ...
                'label', {'Inclinaison thoracique assis PRE (deg)', 'SIR Moroder PRE (deg)', ...
                          'Inclinaison thoracique debout PRE (deg)'});
D.metric = struct('name', {'ROM', 'Pic'}, 'sheet', {'Cinematique', 'Cinematique_pics'}, 'key', {'ROM', 'MAX'});
D.task   = struct('name', {'ANALYTIC1', 'ANALYTIC2'}, 'key', {'analytic1', 'analytic2'}, ...
                  'label', {'flexion', 'scaption'});
D.joint  = struct('name', {'HT', 'HG'}, 'col', {'Humerothoracique', 'Humerogravitaire'});
D.groups    = {'PRE', 'POST'};
D.grpSuffix = {'_Pre', '_Post'};
D.cols      = [0.8500 0.3250 0.0980; 0 0.4470 0.7410];   % PRE, POST
end

% =========================================================================
%  LECTURE EXCEL
% =========================================================================
% Lit une feuille (en-têtes préservés) et retire les lignes vides
% (Numero vide ou non numérique : lignes d'espacement entre les valeurs).
function T = readSheet(DataFile, sheet)
T = readtable(DataFile, 'Sheet', sheet, 'VariableNamingRule', 'preserve');
T = T(~isnan(PostureUtils.getCol(T, 'Numero')), :);
end

% Vrai si la colonne existe (insensible à la casse)
function tf = hasCol(T, name)
tf = any(strcmpi(T.Properties.VariableNames, name));
end

% Colonne numérique (ligne) par nom, insensible à la casse. Une colonne lue
% comme texte (cellule vide, virgule décimale) est convertie, non numérique
% -> NaN.
function v = getCol(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('PostureUtils:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', name, strjoin(names, ', '));
end
v = T.(names{j});
if iscell(v) || isstring(v)
    v = str2double(strrep(string(v), ',', '.'));
end
v = double(v(:)');
end

% Colonne texte (cellule ligne de char) par nom ; cellule vide / NaN -> ''
function v = getText(T, name)
names = T.Properties.VariableNames;
j = find(strcmpi(names, name), 1);
if isempty(j)
    error('PostureUtils:missingColumn', 'Colonne "%s" introuvable. Colonnes : %s', name, strjoin(names, ', '));
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

% Colonne 'name' de T réalignée sur les Numero numRef (NaN si absent)
function v = alignCol(T, name, numRef)
num = PostureUtils.getCol(T, 'Numero');
x   = PostureUtils.getCol(T, name);
[tf, loc] = ismember(numRef, num);
v = NaN(size(numRef));
v(tf) = x(loc(tf));
end

function s = fileName(f)
[~, nm, ext] = fileparts(f);
s = [nm, ext];
end

% =========================================================================
%  STATISTIQUES
% =========================================================================
% Corrélation de Pearson + p bilatéral (Student, df = n-2) via betainc.
% NaN si n < 3 ou variance nulle.
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

% Spearman = Pearson sur les rangs (ex-aequo au rang moyen)
function [rho, p] = spearmanP(x, y)
[rho, p] = PostureUtils.pearsonP(PostureUtils.rankTies(x), PostureUtils.rankTies(y));
end

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

% Moyenne, IC 95 % et p bilatéral vs 0 (t à un échantillon / apparié)
function [m, lo, hi, p] = meanCI(d)
d = d(~isnan(d)); n = numel(d);
m = NaN; lo = NaN; hi = NaN; p = NaN;
if n < 2, return; end
m  = mean(d); se = std(d) / sqrt(n);
tc = PostureUtils.tInv975(n - 1);
lo = m - tc * se; hi = m + tc * se;
if se > 0, p = PostureUtils.tPval(m / se, n - 1); end
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
tc  = PostureUtils.tInv975(df);
lo  = b - tc * se;  hi = b + tc * se;
p0  = PostureUtils.tPval(b / se, df);
p1  = PostureUtils.tPval((b + 1) / se, df);
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
    if PostureUtils.tPval(t, df) > 0.05, lo = t; else, hi = t; end
end
end

% Régression linéaire multiple y ~ 1 + X (moindres carrés, lignes avec NaN
% exclues) : coefficients (sans l'ordonnée), erreurs types, p bilatéraux
% (Student, df = n - k - 1), IC 95 %, R² et n.
function [b, se, p, lo, hi, R2, n] = olsFit(y, X)
y = y(:); if size(X, 1) ~= numel(y), X = X'; end
v = ~isnan(y) & all(~isnan(X), 2);
y = y(v); X = [ones(sum(v), 1), X(v, :)];
n = numel(y); k = size(X, 2); df = n - k;
B   = X \ y; res = y - X * B;
SE  = sqrt(diag((res' * res / df) * inv(X' * X))); %#ok<MINV>
tc  = PostureUtils.tInv975(df);
P   = arrayfun(@(i) PostureUtils.tPval(B(i) / SE(i), df), 1:k)';
R2  = 1 - (res' * res) / sum((y - mean(y)).^2);
b = B(2:end); se = SE(2:end); p = P(2:end);
lo = b - tc * se; hi = b + tc * se;
end

% Médiane et IC 95 % par bootstrap (percentiles, nBoot tirages, graine fixe)
function [m, lo, hi] = bootMedianCI(v, nBoot)
v = v(~isnan(v)); v = v(:); n = numel(v);
m = median(v); lo = NaN; hi = NaN;
if n < 2, return; end
s  = RandStream('mt19937ar', 'Seed', 1);
bm = sort(median(v(randi(s, n, n, nBoot)), 1));
lo = interp1(1:nBoot, bm, 1 + 0.025 * (nBoot - 1));
hi = interp1(1:nBoot, bm, 1 + 0.975 * (nBoot - 1));
end

% Texte "p..." prêt à afficher : 'p=0.040', 'p<0.001' ou 'p=NA'
function s = fmtP(p)
if isnan(p),       s = 'p=NA';
elseif p < 0.001,  s = 'p<0.001';
else,              s = sprintf('p=%.3f', p);
end
end

end
end
