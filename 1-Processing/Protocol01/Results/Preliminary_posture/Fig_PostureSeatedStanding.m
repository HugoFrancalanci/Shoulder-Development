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
% Description:   Paired dotplot comparing Posture angle in seated vs standing position,
%                displayed separately for PRE (left panel) and POST (right
%                panel). Moroder thresholds (20 deg and 40 deg) are shown
%                as reference lines. Stars indicate paired t-test significance.
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

function Fig_PostureSeatedStanding(D, cfg)

fig = figure('Name','Posture — Assis vs Debout','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.55 0.70]);

tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Posture angle — Seated vs Standing',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Red = PRE   Blue = POST   Line = individual patient',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

datasets = {{D.Posture_assis_pre,  D.Posture_debout_pre,  cfg.COL_PRE,  'PRE'}, ...
            {D.Posture_assis_post, D.Posture_debout_post, cfg.COL_POST, 'POST'}};

for ip = 1:2
    ax = nexttile(tl,ip);
    hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    ax.GridAlpha = 0.2; ax.FontSize = 9;

    assis_v  = datasets{ip}{1};
    debout_v = datasets{ip}{2};
    col      = datasets{ip}{3};
    lbl      = datasets{ip}{4};

    for i = 1:D.n
        plot(ax,[1 2],[assis_v(i) debout_v(i)],'-','Color',[col,0.35],'LineWidth',0.9,'HandleVisibility','off');
    end
    scatter(ax,ones(D.n,1),  assis_v, 55,col,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
    scatter(ax,2*ones(D.n,1),debout_v,55,col,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');

    for ix = 1:2
        v={assis_v,debout_v}; mu=mean(v{ix},'omitnan'); sd=std(v{ix},'omitnan');
        errorbar(ax,ix,mu,sd,'o','Color',col,'MarkerFaceColor',col,...
            'MarkerSize',9,'LineWidth',2.2,'CapSize',8,'HandleVisibility','off');
    end

    yline(ax,20,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'Alpha',0.5,...
        'Label','Flat/Neutre','LabelHorizontalAlignment','left','FontSize',7);
    yline(ax,40,'--','Color',[0.5 0.5 0.5],'LineWidth',0.8,'Alpha',0.5,...
        'Label','Neutre/Curve','LabelHorizontalAlignment','left','FontSize',7);

    [~,p] = ttest(assis_v,debout_v);
    stars  = pToStars(p);
    ymax   = max([assis_v;debout_v])*1.07;
    plot(ax,[1 2],[ymax ymax]*0.98,'-k','LineWidth',0.8,'HandleVisibility','off');
    text(ax,1.5,ymax,stars,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);

    ax.XTick=[1 2]; ax.XTickLabel={'Seated','Standing'}; ax.XLim=[0.5 2.5];
    ylabel(ax,'Posture angle (deg)','FontSize',9);
    title(ax,['Posture — ',lbl],'FontSize',10,'FontWeight','bold');
    hold(ax,'off');
end
end

function s = pToStars(p)
if p<0.001,s='*'; elseif p<0.01,s='*'; elseif p<0.05,s='*'; else,s='ns'; end
end
