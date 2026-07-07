% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   May 2026
% -------------------------------------------------------------------------
% Description:   Plot absolute humerus orientation in the patient-referenced
%                gravitational frame (Moissenet et al. 2025).
%                Joint(12) = Right humerus / patient-ICS
%                Joint(13) = Left  humerus / patient-ICS
%
%                Layout : 1 row x 4 columns
%                  Column 1 = legend + affected side
%                  Column 2 = DOF1 X  : Elevation (deg)
%                  Column 3 = DOF2 Y1 : Elevation plane (deg)
%                  Column 4 = DOF3 Y2 : Axial rotation (deg)
%
%                Euler sequence YXY (Wu et al. 2005)
%                Blue = Right, Red = Left
%                Mean + SD (transparent patch)
%                One figure per ANALYTIC trial
% -------------------------------------------------------------------------
% Inputs  : Trial     (struct array)  all trials from MAIN_Protocol_01
%           Pathology (struct)        from ImportSessionData (affected side)
% Outputs : Figure per ANALYTIC trial
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotHumeroGravitaire(Trial, Pathology)

if nargin < 2, Pathology = struct(); end

% -------------------------------------------------------------------------
% PARAMETRES VISUELS
% -------------------------------------------------------------------------
COL_R      = [0.15 0.39 0.92];   % Blue right
COL_L      = [0.86 0.15 0.15];   % Red left
ALPHA_SD   = 0.15;
ALPHA_LINE = 0.85;
LW         = 2.0;
pct        = 0:1:100;

% -------------------------------------------------------------------------
% LABELS
% -------------------------------------------------------------------------
taskLabels = containers.Map(...
    {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4','ANALYTIC5'}, ...
    {'Sagittal elevation','Coronal elevation','External rotation', ...
     'Internal rotation','Scaption'});

dofLabels = {'Elevation', 'Elevation plane', 'Axial rotation'};

% -------------------------------------------------------------------------
% AFFECTED SIDE
% -------------------------------------------------------------------------
if isstruct(Pathology) && isfield(Pathology,'Diagnosis') && ...
   isfield(Pathology.Diagnosis,'side')
    affectedSide = Pathology.Diagnosis.side;
else
    affectedSide = '';
end

% -------------------------------------------------------------------------
% TRIAL LOOP
% -------------------------------------------------------------------------
for itrial = 1:length(Trial)
    t = Trial(itrial);
    if ~contains(t.task,'ANALYTIC'), continue; end
    if isempty(t.Joint),             continue; end
    if length(t.Joint) < 13,         continue; end
    if isempty(t.Joint(12).Euler.rcycle) && isempty(t.Joint(13).Euler.rcycle)
        continue;
    end

    if isKey(taskLabels, t.task)
        figTitle = [t.task, ' - ', taskLabels(t.task), '  |  Humero-Gravitaire'];
    else
        figTitle = [t.task, '  |  Humero-Gravitaire'];
    end

    fig = figure('Name', figTitle, 'Color', 'w', ...
                 'Units', 'normalized', 'OuterPosition', [0.02 0.02 0.96 0.40]);

    tl = tiledlayout(fig, 1, 4, ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    title(tl, figTitle, ...
        'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none', ...
        'Color', [0.15 0.15 0.15]);

    % ---- Legend tile (col 1) ----
    plotLegend(tl, 1, COL_R, COL_L, affectedSide);

    % ---- DOF1, DOF2, DOF3 ----
    for dof = 1:3
        ax = nexttile(tl, dof + 1);
        styleAx(ax);

        % Right — Joint(12)
        if ~isempty(t.Joint(12).Euler.rcycle)
            data = extractEuler(t.Joint(12).Euler.rcycle, dof);
            if ~isempty(data)
                plotMeanSD(ax, pct, data, COL_R, ALPHA_SD, ALPHA_LINE, LW);
            end
        end

        % Left — Joint(13)
        if ~isempty(t.Joint(13).Euler.lcycle)
            data = extractEuler(t.Joint(13).Euler.lcycle, dof);
            if ~isempty(data)
                plotMeanSD(ax, pct, data, COL_L, ALPHA_SD, ALPHA_LINE, LW);
            end
        end

        yline(ax, 0, '--', 'Color', [0.72 0.72 0.72], 'LineWidth', 0.8, 'Alpha', 0.7);
        ylabel(ax, dofLabels{dof}, 'FontSize', 8, 'Color', [0.45 0.45 0.45]);
        xlabel(ax, 'Cycle (%)',    'FontSize', 8, 'Color', [0.45 0.45 0.45]);
        xlim(ax, [0 100]);
        hold(ax, 'off');
    end
end
end

function plotLegend(tl, tileIdx, colR, colL, affectedSide)
ax = nexttile(tl, tileIdx);
axis(ax, 'off');
hold(ax, 'on');

plot(ax, NaN, NaN, '-', 'Color', colR, 'LineWidth', 2.0);
plot(ax, NaN, NaN, '-', 'Color', colL, 'LineWidth', 2.0);

lblR = 'Right shoulder';
lblL = 'Left shoulder';
if ~isempty(affectedSide)
    if strcmpi(affectedSide,'Right') || strcmpi(affectedSide,'Droit')
        lblR = 'Right shoulder  [affected]';
    elseif strcmpi(affectedSide,'Left') || strcmpi(affectedSide,'Gauche')
        lblL = 'Left shoulder  [affected]';
    elseif strcmpi(affectedSide,'Bilateral')
        lblR = 'Right shoulder  [affected]';
        lblL = 'Left shoulder  [affected]';
    end
end

lh = legend(ax, {lblR, lblL}, ...
    'Location', 'best', 'FontSize', 8, 'Box', 'off');
lh.ItemTokenSize = [15, 9];

text(ax, 0.5, 0.15, 'YXY sequence', ...
    'FontSize', 7, 'Color', [0.55 0.55 0.55], ...
    'HorizontalAlignment', 'center', 'Units', 'normalized');

hold(ax, 'off');
end

function styleAx(ax)
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'off');
ax.FontSize  = 8;
ax.GridColor = [0.82 0.82 0.82];
ax.GridAlpha = 0.7;
ax.TickDir   = 'out';
ax.XColor    = [0.50 0.50 0.50];
ax.YColor    = [0.50 0.50 0.50];
ax.LineWidth = 0.5;
end

function plotMeanSD(ax, x, data, gc, alphaSD, alphaLine, lw)
if isempty(data), return; end
if isvector(data), data = data(:); end
x  = x(:)';
mu = mean(data, 2, 'omitnan')';
sd = std(data,  0, 2, 'omitnan')';
fill(ax, [x, fliplr(x)], [mu+sd, fliplr(mu-sd)], gc, ...
    'FaceAlpha', alphaSD, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mu, '-', 'Color', [gc, alphaLine], 'LineWidth', lw);
end

function data = extractEuler(rcycle, dof)
data = [];
if isempty(rcycle), return; end
raw = squeeze(rcycle(1, dof, :, :));
if isvector(raw), raw = raw(:); end
data = double(raw);
end