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
% Description:   Two-row figure analysing thoracic compensation (layout 2x3).
%                Row 1: scatter plots (TX% vs HG range, TX% vs GH%, TX% vs ST%)
%                       with linear regression for PRE and POST groups.
%                Row 2: paired boxplots for TX% and HG range PRE vs POST,
%                       and a legend tile.
%                Arrows connect each patient PRE to POST. Pearson correlations
%                reported in the console (PR_Console.m).
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

function Fig_ThoraxCompensation(D, cfg)

[~,p_tx]  = ttest(D.tx_pre, D.tx_post);
[~,p_hg]  = ttest(D.hg_pre, D.hg_post);

fig = figure('Name','Thorax compensation PRE vs POST','Color','w',...
    'Units','normalized','OuterPosition',[0.03 0.03 0.96 0.92]);

tl = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
title(tl,'Thoracic compensation — ANALYTIC2  |  PRE vs POST',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Red = PRE   Blue = POST   Dashed = linear fit   |   See console for r, p-values',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

% Row 1 — Scatters
ax1 = nexttile(tl,1);
plotScatterReg(ax1, D.hg_pre, D.tx_pre, D.hg_post, D.tx_post, D.n, cfg.COL_PRE, cfg.COL_POST,...
    'HG elevation range (deg)', 'Thorax contribution (%TX)', 'TX% vs HG range');

ax2 = nexttile(tl,2);
plotScatterReg(ax2, D.gh_pre, D.tx_pre, D.gh_post, D.tx_post, D.n, cfg.COL_PRE, cfg.COL_POST,...
    'GH contribution (%GH)', 'Thorax contribution (%TX)', 'TX% vs GH%');

ax3 = nexttile(tl,3);
plotScatterReg(ax3, D.st_pre, D.tx_pre, D.st_post, D.tx_post, D.n, cfg.COL_PRE, cfg.COL_POST,...
    'ST contribution (%ST)', 'Thorax contribution (%TX)', 'TX% vs ST%');

% Row 2 — Paired boxplots
ax4 = nexttile(tl,4);
plotPairedBox(ax4, D.tx_pre, D.tx_post, D.n, cfg.COL_PRE, cfg.COL_POST,...
    'Thorax contribution (%TX)', 'TX% PRE vs POST', p_tx);

ax5 = nexttile(tl,5);
plotPairedBox(ax5, D.hg_pre, D.hg_post, D.n, cfg.COL_PRE, cfg.COL_POST,...
    'HG elevation range (deg)', 'HG range PRE vs POST', p_hg);

% Légende
ax6 = nexttile(tl,6);
axis(ax6,'off'); hold(ax6,'on');
plot(ax6,NaN,NaN,'o','MarkerFaceColor',cfg.COL_PRE, 'MarkerEdgeColor','w','MarkerSize',10,'DisplayName','PRE');
plot(ax6,NaN,NaN,'o','MarkerFaceColor',cfg.COL_POST,'MarkerEdgeColor','w','MarkerSize',10,'DisplayName','POST');
plot(ax6,NaN,NaN,'--','Color',[cfg.COL_PRE, 0.8],'LineWidth',1.8,'DisplayName','Linear fit PRE');
plot(ax6,NaN,NaN,'--','Color',[cfg.COL_POST,0.8],'LineWidth',1.8,'DisplayName','Linear fit POST');
legend(ax6,'Location','west','FontSize',9,'Box','off');
% text(ax6,0.05,0.25,{'See console for','r and p-values'},...
%     'Units','normalized','FontSize',8,'Color',[0.5 0.5 0.5],'FontStyle','italic');
hold(ax6,'off');
end

function plotScatterReg(ax,xpre,ypre,xpost,ypost,n,cPre,cPost,xlbl,ylbl,ttl)
hold(ax,'on'); grid(ax,'on'); box(ax,'off');
ax.GridAlpha=0.18; ax.FontSize=9;
for i=1:n
    dp=[xpost(i)-xpre(i), ypost(i)-ypre(i)];
    if norm(dp)>0.5
        quiver(ax,xpre(i),ypre(i),dp(1),dp(2),0,'Color',[0.65 0.65 0.65 0.45],...
            'LineWidth',0.6,'MaxHeadSize',0.35,'HandleVisibility','off');
    end
end
scatter(ax,xpre, ypre, 60,cPre, 'filled','MarkerFaceAlpha',0.75,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,xpost,ypost,60,cPost,'filled','MarkerFaceAlpha',0.75,'MarkerEdgeColor','w','HandleVisibility','off');
xall=[xpre;xpost]; xfit=linspace(min(xall)-3,max(xall)+3,100);
plot(ax,xfit,polyval(polyfit(xpre, ypre, 1),xfit),'--','Color',[cPre, 0.85],'LineWidth',1.8,'HandleVisibility','off');
plot(ax,xfit,polyval(polyfit(xpost,ypost,1),xfit),'--','Color',[cPost,0.85],'LineWidth',1.8,'HandleVisibility','off');
xlabel(ax,xlbl,'FontSize',9); ylabel(ax,ylbl,'FontSize',9);
title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
end

function plotPairedBox(ax,vpre,vpost,n,cPre,cPost,ylbl,ttl,pval)
hold(ax,'on'); grid(ax,'on'); box(ax,'off');
ax.GridAlpha=0.18; ax.FontSize=9;
for i=1:n
    plot(ax,[1 2],[vpre(i) vpost(i)],'-','Color',[0.65 0.65 0.65 0.45],'LineWidth',0.9,'HandleVisibility','off');
end
drawBoxplot(ax,1,vpre, cPre);
drawBoxplot(ax,2,vpost,cPost);
jit=0.08;
scatter(ax,1+jit*(rand(n,1)-0.5),vpre, 45,cPre, 'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,2+jit*(rand(n,1)-0.5),vpost,45,cPost,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
stars=pToStars(pval); ymax=max([vpre;vpost])*1.10;
plot(ax,[1 2],[ymax ymax]*0.97,'-k','LineWidth',0.8,'HandleVisibility','off');
text(ax,1.5,ymax,stars,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);
ax.XTick=[1 2]; ax.XTickLabel={'PRE','POST'}; ax.XLim=[0.5 2.5];
ylabel(ax,ylbl,'FontSize',9); title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
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
