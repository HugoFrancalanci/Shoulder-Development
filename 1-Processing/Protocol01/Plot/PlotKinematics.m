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
% Description:   Plot joint angles HT, GH and ST for ANALYTIC1 and ANALYTIC2
%                trials. Layout adapts to the selected DOFs (see USER SELECTION
%                section). Subplots fill the entire figure with no margins.
%
%                Layout :
%                  Rows    = HT | GH | ST
%                  Columns = selected DOFs + elevation plane (HT only)
%                  Blue    = Right shoulder
%                  Red     = Left shoulder
%                  Mean + SD (transparent patch)
%                  Joint name displayed in title of first panel per row
%                  Curve side labels localised at end of each mean curve
%                  One figure per ANALYTIC trial
%
%                DOF selection :
%                  Set sel.(task).(joint).dof = [true/false true/false true/false]
%                  to show/hide DOF1, DOF2, DOF3 respectively.
%                  Set sel.(task).(joint).elevPlane = true/false (HT only).
% -------------------------------------------------------------------------
% Inputs  : Trial     (struct array)  all trials from MAIN_Protocol_01
%           Pathology (struct, opt)   with Diagnosis.side field
% Outputs : Figure per ANALYTIC1 / ANALYTIC2 trial
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotKinematics(Trial, Pathology)

% =========================================================================
% USER SELECTION — edit here
% =========================================================================

% ANALYTIC1 : sagittal elevation — DOF principal = flexion/extension (pos3)
sel.ANALYTIC1.HT.dof       = [false false true];
sel.ANALYTIC1.HT.elevPlane = true;
sel.ANALYTIC1.GH.dof       = [false false true];
sel.ANALYTIC1.GH.elevPlane = false;
sel.ANALYTIC1.ST.dof       = [true true true];
sel.ANALYTIC1.ST.elevPlane = false;

% ANALYTIC2 : coronal elevation — DOF principal = elevation (pos1)
sel.ANALYTIC2.HT.dof       = [true false false];
sel.ANALYTIC2.HT.elevPlane = true;
sel.ANALYTIC2.GH.dof       = [true false false];
sel.ANALYTIC2.GH.elevPlane = false;
sel.ANALYTIC2.ST.dof       = [true true true];
sel.ANALYTIC2.ST.elevPlane = false;

% =========================================================================
% VISUAL PARAMETERS
% =========================================================================
COL_R      = [0.15 0.39 0.92];
COL_L      = [0.86 0.20 0.20];
ALPHA_SD   = 0.13;
ALPHA_LINE = 0.90;
LW_MEAN    = 2.0;
pct        = 0:1:100;

% =========================================================================
% DOF LABELS — {DOF1, DOF2, DOF3, ElevPlane}
% =========================================================================
L = struct();

L.ANALYTIC1.HT = {'Flexion/Extension [+=ext]', ...
                   'Axial rotation  [+=int]', ...
                   'Elevation  [-=elev]', ...
                   'Elevation plane'};
L.ANALYTIC1.GH = L.ANALYTIC1.HT;
L.ANALYTIC1.ST = {'Lat./Med. rotation [+=med]', ...
                   'Protraction/Retraction [+=pro]', ...
                   'Ant./Post. tilt  [+=post]', ''};

L.ANALYTIC2.HT = {'Elevation (deg)  [-=elev]', ...
                   'Axial rotation (deg)  [+=int]', ...
                   'Flexion/Extension (deg)  [+=ext]', ...
                   'Elevation plane (deg)'};
L.ANALYTIC2.GH = L.ANALYTIC2.HT;
L.ANALYTIC2.ST = L.ANALYTIC1.ST;

% =========================================================================
% JOINT MAP  [right left]
% =========================================================================
jMap.HT = [1 6];
jMap.GH = [2 7];
jMap.ST = [3 8];
rows    = {'HT','GH','ST'};

