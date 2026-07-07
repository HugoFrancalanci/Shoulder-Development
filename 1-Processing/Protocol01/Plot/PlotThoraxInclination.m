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
% Description:   Plot absolute thoracic inclination profile.
%                Two panels :
%
%                Left panel : Spinal silhouette (sagittal view)
%                  Real positions of markers CV7 and TV8
%                  projected onto the sagittal plane (X-Z Qualisys).
%                  Vector v_thorax (TV8->CV7) drawn with inclination arc
%                  relative to the gravitational vertical [0;0;1].
%
%                Right panel : Postural classification gauge
%                  Colour-coded vertical gauge with inclination zones
%                  and marker positioned at the patient value.
%
% Inputs  : Trial      (struct)  with Joint(11).PostureSummary populated
%                                and Trial.Marker for marker positions
%           taskName   (char)    e.g. 'ANALYTIC1'
%           outputDir  (char)    PNG output folder ('' = no save)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotThoraxInclination(Trial, taskName)

if nargin < 3, outputDir = ''; end

if isempty(Trial.Joint) || length(Trial.Joint) < 11 || ...
   ~isfield(Trial.Joint(11),'PostureSummary') || ...
   ~isfield(Trial.Joint(11).PostureSummary,'thoracic_curvature_angle')
    return;
end

ps   = Trial.Joint(11).PostureSummary;
nRef = min(100, Trial.n1);

% Get marker positions
CV7 = getPos(Trial.Marker, 'CV7', nRef);
TV8 = getPos(Trial.Marker, 'TV8', nRef);

% -------------------------------------------------------------------------
% FIGURE
% -------------------------------------------------------------------------
fig = figure('Color','w','Units','centimeters', ...
             'Position',[2 2 28 18],'Name','Thorax Inclination Profile');

tl = tiledlayout(fig, 1, 2, 'TileSpacing','loose','Padding','compact');
title(tl, sprintf('Thoracic inclination — %s', taskName), ...
    'FontSize', 13, 'FontWeight','bold', 'Interpreter','none');

% =========================================================================
% LEFT PANEL — Sagittal silhouette + inclination vector
% =========================================================================
ax1 = nexttile(tl, 1);
hold(ax1, 'on');
ax1.Color = [0.97 0.98 1.0];
grid(ax1, 'on'); ax1.GridAlpha = 0.2;
ax1.Box = 'off'; ax1.FontSize = 9;
axis(ax1, 'equal');

c_spine   = [0.25 0.25 0.25];
c_vthorax = [0.18 0.42 0.78];   % blue — thoracic vector
c_vgrav   = [0.20 0.65 0.35];   % green — gravitational vertical
c_angle   = [0.85 0.18 0.18];   % red — angle arc
c_marker  = [0.92 0.46 0.13];   % orange — markers

% Sagittal projection (X=col1, Z=col3)
cv7x = CV7(1); cv7z = CV7(3);
tv8x = TV8(1); tv8z = TV8(3);

% Spinal line (just TV8 and CV7)
plot(ax1, [tv8x cv7x], [tv8z cv7z], '-', ...
    'Color',[c_spine, 0.4], 'LineWidth', 1.5);

% Marker points
scatter(ax1, [tv8x cv7x], [tv8z cv7z], 80, c_marker, 'filled', ...
    'MarkerEdgeColor','w', 'LineWidth',1.5);
text(ax1, cv7x+0.008, cv7z, 'CV7', 'FontSize',9,'FontWeight','bold', ...
    'Color',c_spine,'VerticalAlignment','middle');
text(ax1, tv8x+0.008, tv8z, 'TV8', 'FontSize',9,'FontWeight','bold', ...
    'Color',c_spine,'VerticalAlignment','middle');

% v_thorax vector : TV8 -> CV7
scale = 0.8;
quiver(ax1, tv8x, tv8z, (cv7x-tv8x)*scale, (cv7z-tv8z)*scale, 0, ...
    'Color',c_vthorax,'LineWidth',2.5,'MaxHeadSize',0.4);
text(ax1, tv8x+(cv7x-tv8x)*0.45-0.018, tv8z+(cv7z-tv8z)*0.45, ...
    'v_{thorax}','FontSize',8,'Color',c_vthorax,'HorizontalAlignment','right');

% Gravitational vertical reference (from TV8 upward, same length as v_thorax)
v_len = sqrt((cv7x-tv8x)^2 + (cv7z-tv8z)^2) * scale;
quiver(ax1, tv8x, tv8z, 0, v_len, 0, ...
    'Color',c_vgrav,'LineWidth',2,'MaxHeadSize',0.4,'LineStyle','--');
text(ax1, tv8x-0.015, tv8z+v_len*0.5, 'vertical', ...
    'FontSize',8,'Color',c_vgrav,'HorizontalAlignment','right');

