% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Contrôle patient par patient des courbes de la vue
%                d'ensemble (mêmes populations, joints, DOF et conventions
%                que PlotMeanCurvesFromDatabase) :
%                  rTSA PRE et POST : patients de la feuille 'Posture' de
%                      Data_posture.xlsx, côté opéré ;
%                  épaules saines : feuille 'Posture_Asym' (Numero, Cote,
%                      Session), côté sain de la session retenue.
%                Contrairement à PlotMeanCurvesFromDatabase, tous les cycles,
%                les 3 DOF et le signal signé sont gardés (rééchantillonnés
%                sur 101 points), ce qui permet :
%                  1) des contrôles par épaule x session x tâche x mesure :
%                     saut > 90° entre deux échantillons d'un cycle (angle
%                     qui franchit ±180°), repli créé par la valeur absolue,
%                     forme inversée ou atypique (corrélation avec la courbe
%                     moyenne du groupe), ROM extrême (z robuste médiane /
%                     MAD), cycles dispersés, verdict de
%                     ComputeCurveQualityFromDatabase si fourni (hors verdict
%                     "Inversee" du thorax, dont la forme varie normalement) ;
%                  2) pour HT et GH, une élévation 3D indépendante de la
%                     séquence : angle entre l'axe long de l'humérus et l'axe
%                     Y du segment proximal = acos(cos(DOF1) cos(DOF3))
%                     (Euler.full rangé X, Y, Z ; vrai en ZXY comme en XZY),
%                     comparée à l'angle d'Euler tracé, avec l'angle du
%                     milieu de la séquence au pic (blocage de cardan
%                     proche de 90°) ;
%                  3) la liste des sauts avec les valeurs correspondantes de
%                     Data_posture.
%                Conventions de tracé : HG, HT, GH en valeur absolue ; ST
%                signé, sens harmonisé entre côtés ; thorax signé.
%                Textes des figures sans tiret ni tiret long.
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile      (char) chemin vers PatientDatabase.mat (ou ses
%                             parties _partXofY, détectées automatiquement),
%                             ou (struct) Cycles d'un appel précédent : les
%                             contrôles et figures sont refaits sans relire
%                             la base
%           DataFile          (char) chemin vers Data_posture.xlsx (feuilles
%                             Posture, Posture_Asym, Cinematique,
%                             Cinematique_pics et leurs versions _Asym)
%           OutputFolder      (char, optionnel) dossier de sortie : Excel
%                             QC_courbes.xlsx et figures PNG ; '' = pas
%                             d'export
%           CurveQualityFiles (char ou cellstr, optionnel) Excel(s) de
%                             ComputeCurveQualityFromDatabase (feuilles
%                             Curve_Quality et/ou Curve_Quality_Asymptomatic)
% Outputs : QC      (table) une ligne par épaule x session x tâche x mesure
%           Summary (table) nombre de courbes signalées par population,
%                   tâche, mesure et critère
%           Cycles  (struct array) une ligne par épaule x session x tâche :
%                   grp, num, side, cond, task, HG/HT/GH/ST/TX = [101 x 3 x
%                   nCycles] (signé, 3 DOF)
%           + figures : vue d'ensemble par tâche (courbes signalées en
%           rouge) ; GH et HT, angle d'Euler vs élévation 3D
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [QC, Summary, Cycles] = CheckCurvesFromDatabase(DatabaseFile, DataFile, OutputFolder, CurveQualityFiles)

if nargin < 3, OutputFolder = ''; end
if nargin < 4, CurveQualityFiles = {}; end
CurveQualityFiles = cellstr(CurveQualityFiles);

tasks = {'ANALYTIC1', 'ANALYTIC2'};
tlbl  = {'flexion', 'scaption'};
mets  = {'HG', 'HT', 'GH', 'ST', 'TX'};
mlbl  = {'HG, élévation / gravité', 'HT, élévation / thorax', 'GH, élévation', ...
         'ST, rotation latérale', 'Thorax, flexion signée'};