% =========================================================================
% MAIN LOOP
% =========================================================================
for itrial = 1:length(Trial)
    t = Trial(itrial);
    if ~contains(t.task,'ANALYTIC1') && ~contains(t.task,'ANALYTIC2'), continue; end
    if isempty(t.Joint), continue; end

    if contains(t.task,'ANALYTIC1'), tKey = 'ANALYTIC1'; tStr = 'Sagittal elevation';
    else,                            tKey = 'ANALYTIC2'; tStr = 'Coronal elevation';
    end
    figTitle = [t.task '  -  ' tStr];

    affectedSide = '';
    if nargin >= 2 && isstruct(Pathology) && isfield(Pathology,'Diagnosis') && ...
       isfield(Pathology.Diagnosis,'side')
        affectedSide = Pathology.Diagnosis.side;
    end

    % Count max columns across rows
    nCols = 0;
    for ir = 1:numel(rows)
        jn = rows{ir};
        nc = sum(sel.(tKey).(jn).dof) + double(sel.(tKey).(jn).elevPlane);
        if nc > nCols, nCols = nc; end
    end
    nRows = numel(rows);

    % Figure
    fig = figure('Name', figTitle, 'Color','w', ...
                 'Units','normalized', 'OuterPosition',[0.02 0.04 0.96 0.94]);
    tl = tiledlayout(fig, nRows, nCols, ...
        'TileSpacing','compact', 'Padding','compact');
    title(tl, figTitle, 'FontSize',12, 'FontWeight','bold', ...
          'Interpreter','none', 'Color',[0.15 0.15 0.15]);

    for ir = 1:nRows
        jn   = rows{ir};
        jR   = jMap.(jn)(1);
        jL   = jMap.(jn)(2);
        meta = L.(tKey).(jn);
        s    = sel.(tKey).(jn);

        % Build panel list
        dofList = find(s.dof);
        lblList = meta(dofList);
        isElev  = false(1, numel(dofList));
        if s.elevPlane && ~isempty(meta{4})
            dofList = [dofList, 0];
            lblList = [lblList, meta(4)];
            isElev  = [isElev, true];
        end
        nPanels = numel(dofList);

        for ip = 1:nPanels
            tileIdx = (ir-1)*nCols + ip;
            ax = nexttile(tl, tileIdx);
            styleAx(ax);

            dataR = getData(t, jR, dofList(ip), isElev(ip), 'rcycle');
            dataL = getData(t, jL, dofList(ip), isElev(ip), 'lcycle');

            plotMeanSD(ax, pct, dataR, COL_R, ALPHA_SD, ALPHA_LINE, LW_MEAN);
            plotMeanSD(ax, pct, dataL, COL_L, ALPHA_SD, ALPHA_LINE, LW_MEAN);

            yline(ax, 0, '--', 'Color',[0.75 0.75 0.75], 'LineWidth',0.7, 'Alpha',0.8);

            addLabel(ax, pct, dataR, COL_R, 'Right', affectedSide, 'Right');
            addLabel(ax, pct, dataL, COL_L, 'Left',  affectedSide, 'Left');

            if ip == 1
                title(ax, [jn '  -  ' lblList{ip}], 'FontSize',8, ...
                      'FontWeight','bold', 'Color',[0.20 0.20 0.20], ...
                      'Interpreter','none');
            else
                title(ax, lblList{ip}, 'FontSize',8, ...
                      'Color',[0.40 0.40 0.40], 'Interpreter','none');
            end

            ylabel(ax, 'Angle (deg)', 'FontSize',7.5, 'Color',[0.40 0.40 0.40]);
            if ir == nRows
                xlabel(ax, 'Cycle (%)', 'FontSize',7.5, 'Color',[0.50 0.50 0.50]);
            end
            xlim(ax, [0 100]);
            hold(ax,'off');
        end

        % Blank remaining tiles
        for ic = nPanels+1:nCols
            axB = nexttile(tl, (ir-1)*nCols + ic);
            axis(axB,'off');
        end
    end
end
end

% =========================================================================
function data = getData(t, ji, dofIdx, isElevPlane, cycField)
data = [];
if ji < 1 || ji > length(t.Joint), return; end
jt = t.Joint(ji);
if ~isstruct(jt), return; end

if isElevPlane
    if ~isfield(jt,'ElevationPlane'), return; end
    ep = jt.ElevationPlane;
    if ~isfield(ep, cycField) || isempty(ep.(cycField)), return; end
    raw = squeeze(ep.(cycField));
    if isvector(raw), raw = raw(:); end
    data = double(raw);
else
    if ~isfield(jt,'Euler'), return; end
    eu = jt.Euler;
    if ~isfield(eu, cycField) || isempty(eu.(cycField)), return; end
    raw = squeeze(eu.(cycField)(1, dofIdx, :, :));
    if isvector(raw), raw = raw(:); end
    data = double(raw);
end
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