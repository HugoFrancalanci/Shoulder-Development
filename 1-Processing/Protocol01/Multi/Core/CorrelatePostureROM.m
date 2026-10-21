% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Corrélation entre la posture PRÉ-opératoire (inclinaison
%                thoracique assis et debout, SIR de Moroder) et l'élévation
%                du bras (HT et HG), PRE et POST, par tâche (ANALYTIC1 =
%                flexion, ANALYTIC2 = scaption) et pour deux métriques :
%                ROM (feuille 'Cinematique') et pic (feuille
%                'Cinematique_pics'). Hypothèse H2 de l'article.
%                3 postures x 2 joints x 2 groupes x 2 tâches x 2 métriques
%                = 48 tests (pas de correction ici).
%
%                Groupe PRE  = posture PRE x cinématique PRE
%                Groupe POST = posture PRE x cinématique POST
%                Pearson r, Spearman rho (ex-aequo au rang moyen), p
%                bilatéral (Student, df = n-2), régression cinématique ~
%                posture (pente en degrés par degré).
%
%                Lit l'Excel trié à la main (Data_posture.xlsx), appariement
%                par Numero, aucune exclusion. Pas de figure : les figures de
%                l'article sont dans PlotArticleFigures.
%                Analyses déplacées en octobre 2026 :
%                  contribution du thorax (H1) -> AnalyseThoraxContribution
%                  Moroder, inclinaison x SIR, assis vs debout, HG moins HT
%                  -> PostureSecondaryAnalyses
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie, feuille
%                       'Correlation_ROM' ; '' = pas d'export
% Outputs : Corr        (struct array) une ligne par métrique/tâche/
%                       posture/joint/groupe
% -------------------------------------------------------------------------
% Dependencies : PostureUtils
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Corr = CorrelatePostureROM(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end
U = PostureUtils;
D = U.defs();

P    = U.readSheet(DataFile, 'Posture');
numP = U.getCol(P, 'Numero');

Corr = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Posture', {}, 'Joint', {}, 'Group', {}, 'n', {}, ...
    'Pearson_r', {}, 'Pearson_p', {}, 'Spearman_rho', {}, 'Spearman_p', {}, ...
    'Slope_deg_per_degPosture', {}, 'Intercept_deg', {});

for md = D.metric
    K = U.readSheet(DataFile, md.sheet);
    [~, iP, iK] = intersect(numP, U.getCol(K, 'Numero'), 'stable');
    disp(['Patients appariés (Posture et ', md.sheet, ') : ', num2str(numel(iP))]);
    for td = D.task
        for pd = D.post
            xAll = U.getCol(P, pd.col);
            xAll = xAll(iP);
            for jd = D.joint
                for g = 1:numel(D.groups)
                    y = U.getCol(K, sprintf('%s_%s_%s%s', td.key, md.key, jd.col, D.grpSuffix{g}));
                    y = y(iK);
                    v = ~isnan(xAll) & ~isnan(y);
                    x = xAll(v); y = y(v); n = numel(x);
                    [r, pr]     = U.pearsonP(x, y);
                    [rho, prho] = U.spearmanP(x, y);
                    c = [NaN NaN];
                    if n >= 2 && std(x) > 0, c = polyfit(x, y, 1); end
                    Corr(end + 1) = struct('Metric', md.name, 'Task', td.name, 'Movement', td.label, ...
                        'Posture', pd.name, 'Joint', jd.name, 'Group', D.groups{g}, 'n', n, ...
                        'Pearson_r', r, 'Pearson_p', pr, 'Spearman_rho', rho, 'Spearman_p', prho, ...
                        'Slope_deg_per_degPosture', c(1), 'Intercept_deg', c(2)); %#ok<AGROW>
                end
            end
        end
    end
end

if ~isempty(OutputFile)
    writetable(struct2table(Corr), OutputFile, 'Sheet', 'Correlation_ROM');
    disp(['Feuille Correlation_ROM écrite : ', OutputFile]);
end
end
