% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Détection des courbes à forme aberrante par rapport à la
%                courbe moyenne, pour HT, HG, GH, ST, TX (thorax : une seule
%                ligne par patient ; seule l'inversion 'Inversee' y est
%                testée, pas la rugosité). La correction inversée est
%                appliquée à ST et TX uniquement dans les figures ; ANALYTIC1 et
%                ANALYTIC2 ; PRE et POST, depuis PatientDatabase.mat. Mêmes
%                joints/DOF et MÊMES courbes que les sorties clinical/
%                functional : abs() point par point sur chaque cycle, puis
%                moyenne des cycles (getRangeCycle/getCurveCycle).
%                HT 1/6 DOF3|1, HG 12/13 DOF1, GH 2/7 DOF3|1, ST 3/8 DOF1
%                (DOF ANALYTIC1|ANALYTIC2).
%
%                Pour chaque groupe (tâche+métrique, PRE/POST/côtés
%                confondus), la courbe de référence est la moyenne des
%                courbes du groupe (recalculée sans les courbes aberrantes,
%                2 passes) et chaque courbe c est ajustée par c ~ a*t + b
%                (a >= 0 : une courbe inversée n'est pas acceptée) :
%                l'AMPLITUDE et l'OFFSET sont libres, seule la forme compte.
%
%                Deux scores LOCAUX (un RMSE global, lui, moyenne sur 101
%                points et noie un pic ou un saut de quelques points -
%                gardé en colonne informative seulement, RMSE_fit_deg) :
%                  MaxResid_deg  max |c - (a*t + b)| : plus grand écart
%                                ponctuel à la moyenne ajustée (pic, saut,
%                                repli en V, forme inversée)
%                  Rough_deg     max |dérivée seconde| de la courbe : détecte
%                                les discontinuités SANS référence
%                Chacun est converti en z-score robuste (médiane/MAD) de
%                son log dans le groupe : RobustZ_MaxResid, RobustZ_Rough.
%                Le seuil est relatif à la distribution du groupe, pas un
%                nombre de degrés fixé (voir plus bas quels scores comptent
%                pour le verdict).
%                Corr_vsMean : corrélation de Pearson SIGNEE avec la référence.
%                Négative = la courbe va à l'opposé de la moyenne (cloche
%                inversée ou en U, typiquement une courbe brute qui traverse
%                zéro à cause d'un offset et que abs() replie) : Reason
%                'Inversee' si Corr_vsMean < CorrThresh (défaut 0). Ces
%                courbes lisses n'ont ni pic ni saut, donc les scores locaux
%                ne les voient pas ; elles sont aussi exclues de la
%                référence pour ne pas la tirer.
%                CRITERES D'EXCLUSION (verdict) : forte discontinuité
%                (RobustZ_Rough > ZThresh -> Reason 'Rough') et inversion vs
%                moyenne (Corr_vsMean < CorrThresh -> 'Inversee'), seuls ou
%                combinés ('Rough+Inversee'), sinon 'OK'. MaxResid_deg et
%                RobustZ_MaxResid restent en colonnes INFORMATIVES (trop
%                d'outliers), n'entrent ni dans le verdict ni dans la
%                référence. RobustZ = RobustZ_Rough.
%                Colonnes de diagnostic sur le brut signé : Range_raw_deg
%                (max-min du brut, indépendant du signe et de l'offset),
%                CrossesZero (le brut traverse zéro, ce que abs() replie),
%                Raw_ExcSign (sens de l'excursion brute par rapport au repos).
%
%                ZThresh est provisoire (défaut 3) : régler d'après les
%                courbes superposées et la figure interactive.
%
% Inputs  : DatabaseFile  (char) chemin vers PatientDatabase.mat
%           OutputFile    (char) chemin de l'Excel de sortie (feuilles
%                         Curve_Quality et Summary)
%           ResultsFolder (char, optionnel) dossier où se terminer (cd)
%           Opts          (struct, optionnel) champs : ZThresh (3),
%                         CorrThresh (0), AsymptomaticSelection ({} par
%                         défaut ; épaules asymptomatiques {ID, côté,
%                         'PRE'/'POST', date}, voir userCommands_Multi.m) :
%                         scorées À PART (référence = moyenne des
%                         asymptomatiques seules, patients inchangés),
%                         feuilles 'Curve_Quality_Asymptomatic' et
%                         'Summary_Asymptomatic' ; pas sur les figures
% Outputs : Results (struct array) une ligne par courbe
%           Excel + 1 figure de courbes superposées par tâche (OK gris,
%           aberrante rouge, moyenne noire) + la même en courbes BRUTES
%           signées (sans abs, ligne 0) + la même figure abs avec la
%           correction inversée (courbes inversées corrigées en vert, ST et
%           TX seulement) + 1 figure
%           interactive :
%           ANALYTIC2, un patient à la fois, tous les DOF (HT, HG, GH,
%           ST) ; touche 'a' = patient suivant, 'q' = précédent (cliquer
%           d'abord sur la figure pour lui donner le focus clavier) + sa
%           figure "Diagnostic patient".
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, AsymResults] = ComputeCurveQualityFromDatabase(DatabaseFile, OutputFile, ResultsFolder, Opts)

if nargin < 3, ResultsFolder = ''; end
if nargin < 4, Opts = struct(); end
if ~isfield(Opts, 'ZThresh') || isempty(Opts.ZThresh), Opts.ZThresh = 3; end
if ~isfield(Opts, 'CorrThresh') || isempty(Opts.CorrThresh), Opts.CorrThresh = 0; end
if ~isfield(Opts, 'AsymptomaticSelection'), Opts.AsymptomaticSelection = {}; end

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputeCurveQualityFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

% Joint(s) [R L] et DOF [ANALYTIC1 ANALYTIC2] par métrique - mêmes valeurs que
% ComputeClinicalContributionsFromDatabase.m / ComputeFunctionalContributionsFromDatabase.m
% TX (thorax, joint 11 unique, partagé) : seule l'inversion est testée (pas
% la rugosité) ; une seule ligne par patient/condition/tâche (pas de doublon R/L).
MetricDef = struct('name',   {'HT',    'HG',      'GH',    'ST',    'TX'}, ...
                   'ji',     {[1 6],   [12 13],   [2 7],   [3 8],   [11 11]}, ...
                   'dof',    {[3 1],   [1 1],     [3 1],   [1 1],   [3 3]}, ...
                   'shared', {false,   false,     false,   false,   true});
tasks      = {'ANALYTIC1', 'ANALYTIC2'};
sides      = {'R', 'L'};
cycFields  = {'rcycle', 'lcycle'};
conditions = {'PRE', 'POST'};

% -------------------------------------------------------------------------
% PASSE 1 : courbe de chaque patient (abs, moyenne des cycles, 101 points)
% -------------------------------------------------------------------------
Results = [];
Curves  = {};   % abs, moyenne des cycles, 101 points (= sorties clinical/functional)
RawCurves = {}; % brut signé, moyenne des cycles, 101 points (diagnostic)
AsymResults = []; % épaules asymptomatiques (côté controlatéral), scorées à part
AsymCurves  = {};

totalPatients = 0;
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S       = load(fileList{iFile}, 'Database');
    nInFile = numel(S.Database);
    totalPatients = totalPatients + nInFile;

for iP = 1:nInFile
    d = S.Database(iP);
    if isempty(d.Numero), continue; end

    for iC = 1:numel(conditions)
        condition = conditions{iC};
        if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Trial')
            continue;
        end
        Trial = d.(condition).Trial;

        for iT = 1:numel(tasks)
            task = tasks{iT};
            tidx = [];
            for k = 1:length(Trial)
                if contains(Trial(k).task, task)
                    tidx = k;
                    break;
                end
            end
            if isempty(tidx), continue; end
            t = Trial(tidx);

            asymSide = findAsymptomaticSide(Opts.AsymptomaticSelection, d, condition);

            for iS = 1:numel(sides)
                side = sides{iS};
                isAsym = strcmp(side, asymSide);
                if ~ismember(side, d.Side) && ~isAsym, continue; end

                for iM = 1:numel(MetricDef)
                    md  = MetricDef(iM);
                    if ~isAsym && md.shared && iS == 2 && ismember('R', d.Side), continue; end
                    ji  = md.ji(iS);
                    dof = md.dof(iT);
                    cyc = getCycles(t, ji, dof, cycFields{iS}, md.shared);
                    if isempty(cyc), continue; end
                    cyc = cyc(:, any(~isnan(cyc), 1));
                    if isempty(cyc), continue; end

                    cycA  = abs(cyc);
                    curve = resample101(mean(cycA, 2, 'omitnan'));
                    if all(isnan(curve)), continue; end

                    % Diagnostic brut : sens de l'excursion par rapport au repos
                    % (moyenne début/fin) et traversée de zéro (que abs() replie)
                    rawCurve = resample101(mean(cyc, 2, 'omitnan'));
                    base0    = mean(rawCurve([1 end]));
                    [~, ipk] = max(abs(rawCurve - base0));
                    excSign  = sign(rawCurve(ipk) - base0);
                    if excSign == 0, excSign = 1; end
                    crossZ   = double(min(rawCurve) < -5 && max(rawCurve) > 5);

                    row = struct('Numero', d.Numero, 'PatientID', d.PatientID, 'Side', side, ...
                        'Task', task, 'Condition', condition, 'Metric', md.name, ...
                        'Joint', ji, 'DOF', dof, 'nCycles', size(cyc, 2), ...
                        'Range_deg', mean(max(cycA, [], 1) - min(cycA, [], 1), 'omitnan'), ...
                        'Peak_deg',  mean(max(cycA, [], 1), 'omitnan'), ...
                        'Range_raw_deg', max(rawCurve) - min(rawCurve), ...
                        'CrossesZero', crossZ, 'Raw_ExcSign', excSign, ...
                        'Fit_scale', NaN, 'Fit_offset_deg', NaN, 'RMSE_fit_deg', NaN, ...
                        'MaxResid_deg', NaN, 'Rough_deg', NaN, 'Corr_vsMean', NaN, ...
                        'RobustZ_MaxResid', NaN, 'RobustZ_Rough', NaN, 'RobustZ', NaN, ...
                        'Reason', '', 'Verdict', '');

                    if isAsym
                        if isempty(AsymResults), AsymResults = row; else, AsymResults(end+1) = row; end %#ok<AGROW>
                        AsymCurves{end+1} = curve; %#ok<AGROW>
                        continue;
                    end
                    if isempty(Results)
                        Results = row;
                    else
                        Results(end+1) = row; %#ok<AGROW>
                    end
                    Curves{end+1} = curve; %#ok<AGROW>
                    RawCurves{end+1} = rawCurve; %#ok<AGROW>
                end
            end
        end
    end
end
clear S
end
disp(['Patients dans la base : ', num2str(totalPatients)]);

if isempty(Results)
    disp('Aucune courbe à analyser.');
    return;
end

% -------------------------------------------------------------------------
% PASSE 2 : ajustement sur la moyenne du groupe + scores locaux + z robuste
% -------------------------------------------------------------------------
[Results, TemplateKeys, TemplateCurves, TemplateSign] = scoreGroups(Results, Curves, Opts);

% Épaules asymptomatiques : scorées à part (référence = moyenne des
% asymptomatiques seules, comme la correction ST/TX des sorties
% clinical/functional), pour ne pas modifier la référence ni les verdicts
% des patients.
if ~isempty(AsymResults)
    AsymResults = scoreGroups(AsymResults, AsymCurves, Opts);
end
if ~isempty(Opts.AsymptomaticSelection)
    nAsym = 0;
    if ~isempty(AsymResults)
        nAsym = numel(unique(strcat({AsymResults.PatientID}, {AsymResults.Side})));
    end
    disp(['Épaules asymptomatiques retrouvées : ', num2str(nAsym), ...
          ' / ', num2str(size(Opts.AsymptomaticSelection, 1))]);
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
if isfile(OutputFile), delete(OutputFile); end
writetable(struct2table(Results), OutputFile, 'Sheet', 'Curve_Quality');
Summary = buildSummary(Results);
writetable(struct2table(Summary), OutputFile, 'Sheet', 'Summary');
if ~isempty(AsymResults)
    writetable(struct2table(AsymResults), OutputFile, 'Sheet', 'Curve_Quality_Asymptomatic');
    writetable(struct2table(buildSummary(AsymResults)), OutputFile, 'Sheet', 'Summary_Asymptomatic');
end
disp(' ');
disp(['Excel exporté : ', OutputFile]);
disp(['Courbes analysées : ', num2str(numel(Results)), ...
      ' | Forme aberrante : ', num2str(sum(strcmp({Results.Verdict}, 'Forme aberrante')))]);
if ~isempty(AsymResults)
    disp(['Courbes asymptomatiques analysées : ', num2str(numel(AsymResults)), ...
          ' | Forme aberrante : ', num2str(sum(strcmp({AsymResults.Verdict}, 'Forme aberrante')))]);
end
% Courbes affectées par la correction inversée (Inversee), par tâche : ST et TX
for tk = unique({Results.Task})
    for mk = {'ST', 'TX'}
        selM = strcmp({Results.Task}, tk{1}) & strcmp({Results.Metric}, mk{1});
        nInv = sum(contains({Results(selM).Reason}, 'Inversee'));
        disp(['  Correction inversée ', mk{1}, ' - ', tk{1}, ' : ', num2str(nInv), ' / ', num2str(sum(selM)), ...
              ' courbe(s) inversée(s) (', num2str(100 * nInv / max(sum(selM), 1), '%.1f'), ' %)']);
    end
end

PlotCurveQuality(Results, Curves, RawCurves, TemplateKeys, TemplateCurves);
BrowsePatients(Results, Curves, RawCurves, TemplateKeys, TemplateCurves, TemplateSign, 'ANALYTIC2');

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
end

end

% =========================================================================
%  SCORING PAR GROUPE (tâche + métrique) : ajustement sur la moyenne du
%  groupe, rugosité, corrélation, z robustes, verdict
% =========================================================================
function [Results, TemplateKeys, TemplateCurves, TemplateSign] = scoreGroups(Results, Curves, Opts)
keys = strcat({Results.Task}, '|', {Results.Metric});
[ukeys, ~, gi] = unique(keys);
TemplateKeys   = ukeys;
TemplateCurves = cell(size(ukeys));
TemplateSign   = ones(size(ukeys));   % sens d'excursion brute dominant de la cohorte

for g = 1:numel(ukeys)
    idx = find(gi == g);
    C   = vertcat(Curves{idx});
    n   = numel(idx);
    isTX = strcmp(Results(idx(1)).Metric, 'TX');

    gs = sign(median([Results(idx).Raw_ExcSign], 'omitnan'));
    if gs == 0 || isnan(gs), gs = 1; end
    TemplateSign(g) = gs;

    % Rugosité : ne dépend pas de la référence
    rough = NaN(n, 1);
    for k = 1:n
        d2 = abs(diff(C(k, :), 2));
        if any(~isnan(d2)), rough(k) = max(d2); end
    end
    zR = robustZ(log(rough + 1e-3));

    keep = true(n, 1);
    for pass = 1:2
        tmpl = mean(C(keep, :), 1, 'omitnan');
        rm = NaN(n, 1); sc = NaN(n, 1); of = NaN(n, 1); mx = NaN(n, 1);
        for k = 1:n
            [rm(k), sc(k), of(k), mx(k)] = fitResidual(C(k, :), tmpl);
        end
        zM = robustZ(log(mx + 1e-3));
        rc = NaN(n, 1);
        for k = 1:n
            rc(k) = pearsonR(C(k, :), tmpl);
        end
        keep = ~(zR > Opts.ZThresh) & ~(rc < Opts.CorrThresh);
        % TX : seule l'inversion (Corr_vsMean) est testée, pas la rugosité
        if isTX, keep = ~(rc < Opts.CorrThresh); end
    end
    TemplateCurves{g} = tmpl;

    for k = 1:n
        j = idx(k);
        Results(j).Fit_scale        = sc(k);
        Results(j).Fit_offset_deg   = of(k);
        Results(j).RMSE_fit_deg     = rm(k);
        Results(j).MaxResid_deg     = mx(k);
        Results(j).Rough_deg        = rough(k);
        Results(j).Corr_vsMean      = rc(k);
        Results(j).RobustZ_MaxResid = zM(k);
        Results(j).RobustZ_Rough    = zR(k);
        Results(j).RobustZ          = zR(k);

        reasons = {};
        if zR(k) > Opts.ZThresh, reasons{end+1} = 'Rough'; end %#ok<AGROW>
        if rc(k) < Opts.CorrThresh, reasons{end+1} = 'Inversee'; end %#ok<AGROW>
        if isTX, reasons = reasons(strcmp(reasons, 'Inversee')); end
        if ~isempty(reasons)
            Results(j).Reason  = strjoin(reasons, '+');
            Results(j).Verdict = 'Forme aberrante';
        elseif ~isnan(Results(j).RobustZ)
            Results(j).Verdict = 'OK';
        end
    end
end

end

% =========================================================================
%  EPAULE ASYMPTOMATIQUE (voir AsymptomaticSelection, userCommands_Multi.m)
% =========================================================================
% Côté asymptomatique ('R'/'L') du patient d pour cette condition, '' si
% aucun. Même règle que dans ComputeClinicalContributionsFromDatabase.m.
function asymSide = findAsymptomaticSide(AsymSel, d, condition)
asymSide = '';
for k = 1:size(AsymSel, 1)
    if ~strcmp(num2str(AsymSel{k, 1}), num2str(d.PatientID)), continue; end
    if ~strcmp(AsymSel{k, 3}, condition), continue; end
    if ismember(AsymSel{k, 2}, d.Side), continue; end
    [~, sessName] = fileparts(d.(condition).Date);
    if ~startsWith(sessName, AsymSel{k, 4}), continue; end
    asymSide = AsymSel{k, 2};
    return;
end
end

% =========================================================================
%  DECOUVERTE DES FICHIERS DE PARTIES (voir NumDatabaseParts,
%  userCommands_Multi.m / MAIN_MULTI_Protocol_01.m)
% =========================================================================
function fileList = discoverDatabaseFiles(DatabaseFile)
[dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
parts = dir(fullfile(dbFolder, [dbName, '_part*of*', dbExt]));
if isempty(parts)
    if isfile(DatabaseFile)
        fileList = {DatabaseFile};
    else
        fileList = {};
    end
    return;
end
partNum = zeros(numel(parts), 1);
for i = 1:numel(parts)
    tok = regexp(parts(i).name, '_part(\d+)of\d+', 'tokens', 'once');
    partNum(i) = str2double(tok{1});
end
[~, order] = sort(partNum);
parts = parts(order);
fileList = fullfile({parts.folder}, {parts.name});
end

% =========================================================================
%  EXTRACTION DES CYCLES BRUTS, [nPoints x nCycles]
% =========================================================================
% shared = joint unique non dupliqué par côté (TX, joint 11) : repli R/L.
function cyc = getCycles(t, ji, dof, cycField, shared)
cyc = [];
if length(t.Joint) < ji, return; end
cf = cycField;
if shared && isempty(t.Joint(ji).Euler.(cf))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if isempty(t.Joint(ji).Euler.(cf)), return; end
cyc = squeeze(t.Joint(ji).Euler.(cf)(1, dof, :, :));
if isvector(cyc), cyc = cyc(:); end
end

% =========================================================================
%  AJUSTEMENT c ~ a*t + b (a >= 0) : RMSE ET RESIDU MAXIMAL
% =========================================================================
% a >= 0 : une courbe inversée ne doit pas être acceptée comme ajustée.
function [r, a, b, rmax] = fitResidual(c, t)
r = NaN; a = NaN; b = NaN; rmax = NaN;
v = ~isnan(c) & ~isnan(t);
if sum(v) < 3, return; end
c = c(v); t = t(v);
tc = t - mean(t);
den = sum(tc.^2);
if den == 0
    a = 0;
else
    a = max(0, sum((c - mean(c)) .* tc) / den);
end
b = mean(c) - a * mean(t);
res  = c - (a * t + b);
r    = sqrt(mean(res.^2));
rmax = max(abs(res));
end

% Corrélation de Pearson signée (négative = la courbe va à l'opposé de la
% référence : cloche inversée, U). NaN si moins de 3 points ou variance nulle.
function r = pearsonR(c, t)
r = NaN;
v = ~isnan(c) & ~isnan(t);
if sum(v) < 3, return; end
c = c(v); t = t(v);
if std(c) == 0 || std(t) == 0, return; end
cc = corrcoef(c, t);
r = cc(1, 2);
end

function z = robustZ(x)
m = median(x, 'omitnan');
s = 1.4826 * median(abs(x - m), 'omitnan');
if isnan(s) || s == 0
    z = zeros(size(x));
    z(isnan(x)) = NaN;
else
    z = (x - m) / s;
end
end

function s = patientIDStr(pid)
% PatientID peut être numérique ou char selon la source - conversion défensive
if isnumeric(pid)
    s = num2str(pid);
else
    s = char(pid);
end
end

function c = resample101(curve)
% Rééchantillonne sur 101 points (0-100 %) - voir PlotHTContributionsCurves
c = NaN(1, 101);
curve = curve(:);
curve = curve(~isnan(curve));
if length(curve) < 2, return; end
xOrig = linspace(0, 100, length(curve));
c = interp1(xOrig, curve, linspace(0, 100, 101), 'linear');
end

% =========================================================================
%  FEUILLE SUMMARY : comptages par tâche+métrique
% =========================================================================
function Summary = buildSummary(Results)
tasks   = unique({Results.Task});
metrics = {'HT', 'HG', 'GH', 'ST', 'TX'};
Summary = [];
for iT = 1:numel(tasks)
    for iM = 1:numel(metrics)
        sel = strcmp({Results.Task}, tasks{iT}) & strcmp({Results.Metric}, metrics{iM});
        if ~any(sel), continue; end
        R = Results(sel);
        row = struct('Task', tasks{iT}, 'Metric', metrics{iM}, 'N', numel(R), ...
            'nOK', sum(strcmp({R.Verdict}, 'OK')), ...
            'nFormeAberrante', sum(strcmp({R.Verdict}, 'Forme aberrante')), ...
            'nAberrante_Rough', sum(contains({R.Reason}, 'Rough')), ...
            'nAberrante_Inversee', sum(contains({R.Reason}, 'Inversee')), ...
            'Median_MaxResid_deg', median([R.MaxResid_deg], 'omitnan'), ...
            'Median_Rough_deg', median([R.Rough_deg], 'omitnan'));
        if isempty(Summary), Summary = row; else, Summary(end+1) = row; end %#ok<AGROW>
    end
end
end

% =========================================================================
%  FIGURES
% =========================================================================
% Une figure par tâche : courbes (abs) superposées par métrique, OK gris,
% forme aberrante rouge, moyenne noire. Puis, par tâche, la même figure avec
% les courbes BRUTES signées (moyenne des cycles, sans abs) et la ligne 0.
function PlotCurveQuality(Results, Curves, RawCurves, TemplateKeys, TemplateCurves)

metrics = {'HT', 'HG', 'GH', 'ST', 'TX'};
tasks   = unique({Results.Task});
colOK   = [0.5 0.5 0.5];
colBad  = [0.85 0.15 0.10];
xgrid   = linspace(0, 100, 101);

for iT = 1:numel(tasks)
    figure('Name', ['Courbes superposées — ', tasks{iT}], 'Color', 'w');
    for m = 1:numel(metrics)
        subplot(2, 3, m); hold on;
        idx = find(strcmp({Results.Task}, tasks{iT}) & strcmp({Results.Metric}, metrics{m}));
        drawGroup(Curves, idx, 'OK',              colOK, 0.15);
        drawBad(Curves, idx, metrics{m});
        ig = find(strcmp(TemplateKeys, [tasks{iT}, '|', metrics{m}]), 1);
        if ~isempty(ig) && ~isempty(TemplateCurves{ig})
            plot(xgrid, TemplateCurves{ig}, 'k', 'LineWidth', 3, 'HandleVisibility', 'off');
        end
        hold off;
        xlim([0 100]);
        xlabel('Cycle (%)');
        ylabel([metrics{m}, ' (deg, abs - comme clinical/functional)']);
        title(sprintf('%s — %d aberrante(s) / %d', metrics{m}, ...
            sum(strcmp({Results(idx).Verdict}, 'Forme aberrante')), numel(idx)));
        box on;
    end
    sgtitle(tasks{iT});

    figure('Name', ['Courbes brutes — ', tasks{iT}], 'Color', 'w');
    for m = 1:numel(metrics)
        subplot(2, 3, m); hold on;
        idx = find(strcmp({Results.Task}, tasks{iT}) & strcmp({Results.Metric}, metrics{m}));
        drawGroup(RawCurves, idx, 'OK',              colOK, 0.15);
        drawBad(RawCurves, idx, metrics{m});
        yline(0, 'k:', 'HandleVisibility', 'off');
        hold off;
        xlim([0 100]);
        xlabel('Cycle (%)');
        ylabel([metrics{m}, ' (deg, brut signé)']);
        title(sprintf('%s — %d aberrante(s) / %d', metrics{m}, ...
            sum(strcmp({Results(idx).Verdict}, 'Forme aberrante')), numel(idx)));
        box on;
    end
    sgtitle([tasks{iT}, ' — courbes brutes (moyenne des cycles, sans abs)']);

    % Même figure que la première (abs, outliers en rouge), avec la
    % correction inversée appliquée à ST et TX uniquement : les courbes
    % 'Inversee' sont remplacées par leur version corrigée (excursion depuis
    % le repos, retournée vers la moyenne, + repos cohorte :
    % sp*(brut - repos) + repos_cohorte, repos = moyenne début/fin du cycle,
    % sp = sens propre de l'excursion brute du patient), tracées en vert.
    % Les autres courbes ne sont pas modifiées.
    figure('Name', ['Courbes superposées, correction inversée — ', tasks{iT}], 'Color', 'w');
    colFix = [0.10 0.55 0.20];
    for m = 1:numel(metrics)
        subplot(2, 3, m); hold on;
        idx = find(strcmp({Results.Task}, tasks{iT}) & strcmp({Results.Metric}, metrics{m}));
        ig  = find(strcmp(TemplateKeys, [tasks{iT}, '|', metrics{m}]), 1);
        isFix = false(size(idx));
        if strcmp(metrics{m}, 'ST') || strcmp(metrics{m}, 'TX')
            isFix = contains({Results(idx).Reason}, 'Inversee');
        end
        drawGroup(Curves, idx(~isFix), 'OK',              colOK,  0.15);
        drawBad(Curves, idx(~isFix), metrics{m});
        fixedCurves = [];
        if any(isFix) && ~isempty(ig) && ~isempty(TemplateCurves{ig})
            restS = mean(TemplateCurves{ig}([1 end]));
            for k = idx(isFix)
                raw = RawCurves{k};
                yc  = Results(k).Raw_ExcSign * (raw - mean(raw([1 end]))) + restS;
                h = plot(xgrid, yc, 'Color', colFix, 'LineWidth', 1, 'HandleVisibility', 'off');
                h.Color(4) = 0.7;
                if ~contains(Results(k).Reason, 'Rough')
                    fixedCurves = [fixedCurves; yc(:)']; %#ok<AGROW>
                end
            end
        end
        if ~isempty(ig) && ~isempty(TemplateCurves{ig})
            plot(xgrid, TemplateCurves{ig}, 'k', 'LineWidth', 3, 'DisplayName', 'moyenne (sans inversées)');
            % Moyenne recalculée AVEC les courbes corrigées : courbes sans
            % aucun flag (celles de la référence) + inversées corrigées
            % (sans celles aussi flaguées 'Rough')
            if ~isempty(fixedCurves)
                refIdx   = idx(strcmp({Results(idx).Reason}, ''));
                meanCorr = mean([vertcat(Curves{refIdx}); fixedCurves], 1, 'omitnan');
                plot(xgrid, meanCorr, 'k--', 'LineWidth', 3, 'DisplayName', 'moyenne avec correction inversée');
                legend('show', 'Location', 'best');
            end
        end
        hold off;
        xlim([0 100]);
        xlabel('Cycle (%)');
        if any(isFix)
            ylabel([metrics{m}, ' (deg, corrigé)']);
            title(sprintf('%s — %d corrigée(s) en vert / %d', metrics{m}, sum(isFix), numel(idx)));
        else
            ylabel([metrics{m}, ' (deg, abs)']);
            title(sprintf('%s — %d aberrante(s) / %d', metrics{m}, ...
                sum(strcmp({Results(idx).Verdict}, 'Forme aberrante')), numel(idx)));
        end
        box on;
    end
    sgtitle([tasks{iT}, ' — correction inversée (vert = inversées corrigées, rouge = autres outliers)']);
end

    function drawGroup(curveSet, idx, verdict, col, alpha)
        for k = idx(:)'
            if ~strcmp(Results(k).Verdict, verdict), continue; end
            h = plot(xgrid, curveSet{k}, 'Color', col, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = alpha;
        end
    end

    % Courbes aberrantes. HG : une couleur par patient (Numero), PRE plein /
    % POST tireté, légende "N°<Numero> <condition> <côté> (<raison>)".
    % Autres métriques : rouge, sans légende (comme avant).
    function drawBad(curveSet, idx, metric)
        if ~strcmp(metric, 'HG')
            drawGroup(curveSet, idx, 'Forme aberrante', colBad, 0.6);
            return;
        end
        badIdx = idx(strcmp({Results(idx).Verdict}, 'Forme aberrante'));
        if isempty(badIdx), return; end
        badNums = unique([Results(badIdx).Numero]);
        if numel(badNums) <= 7
            cmap = lines(numel(badNums));
        else
            cmap = turbo(numel(badNums));
        end
        hs = gobjects(1, numel(badIdx));
        for q = 1:numel(badIdx)
            r = badIdx(q);
            if strcmp(Results(r).Condition, 'PRE'), ls = '-'; else, ls = '--'; end
            hs(q) = plot(xgrid, curveSet{r}, 'Color', cmap(badNums == Results(r).Numero, :), ...
                'LineStyle', ls, 'LineWidth', 1.5, 'DisplayName', ...
                sprintf('N°%d %s %s (%s)', Results(r).Numero, Results(r).Condition, ...
                        Results(r).Side, Results(r).Reason));
        end
        legend(hs, 'Location', 'best', 'FontSize', 7, 'Interpreter', 'none');
    end

end

% =========================================================================
%  FIGURE INTERACTIVE : un patient à la fois, tous les DOF
% =========================================================================
% Pour la tâche donnée (ANALYTIC2), affiche HT, HG, GH, ST du patient
% courant : PRE en orange, POST en bleu (côté R plein, côté L tireté),
% sur le nuage des courbes de cohorte (gris) et la moyenne (noir).
% Touche 'a' = patient suivant, 'q' = précédent (boucle). Cliquer d'abord
% sur la figure pour lui donner le focus clavier.
%
% Une 2e figure ("Diagnostic patient") se met à jour avec le même patient :
% si l'une de ses courbes est flaguée 'Inversee' (première trouvée dans
% l'ordre HT, HG, GH, ST), elle trace le BRUT signé, le abs actuel et 4
% corrections candidates contre la moyenne de cohorte, avec r (corrélation
% à la moyenne) et ROM (max-min) de chaque, et dit si le sens de
% l'excursion brute est celui de la cohorte (offset replié par abs) ou
% l'opposé (vraie inversion, à vérifier en amont). Aucune correction n'est
% appliquée aux sorties : c'est un outil de choix.
function BrowsePatients(Results, Curves, RawCurves, TemplateKeys, TemplateCurves, TemplateSign, task)

metrics = {'HT', 'HG', 'GH', 'ST', 'TX'};
inTask  = strcmp({Results.Task}, task);
nums    = unique([Results(inTask).Numero]);
if isempty(nums)
    disp(['BrowsePatients: aucune courbe pour ', task]);
    return;
end

xgrid   = linspace(0, 100, 101);
colPre  = [0.8500 0.3250 0.0980];
colPost = [0 0.4470 0.7410];
colCoh  = [0.5 0.5 0.5];

fig = figure('Name', ['Parcours patients — ', task, ' (a = suivant, q = précédent)'], 'Color', 'w');
axs = gobjects(1, numel(metrics));
for m = 1:numel(metrics)
    axs(m) = subplot(2, 3, m); hold(axs(m), 'on');
    idx = find(inTask & strcmp({Results.Metric}, metrics{m}));
    for k = idx(:)'
        h = plot(axs(m), xgrid, Curves{k}, 'Color', colCoh, 'LineWidth', 1, 'HandleVisibility', 'off');
        h.Color(4) = 0.08;
    end
    ig = find(strcmp(TemplateKeys, [task, '|', metrics{m}]), 1);
    if ~isempty(ig) && ~isempty(TemplateCurves{ig})
        plot(axs(m), xgrid, TemplateCurves{ig}, 'k', 'LineWidth', 2.5, 'HandleVisibility', 'off');
    end
    xlim(axs(m), [0 100]);
    xlabel(axs(m), 'Cycle (%)');
    ylabel(axs(m), [metrics{m}, ' (deg, abs)']);
    box(axs(m), 'on');
end

figD = figure('Name', 'Diagnostic patient — courbes inversées (a = suivant, q = précédent)', 'Color', 'w');
axD  = axes('Parent', figD);

pos = 1;
drawPatient();
set(fig,  'KeyPressFcn', @onKey);
set(figD, 'KeyPressFcn', @onKey);
figure(fig);

    function onKey(~, evt)
        switch evt.Key
            case 'a'
                pos = pos + 1;
                if pos > numel(nums), pos = 1; end
            case 'q'
                pos = pos - 1;
                if pos < 1, pos = numel(nums); end
            otherwise
                return;
        end
        drawPatient();
    end

    function drawPatient()
        n    = nums(pos);
        rows = find(inTask & [Results.Numero] == n);
        for m2 = 1:numel(metrics)
            ax = axs(m2);
            delete(findobj(ax, 'Tag', 'pt'));
            mrows = rows(strcmp({Results(rows).Metric}, metrics{m2}));
            info  = cell(1, numel(mrows));
            for q = 1:numel(mrows)
                r = mrows(q);
                if strcmp(Results(r).Condition, 'PRE'), col = colPre; else, col = colPost; end
                if strcmp(Results(r).Side, 'R'), ls = '-'; else, ls = '--'; end
                plot(ax, xgrid, Curves{r}, 'Color', col, 'LineStyle', ls, 'LineWidth', 2, ...
                    'Tag', 'pt', 'DisplayName', [Results(r).Condition, ' ', Results(r).Side]);
                info{q} = sprintf('%s %s z=%.1f r=%.2f %s', Results(r).Condition, Results(r).Side, ...
                    Results(r).RobustZ, Results(r).Corr_vsMean, Results(r).Verdict);
            end
            title(ax, [{metrics{m2}}, info], 'FontSize', 8, 'Interpreter', 'none');
            if m2 == 1 && ~isempty(mrows)
                legend(ax, flipud(findobj(ax, 'Tag', 'pt')), 'Location', 'best');
            end
        end
        pid = '';
        if ~isempty(rows), pid = patientIDStr(Results(rows(1)).PatientID); end
        sgtitle(fig, sprintf('%s — Patient %s (Numero %d) — %d/%d  |  a = suivant, q = précédent', ...
            task, pid, n, pos, numel(nums)), 'Interpreter', 'none');
        drawDiagnostic(rows, pid, n);
    end

    function drawDiagnostic(rows, pid, n)
        cla(axD, 'reset');
        hold(axD, 'on');
        bad = rows(contains({Results(rows).Reason}, 'Inversee'));
        if isempty(bad)
            axis(axD, 'off');
            text(axD, 0.5, 0.5, sprintf('Patient %s (Numero %d) : aucune courbe inversée détectée', pid, n), ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
            return;
        end

        r  = bad(1);
        ig = find(strcmp(TemplateKeys, [task, '|', Results(r).Metric]), 1);
        tmpl = TemplateCurves{ig};
        gs   = TemplateSign(ig);
        raw  = RawCurves{r};

        base = mean(raw([1 end]));
        rest = mean(tmpl([1 end]));
        [~, ipk] = max(abs(raw));
        sDom = sign(raw(ipk)); if sDom == 0, sDom = 1; end
        sMir = sign(pearsonR(raw, tmpl)); if sMir == 0 || isnan(sMir), sMir = 1; end

        sp = Results(r).Raw_ExcSign;   % sens propre de l'excursion brute de ce patient
        names = {'abs (actuel)', 'signe dominant s*brut', 'miroir vers la moyenne', ...
                 'excursion / repos (sens cohorte, sans retournement)', ...
                 'excursion / repos RETOURNEE vers la moyenne + repos cohorte'};
        ys    = {abs(raw), sDom * raw, sMir * raw, gs * (raw - base), sp * (raw - base) + rest};
        cols  = [0.85 0.33 0.10; 0.93 0.69 0.13; 0.49 0.18 0.56; 0.47 0.67 0.19; 0 0.45 0.74];

        plot(axD, xgrid, tmpl, 'k', 'LineWidth', 3, 'DisplayName', 'moyenne cohorte (abs)');
        plot(axD, xgrid, raw, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 2, ...
            'DisplayName', sprintf('brut signé (ROM=%.0f°)', max(raw) - min(raw)));
        for c = 1:numel(ys)
            plot(axD, xgrid, ys{c}, 'Color', cols(c, :), 'LineWidth', 1.8, 'DisplayName', ...
                sprintf('%s | r=%.2f | ROM=%.0f°', names{c}, pearsonR(ys{c}, tmpl), max(ys{c}) - min(ys{c})));
        end
        yline(axD, 0, ':', 'HandleVisibility', 'off');
        xlim(axD, [0 100]);
        xlabel(axD, 'Cycle (%)');
        ylabel(axD, [Results(r).Metric, ' (deg)']);
        legend(axD, 'Location', 'eastoutside', 'Interpreter', 'none', 'FontSize', 8);
        box(axD, 'on');

        if Results(r).Raw_ExcSign == gs && Results(r).CrossesZero
            verdictTxt = 'excursion brute dans le sens cohorte MAIS traverse zéro : offset au repos replié par abs -> "excursion / repos" adaptée';
        elseif Results(r).Raw_ExcSign == gs
            verdictTxt = 'excursion brute dans le sens cohorte, sans passage par zéro : forme atypique, pas un problème de abs';
        else
            verdictTxt = 'excursion brute de SENS OPPOSE à la cohorte : vraie inversion (repère/calibration ?), miroir possible mais à vérifier en amont';
        end
        title(axD, {sprintf('Patient %s (Numero %d) — %s %s %s — %d courbe(s) inversée(s) pour ce patient', ...
            pid, n, Results(r).Metric, Results(r).Condition, Results(r).Side, numel(bad)), verdictTxt}, ...
            'FontSize', 9, 'Interpreter', 'none');
    end

end