isAbs = [true true true false false];
grps  = {'PRE', 'POST', 'ASYM'};
glbl  = {'rTSA PRE', 'rTSA POST', 'Épaules saines'};
cols  = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

% Seuils des contrôles
Th.jump  = 90;    % deg, saut entre deux échantillons d'un cycle
Th.fold  = 10;    % deg, repli créé par la valeur absolue
Th.rAtyp = 0.5;   % corrélation avec la moyenne du groupe sous laquelle la forme est atypique
Th.zROM  = 3.5;   % z robuste du ROM
Th.sdCyc = 15;    % deg, SD moyen entre cycles
Th.gap3D = 40;    % deg, écart entre angle d'Euler et élévation 3D au pic (HT, GH)

% -------------------------------------------------------------------------
% LECTURE DES CYCLES
% -------------------------------------------------------------------------
if isstruct(DatabaseFile)
    Cycles = DatabaseFile;
else
    Cycles = readCycles(DatabaseFile, DataFile, tasks);
end
nR = numel(Cycles);
fprintf('%d courbes épaule x session x tâche\n', nR);

% Sens de ST harmonisé entre côtés (même règle que PlotMeanCurvesFromDatabase)
stFlip = false(1, numel(tasks));
for t = 1:numel(tasks)
    ex = NaN(nR, 1); sd = {Cycles.side}';
    for i = find(strcmp({Cycles.task}, tasks{t}))
        c = Cycles(i).ST;
        if ~isempty(c), mc = mean(squeeze(c(:, 1, :)), 2, 'omitnan'); ex(i) = mc(51) - mc(1); end
    end
    stFlip(t) = sign(median(ex(strcmp(sd, 'R')), 'omitnan')) ~= sign(median(ex(strcmp(sd, 'L')), 'omitnan'));
end

