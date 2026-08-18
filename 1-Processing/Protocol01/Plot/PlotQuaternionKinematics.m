% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Plot the quaternion total rotation angle (QuatAngle, see
%                Core/ComputeQuaternionKinematics.m) for HG, GH, ST and TX,
%                for ANALYTIC1-4 trials. Mirrors PlotKinematics.m's visual
%                style (mean +/- SD ribbon, blue=Right, red=Left, one
%                figure per trial), but needs no per-task DOF selection --
%                QuatAngle is the same sequence-free quantity regardless
%                of movement plane, so unlike PlotKinematics.m (ANALYTIC1/
%                2 only, each with its own hand-picked DOF), this covers
%                ANALYTIC1-4 with the same single panel per joint.
%
%                Layout :
%                  Rows    = HG | GH | ST | TX
%                  Column  = QuatAngle (deg, bounded [0,180])
%                  Blue    = Right shoulder, Red = Left shoulder
%                  TX has no side split (single, non-lateralised joint)
%                  One figure per ANALYTIC trial
% -------------------------------------------------------------------------
% Inputs  : Trial     (struct array)  all trials from MAIN_Protocol_01
%           Pathology (struct, opt)   with Diagnosis.side field
% Outputs : Figure per ANALYTIC1-4 trial
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotQuaternionKinematics(Trial, Pathology)

% =========================================================================
% VISUAL PARAMETERS
% =========================================================================
COL_R      = [0.15 0.39 0.92];
COL_L      = [0.86 0.20 0.20];
COL_TX     = [0.40 0.40 0.40];
ALPHA_SD   = 0.13;
ALPHA_LINE = 0.90;
LW_MEAN    = 2.0;
pct        = 0:1:100;

% =========================================================================
% TASK LABELS
% =========================================================================
taskKeys = {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4'};
taskStr  = {'Sagittal elevation','Coronal elevation','External rotation','Internal rotation'};

% =========================================================================
% JOINT MAP  [right left] -- TX has no side split (Joint 11 only)
% =========================================================================
jMap.HG = [12 13];
jMap.GH = [2 7];
jMap.ST = [3 8];
rows    = {'HG','GH','ST','TX'};

% =========================================================================
% MAIN LOOP
% =========================================================================
for itrial = 1:length(Trial)
    t = Trial(itrial);
    if isempty(t.Joint), continue; end

    tKey = '';
    for k = 1:numel(taskKeys)
        if contains(t.task, taskKeys{k})
            tKey = taskKeys{k};
            tStr = taskStr{k};
            break;
        end
    end
    if isempty(tKey), continue; end

    figTitle = [t.task '  -  ' tStr '  (quaternion)'];

    affectedSide = '';
    if nargin >= 2 && isstruct(Pathology) && isfield(Pathology,'Diagnosis') && ...
       isfield(Pathology.Diagnosis,'side')
        affectedSide = Pathology.Diagnosis.side;
    end

    nRows = numel(rows);
    fig = figure('Name', figTitle, 'Color','w', ...
                 'Units','normalized', 'OuterPosition',[0.02 0.04 0.42 0.94]);
    tl = tiledlayout(fig, nRows, 1, ...
        'TileSpacing','compact', 'Padding','compact');
    title(tl, figTitle, 'FontSize',12, 'FontWeight','bold', ...
          'Interpreter','none', 'Color',[0.15 0.15 0.15]);

    for ir = 1:nRows
        jn = rows{ir};
        ax = nexttile(tl, ir);
        styleAx(ax);

        if strcmp(jn,'TX')
            dataC = getQuatAngleData(t, 11, 'rcycle');
            if isempty(dataC)
                dataC = getQuatAngleData(t, 11, 'lcycle');
            end
            plotMeanSD(ax, pct, dataC, COL_TX, ALPHA_SD, ALPHA_LINE, LW_MEAN);
        else
            jR = jMap.(jn)(1);
            jL = jMap.(jn)(2);
            dataR = getQuatAngleData(t, jR, 'rcycle');
            dataL = getQuatAngleData(t, jL, 'lcycle');
            plotMeanSD(ax, pct, dataR, COL_R, ALPHA_SD, ALPHA_LINE, LW_MEAN);
            plotMeanSD(ax, pct, dataL, COL_L, ALPHA_SD, ALPHA_LINE, LW_MEAN);
            addLabel(ax, pct, dataR, COL_R, 'Right', affectedSide, 'Right');
            addLabel(ax, pct, dataL, COL_L, 'Left',  affectedSide, 'Left');
        end

        title(ax, [jn '  -  Angle de rotation total (quaternion)'], ...
              'FontSize',9, 'FontWeight','bold', 'Color',[0.20 0.20 0.20], ...
              'Interpreter','none');
        ylabel(ax, 'Angle (deg)', 'FontSize',7.5, 'Color',[0.40 0.40 0.40]);
        if ir == nRows
            xlabel(ax, 'Cycle (%)', 'FontSize',7.5, 'Color',[0.50 0.50 0.50]);
        end
        xlim(ax, [0 100]);
        ylim(ax, [0 180]);
        hold(ax,'off');
    end
end
end

% =========================================================================
function data = getQuatAngleData(t, ji, cycField)
data = [];
if ji < 1 || ji > length(t.Joint), return; end
jt = t.Joint(ji);
if ~isstruct(jt) || ~isfield(jt,'QuatAngle'), return; end
qa = jt.QuatAngle;
if ~isfield(qa, cycField) || isempty(qa.(cycField)), return; end
raw = squeeze(qa.(cycField));
if isvector(raw), raw = raw(:); end
data = double(raw);
end

% =========================================================================
function plotMeanSD(ax, x, data, gc, alphaSD, alphaLine, lw)
if isempty(data), return; end
data = double(data);
x    = x(:)';
n    = numel(x);
if size(data,1) ~= n
    if size(data,2) == n, data = data'; else, return; end
end
mu = mean(data, 2, 'omitnan')';
sd = std( data, 0, 2, 'omitnan')';
fill(ax, [x fliplr(x)], [mu+sd fliplr(mu-sd)], gc, ...
    'FaceAlpha', alphaSD, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax, x, mu, '-', 'Color',[gc alphaLine], 'LineWidth', lw);
end

% =========================================================================
function addLabel(ax, x, data, col, sideName, affectedSide, sideKey)
if isempty(data), return; end
data = double(data);
x    = x(:)';
n    = numel(x);
if size(data,1) ~= n
    if size(data,2) == n, data = data'; else, return; end
end
mu  = mean(data, 2, 'omitnan')';
lbl = sideName;
if (strcmpi(affectedSide,sideKey)) || ...
   (strcmpi(affectedSide,'Droit')  && strcmpi(sideKey,'Right')) || ...
   (strcmpi(affectedSide,'Gauche') && strcmpi(sideKey,'Left'))
    lbl = [sideName ' *'];
end
text(ax, x(end)+1, mu(end), lbl, 'Color',col, 'FontSize',7, ...
     'FontWeight','bold', 'VerticalAlignment','middle', 'Clipping','off');
end

% =========================================================================
function styleAx(ax)
hold(ax,'on'); grid(ax,'on'); box(ax,'off');
ax.Color      = 'w';
ax.FontSize   = 8;
ax.GridColor  = [0.88 0.88 0.88];
ax.GridAlpha  = 1.0;
ax.TickDir    = 'out';
ax.XColor     = [0.55 0.55 0.55];
ax.YColor     = [0.55 0.55 0.55];
ax.LineWidth  = 0.5;
ax.TickLength = [0.012 0.012];
end
