% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Choix du cycle retenu pour les valeurs d'élévation (pic et
%                amplitude), commun à ComputeClinicalContributionsFromDatabase
%                et ComputeFunctionalContributionsFromDatabase pour que HT,
%                HG, GH, ST et le thorax d'une même épaule viennent du même
%                cycle (décomposition cohérente).
%
%                Règle (validée avec le superviseur, octobre 2026) :
%                  1) pic de chaque cycle = moyenne de Win (10) points
%                     autour du maximum de |HG| (5 avant, 4 après, bornés au
%                     cycle), au lieu d'un seul point ;
%                  2) cycle retenu = meilleur des cycles valides (pic le plus
%                     haut) ;
%                  3) un cycle n'est pas valide s'il contient un saut (écart
%                     entre deux points consécutifs > JumpThresh = 90 deg sur
%                     le signal signé de HG, HT, ST ou du thorax, typiquement
%                     un repliement à ±180 deg ; ou variation > WrapThresh =
%                     120 deg sur WrapWin = 3 points : repliement étalé sur
%                     plusieurs points par le rééchantillonnage à 101 points,
%                     invisible point à point, ajouté le 26.11.2026 après
%                     n°59 scaption post cycle 3, HT de -144 à +37 deg, 132
%                     deg sur 3 points pour 77 deg au plus d'un point au
%                     suivant ; sur toute la cohorte, élévations, 99,9 % des
%                     cycles sans saut restent sous 91 deg sur 3 points et
%                     seul ce cycle dépasse 120) ou si son pic HG s'écarte de
%                     plus de OutlierThresh = 20 deg de la médiane des pics
%                     (si au moins 3 cycles) ; alerte si le cycle au pic le
%                     plus haut est écarté, ou si aucun cycle n'est valide (le
%                     meilleur est alors gardé).
%                Amplitude d'un angle sur le cycle retenu = moyenne de Win
%                points autour du maximum moins minimum brut ; pic = moyenne
%                de Win points autour du maximum. Le minimum n'est pas lissé :
%                il tombe presque toujours au bord du cycle (repos), où une
%                fenêtre mordrait sur la montée du bras et sous-estimerait
%                l'amplitude de 5 à 20 deg (vérifié sur la partie 16).
%                GH n'entre pas dans le contrôle des sauts (blocage de cardan
%                en flexion, voir CheckCurvesFromDatabase).
%                Rotations (ANALYTIC3 RE, ANALYTIC4 RI ; octobre 2026, même
%                règle que le fichier de l'article collaboratif) : HG est
%                proche du blocage de cardan bras le long du corps, le cycle
%                est donc choisi sur HT (rotation axiale, DOF2 Y, séquence
%                YXZ), signal orienté dans le sens du mouvement (RotSign :
%                RE = -angle, RI = +angle, mêmes signes à droite et à gauche,
%                vérifié sur les 72 patients de l'article collaboratif).
%                Valeur d'un cycle = rotation réalisée depuis la position de
%                départ (moyenne de Win points autour du maximum moins
%                moyenne des NStart premiers points) : pas de valeur négative
%                quand le neutre n'est pas atteint, et le départ décalé de la
%                RI (environ 40 deg) n'est pas compté. Contrôle des sauts sur
%                HT seul ; même contrôle des valeurs aberrantes et même choix
%                du cycle que pour les élévations.
%                Contrôles de forme (alerte seulement, valeurs gardées ;
%                mêmes contrôles que le fichier de l'article collaboratif) :
%                  sens opposé au groupe : la courbe moyenne s'éloigne de
%                    son départ dans l'autre sens que le groupe (HT signé
%                    avec RotSign en rotation, ElevSignHT en élévation, sens
%                    mesurés sur les 72 patients ; |HG| en élévation) ;
%                  courbe décalée : départ du cycle retenu (NStart premiers
%                    points) au-delà de ShiftThresh = 90 deg (repliement à
%                    ±180 deg probable).
% -------------------------------------------------------------------------
% Usage   : Sel = BestCycle.select(t, task, side)
%             t    : un essai (Trial) ; task : 'ANALYTIC1'...'ANALYTIC4' ;
%             side : 'R' | 'L'
%             Sel  : .idx (cycle retenu ; NaN = pas de donnée), .nCycles,
%                    .peaks (pic HG lissé, ou rotation HT depuis le départ,
%                    de chaque cycle), .jump, .outlier (logiques par cycle),
%                    .sign (sens du mouvement HT pour les rotations, NaN
%                    sinon), .alert (texte, '' si rien)
%           v = BestCycle.peak(data, idx)   ; v = BestCycle.range(data, idx)
%           v = BestCycle.rotation(data, idx)  (pic moins départ)
%           c = BestCycle.curve(data, idx)     (courbe du cycle retenu)
%             data : [points x cycles] ; idx : cycle retenu (NaN : ancien
%                    calcul, moyenne des cycles, sans fenêtre)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

classdef BestCycle

properties (Constant)
    Win           = 10;   % points moyennés autour d'un extremum (sur 101)
    JumpThresh    = 90;   % deg : saut entre deux points consécutifs
    WrapThresh    = 120;  % deg : variation sur WrapWin points (repliement étalé)
    WrapWin       = 3;
    OutlierThresh = 20;   % deg : écart du pic HG à la médiane des pics
    RotSign       = [-1 1];   % sens du mouvement HT : RE (ANALYTIC3), RI (ANALYTIC4)
    ElevSignHT    = [1 -1; -1 -1];   % sens du mouvement HT en élévation : lignes
                                     % ANALYTIC1 / ANALYTIC2, colonnes R / L
    NStart        = 3;    % points moyennés pour la position de départ
    ShiftThresh   = 90;   % deg : départ du cycle retenu au-delà = courbe décalée
end

methods (Static)

function Sel = select(t, task, side)
Sel = struct('idx', NaN, 'nCycles', 0, 'peaks', [], 'jump', [], 'outlier', [], 'sign', NaN, 'alert', '');
% Joints et DOF (mêmes conventions que les fonctions Compute*Contributions)
tasks = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'};
iT = find(strcmp(tasks, task), 1);
if isempty(iT), return; end
dofHG = [1 1 3 3]; dofHT = [3 1 2 2]; dofST = [1 1 2 2]; dofTX = [3 3 2 2];
if strcmp(side, 'R'), ji = struct('HG', 12, 'HT', 1, 'ST', 3); cf = 'rcycle';
else,                 ji = struct('HG', 13, 'HT', 6, 'ST', 8); cf = 'lcycle';
end

% Rotations : cycle choisi sur HT, rotation depuis la position de départ
if iT > 2
    ht = BestCycle.raw(t, ji.HT, dofHT(iT), cf, false);
    if isempty(ht), return; end
    n = size(ht, 2);
    Sel.nCycles = n;
    Sel.sign = BestCycle.RotSign(iT - 2);
    pk = NaN(1, n);
    for c = 1:n, pk(c) = BestCycle.rotation(Sel.sign * ht, c); end
    [jump, d] = BestCycle.jumps(ht);
    why = repmat({''}, 1, n);
    for c = find(jump), why{c} = sprintf('saut %.0f deg HT', d(c)); end
    Sel = BestCycle.pick(Sel, pk, jump, why, 'rotation');
    Sel = BestCycle.shape(Sel, Sel.sign * ht, 'HT');
    return;
end

hg = BestCycle.raw(t, ji.HG, dofHG(iT), cf, false);
if isempty(hg), return; end
n = size(hg, 2);
Sel.nCycles = n;

% Pic HG lissé de chaque cycle
pk = NaN(1, n);
for c = 1:n, pk(c) = BestCycle.peak(abs(hg), c); end

% Sauts sur les signaux signés (HG, HT, ST, thorax flexion / extension et
% inclinaison latérale)
sig = {hg, BestCycle.raw(t, ji.HT, dofHT(iT), cf, false), BestCycle.raw(t, ji.ST, dofST(iT), cf, false), ...
       BestCycle.raw(t, 11, dofTX(iT), cf, true), BestCycle.raw(t, 11, 1, cf, true)};
sigName = {'HG', 'HT', 'ST', 'thorax', 'thorax lat.'};
jump = false(1, n); why = repmat({''}, 1, n);
for k = 1:numel(sig)
    x = sig{k};
    if isempty(x) || size(x, 2) ~= n, continue; end
    [j, d] = BestCycle.jumps(x);
    for c = find(j & ~jump), why{c} = sprintf('saut %.0f deg %s', d(c), sigName{k}); end
    jump = jump | j;
end
Sel = BestCycle.pick(Sel, pk, jump, why, 'pic');
Sel = BestCycle.shape(Sel, abs(hg), 'HG');
if size(sig{2}, 2) == n
    Sel = BestCycle.shape(Sel, BestCycle.ElevSignHT(iT, 1 + strcmp(side, 'L')) * sig{2}, 'HT');
end
end

% Contrôle de la forme (alerte seulement, valeurs gardées) sur x [points x
% cycles], déjà orienté dans le sens du mouvement attendu : sens opposé au
% groupe (la courbe moyenne s'éloigne de son départ dans l'autre sens) et
% courbe décalée (départ du cycle retenu au-delà de ShiftThresh, repliement
% à ±180 deg probable)
function Sel = shape(Sel, x, name)
if isempty(x) || isnan(Sel.idx) || Sel.idx > size(x, 2), return; end
msg = {};
m = mean(x, 2, 'omitnan');
[~, im] = max(abs(m - m(1)));
if m(im) - m(1) < 0
    msg{end + 1} = sprintf('sens opposé au groupe (%s)', name);
end
s0 = mean(x(1:min(BestCycle.NStart, size(x, 1)), Sel.idx), 'omitnan');
if abs(s0) > BestCycle.ShiftThresh
    msg{end + 1} = sprintf('courbe décalée (départ %s à %.0f deg)', name, s0);
end
if isempty(msg), return; end
if ~isempty(Sel.alert), msg = [{Sel.alert}, msg]; end
Sel.alert = strjoin(msg, ' ; ');
end

% Contrôle des valeurs aberrantes (écart à la médiane des cycles, si au
% moins 3 cycles) et choix du cycle valide à la valeur la plus haute ;
% alerte si ce n'est pas le cycle le plus haut, ou si aucun n'est valide
function Sel = pick(Sel, pk, jump, why, label)
outlier = false(size(pk));
if sum(~isnan(pk)) >= 3
    outlier = abs(pk - median(pk, 'omitnan')) > BestCycle.OutlierThresh;
    for c = find(outlier & ~jump)
        why{c} = sprintf('%s à %.0f deg de la médiane', label, pk(c) - median(pk, 'omitnan'));
    end
end
Sel.peaks = pk; Sel.jump = jump; Sel.outlier = outlier;

valid = ~jump & ~outlier & ~isnan(pk);
[~, iMax] = max(pk);
if any(valid)
    cand = pk; cand(~valid) = -Inf;
    [~, Sel.idx] = max(cand);
    if Sel.idx ~= iMax
        Sel.alert = sprintf('cycle %d écarté (%s), cycle %d retenu', iMax, why{iMax}, Sel.idx);
    end
else
    Sel.idx = iMax;
    Sel.alert = sprintf('aucun cycle valide (%s), cycle %d gardé', strjoin(unique(why(~cellfun(@isempty, why))), ', '), iMax);
end
end

% Moyenne de Win points autour du maximum de la colonne idx ; idx = NaN :
% moyenne des cycles du maximum (ancien calcul, rotations)
function v = peak(data, idx)
v = NaN;
if isempty(data), return; end
if isnan(idx), v = mean(max(data, [], 1), 'omitnan'); return; end
if idx > size(data, 2), return; end
x = data(:, idx);
if all(isnan(x)), return; end
[~, im] = max(x);
v = mean(x(BestCycle.window(im, numel(x))), 'omitnan');
end

% Moyenne de Win points autour du maximum moins minimum brut de la colonne
% idx ; idx = NaN : moyenne des cycles de (max - min) (ancien calcul,
% rotations)
function v = range(data, idx)
v = NaN;
if isempty(data), return; end
if isnan(idx), v = mean(max(data, [], 1) - min(data, [], 1), 'omitnan'); return; end
if idx > size(data, 2), return; end
x = data(:, idx);
if all(isnan(x)), return; end
[~, im] = max(x);
v = mean(x(BestCycle.window(im, numel(x))), 'omitnan') - min(x);
end

% Rotation réalisée depuis la position de départ sur la colonne idx :
% moyenne de Win points autour du maximum moins moyenne des NStart premiers
% points (data déjà orienté dans le sens du mouvement)
function v = rotation(data, idx)
v = NaN;
if isempty(data) || isnan(idx) || idx > size(data, 2), return; end
x = data(:, idx);
if all(isnan(x)), return; end
[~, im] = max(x);
v = mean(x(BestCycle.window(im, numel(x))), 'omitnan') - mean(x(1:min(BestCycle.NStart, numel(x))), 'omitnan');
end

% Courbe [points x 1] du cycle retenu idx (figures, correction ST/TX) ;
% idx = NaN ou cycle vide : moyenne des cycles (ancien calcul)
function c = curve(data, idx)
c = [];
if isempty(data), return; end
if ~isnan(idx) && idx <= size(data, 2) && any(~isnan(data(:, idx)))
    c = data(:, idx);
else
    c = mean(data, 2, 'omitnan');
end
end

% Sauts de chaque cycle de x [points x cycles] : écart entre deux points
% consécutifs > JumpThresh, ou variation sur WrapWin points > WrapThresh
% (repliement à ±180 deg étalé par le rééchantillonnage). d = plus grand
% écart d'un point au suivant, ou variation sur WrapWin points si c'est elle
% qui déclenche (pour l'alerte).
function [j, d] = jumps(x)
d = max(abs(diff(x, 1, 1)), [], 1, 'omitnan');
w = BestCycle.WrapWin;
dw = zeros(1, size(x, 2));
if size(x, 1) > w, dw = max(abs(x(1 + w:end, :) - x(1:end - w, :)), [], 1, 'omitnan'); end
j1 = d > BestCycle.JumpThresh; jw = dw > BestCycle.WrapThresh;
d(jw & ~j1) = dw(jw & ~j1);
j = j1 | jw;
end

% Indices de la fenêtre de Win points autour de l'indice i, bornée au cycle
function w = window(i, n)
lo = max(1, i - BestCycle.Win / 2);
hi = min(n, lo + BestCycle.Win - 1);
lo = max(1, hi - BestCycle.Win + 1);
w = lo:hi;
end

% Signal signé [points x cycles] d'un DOF ; shared = thorax (Joint 11),
% repli sur l'autre côté si le champ est vide
function x = raw(t, ji, dof, cf, shared)
x = [];
if length(t.Joint) < ji, return; end
if shared && isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
x = squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :));
if isvector(x), x = x(:); end
end

end
end
