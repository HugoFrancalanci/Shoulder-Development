% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Correction des courbes ST et TX "inversées" dans les
%                résultats de ComputeClinicalContributionsFromDatabase.m et
%                ComputeFunctionalContributionsFromDatabase.m (fonction
%                partagée par les deux, pour ne pas dupliquer la logique).
%
%                Problème : l'angle de repos de ST (et de TX) diffère
%                fortement d'un patient à l'autre (ex. ST : environ -10 deg
%                pour la majorité, +20 à +50 deg pour certains, avec un
%                mouvement de même sens et d'amplitude proche). abs() retourne
%                les courbes négatives en cloche mais pas les positives, qui
%                restent en U : ces courbes vont alors à l'opposé de la
%                moyenne. Le range (max-min) n'est pas touché quand le brut
%                ne traverse pas zéro ; la courbe et le max, si.
%
%                Détection (par tâche et par métrique, PRE/POST/côtés
%                confondus) : la courbe (abs, moyenne des cycles, 101 points)
%                est corrélée (Pearson signé) à la courbe moyenne du groupe,
%                recalculée sans les courbes inversées (2 passes). Corrélation
%                < CorrThresh (0 par défaut) = 'inversée'. Même règle que
%                Multi/Core/ComputeCurveQualityFromDatabase.m (sauf que la
%                rugosité n'entre pas ici dans la sélection de la référence).
%
%                Correction, uniquement pour les courbes inversées :
%                  courbe   = sp * (brut - repos) + repos_cohorte
%                  range    = moyenne des cycles de (max - min) du BRUT
%                             (indépendant du signe et de l'offset)
%                  max      = moyenne des cycles de max(sp*(brut - repos))
%                             + repos_cohorte
%                  pct      = range corrigé / range de la référence (HT ou HG)
%                repos = moyenne du début et de la fin du cycle du patient ;
%                sp = sens propre de l'excursion brute du patient (+1/-1) ;
%                repos_cohorte = repos de la courbe moyenne du groupe. Une
%                colonne <Metrique>_<PRE|POST>_corrected (0/1) indique les
%                valeurs corrigées.
%
%                Attention TX : l'angle du thorax reflète en partie la
%                posture réelle du patient ; remplacer son niveau de repos
%                par celui de la cohorte efface cette information (le range
%                est, lui, conservé).
%
% Inputs  : Results   (struct array) tel que construit par les fonctions
%                     Compute*ContributionsFromDatabase (champs
%                     <M>_<PRE|POST>_deg/_pct/_max_deg, M = ST, TX)
%           Curves    (struct array, même indexation que Results) champs
%                     <M>_<C> (courbe abs) et <M>_<C>_raw, _rangeRaw,
%                     _peakExc, _excSign (M = ST, TX ; C = PRE, POST)
%           refPrefix (char) 'HT' (clinical) ou 'HG' (functional) :
%                     dénominateur des pourcentages
%           CorrThresh (double) seuil de corrélation (0)
% Outputs : Results, Curves mis à jour (courbes inversées corrigées) + champs
%           <M>_<C>_corrected dans Results
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, Curves] = ApplyInversionCorrectionSTTX(Results, Curves, refPrefix, CorrThresh)

if isempty(Results), return; end
if nargin < 4 || isempty(CorrThresh), CorrThresh = 0; end

metrics = {'ST', 'TX'};
conds   = {'PRE', 'POST'};

for m = 1:numel(metrics)
    for c = 1:numel(conds)
        fld = [metrics{m}, '_', conds{c}, '_corrected'];
        for i = 1:numel(Results)
            Results(i).(fld) = 0;
        end
    end
end

tasks = unique({Results.Task});
for it = 1:numel(tasks)
    for m = 1:numel(metrics)
        metric  = metrics{m};
        entries = [];   % [indice ligne, indice condition]
        C       = [];   % courbes rééchantillonnées, 1 par entrée

        for i = find(strcmp({Results.Task}, tasks{it}))
            for c = 1:numel(conds)
                f = [metric, '_', conds{c}];
                if ~isfield(Curves, f) || isempty(Curves(i).(f)), continue; end
                r = resample101(Curves(i).(f));
                if all(isnan(r)), continue; end
                entries(end+1, :) = [i, c]; %#ok<AGROW>
                C(end+1, :)       = r;      %#ok<AGROW>
            end
        end
        if size(C, 1) < 3, continue; end

        keep = true(size(C, 1), 1);
        rc   = NaN(size(C, 1), 1);
        for pass = 1:2
            tmpl = mean(C(keep, :), 1, 'omitnan');
            for k = 1:size(C, 1)
                rc(k) = pearsonR(C(k, :), tmpl);
            end
            keep = ~(rc < CorrThresh);
        end
        rest = mean(tmpl([1 end]));

        nFix = 0;
        for k = find(rc < CorrThresh)'
            i  = entries(k, 1);
            cn = conds{entries(k, 2)};
            f  = [metric, '_', cn];
            if ~isfield(Curves, [f, '_raw']) || isempty(Curves(i).([f, '_raw'])), continue; end

            raw  = Curves(i).([f, '_raw']);
            sp   = Curves(i).([f, '_excSign']);
            base = mean(raw([1 end]));
            rangeRaw = Curves(i).([f, '_rangeRaw']);

            Curves(i).(f)                = sp * (raw - base) + rest;
            Results(i).([f, '_deg'])     = rangeRaw;
            Results(i).([f, '_pct'])     = safePct(rangeRaw, Results(i).([refPrefix, '_', cn, '_deg']));
            Results(i).([f, '_max_deg']) = Curves(i).([f, '_peakExc']) + rest;
            Results(i).([f, '_corrected']) = 1;
            nFix = nFix + 1;
        end
        disp(['  Correction inversée ', metric, ' - ', tasks{it}, ' : ', num2str(nFix), ' / ', ...
              num2str(size(C, 1)), ' courbe(s) PRE+POST corrigée(s) (', ...
              num2str(100 * nFix / size(C, 1), '%.1f'), ' %)']);
    end
end

end

function r = pearsonR(c, t)
r = NaN;
v = ~isnan(c) & ~isnan(t);
if sum(v) < 3, return; end
c = c(v); t = t(v);
if std(c) == 0 || std(t) == 0, return; end
cc = corrcoef(c, t);
r = cc(1, 2);
end

function p = safePct(num, den)
if isnan(num) || isnan(den) || den == 0
    p = NaN;
else
    p = num / den * 100;
end
end

function c = resample101(curve)
c = NaN(1, 101);
curve = curve(:);
curve = curve(~isnan(curve));
if length(curve) < 2, return; end
xOrig = linspace(0, 100, length(curve));
c = interp1(xOrig, curve, linspace(0, 100, 101), 'linear');
end
