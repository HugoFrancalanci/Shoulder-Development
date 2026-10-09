% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   September 2026
% -------------------------------------------------------------------------
% Description:   Rapport postural (inclinaison thoracique + classification
%                de Moroder), calculé depuis PatientDatabase.mat plutôt
%                qu'en repassant par les C3D. Même patron que
%                Multi/Core/ComputeClinicalContributionsFromDatabase.m.
%
%                Lit Trial(k).Joint(11).PostureSummary, déjà calculé
%                pendant le run C3D par Protocol01/Core/Thorax/
%                ComputeThoraxPosture.m (rien n'est recalculé ici) :
%                  thoracic_curvature_angle : angle 3D TV8->CV7 vs verticale,
%                      moyenne des 100 premières frames (0 deg = thorax
%                      vertical)
%                  SIR_R / SIR_L            : |ST DOF2 Y| (Joint 3 / 8),
%                      moyenne des 100 premières frames - approximation
%                      cinématique de la SIR de Moroder (CT), non validée
%                  moroder_R / moroder_L    : Type A (<=36) / B (<=46) / C
%                Les trajectoires marqueurs n'étant pas gardées dans la
%                base (FilterTrialForDatabase.m), toute autre définition de
%                l'inclinaison demande de relancer MAIN_MULTI_Protocol_01.m.
%
%                Tâches : CALIBRATION3 (alias STATIC3 sur les sessions plus
%                anciennes, reporté sous 'CALIBRATION3'), ANALYTIC1,
%                ANALYTIC2 (la base garde aussi ANALYTIC3/4, non utilisées
%                ici).
%
%                Callable à tout moment depuis la fenêtre de commande :
%                  ComputePostureFromDatabase(DatabaseFile, OutputFile, ResultsFolder)
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile  (char) chemin vers PatientDatabase.mat
%           OutputFile    (char) chemin de l'Excel de sortie
%           ResultsFolder (char, optionnel) dossier où se terminer (cd) une
%                         fois l'export fait ; omis = pas de cd
%           Opts          (struct, optionnel) AsymptomaticSelection (cell,
%                         {} par défaut) : épaules asymptomatiques {ID, côté,
%                         'PRE'/'POST', date} (voir userCommands_Multi.m),
%                         exportées dans une feuille séparée
% Outputs : Results (struct array) une ligne par patient/côté/tâche, PRE et
%           POST côte à côte - aussi retourné pour exploitation directe
%           AsymResults (struct array) une ligne par épaule asymptomatique/
%           tâche, pour la seule condition retenue
%           Fichier Excel écrit sur disque (feuilles 'Posture' et, si
%           AsymptomaticSelection non vide, 'Posture_Asymptomatic')
%           + 1 figure de distribution par tâche (PlotPostureDistribution :
%           inclinaison, SIR, % types d'inclinaison I-A/I-B/I-C (moyenne
%           ± 1 SD), % Moroder A/B/C - PRE vs
%           POST vs asymptomatique ; SIR > 100 deg = outlier exclu)
%           + corrélation inclinaison vs SIR par tâche/groupe
%           (CorrelatePosture : Pearson, Spearman, p, régression ; feuille
%           'Correlation_Incl_SIR' + 1 figure de nuages par tâche)
%           ThxFlex (struct array) flexion thoracique signée pendant le
%           geste, ANALYTIC1/2, PRE et POST, une ligne par patient/côté
%           (summariseThoraxFlexion, lecture seule des cycles de la base) ;
%           feuille 'Thorax_Flexion_Signed', colonnes au format de
%           Data_posture.xlsx (ex. analytic1_TXflex_Change_Post)
%           ThxFlexAsym (struct array) idem pour les épaules
%           asymptomatiques (cycles du bras asymptomatique, session
%           retenue seulement) ; feuille 'Thorax_Flexion_Signed_Asym',
%           colonnes <tâche>_TXflex_<stat>_Asym + Condition
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Results, AsymResults, ThxFlex, ThxFlexAsym] = ComputePostureFromDatabase(DatabaseFile, OutputFile, ResultsFolder, Opts)

if nargin < 3, ResultsFolder = ''; end
if nargin < 4, Opts = struct(); end
if ~isfield(Opts, 'AsymptomaticSelection'), Opts.AsymptomaticSelection = {}; end

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('ComputePostureFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants) - lancer MAIN_MULTI_Protocol_01.m avec SaveDatabase=true d''abord.', ...
        DatabaseFile);
end