% Cycles tracés (convention de la vue d'ensemble) et courbe moyenne par épaule
Disp = cell(nR, numel(mets)); Sgn = Disp; MeanD = NaN(nR, numel(mets), 101);
for i = 1:nR
    t = find(strcmp(tasks, Cycles(i).task));
    for m = 1:numel(mets)
        c = Cycles(i).(mets{m});
        if isempty(c) || size(c, 3) == 0, continue; end
        s = squeeze(c(:, dofOf(mets{m}, t), :)); if isvector(s), s = s(:); end
        if strcmp(mets{m}, 'ST') && stFlip(t) && strcmp(Cycles(i).side, 'L'), s = -s; end
        Sgn{i, m} = s;
        if isAbs(m), Disp{i, m} = abs(s); else, Disp{i, m} = s; end
        MeanD(i, m, :) = mean(Disp{i, m}, 2, 'omitnan');
    end
end

% Moyennes de groupe
inG = @(g, t) strcmp({Cycles.grp}, grps{g}) & strcmp({Cycles.task}, tasks{t});
GM = NaN(numel(grps), numel(tasks), numel(mets), 101);
for g = 1:numel(grps)
    for t = 1:numel(tasks)
        for m = 1:numel(mets)
            X = squeeze(MeanD(inG(g, t), m, :));
            if isvector(X), X = X(:)'; end
            GM(g, t, m, :) = mean(X, 1, 'omitnan');
        end
    end
end

% Verdicts du pipeline (ComputeCurveQualityFromDatabase)
CQ = readCurveQuality(CurveQualityFiles);

% -------------------------------------------------------------------------
% CONTRÔLES
% -------------------------------------------------------------------------
rows = cell(nR * numel(mets), 1); Flag = false(nR, numel(mets)); E3 = cell(nR, 2); nq = 0;
for i = 1:nR
    g = find(strcmp(grps, Cycles(i).grp)); t = find(strcmp(tasks, Cycles(i).task));
    for m = 1:numel(mets)
        r = emptyRow();
        r.Population = Cycles(i).grp; r.Numero = Cycles(i).num; r.Side = Cycles(i).side;
        r.Session = Cycles(i).cond; r.Task = tasks{t}; r.Metric = mets{m};
        dc = Disp{i, m}; sc = Sgn{i, m};
        r.nCycles = size(dc, 2);
        f = {};
        if r.nCycles == 0
            f{end+1} = 'aucun cycle'; %#ok<AGROW>
        else
            md = squeeze(MeanD(i, m, :)); ms = mean(sc, 2, 'omitnan');
            gm = squeeze(GM(g, t, m, :));
            r.ROM_deg = max(md) - min(md); r.Peak_deg = max(abs(md)); r.Rest_deg = md(1);
            r.CyclesJump = sum(any(abs(diff(sc, 1, 1)) > Th.jump, 1));
            r.CyclesZeroCross = sum(any(sc > 3, 1) & any(sc < -3, 1));
            if isAbs(m), r.AbsFold_deg = max(abs(md - abs(ms))); else, r.AbsFold_deg = 0; end
            if r.nCycles > 1, r.SD_cycles_deg = mean(std(dc, 0, 2, 'omitnan'), 'omitnan'); end
            ok = ~isnan(md) & ~isnan(gm);
            if sum(ok) > 10 && std(md(ok)) > 0
                cc = corrcoef(md(ok), gm(ok)); r.r_shape = cc(1, 2);
            end
            G3 = squeeze(MeanD(inG(g, t), m, :));
            romG = max(G3, [], 2) - min(G3, [], 2);
            mdn = median(romG, 'omitnan'); mad = 1.4826 * median(abs(romG - mdn), 'omitnan');
            if mad > 0, r.z_ROM = (r.ROM_deg - mdn) / mad; end
            % élévation 3D (HT, GH)
            if any(strcmp(mets{m}, {'HT', 'GH'}))
                c = Cycles(i).(mets{m});
                e3 = squeeze(acosd(min(1, max(-1, cosd(c(:, 1, :)) .* cosd(c(:, 3, :))))));
                if isvector(e3), e3 = e3(:); end
                m3 = mean(e3, 2, 'omitnan');
                [~, k] = max(md);
                mid = 1; if t == 2, mid = 3; end           % angle du milieu : X en ZXY, Z en XZY
                r.Peak3D_deg = max(m3);
                r.EulerMinus3D_deg = r.Peak_deg - r.Peak3D_deg;
                r.MiddleAngleAtPeak_deg = mean(squeeze(c(k, mid, :)), 'omitnan');
                E3{i, strcmp({'HT', 'GH'}, mets{m})} = m3;
            end
            % verdict du pipeline
            key = sprintf('%d|%s|%s|%s|%s', r.Numero, r.Side, r.Task, upper(r.Session), r.Metric);
            if isKey(CQ, key)
                v = CQ(key); r.PipelineVerdict = v{1}; r.PipelineReason = v{2};
            end
            % signalements
            if r.CyclesJump > 0, f{end+1} = sprintf('saut > %d° (%d cycle(s))', Th.jump, r.CyclesJump); end %#ok<AGROW>
            if r.AbsFold_deg > Th.fold, f{end+1} = sprintf('repli valeur absolue %.0f°', r.AbsFold_deg); end %#ok<AGROW>
            if r.r_shape < 0, f{end+1} = 'forme inversée'; %#ok<AGROW>
            elseif r.r_shape < Th.rAtyp, f{end+1} = sprintf('forme atypique (r %.2f)', r.r_shape); end %#ok<AGROW>
            if abs(r.z_ROM) > Th.zROM, f{end+1} = sprintf('ROM extrême (z %.1f)', r.z_ROM); end %#ok<AGROW>
            if r.SD_cycles_deg > Th.sdCyc, f{end+1} = sprintf('cycles dispersés (SD %.0f°)', r.SD_cycles_deg); end %#ok<AGROW>
            if abs(r.EulerMinus3D_deg) > Th.gap3D, f{end+1} = sprintf('Euler vs 3D %+.0f°', r.EulerMinus3D_deg); end %#ok<AGROW>
            if ~isempty(r.PipelineVerdict) && ~strcmp(r.PipelineVerdict, 'OK') && ...
                    ~(strcmp(mets{m}, 'TX') && strcmp(r.PipelineReason, 'Inversee'))
                f{end+1} = ['pipeline : ', r.PipelineVerdict, ' (', r.PipelineReason, ')']; %#ok<AGROW>
            end
        end
        r.Flags = strjoin(f, ' ; ');
        Flag(i, m) = ~isempty(f);
        nq = nq + 1; rows{nq} = r;
    end
end
QC = struct2table([rows{1:nq}]);

% Synthèse
crit = {'Signalées', ''; 'Saut', 'saut'; 'Repli_abs', 'repli'; 'Forme_inversee', 'inversée'; ...
        'Forme_atypique', 'atypique'; 'ROM_extreme', 'extrême'; 'Cycles_disperses', 'dispersés'; ...
        'Euler_vs_3D', 'Euler vs 3D'; 'Pipeline', 'pipeline'};
S = {};
for g = 1:numel(grps)
    for t = 1:numel(tasks)
        for m = 1:numel(mets)
            k = strcmp(QC.Population, grps{g}) & strcmp(QC.Task, tasks{t}) & strcmp(QC.Metric, mets{m});
            fl = QC.Flags(k);
            v = cellfun(@(p) sum(contains(fl, p) & ~cellfun(@isempty, fl)), crit(:, 2))';
            S(end+1, :) = [grps(g), tlbl(t), mets(m), {sum(k)}, num2cell(v)]; %#ok<AGROW>
        end
    end
end
Summary = cell2table(S, 'VariableNames', [{'Population', 'Tache', 'Mesure', 'n'}, crit(:, 1)']);
disp(Summary);

% Sauts : valeurs correspondantes de Data_posture
Jumps = jumpTable(QC(QC.CyclesJump > 0, :), DataFile);
if height(Jumps), disp(Jumps); end

% -------------------------------------------------------------------------
% FIGURES
% -------------------------------------------------------------------------
x = 0:100;
figs = gobjects(0);
for t = 1:numel(tasks)
    fig = figure('Name', sprintf('Contrôle des courbes, %s', tlbl{t}), 'Color', 'w');
    for g = 1:numel(grps)
        idx = find(inG(g, t));
        for m = 1:numel(mets)
            ax = subplot(numel(grps), numel(mets), (g - 1) * numel(mets) + m); hold(ax, 'on');
            for i = idx(~Flag(idx, m))
                plot(ax, x, squeeze(MeanD(i, m, :)), '-', 'Color', [0.6 0.6 0.6 0.35], 'LineWidth', 0.5);
            end
            for i = idx(Flag(idx, m))
                plot(ax, x, squeeze(MeanD(i, m, :)), '-', 'Color', [0.85 0.1 0.1 0.8], 'LineWidth', 0.8);
            end
            plot(ax, x, squeeze(GM(g, t, m, :)), '-', 'Color', cols(g, :), 'LineWidth', 2.4);
            if strcmp(mets{m}, 'TX'), yline(ax, 0, ':k'); end
            hold(ax, 'off'); box(ax, 'on'); grid(ax, 'on');
            title(ax, sprintf('%s\n%s : %d signalée(s) sur %d', mlbl{m}, glbl{g}, sum(Flag(idx, m)), numel(idx)), 'FontSize', 9);
            if g == numel(grps), xlabel(ax, '% du cycle'); end
            if m == 1, ylabel(ax, 'angle (deg)'); end
        end
    end
    sgtitle(fig, sprintf('Contrôle des courbes, %s : gris = épaule, rouge = signalée, trait épais = moyenne', tlbl{t}), 'FontSize', 13);
    figs(end+1) = fig; %#ok<AGROW>
end

% GH (et HT) : angle d'Euler tracé vs élévation 3D
fig = figure('Name', 'GH, angle d''Euler vs élévation 3D', 'Color', 'w');
for t = 1:numel(tasks)
    for g = 1:numel(grps)
        ax = subplot(numel(tasks), numel(grps) + 1, (t - 1) * (numel(grps) + 1) + g); hold(ax, 'on');
        idx = find(inG(g, t));
        A = squeeze(MeanD(idx, 3, :)); B = cell2mat(cellfun(@(v) v(:)', E3(idx, 2), 'UniformOutput', false));
        plot(ax, x, A', '-', 'Color', [0.8 0.35 0.35 0.3], 'LineWidth', 0.4);
        h1 = plot(ax, x, mean(A, 1, 'omitnan'), '-', 'Color', [0.7 0.1 0.1], 'LineWidth', 2.4);
        h2 = plot(ax, x, mean(B, 1, 'omitnan'), '-', 'Color', [0.1 0.1 0.65], 'LineWidth', 2.4);
        hold(ax, 'off'); box(ax, 'on'); grid(ax, 'on'); ylim(ax, [0 200]);
        title(ax, sprintf('GH %s, %s (n=%d)', tlbl{t}, glbl{g}, numel(idx)), 'FontSize', 9);
        xlabel(ax, '% du cycle'); if g == 1, ylabel(ax, 'angle (deg)'); end
        if t == 1 && g == 1, legend(ax, [h1 h2], {'Angle d''Euler tracé', 'Élévation 3D'}, 'Location', 'northwest', 'FontSize', 8); end
    end
    ax = subplot(numel(tasks), numel(grps) + 1, t * (numel(grps) + 1)); hold(ax, 'on');
    for g = 1:numel(grps)
        k = strcmp(QC.Population, grps{g}) & strcmp(QC.Task, tasks{t}) & strcmp(QC.Metric, 'GH');
        scatter(ax, abs(QC.MiddleAngleAtPeak_deg(k)), QC.EulerMinus3D_deg(k), 12, cols(g, :), 'filled', ...
            'MarkerFaceAlpha', 0.6, 'DisplayName', glbl{g});
    end
    yline(ax, 0, 'k', 'HandleVisibility', 'off'); xline(ax, 90, ':k', 'HandleVisibility', 'off');
    hold(ax, 'off'); box(ax, 'on'); grid(ax, 'on'); xlim(ax, [0 95]);
    xlabel(ax, '|angle du milieu| au pic (deg)'); ylabel(ax, 'Euler moins 3D (deg)');
    title(ax, sprintf('GH %s : écart selon la proximité du blocage (90°)', tlbl{t}), 'FontSize', 9);
    if t == 1, legend(ax, 'Location', 'northwest', 'FontSize', 7); end
end
sgtitle(fig, 'GH : angle d''Euler tracé vs élévation 3D (indépendante de la séquence)', 'FontSize', 13);
figs(end+1) = fig;

% -------------------------------------------------------------------------
% EXPORT
% -------------------------------------------------------------------------
if isempty(OutputFolder), return; end
if ~isfolder(OutputFolder), mkdir(OutputFolder); end
xl = fullfile(OutputFolder, 'QC_courbes.xlsx');
if isfile(xl), delete(xl); end
writetable(QC, xl, 'Sheet', 'QC_courbes');
writetable(Summary, xl, 'Sheet', 'Synthese');
if height(Jumps), writetable(Jumps, xl, 'Sheet', 'Sauts'); end
for f = figs
    set(f, 'Position', [0 0 1900 1150]);
    fn = regexprep(regexprep(f.Name, '[éèê]', 'e'), 'ô', 'o');      % nom de fichier sans accent
    fn = regexprep(regexprep(fn, '[^A-Za-z0-9]+', '_'), '_+$', '');
    exportgraphics(f, fullfile(OutputFolder, [fn '.png']), 'Resolution', 150);
end
fprintf('Export : %s\n', OutputFolder);
end

% =========================================================================
%  LECTURE
% =========================================================================
% Cycles de la base pour les patients de 'Posture' (PRE, POST, côté opéré)
% et les épaules de 'Posture_Asym' (côté sain, session retenue)
function Cycles = readCycles(DatabaseFile, DataFile, tasks)
fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('CheckCurvesFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants).', DatabaseFile);
end
P  = readtable(DataFile, 'Sheet', 'Posture', 'VariableNamingRule', 'preserve');
nums = P.Numero(~isnan(P.Numero));
Pa = readtable(DataFile, 'Sheet', 'Posture_Asym', 'VariableNamingRule', 'preserve');
Pa = Pa(~isnan(Pa.Numero), :);
mets = {'HG', 'HT', 'GH', 'ST', 'TX'};
Cycles = struct('grp', {}, 'num', {}, 'side', {}, 'cond', {}, 'task', {}, ...
                'HG', {}, 'HT', {}, 'GH', {}, 'ST', {}, 'TX', {});
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S = load(fileList{iFile}, 'Database');
    for iP = 1:numel(S.Database)
        d = S.Database(iP);
        if isempty(d.Numero), continue; end
        sides = d.Side; if ischar(sides), sides = cellstr(sides(:)); end
        jobs = cell(0, 3);
        if ismember(d.Numero, nums)
            jobs(end+1, :) = {'PRE', 'PRE', sides{1}};   %#ok<AGROW>
            jobs(end+1, :) = {'POST', 'POST', sides{1}}; %#ok<AGROW>
        end
        ka = find(Pa.Numero == d.Numero, 1);
        if ~isempty(ka), jobs(end+1, :) = {'ASYM', Pa.Session{ka}, Pa.Cote{ka}}; end %#ok<AGROW>
        for jb = 1:size(jobs, 1)
            [grp, cond, sd] = jobs{jb, :};
            if ~isfield(d, cond) || ~isstruct(d.(cond)) || ~isfield(d.(cond), 'Trial'), continue; end
            T = d.(cond).Trial;
            if strcmp(sd, 'R'), J = [12 1 2 3 11]; cf = 'rcycle'; else, J = [13 6 7 8 11]; cf = 'lcycle'; end
            for t = 1:numel(tasks)
                k = find(strcmp({T.task}, tasks{t}), 1);
                if isempty(k), continue; end
                r = struct('grp', grp, 'num', d.Numero, 'side', sd, 'cond', cond, 'task', tasks{t}, ...
                           'HG', [], 'HT', [], 'GH', [], 'ST', [], 'TX', []);
                for m = 1:numel(mets)
                    r.(mets{m}) = allCycles(T(k), J(m), cf, m == numel(mets));
                end
                Cycles(end+1) = r; %#ok<AGROW>
            end
        end
    end
    clear S
end
end

% [101 x 3 x nCycles] : 3 DOF signés, chaque cycle rééchantillonné sur 101
% points ; shared = joint unique (thorax) : repli sur l'autre côté si vide
function c = allCycles(t, ji, cf, shared)
c = zeros(101, 3, 0);
if numel(t.Joint) < ji || ~isfield(t.Joint(ji), 'Euler') || ~isstruct(t.Joint(ji).Euler), return; end
E = t.Joint(ji).Euler;
if shared && (~isfield(E, cf) || isempty(E.(cf)))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if ~isfield(E, cf) || isempty(E.(cf)), return; end
X = E.(cf);                                   % [1 x 3 x n x nCycles]
for q = 1:size(X, 4)
    y = squeeze(X(1, :, :, q))';              % [n x 3]
    if all(isnan(y(:))), continue; end
    y = y(1:find(any(~isnan(y), 2), 1, 'last'), :);
    if size(y, 1) ~= 101
        y = interp1(linspace(0, 100, size(y, 1)), y, 0:100, 'linear');
    end
    c(:, :, end+1) = y; %#ok<AGROW>
end
end

% Verdicts de ComputeCurveQualityFromDatabase : clé Numero|côté|tâche|session|mesure
function CQ = readCurveQuality(files)
CQ = containers.Map('KeyType', 'char', 'ValueType', 'any');
for f = files(:)'
    if isempty(f{1}) || ~isfile(f{1}), continue; end
    for s = intersect(sheetnames(f{1}), {'Curve_Quality', 'Curve_Quality_Asymptomatic'})'
        Q = readtable(f{1}, 'Sheet', s{1}, 'VariableNamingRule', 'preserve');
        txt = @(v) strip(fillmissing(string(v), 'constant', ""));   % colonne texte, vide si absente
        sd = txt(Q.Side); tk = txt(Q.Task); cd = upper(txt(Q.Condition)); mt = txt(Q.Metric);
        vd = txt(Q.Verdict);
        if ismember('Reason', Q.Properties.VariableNames) && ~isnumeric(Q.Reason), rs = txt(Q.Reason);
        else, rs = strings(height(Q), 1); end
        for i = 1:height(Q)
            if isnan(Q.Numero(i)), continue; end
            key = sprintf('%d|%s|%s|%s|%s', Q.Numero(i), sd(i), tk(i), cd(i), mt(i));
            CQ(key) = {char(vd(i)), char(rs(i))};
        end
    end
end
if CQ.Count == 0, disp('Verdicts du pipeline : aucun fichier CurveQuality lu.'); end
end

% Sauts > 90° avec les valeurs de Data_posture (ROM, pic) de la même courbe
function J = jumpTable(Q, DataFile)
jn = struct('HG', 'Humerogravitaire', 'HT', 'Humerothoracique', 'GH', 'Glenohumerale', ...
            'ST', 'Scapulothoracique', 'TX', 'Thoracique');
cache = containers.Map();
romDP = NaN(height(Q), 1); pkDP = romDP;
for i = 1:height(Q)
    if strcmp(Q.Population{i}, 'ASYM'), suf = 'Asym'; sh = {'Cinematique_Asym', 'Cinematique_pics_Asym'};
    else, suf = lower(Q.Population{i}); suf(1) = upper(suf(1)); sh = {'Cinematique', 'Cinematique_pics'}; end
    tk = lower(Q.Task{i});
    for k = 1:2
        if ~isKey(cache, sh{k})
            try cache(sh{k}) = readtable(DataFile, 'Sheet', sh{k}, 'VariableNamingRule', 'preserve');
            catch, cache(sh{k}) = table(); end
        end
        D = cache(sh{k});
        col = sprintf('%s_%s_%s_%s', tk, ternary(k == 1, 'ROM', 'MAX'), jn.(Q.Metric{i}), suf);
        if ~isempty(D) && ismember(col, D.Properties.VariableNames)
            v = D.(col)(D.Numero == Q.Numero(i));
            if ~isempty(v), if k == 1, romDP(i) = v(1); else, pkDP(i) = v(1); end, end
        end
    end
end
J = Q(:, {'Population', 'Numero', 'Side', 'Session', 'Task', 'Metric', 'nCycles', 'CyclesJump', ...
          'Peak_deg', 'Peak3D_deg', 'Flags'});
J.ROM_Data_posture = romDP; J.Peak_Data_posture = pkDP;
end

% =========================================================================
%  OUTILS
% =========================================================================
function r = emptyRow()
r = struct('Population', '', 'Numero', NaN, 'Side', '', 'Session', '', 'Task', '', 'Metric', '', ...
    'nCycles', 0, 'ROM_deg', NaN, 'Peak_deg', NaN, 'Rest_deg', NaN, 'CyclesJump', 0, ...
    'CyclesZeroCross', 0, 'AbsFold_deg', NaN, 'SD_cycles_deg', NaN, 'r_shape', NaN, 'z_ROM', NaN, ...
    'Peak3D_deg', NaN, 'EulerMinus3D_deg', NaN, 'MiddleAngleAtPeak_deg', NaN, ...
    'PipelineVerdict', '', 'PipelineReason', '', 'Flags', '');
end

% DOF tracé : HT et GH DOF3 en flexion (ZXY), DOF1 en scaption (XZY) ;
% HG et ST DOF1 ; thorax DOF3
function d = dofOf(met, t)
switch met
    case {'HT', 'GH'}, d = 3 * (t == 1) + 1 * (t == 2);
    case 'TX',         d = 3;
    otherwise,         d = 1;
end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

% Fichiers de la base : parties _partXofY triées, sinon DatabaseFile seul
function fileList = discoverDatabaseFiles(DatabaseFile)
[dbFolder, dbName, dbExt] = fileparts(DatabaseFile);
parts = dir(fullfile(dbFolder, [dbName, '_part*of*', dbExt]));
if isempty(parts)
    if isfile(DatabaseFile), fileList = {DatabaseFile}; else, fileList = {}; end
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
