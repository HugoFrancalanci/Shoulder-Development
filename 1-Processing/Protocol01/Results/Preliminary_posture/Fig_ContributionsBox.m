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
% Description:   Boxplot with individual data points showing HG range and segmental
%                contributions (GH%, ST%, TX%) PRE vs POST. Grey lines connect
%                each patient PRE to POST. Stars indicate paired t-test significance.
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

function Fig_ContributionsBox(D, cfg)

fig = figure('Name','Contributions PRE vs POST','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.90 0.75]);

tl = tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
title(tl,'Kinematic contributions ANALYTIC2 — PRE vs POST',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Boxplot + individual patients   |   Red = PRE   Blue = POST',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

vars_pre  = {D.hg_pre,  D.gh_pre,  D.st_pre,  D.tx_pre};
vars_post = {D.hg_post, D.gh_post, D.st_post, D.tx_post};
ylabels   = {'HG range (deg)','%GH','%ST','%TX'};
subtitls  = {'Humero-gravitaire','Gleno-humeral','Scapulo-thoracic','Thorax/ICS'};

for iv=1:4
    ax=nexttile(tl,iv);
    hold(ax,'on'); grid(ax,'on'); box(ax,'off');
    ax.GridAlpha=0.2; ax.FontSize=9;

    pre_v=vars_pre{iv}; post_v=vars_post{iv};

    for i=1:D.n
        plot(ax,[1 2],[pre_v(i) post_v(i)],'-','Color',[0.65 0.65 0.65 0.45],'LineWidth',0.9,'HandleVisibility','off');
    end

    drawBoxplot(ax,1,pre_v, cfg.COL_PRE);
    drawBoxplot(ax,2,post_v,cfg.COL_POST);

    jit=0.08;
    scatter(ax,1+jit*(rand(D.n,1)-0.5),pre_v, 40,cfg.COL_PRE, 'filled','MarkerFaceAlpha',0.5,'MarkerEdgeColor','w','HandleVisibility','off');
    scatter(ax,2+jit*(rand(D.n,1)-0.5),post_v,40,cfg.COL_POST,'filled','MarkerFaceAlpha',0.5,'MarkerEdgeColor','w','HandleVisibility','off');

    [~,p]=ttest(pre_v,post_v); stars=pToStars(p);
    ymax=max([pre_v;post_v])*1.10;
    plot(ax,[1 2],[ymax ymax]*0.97,'-k','LineWidth',0.8,'HandleVisibility','off');
    text(ax,1.5,ymax,stars,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);

    ylabel(ax,ylabels{iv},'FontSize',9);
    title(ax,subtitls{iv},'FontSize',9,'FontWeight','bold');
    ax.XTick=[1 2]; ax.XTickLabel={'PRE','POST'}; ax.XLim=[0.5 2.5];
    hold(ax,'off');
end
end

function drawBoxplot(ax,x,v,col)
w=0.18; q1=quantile(v,0.25); q3=quantile(v,0.75); med=median(v);
iqr_v=q3-q1; lo=max(min(v),q1-1.5*iqr_v); hi=min(max(v),q3+1.5*iqr_v);
patch(ax,[x-w x+w x+w x-w],[q1 q1 q3 q3],col,'FaceAlpha',0.25,'EdgeColor',col,'LineWidth',1.8,'HandleVisibility','off');
plot(ax,[x-w x+w],[med med],'-','Color',col,'LineWidth',2.5,'HandleVisibility','off');
plot(ax,[x x],[lo q1],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x x],[q3 hi],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x-w/2 x+w/2],[lo lo],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x-w/2 x+w/2],[hi hi],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
end

function s=pToStars(p)
if p<0.001,s='*'; elseif p<0.01,s='*'; elseif p<0.05,s='*'; else,s='ns'; end
end