% Tâche reportée -> noms d'essai acceptés (STATIC3 = ancien nom de CALIBRATION3)
taskDef = struct('name',    {'CALIBRATION3', 'ANALYTIC1', 'ANALYTIC2'}, ...
                 'aliases', {{'CALIBRATION3', 'STATIC3'}, {'ANALYTIC1'}, {'ANALYTIC2'}});

% -------------------------------------------------------------------------
% BOUCLE PATIENTS (depuis Database, pas depuis PatientSelection/C3D)
% -------------------------------------------------------------------------
Results = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, ...
    'Inclination_PRE_deg', {}, 'SIR_PRE_deg', {}, 'Moroder_PRE', {}, ...
    'Inclination_POST_deg', {}, 'SIR_POST_deg', {}, 'Moroder_POST', {});

% Épaules asymptomatiques (côté controlatéral, une seule session) - même
% correspondance que ComputeClinicalContributionsFromDatabase.m
AsymResults = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, 'Condition', {}, ...
    'Inclination_deg', {}, 'SIR_deg', {}, 'Moroder', {});

conditions = {'PRE', 'POST'};

% Flexion thoracique signée pendant le geste (voir summariseThoraxFlexion) :
% une ligne par patient/côté/tâche/condition, mise en large à l'export
flexTasks = {'ANALYTIC1', 'ANALYTIC2'};
ThxLong = struct('Numero', {}, 'PatientID', {}, 'Side', {}, 'Task', {}, 'Condition', {}, ...
    'Start', {}, 'AtPeak', {}, 'Change', {}, 'Min', {}, 'Max', {}, 'nCycles', {});
ThxAsymLong = ThxLong;   % même chose pour les épaules asymptomatiques

totalPatients = 0;
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S       = load(fileList{iFile}, 'Database');
    nInFile = numel(S.Database);
    totalPatients = totalPatients + nInFile;

