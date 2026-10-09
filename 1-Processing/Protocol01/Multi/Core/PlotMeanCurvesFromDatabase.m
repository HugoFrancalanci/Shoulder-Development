% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Courbes moyennes ± 1 SD de HG, HT, GH, ST et thorax pour
%                trois populations, en flexion (ANALYTIC1) et scaption
%                (ANALYTIC2) :
%                  rTSA PRE et rTSA POST : patients de la feuille 'Posture'
%                      de Data_posture.xlsx (tri manuel), côté opéré ;
%                  épaules saines : feuille 'Posture_Asym' (Numero, Cote,
%                      Session), côté sain de la session retenue.
%                Lecture seule des cycles stockés dans la base (rien n'est
%                recalculé), mêmes joints et DOF que
%                ComputeClinicalContributionsFromDatabase.m :
%                  HG  Joint(12/13) DOF1, HT Joint(1/6) et GH Joint(2/7)
%                      DOF de la tâche (ANALYTIC1 : DOF3, ANALYTIC2 : DOF1),
%                      en valeur absolue ;
%                  ST  Joint(3/8) DOF1 (rotation latérale), signé, sens
%                      harmonisé entre côtés droit et gauche (signe de
%                      l'excursion médiane par côté) ;
%                  thorax Joint(11) DOF3, flexion signée (> 0 = extension).
%                Moyenne des cycles par patient, rééchantillonnée sur 101
%                points, puis moyenne ± SD par population.
%                Élévations bilatérales : le thorax des épaules saines est
%                celui de la session du patient (commun aux deux bras).
%                Textes de la figure sans tiret ni tiret long.
% -------------------------------------------------------------------------
% Inputs  : DatabaseFile (char) chemin vers PatientDatabase.mat (ou ses
%                        parties _partXofY, détectées automatiquement)
%           DataFile     (char) chemin vers Data_posture.xlsx (feuilles
%                        'Posture' et 'Posture_Asym')
% Outputs : Curves (struct) Curves.<PRE|POST|ASYM>.<ANALYTIC1|ANALYTIC2>
%                  .<HG|HT|GH|ST|TX> = [n x 101] (une ligne par épaule),
%                  .side = côté de chaque ligne
%           + 1 figure 2 x 5 (lignes : flexion, scaption ; colonnes : HG,
%           HT, GH, ST, thorax)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Curves = PlotMeanCurvesFromDatabase(DatabaseFile, DataFile)

fileList = discoverDatabaseFiles(DatabaseFile);
if isempty(fileList)
    error('PlotMeanCurvesFromDatabase:noDatabase', ...
        'PatientDatabase.mat introuvable (%s, ni fichiers _partXofY correspondants).', DatabaseFile);
end

% Populations : patients retenus (feuille Posture) et épaules saines
P  = readtable(DataFile, 'Sheet', 'Posture', 'VariableNamingRule', 'preserve');
nums = P.Numero(~isnan(P.Numero));
Pa = readtable(DataFile, 'Sheet', 'Posture_Asym', 'VariableNamingRule', 'preserve');
Pa = Pa(~isnan(Pa.Numero), :);

tasks = {'ANALYTIC1', 'ANALYTIC2'};
tlbl  = {'flexion', 'scaption'};
dofHT = [3 1];                      % DOF de HT et GH par tâche
mets  = {'HG', 'HT', 'GH', 'ST', 'TX'};
mlbl  = {'HG, élévation / gravité', 'HT, élévation / thorax', 'GH, élévation', ...
         'ST, rotation latérale', 'Thorax, flexion signée'};
grps  = {'PRE', 'POST', 'ASYM'};
glbl  = {'rTSA PRE', 'rTSA POST', 'Épaules saines'};
cols  = [0.8500 0.3250 0.0980; 0 0.4470 0.7410; 0.4660 0.6740 0.1880];

Curves = struct();
for g = 1:numel(grps)
    for t = 1:numel(tasks)
        for m = 1:numel(mets), Curves.(grps{g}).(tasks{t}).(mets{m}) = zeros(0, 101); end
        Curves.(grps{g}).(tasks{t}).side = {};
    end
end

% -------------------------------------------------------------------------
% LECTURE DES CYCLES
% -------------------------------------------------------------------------
for iFile = 1:numel(fileList)
    disp(['Chargement : ', fileList{iFile}]);
    S = load(fileList{iFile}, 'Database');
    for iP = 1:numel(S.Database)
        d = S.Database(iP);
        if isempty(d.Numero), continue; end
        sides = d.Side; if ischar(sides), sides = cellstr(sides(:)); end
        % {population, condition de la session, côté}
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
            if strcmp(sd, 'R'), J = [12 1 2 3]; cf = 'rcycle'; else, J = [13 6 7 8]; cf = 'lcycle'; end
            for t = 1:numel(tasks)
                k = find(strcmp({T.task}, tasks{t}), 1);
                if isempty(k), continue; end
                % {joint, DOF, valeur absolue}
                spec = {J(1), 1, true; J(2), dofHT(t), true; J(3), dofHT(t), true; J(4), 1, false; 11, 3, false};
                for m = 1:numel(mets)
                    cyc = cycles(T(k), spec{m, 1}, spec{m, 2}, cf, m == numel(mets));
                    row = NaN(1, 101);
                    if ~isempty(cyc)
                        if spec{m, 3}, cyc = abs(cyc); end
                        row = resample101(mean(cyc, 2, 'omitnan'));
                    end
                    Curves.(grp).(tasks{t}).(mets{m})(end+1, :) = row;
                end
                Curves.(grp).(tasks{t}).side{end+1} = sd;
            end
        end
    end
    clear S
end

% Sens de ST harmonisé entre côtés droit et gauche (toutes populations)
for t = 1:numel(tasks)
    sdAll = [Curves.PRE.(tasks{t}).side, Curves.POST.(tasks{t}).side, Curves.ASYM.(tasks{t}).side];
    st = [Curves.PRE.(tasks{t}).ST; Curves.POST.(tasks{t}).ST; Curves.ASYM.(tasks{t}).ST];
    ex = st(:, 51) - st(:, 1);
    if sign(median(ex(strcmp(sdAll, 'R')), 'omitnan')) ~= sign(median(ex(strcmp(sdAll, 'L')), 'omitnan'))
        for g = 1:numel(grps)
            isL = strcmp(Curves.(grps{g}).(tasks{t}).side, 'L');
            Curves.(grps{g}).(tasks{t}).ST(isL, :) = -Curves.(grps{g}).(tasks{t}).ST(isL, :);
        end
    end
end

% -------------------------------------------------------------------------
% FIGURE
% -------------------------------------------------------------------------
fig = figure('Name', 'Courbes moyennes : rTSA PRE, rTSA POST et épaules saines', 'Color', 'w');
x = 0:100;
for t = 1:numel(tasks)
    for m = 1:numel(mets)
        ax = subplot(numel(tasks), numel(mets), (t - 1) * numel(mets) + m); hold(ax, 'on');
        h = gobjects(1, numel(grps));
        for g = 1:numel(grps)
            Y = Curves.(grps{g}).(tasks{t}).(mets{m});
            Y = Y(~all(isnan(Y), 2), :);
            mu = mean(Y, 1, 'omitnan'); s = std(Y, 0, 1, 'omitnan');
            fill(ax, [x fliplr(x)], [mu + s fliplr(mu - s)], cols(g, :), 'EdgeColor', 'none', ...
                'FaceAlpha', 0.15, 'HandleVisibility', 'off');
            h(g) = plot(ax, x, mu, '-', 'Color', cols(g, :), 'LineWidth', 2.2, ...
                'DisplayName', sprintf('%s (n=%d)', glbl{g}, size(Y, 1)));
        end
        if strcmp(mets{m}, 'TX'), yline(ax, 0, ':k', 'HandleVisibility', 'off'); end
        hold(ax, 'off'); box(ax, 'on'); grid(ax, 'on');
        title(ax, sprintf('%s, %s', mlbl{m}, tlbl{t}), 'FontSize', 10);
        xlabel(ax, '% du cycle'); ylabel(ax, 'angle (deg)');
        if t == 1 && m == 1, legend(ax, h, 'Location', 'south', 'FontSize', 8); end
    end
end
sgtitle(fig, 'Courbes moyennes ± 1 SD : rTSA PRE, rTSA POST et épaules saines controlatérales', 'FontSize', 13);
annotation(fig, 'textbox', [0 0 1 0.03], 'String', ['Élévations bilatérales : le thorax des épaules saines est celui ', ...
    'de la session du patient. HG, HT, GH en valeur absolue ; ST et thorax signés (thorax > 0 = extension).'], ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
for g = 1:numel(grps)
    fprintf('%s : %d courbes en flexion, %d en scaption\n', glbl{g}, ...
        size(Curves.(grps{g}).ANALYTIC1.HG, 1), size(Curves.(grps{g}).ANALYTIC2.HG, 1));
end

end

% =========================================================================
%  OUTILS
% =========================================================================
% Cycles [101 x nCycles] d'un DOF de Joint.Euler ; shared = joint unique
% (thorax) : repli sur l'autre côté si le champ demandé est vide
function c = cycles(t, ji, dof, cf, shared)
c = [];
if numel(t.Joint) < ji || ~isfield(t.Joint(ji), 'Euler') || ~isstruct(t.Joint(ji).Euler), return; end
E = t.Joint(ji).Euler;
if shared && (~isfield(E, cf) || isempty(E.(cf)))
    if strcmp(cf, 'rcycle'), cf = 'lcycle'; else, cf = 'rcycle'; end
end
if ~isfield(E, cf) || isempty(E.(cf)), return; end
c = squeeze(E.(cf)(1, dof, :, :));
if isvector(c), c = c(:); end
c = c(:, any(~isnan(c), 1));
end

% Courbe rééchantillonnée sur 101 points (0 à 100 % du cycle)
function r = resample101(v)
r = NaN(1, 101); v = v(:)';
if numel(v) == 101, r = v; return; end
if sum(~isnan(v)) < 2, return; end
r = interp1(linspace(0, 100, numel(v)), v, 0:100, 'linear');
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
