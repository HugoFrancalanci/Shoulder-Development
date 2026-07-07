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
% Description:   Stacked bar chart showing the distribution of thoracic posture
%                types (Flat / Neutral / Curved) across four conditions
%                (PRE seated, PRE standing, POST seated, POST standing),
%                based on the Moroder classification.
%                n labels are displayed inside each bar segment.
%
% Inputs  : D   (struct)  data struct from PlotResults_Main
%           cfg (struct)  visual config from PR_Config
% Outputs : Figure
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Fig_PostureDistribution(D, cfg)

fig = figure('Name','Posture — Distribution posturale','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.55 0.65]);

type_labels = {'Plat','Neutre','Curve'};
type_colors = {[0.30 0.75 0.45],[0.25 0.55 0.85],[0.95 0.72 0.20]};
conditions  = {D.type_assis_pre, D.type_debout_pre, D.type_assis_post, D.type_debout_post};
cond_labels = {'PRE seated','PRE standing','POST seated','POST standing'};

counts = zeros(4,3);
for ic = 1:4
    counts(ic,1) = sum(strcmpi(conditions{ic},'Plat')) + sum(strcmpi(conditions{ic},'Flat'));
    counts(ic,2) = sum(strcmpi(conditions{ic},'Neutre'));
    counts(ic,3) = sum(strcmpi(conditions{ic},'Curve'));
end

ax = axes(fig);
hold(ax,'on'); box(ax,'off'); ax.FontSize = 10;

b = bar(ax, counts, 'stacked', 'BarWidth', 0.55);
for it = 1:3
    b(it).FaceColor = type_colors{it};
    b(it).EdgeColor = 'w';
    b(it).LineWidth = 0.8;
end

for ic = 1:4
    cs = 0;
    for it = 1:3
        if counts(ic,it) > 0
            text(ax, ic, cs+counts(ic,it)/2, sprintf('n=%d',counts(ic,it)),...
                'HorizontalAlignment','center','FontSize',9,'FontWeight','bold','Color','w');
        end
        cs = cs + counts(ic,it);
    end
end

legend(ax, type_labels, 'Location','northeast','FontSize',9,'Box','off');
ax.XTick = 1:4; ax.XTickLabel = cond_labels;
ax.YLim  = [0 D.n+1];
ylabel(ax,'Number of patients','FontSize',10);
title(ax,'Thoracic posture type distribution — PRE vs POST',...
    'FontSize',12,'FontWeight','bold','Color',[0.15 0.15 0.15]);
hold(ax,'off');
end