% Inclination angle arc (between v_thorax and vertical)
r_arc  = v_len * 0.35;
ang_v  = pi/2;                                    % vertical = 90 deg from X
ang_th = atan2(cv7z-tv8z, cv7x-tv8x);            % thorax vector angle
angs   = linspace(ang_v, ang_th, 60);
plot(ax1, tv8x + r_arc*cos(angs), tv8z + r_arc*sin(angs), ...
    '-', 'Color',c_angle, 'LineWidth',2);

% Angle label
mid_ang = (ang_v + ang_th) / 2;
text(ax1, tv8x + (r_arc+0.015)*cos(mid_ang), tv8z + (r_arc+0.015)*sin(mid_ang), ...
    sprintf('%.1f°', ps.thoracic_curvature_angle), ...
    'FontSize',10,'FontWeight','bold','Color',c_angle, ...
    'HorizontalAlignment','center');

xlabel(ax1, 'X — Anterior (m)', 'FontSize', 9);
ylabel(ax1, 'Z — Superior (m)', 'FontSize', 9);
title(ax1, 'Spinal markers — Sagittal plane', 'FontSize',10,'FontWeight','bold');

legend(ax1, {'Spinal segment','v_{thorax} (TV8→CV7)','Gravitational vertical'}, ...
    'Location','southeast','FontSize',8,'Box','off');

hold(ax1, 'off');

% =========================================================================
% RIGHT PANEL — Classification gauge
% =========================================================================
ax2 = nexttile(tl, 2);
hold(ax2, 'on');
ax2.Color = [0.98 0.98 0.98];
ax2.Box = 'off'; ax2.FontSize = 9;
ax2.XTick = []; ax2.YTick = [];
xlim(ax2, [0 3]); ylim(ax2, [0 55]);

% Zones — to be refined against literature
zones  = [0 10; 10 25; 25 40; 40 55];
colors = {[0.30 0.75 0.45], ...
          [0.25 0.55 0.85], ...
          [0.95 0.72 0.20], ...
          [0.88 0.22 0.22]};
zlabels = {'Upright','Normal','Moderate kyphosis','Pronounced kyphosis'};
zranges = {'<10°','10-25°','25-40°','>40°'};

for iz = 1:4
    y0 = zones(iz,1); y1 = zones(iz,2);
    patch(ax2, [0.3 1.2 1.2 0.3], [y0 y0 y1 y1], colors{iz}, ...
        'FaceAlpha',0.75,'EdgeColor','w','LineWidth',0.5);
    ymid = (y0+y1)/2;
    text(ax2, 1.35, ymid,     zlabels{iz}, 'FontSize',8,'FontWeight','bold', ...
        'Color',colors{iz}*0.6,'VerticalAlignment','middle');
    text(ax2, 1.35, ymid-2.5, zranges{iz}, 'FontSize',7.5, ...
        'Color',[0.5 0.5 0.5],'VerticalAlignment','middle');
end

% Patient marker
incl = min(ps.thoracic_curvature_angle, 54);
scatter(ax2, 0.75, incl, 200, [0.1 0.1 0.1], 'filled', ...
    'MarkerEdgeColor','w','LineWidth',2);
plot(ax2, [0.3 1.2], [incl incl], '--', 'Color',[0.1 0.1 0.1], ...
    'LineWidth',1.2);
text(ax2, 0.05, incl, sprintf('%.1f°', ps.thoracic_curvature_angle), ...
    'FontSize',11,'FontWeight','bold','Color',[0.1 0.1 0.1], ...
    'VerticalAlignment','middle','HorizontalAlignment','left');

% Y axis
ax2.YTick      = [0 10 25 40 55];
ax2.YTickLabel = {'0°','10°','25°','40°','55°'};
ax2.YAxis.Visible = 'on';
ylabel(ax2, 'Thoracic inclination from vertical (°)', 'FontSize',9);
title(ax2, 'Postural classification', 'FontSize',10,'FontWeight','bold');

% Classification text + note
text(ax2, 1.7, 48, ps.thorax_posture_type, 'FontSize',8,'FontWeight','bold', ...
    'Color',[0.2 0.2 0.2],'Interpreter','none');
text(ax2, 1.7, 42, 'Thresholds provisional', 'FontSize',7, ...
    'Color',[0.6 0.6 0.6],'Interpreter','none','FontAngle','italic');
text(ax2, 1.7, 36, '— to be refined', 'FontSize',7, ...
    'Color',[0.6 0.6 0.6],'Interpreter','none','FontAngle','italic');

hold(ax2, 'off');

end

% =========================================================================
%  GET MARKER MEAN POSITION OVER nRef FRAMES
% =========================================================================
function pos = getPos(MarkerArray, label, nRef)
pos = zeros(3,1);
for i = 1:length(MarkerArray)
    if strcmp(MarkerArray(i).label, label)
        traj = MarkerArray(i).Trajectory.full;
        pos  = mean(traj(:,1,1:min(nRef,size(traj,3))), 3);
        return;
    end
end
end