for iP = 1:nInFile
    d = S.Database(iP);
    if isempty(d.Numero)
        continue; % ligne pré-allouée jamais remplie
    end
    sides = d.Side;
    if ischar(sides), sides = cellstr(sides(:)); end

    for iC = 1:numel(conditions)
        condition = conditions{iC};
        if ~isfield(d, condition) || ~isstruct(d.(condition)) || ~isfield(d.(condition), 'Trial')
            continue;
        end
        Trial = d.(condition).Trial;

        for iT = 1:numel(taskDef)
            ps = getPostureSummary(Trial, taskDef(iT).aliases);
            if isempty(ps), continue; end

            for iS = 1:numel(sides)
                side = sides{iS};
                ri = find([Results.Numero] == d.Numero & strcmp({Results.Side}, side) & ...
                          strcmp({Results.Task}, taskDef(iT).name), 1);
                if isempty(ri)
                    ri = length(Results) + 1;
                    Results(ri).Numero    = d.Numero;
                    Results(ri).PatientID = d.PatientID;
                    Results(ri).Side      = side;
                    Results(ri).Task      = taskDef(iT).name;
                    for c = conditions
                        Results(ri).(['Inclination_', c{1}, '_deg']) = NaN;
                        Results(ri).(['SIR_', c{1}, '_deg'])         = NaN;
                        Results(ri).(['Moroder_', c{1}])             = '';
                    end
                end

                Results(ri).(['Inclination_', condition, '_deg']) = getNum(ps, 'thoracic_curvature_angle');
                Results(ri).(['SIR_', condition, '_deg'])         = getNum(ps, ['SIR_', side]);
                Results(ri).(['Moroder_', condition])             = shortMoroderType(getStr(ps, ['moroder_', side]));
            end
        end

        % Flexion thoracique signée (lecture des cycles stockés, rien n'est recalculé)
        for iT = 1:numel(flexTasks)
            k = find(strcmp({Trial.task}, flexTasks{iT}), 1);
            if isempty(k), continue; end
            for iS = 1:numel(sides)
                s = summariseThoraxFlexion(Trial(k), sides{iS});
                if isempty(s), continue; end
                li = numel(ThxLong) + 1;
                ThxLong(li).Numero = d.Numero;   ThxLong(li).PatientID = d.PatientID;
                ThxLong(li).Side   = sides{iS};  ThxLong(li).Task      = flexTasks{iT};
                ThxLong(li).Condition = condition;
                ThxLong(li).Start  = s.Start;    ThxLong(li).AtPeak = s.AtPeak;
                ThxLong(li).Change = s.Change;   ThxLong(li).Min    = s.Min;
                ThxLong(li).Max    = s.Max;      ThxLong(li).nCycles = s.nCycles;
            end
        end

        % Épaule asymptomatique de ce patient à cette condition ?
        asymSide = findAsymptomaticSide(Opts.AsymptomaticSelection, d, condition);
        if isempty(asymSide), continue; end
        for iT = 1:numel(taskDef)
            ps = getPostureSummary(Trial, taskDef(iT).aliases);
            if isempty(ps), continue; end
            ai = length(AsymResults) + 1;
            AsymResults(ai).Numero          = d.Numero;
            AsymResults(ai).PatientID       = d.PatientID;
            AsymResults(ai).Side            = asymSide;
            AsymResults(ai).Task            = taskDef(iT).name;
            AsymResults(ai).Condition       = condition;
            AsymResults(ai).Inclination_deg = getNum(ps, 'thoracic_curvature_angle');
            AsymResults(ai).SIR_deg         = getNum(ps, ['SIR_', asymSide]);
            AsymResults(ai).Moroder         = shortMoroderType(getStr(ps, ['moroder_', asymSide]));
        end
        % Flexion thoracique signée, cycles du bras asymptomatique
        for iT = 1:numel(flexTasks)
            k = find(strcmp({Trial.task}, flexTasks{iT}), 1);
            if isempty(k), continue; end
            s = summariseThoraxFlexion(Trial(k), asymSide);
            if isempty(s), continue; end
            li = numel(ThxAsymLong) + 1;
            ThxAsymLong(li).Numero = d.Numero;   ThxAsymLong(li).PatientID = d.PatientID;
            ThxAsymLong(li).Side   = asymSide;   ThxAsymLong(li).Task      = flexTasks{iT};
            ThxAsymLong(li).Condition = condition;
            ThxAsymLong(li).Start  = s.Start;    ThxAsymLong(li).AtPeak = s.AtPeak;
            ThxAsymLong(li).Change = s.Change;   ThxAsymLong(li).Min    = s.Min;
            ThxAsymLong(li).Max    = s.Max;      ThxAsymLong(li).nCycles = s.nCycles;
        end
    end
end
clear S
end
disp(['Patients dans la base : ', num2str(totalPatients)]);
if ~isempty(Opts.AsymptomaticSelection)
    disp(['Épaules asymptomatiques retrouvées : ', num2str(numel(unique(strcat({AsymResults.PatientID}, {AsymResults.Side})))), ...
          ' / ', num2str(size(Opts.AsymptomaticSelection, 1))]);
end

% -------------------------------------------------------------------------
% EXPORT EXCEL
% -------------------------------------------------------------------------
Corr = CorrelatePosture(Results, AsymResults, taskDef);
ThxFlex = pivotThoraxFlexion(ThxLong, flexTasks);
ThxFlexAsym = pivotThoraxFlexionAsym(ThxAsymLong, flexTasks);

if ~isempty(Results)
    T = struct2table(Results);
    if isfile(OutputFile), delete(OutputFile); end
    writetable(T, OutputFile, 'Sheet', 'Posture');
    if ~isempty(AsymResults)
        writetable(struct2table(AsymResults), OutputFile, 'Sheet', 'Posture_Asymptomatic');
    end
    if ~isempty(Corr)
        writetable(struct2table(Corr), OutputFile, 'Sheet', 'Correlation_Incl_SIR');
    end
    if ~isempty(ThxFlex)
        writetable(struct2table(ThxFlex), OutputFile, 'Sheet', 'Thorax_Flexion_Signed');
    end
    if ~isempty(ThxFlexAsym)
        writetable(struct2table(ThxFlexAsym), OutputFile, 'Sheet', 'Thorax_Flexion_Signed_Asym');
    end
    disp(' ');
    disp(['Excel exporté : ', OutputFile]);
else
    disp(' ');
    disp('Aucune donnée à exporter.');
end

PlotPostureDistribution(Results, AsymResults, taskDef);

if ~isempty(ResultsFolder) && isfolder(ResultsFolder)
    cd(ResultsFolder);
end

end

% =========================================================================
%  CORRELATION INCLINAISON THORACIQUE vs SIR (MORODER)
% =========================================================================
% Par tâche et par groupe (PRE, POST, asymptomatique) : paires (inclinaison,
% SIR) de la MÊME session et du même côté (une paire par ligne patient/côté ;
% un patient 'RL' donne 2 paires partageant la même inclinaison). Seules
% les paires dans la plage plausible sont gardées : inclinaison dans
% [InclRange] = [0 50] deg ET SIR dans [SIRRange] = [10 60] deg (SIR hors
% plage = artefacts probables de l'approximation cinématique ; plage propre
% à cette analyse, les graphes de distribution gardent leur seuil SIR > 100).
% Nombre de paires exclues par groupe dans le titre, plage rappelée en bas
% de la figure, axes fixés sur la plage.
%   Pearson r   : relation linéaire
%   Spearman rho: relation monotone (rangs, ex-aequo au rang moyen) - plus
%                 robuste aux valeurs extrêmes restantes
% p bilatéral via la loi de Student (df = n-2), sans Statistics Toolbox.
% Une figure par tâche, 1x3 : nuage de points + droite de régression
% (moindres carrés), r/rho/p/n dans le titre, lignes aux seuils 36/46 deg
% (Moroder A/B/C).
% Outputs : Corr (struct array) une ligne par tâche/groupe - feuille Excel
%           'Correlation_Incl_SIR'
function Corr = CorrelatePosture(Results, AsymResults, taskDef)

InclRange = [0 50];   % deg
SIRRange  = [10 60];  % deg
groups = {'PRE', 'POST', 'ASYM'};
labels = {'PRE', 'POST', 'Asympto.'};
cols   = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

Corr = struct('Task', {}, 'Group', {}, 'n', {}, 'nExcluded_OutOfRange', {}, ...
    'Pearson_r', {}, 'Pearson_p', {}, 'Spearman_rho', {}, 'Spearman_p', {}, ...
    'Slope_degSIR_per_degIncl', {}, 'Intercept_deg', {});
if isempty(Results) && isempty(AsymResults), return; end

for iT = 1:numel(taskDef)
    task = taskDef(iT).name;
    X = cell(1, 3); Y = cell(1, 3); nOut = zeros(1, 3);
    for g = 1:3
        if strcmp(groups{g}, 'ASYM')
            if isempty(AsymResults), continue; end
            R = AsymResults(strcmp({AsymResults.Task}, task));
            fI = 'Inclination_deg'; fS = 'SIR_deg';
        else
            if isempty(Results), continue; end
            R = Results(strcmp({Results.Task}, task));
            fI = ['Inclination_', groups{g}, '_deg']; fS = ['SIR_', groups{g}, '_deg'];
        end
        if isempty(R), continue; end
        x = [R.(fI)]; y = [R.(fS)];
        valid   = ~isnan(x) & ~isnan(y);
        inRange = x >= InclRange(1) & x <= InclRange(2) & y >= SIRRange(1) & y <= SIRRange(2);
        nOut(g) = sum(valid & ~inRange);
        keep    = valid & inRange;
        X{g} = x(keep); Y{g} = y(keep);
    end
    if all(cellfun(@isempty, X)), continue; end

    figure('Name', ['Corrélation inclinaison vs SIR — ', task], 'Color', 'w');
    for g = 1:3
        x = X{g}; y = Y{g}; n = numel(x);
        [r, pr]     = pearsonP(x, y);
        [rho, prho] = pearsonP(rankTies(x), rankTies(y));
        slope = NaN; icpt = NaN;
        if n >= 2 && std(x) > 0
            c = polyfit(x, y, 1); slope = c(1); icpt = c(2);
        end

        ci = length(Corr) + 1;
        Corr(ci).Task = task;              Corr(ci).Group = groups{g};
        Corr(ci).n = n;                    Corr(ci).nExcluded_OutOfRange = nOut(g);
        Corr(ci).Pearson_r = r;            Corr(ci).Pearson_p = pr;
        Corr(ci).Spearman_rho = rho;       Corr(ci).Spearman_p = prho;
        Corr(ci).Slope_degSIR_per_degIncl = slope;
        Corr(ci).Intercept_deg = icpt;

        subplot(1, 3, g); hold on;
        if n > 0
            scatter(x, y, 22, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.6);
            if ~isnan(slope)
                xx = [min(x) max(x)];
                plot(xx, slope * xx + icpt, '-', 'Color', cols(g, :) * 0.7, 'LineWidth', 2);
            end
        end
        yline(36, ':k'); yline(46, ':k');
        hold off;
        xlim(InclRange); ylim(SIRRange);
        xlabel('Inclinaison thoracique (deg)');
        ylabel('SIR (deg)');
        title({sprintf('%s (n=%d, %d exclu(s) hors plage)', labels{g}, n, nOut(g)), ...
               sprintf('Pearson r=%.2f (p=%s) | Spearman \\rho=%.2f (p=%s)', r, fmtP(pr), rho, fmtP(prho))}, ...
              'FontSize', 9);
        box on;
    end
    sgtitle(['Inclinaison thoracique vs SIR (Moroder) — ', task]);
    annotation('textbox', [0 0 1 0.04], 'String', ...
        sprintf(['Régressions et corrélations sur les paires avec inclinaison dans [%d, %d]° et SIR dans [%d, %d]° ', ...
                 'uniquement (hors plage exclus : PRE %d, POST %d, Asympto. %d). Graphes de distribution inchangés.'], ...
                InclRange(1), InclRange(2), SIRRange(1), SIRRange(2), nOut(1), nOut(2), nOut(3)), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

end

% Corrélation de Pearson + p bilatéral (Student, df = n-2) via betainc
% (MATLAB de base). NaN si n < 3 ou variance nulle.
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

% =========================================================================
%  DISTRIBUTION DE LA POSTURE : PRE vs POST vs ASYMPTOMATIQUE
% =========================================================================
% Une figure par tâche (CALIBRATION3, ANALYTIC1, ANALYTIC2), 3x2 :
%   haut gauche  : inclinaison thoracique, points individuels (jitter) +
%                  médiane et IQR par groupe, seuils des types d'inclinaison
%   haut droite  : SIR (Moroder), idem, seuils A/B (36 deg) et B/C (46 deg)
%   bas gauche   : % de types d'inclinaison I-A / I-B / I-C par groupe,
%                  construits comme Moroder : moyenne ± 1 SD de
%                  l'inclinaison PRE de la tâche (voir
%                  InclinationClassification.m)
%   bas droite   : % Moroder A / B / C par groupe
%   dernière ligne (pleine largeur) : inclinaison par strates de 5 deg
%                  (5-10 ... 45-50), % de chaque groupe par strate, hors
%                  plage comptés dans le titre, seuils des types
% PRE rouge, POST bleu, asymptomatique vert. Inclinaison : une valeur par
% patient (propre au thorax - dédoublonnée pour les patients 'RL'). SIR :
% une valeur par côté. SIR > SIROutlierDeg = outlier (valeur aberrante, à
% traiter plus tard) : exclu des distributions et des pourcentages, compté
% dans le titre.
function PlotPostureDistribution(Results, AsymResults, taskDef)

SIROutlierDeg = 100;
groups = {'PRE', 'POST', 'ASYM'};
labels = {'PRE', 'POST', 'Asympto.'};
cols   = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

if isempty(Results) && isempty(AsymResults)
    disp('PlotPostureDistribution: no data to plot.');
    return;
end

for iT = 1:numel(taskDef)
    task = taskDef(iT).name;
    incl = cell(1, 3); sir = cell(1, 3); nOut = zeros(1, 3);
    mor = cell(1, 3);

    for g = 1:3
        if strcmp(groups{g}, 'ASYM')
            if isempty(AsymResults), R = AsymResults; else, R = AsymResults(strcmp({AsymResults.Task}, task)); end
            fI = 'Inclination_deg'; fS = 'SIR_deg'; fM = 'Moroder';
        else
            if isempty(Results), R = Results; else, R = Results(strcmp({Results.Task}, task)); end
            fI = ['Inclination_', groups{g}, '_deg'];
            fS = ['SIR_', groups{g}, '_deg'];          fM = ['Moroder_', groups{g}];
        end
        if isempty(R), continue; end

        % Inclinaison : une valeur par patient (Numero)
        [~, iu] = unique([R.Numero], 'stable');
        vI = [R(iu).(fI)];
        incl{g}  = vI(~isnan(vI));

        % SIR : une valeur par côté, outliers exclus
        vS = [R.(fS)];
        mm = {R.(fM)};
        isOut = vS > SIROutlierDeg;
        nOut(g) = sum(isOut);
        keepS = ~isnan(vS) & ~isOut;
        sir{g} = vS(keepS);
        mor{g} = mm(keepS);
    end

    if all(cellfun(@isempty, incl)) && all(cellfun(@isempty, sir)), continue; end

    % Types d'inclinaison : moyenne ± 1 SD de l'inclinaison PRE de la tâche
    % (construction des seuils de Moroder), appliqués à tous les groupes
    ref = incl{1}; if isempty(ref), ref = [incl{:}]; end
    thrI = mean(ref) + [-1 1] * std(ref);
    itype = cell(1, 3);
    for g = 1:3
        t = repmat({'I-B'}, size(incl{g}));
        t(incl{g} < thrI(1)) = {'I-A'}; t(incl{g} > thrI(2)) = {'I-C'};
        itype{g} = t;
    end

    figure('Name', ['Distribution posture — ', task], 'Color', 'w');

    subplot(3, 2, 1);
    drawDots(incl, cols);
    yline(thrI(1), '--k', sprintf('I-A | I-B (%.1f°)', thrI(1)), 'LabelHorizontalAlignment', 'left');
    yline(thrI(2), '--k', sprintf('I-B | I-C (%.1f°)', thrI(2)), 'LabelHorizontalAlignment', 'left');
    finishAxes(labels, incl, 'Inclinaison thoracique (deg)', 'Inclinaison thoracique (TV8→CV7 vs verticale)');

    subplot(3, 2, 2);
    drawDots(sir, cols);
    yline(36, '--k', 'A | B (36°)', 'LabelHorizontalAlignment', 'left');
    yline(46, '--k', 'B | C (46°)', 'LabelHorizontalAlignment', 'left');
    outTxt = sprintf('outliers > %d° exclus : PRE %d, POST %d, Asympto. %d', ...
        SIROutlierDeg, nOut(1), nOut(2), nOut(3));
    finishAxes(labels, sir, 'SIR (deg)', {'SIR (Moroder, approx. cinématique)', outTxt});

    subplot(3, 2, 3);
    drawPct(itype, {'I-A', 'I-B', 'I-C'}, labels, [0.55 0.80 0.55; 0.98 0.85 0.40; 0.90 0.45 0.40]);
    title(sprintf('Types d''inclinaison (%% par groupe ; seuils = moyenne ± SD PRE : %.1f et %.1f°)', thrI));

    subplot(3, 2, 4);
    drawPct(mor, {'A', 'B', 'C'}, labels, [0.55 0.80 0.55; 0.98 0.85 0.40; 0.90 0.45 0.40]);
    title('Classification de Moroder (% par groupe, outliers exclus)');

    subplot(3, 2, [5 6]);
    drawStrata(incl, labels, cols, 5:5:50, thrI);

    sgtitle(['Posture — ', task, ' — PRE vs POST vs asymptomatique']);
end

end

% Points individuels (jitter horizontal) + médiane (trait épais) + IQR
% (barre verticale) par groupe, en x = 1..nGroupes.
function drawDots(vals, cols)
hold on;
for g = 1:numel(vals)
    v = vals{g};
    if isempty(v), continue; end
    x = g + 0.15 * (rand(size(v)) - 0.5) * 2;
    scatter(x, v, 18, cols(g, :), 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
    q = quartiles(v);
    plot([g g], q([1 3]), '-', 'Color', 'k', 'LineWidth', 2, 'HandleVisibility', 'off');
    plot(g + [-0.25 0.25], [q(2) q(2)], '-', 'Color', 'k', 'LineWidth', 3, 'HandleVisibility', 'off');
end
hold off;
end

% Inclinaison par strates de 5 deg (edges 5:5:50) : % de chaque groupe par
% strate, barres groupées PRE/POST/asympto. Dernière strate fermée à droite
% (45-50 inclut 50). Valeurs hors [5, 50] non tracées, comptées dans le
% titre. Lignes verticales aux seuils des types d'inclinaison (thr).
function drawStrata(vals, labels, cols, edges, thr)
nB = numel(edges) - 1;
P  = zeros(nB, numel(vals));
nBelow = zeros(1, numel(vals)); nAbove = zeros(1, numel(vals));
for g = 1:numel(vals)
    v = vals{g};
    if isempty(v), continue; end
    nBelow(g) = sum(v < edges(1));
    nAbove(g) = sum(v > edges(end));
    P(:, g) = 100 * histcounts(v, edges) / numel(v);
end
b = bar(1:nB, P, 'grouped');
for g = 1:numel(vals)
    b(g).FaceColor = cols(g, :);
    b(g).DisplayName = sprintf('%s (n=%d)', labels{g}, numel(vals{g}));
end
binLbl = arrayfun(@(k) sprintf('%d-%d', edges(k), edges(k+1)), 1:nB, 'UniformOutput', false);
set(gca, 'XTick', 1:nB, 'XTickLabel', binLbl);
% seuils -> position sur l'axe des strates (centre de strate k = k)
for it = 1:numel(thr)
    xl = 0.5 + (thr(it) - edges(1)) / (edges(2) - edges(1));
    xline(xl, '--k', sprintf('%.1f°', thr(it)), 'HandleVisibility', 'off');
end
xlabel('Inclinaison thoracique (deg)');
ylabel('% du groupe');
legend('Location', 'northeast');
outTxt = strjoin(arrayfun(@(g) sprintf('%s : %d < %d°, %d > %d°', labels{g}, nBelow(g), edges(1), ...
    nAbove(g), edges(end)), 1:numel(vals), 'UniformOutput', false), ' | ');
title({'Inclinaison thoracique par strates de 5°', ['hors plage : ', outTxt]}, 'FontSize', 9);
box on;
end

% Q1 / médiane / Q3 par interpolation linéaire (sans Statistics Toolbox)
function q = quartiles(v)
v = sort(v(:));
if numel(v) == 1, q = [v v v]; return; end
p = ((1:numel(v)) - 0.5) / numel(v);
q = interp1(p, v, [0.25 0.5 0.75], 'linear', 'extrap');
q = min(max(q, v(1)), v(end));
end

function finishAxes(labels, vals, yl, ttl)
n = cellfun(@numel, vals);
xt = arrayfun(@(g) sprintf('%s (n=%d)', labels{g}, n(g)), 1:numel(labels), 'UniformOutput', false);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', xt);
xlim([0.4 numel(labels) + 0.6]);
ylabel(yl);
title(ttl, 'FontSize', 9);
box on;
end

% Barres empilées : % de chaque catégorie par groupe (catégorie vide = non
% comptée).
function drawPct(cats, catNames, labels, catCols)
P = zeros(numel(cats), numel(catNames));
n = zeros(1, numel(cats));
for g = 1:numel(cats)
    c = cats{g};
    c = c(~cellfun(@isempty, c));
    n(g) = numel(c);
    for k = 1:numel(catNames)
        if n(g) > 0, P(g, k) = 100 * sum(strcmp(c, catNames{k})) / n(g); end
    end
end
b = bar(P, 'stacked');
for k = 1:numel(catNames)
    b(k).FaceColor = catCols(k, :);
    b(k).DisplayName = catNames{k};
end
xt = arrayfun(@(g) sprintf('%s (n=%d)', labels{g}, n(g)), 1:numel(labels), 'UniformOutput', false);
set(gca, 'XTickLabel', xt);
ylim([0 100]);
ylabel('%');
legend('Location', 'eastoutside');
box on;
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
%  LECTURE DU PostureSummary
% =========================================================================
% PostureSummary (Joint 11) du premier essai dont la tâche correspond à
% l'un des alias ; [] si absent.
function ps = getPostureSummary(Trial, aliases)
ps = [];
for k = 1:numel(Trial)
    if ~any(contains(Trial(k).task, aliases)), continue; end
    if isempty(Trial(k).Joint) || numel(Trial(k).Joint) < 11, continue; end
    if ~isfield(Trial(k).Joint(11), 'PostureSummary') || isempty(Trial(k).Joint(11).PostureSummary), continue; end
    ps = Trial(k).Joint(11).PostureSummary;
    return;
end
end

function v = getNum(s, field)
v = NaN;
if isfield(s, field) && ~isempty(s.(field)), v = s.(field); end
end

function v = getStr(s, field)
v = '';
if isfield(s, field) && ~isempty(s.(field)), v = s.(field); end
end

% 'Type A — Upright (...)' -> 'A' (même règle que ExportPostureSummary.m)
function short = shortMoroderType(full)
if contains(full, 'Type A'),     short = 'A';
elseif contains(full, 'Type B'), short = 'B';
elseif contains(full, 'Type C'), short = 'C';
else,                            short = '';
end
end

% =========================================================================
%  FLEXION THORACIQUE SIGNÉE PENDANT LE GESTE
% =========================================================================
% Lecture seule des cycles déjà stockés dans la base (rien n'est
% recalculé) : thorax = Joint(11).Euler, DOF3 = Z, flexion/extension du
% thorax par rapport au repère gravitaire du patient (ComputeKinematics.m :
% négatif = flexion, positif = extension) ; pic d'élévation repéré sur HG
% (Joint 12 côté R / 13 côté L, DOF1 = élévation). Cycles du côté du
% patient (rcycle / lcycle ; thorax partagé : repli sur l'autre côté si
% vide). Par cycle, puis moyenne des cycles :
%   Start  : thorax au début du cycle (moyenne des 3 premières frames,
%            bras le long du corps)
%   AtPeak : thorax à la frame du pic d'élévation HG
%   Change : AtPeak moins Start (> 0 = le tronc se redresse pendant
%            l'élévation, < 0 = il s'enroule)
%   Min / Max : extrêmes signés du thorax sur le cycle
% Vide si pas de cycle thorax.
function s = summariseThoraxFlexion(t, side)
s = [];
if strcmp(side, 'R'), cf = 'rcycle'; jHG = 12; else, cf = 'lcycle'; jHG = 13; end
if ~isfield(t, 'Joint') || numel(t.Joint) < 11, return; end
tx = cycleCurves(t.Joint(11), cf, 3, true);
if isempty(tx), return; end
hg = [];
if numel(t.Joint) >= jHG, hg = cycleCurves(t.Joint(jHG), cf, 1, false); end

nc = size(tx, 2);
st = NaN(1, nc); pk = NaN(1, nc); mn = NaN(1, nc); mx = NaN(1, nc);
for c = 1:nc
    z = tx(:, c);
    if all(isnan(z)), continue; end
    st(c) = mean(z(1:3), 'omitnan');
    mn(c) = min(z); mx(c) = max(z);
    if ~isempty(hg) && c <= size(hg, 2) && any(~isnan(hg(:, c)))
        [~, ip] = max(abs(hg(:, c)));
        pk(c) = z(ip);
    end
end
s.Start   = mean(st, 'omitnan');
s.AtPeak  = mean(pk, 'omitnan');
s.Change  = mean(pk - st, 'omitnan');
s.Min     = mean(mn, 'omitnan');
s.Max     = mean(mx, 'omitnan');
s.nCycles = sum(~isnan(st));
end

% Cycles [101 x nCycles] d'un DOF de Joint.Euler ; shared = joint unique
% (thorax) : repli sur l'autre côté si le champ demandé est vide
function c = cycleCurves(J, cf, dof, shared)
c = [];
if ~isfield(J, 'Euler') || ~isstruct(J.Euler), return; end
E = J.Euler;
if shared && (~isfield(E, cf) || isempty(E.(cf)))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if ~isfield(E, cf) || isempty(E.(cf)), return; end
c = squeeze(E.(cf)(1, dof, :, :));
if isvector(c), c = c(:); end
end

% Format large, une ligne par patient/côté, colonnes nommées comme
% Data_posture.xlsx : <tâche>_TXflex_<Start|AtPeak|Change|Min|Max>_<Pre|Post>
% (+ <tâche>_TXflex_nCycles_<Pre|Post>), ex. analytic1_TXflex_Change_Post
function W = pivotThoraxFlexion(L, flexTasks)
W = [];
if isempty(L), return; end
stats = {'Start', 'AtPeak', 'Change', 'Min', 'Max', 'nCycles'};
cond  = struct('PRE', 'Pre', 'POST', 'Post');
keys  = strcat(arrayfun(@num2str, [L.Numero], 'UniformOutput', false), '|', {L.Side});
[uk, iu] = unique(keys, 'stable');
for i = 1:numel(uk)
    row = struct('Numero', L(iu(i)).Numero, 'PatientID', L(iu(i)).PatientID, 'Side', L(iu(i)).Side);
    for iT = 1:numel(flexTasks)
        for cc = {'PRE', 'POST'}
            for st = stats
                row.(sprintf('%s_TXflex_%s_%s', lower(flexTasks{iT}), st{1}, cond.(cc{1}))) = NaN;
            end
        end
    end
    for j = find(strcmp(keys, uk{i}))
        for st = stats
            row.(sprintf('%s_TXflex_%s_%s', lower(L(j).Task), st{1}, cond.(L(j).Condition))) = L(j).(st{1});
        end
    end
    if isempty(W), W = row; else, W(end+1) = row; end %#ok<AGROW>
end
end

% Même format pour les épaules asymptomatiques (une seule session par
% épaule) : une ligne par épaule, colonne Condition (PRE/POST de la
% session retenue) et colonnes <tâche>_TXflex_<stat>_Asym
function W = pivotThoraxFlexionAsym(L, flexTasks)
W = [];
if isempty(L), return; end
stats = {'Start', 'AtPeak', 'Change', 'Min', 'Max', 'nCycles'};
keys  = strcat(arrayfun(@num2str, [L.Numero], 'UniformOutput', false), '|', {L.Side});
[uk, iu] = unique(keys, 'stable');
for i = 1:numel(uk)
    row = struct('Numero', L(iu(i)).Numero, 'PatientID', L(iu(i)).PatientID, 'Side', L(iu(i)).Side, ...
                 'Condition', L(iu(i)).Condition);
    for iT = 1:numel(flexTasks)
        for st = stats
            row.(sprintf('%s_TXflex_%s_Asym', lower(flexTasks{iT}), st{1})) = NaN;
        end
    end
    for j = find(strcmp(keys, uk{i}))
        for st = stats
            row.(sprintf('%s_TXflex_%s_Asym', lower(L(j).Task), st{1})) = L(j).(st{1});
        end
    end
    if isempty(W), W = row; else, W(end+1) = row; end %#ok<AGROW>
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
