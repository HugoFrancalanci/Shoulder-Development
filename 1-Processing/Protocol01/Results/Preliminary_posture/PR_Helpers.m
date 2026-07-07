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
% Description:   Shared graphical helper functions used across all figure functions.
%                Includes: drawBoxplot, addStars, addStarsXY, styleAx,
%                plotScatterReg, plotPairedBox, plotPrePost, pToStars.
%
% Inputs  : Various (see individual function signatures)
% Outputs : Graphical elements added to existing axes
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

function drawBoxplot(ax, x, v, col)
w     = 0.18;
q1    = quantile(v,0.25); q3 = quantile(v,0.75);
med   = median(v);
iqr_v = q3-q1;
lo    = max(min(v), q1-1.5*iqr_v);
hi    = min(max(v), q3+1.5*iqr_v);
patch(ax,[x-w x+w x+w x-w],[q1 q1 q3 q3],col,...
    'FaceAlpha',0.25,'EdgeColor',col,'LineWidth',1.8,'HandleVisibility','off');
plot(ax,[x-w x+w],[med med],'-','Color',col,'LineWidth',2.5,'HandleVisibility','off');
plot(ax,[x x],[lo q1],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x x],[q3 hi],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x-w/2 x+w/2],[lo lo],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
plot(ax,[x-w/2 x+w/2],[hi hi],'-','Color',col,'LineWidth',1.2,'HandleVisibility','off');
end

function addStars(ax, v1, v2, pval)
stars = pToStars(pval);
ymax  = max([v1; v2]) * 1.10;
plot(ax,[1 2],[ymax ymax]*0.97,'-k','LineWidth',0.8,'HandleVisibility','off');
text(ax,1.5,ymax,stars,'FontSize',14,'FontWeight','bold',...
    'HorizontalAlignment','center','Color',[0.2 0.2 0.2]);
end

function addStarsXY(ax, x1, x2, ymax, pval)
stars = pToStars(pval);
plot(ax,[x1 x2],[ymax ymax]*0.97,'-k','LineWidth',0.8,'HandleVisibility','off');
text(ax,(x1+x2)/2, ymax, stars,'FontSize',14,'FontWeight','bold',...
    'HorizontalAlignment','center','Color',[0.2 0.2 0.2]);
end

function styleAx(ax)
hold(ax,'on'); grid(ax,'on'); box(ax,'off');
ax.GridAlpha = 0.2; ax.FontSize = 9;
ax.GridColor = [0.82 0.82 0.82];
ax.TickDir   = 'out';
end

function s = pToStars(p)
if     p < 0.001, s = '*';
elseif p < 0.01,  s = '*';
elseif p < 0.05,  s = '*';
else,             s = 'ns';
end
end

function plotScatterReg(ax, xpre, ypre, xpost, ypost, n, cPre, cPost, xlbl, ylbl, ttl)
styleAx(ax);
for i = 1:n
    dp = [xpost(i)-xpre(i), ypost(i)-ypre(i)];
    if norm(dp) > 0.5
        quiver(ax,xpre(i),ypre(i),dp(1),dp(2),0,...
            'Color',[0.65 0.65 0.65 0.45],'LineWidth',0.6,...
            'MaxHeadSize',0.35,'HandleVisibility','off');
    end
end
scatter(ax,xpre, ypre, 60,cPre, 'filled','MarkerFaceAlpha',0.75,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,xpost,ypost,60,cPost,'filled','MarkerFaceAlpha',0.75,'MarkerEdgeColor','w','HandleVisibility','off');
xall = [xpre;xpost];
xfit = linspace(min(xall)-3,max(xall)+3,100);
plot(ax,xfit,polyval(polyfit(xpre, ypre, 1),xfit),'--','Color',[cPre, 0.85],'LineWidth',1.8,'HandleVisibility','off');
plot(ax,xfit,polyval(polyfit(xpost,ypost,1),xfit),'--','Color',[cPost,0.85],'LineWidth',1.8,'HandleVisibility','off');
xlabel(ax,xlbl,'FontSize',9); ylabel(ax,ylbl,'FontSize',9);
title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
end

function plotPairedBox(ax, vpre, vpost, n, cPre, cPost, ylbl, ttl, pval)
styleAx(ax);
for i = 1:n
    plot(ax,[1 2],[vpre(i) vpost(i)],'-','Color',[0.65 0.65 0.65 0.45],'LineWidth',0.9,'HandleVisibility','off');
end
drawBoxplot(ax,1,vpre, cPre);
drawBoxplot(ax,2,vpost,cPost);
jit = 0.08;
scatter(ax,1+jit*(rand(n,1)-0.5),vpre, 45,cPre, 'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,2+jit*(rand(n,1)-0.5),vpost,45,cPost,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
addStars(ax,vpre,vpost,pval);
ax.XTick=[1 2]; ax.XTickLabel={'PRE','POST'}; ax.XLim=[0.5 2.5];
ylabel(ax,ylbl,'FontSize',9); title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
end

function plotPrePost(ax, vpre, vpost, n, cPre, cPost, ylbl, ttl, pval)
styleAx(ax);
for i = 1:n
    plot(ax,[1 2],[vpre(i) vpost(i)],'-','Color',[0.65 0.65 0.65 0.45],'LineWidth',0.9,'HandleVisibility','off');
end
scatter(ax,ones(n,1),  vpre, 55,cPre, 'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,2*ones(n,1),vpost,55,cPost,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
cols = {cPre,cPost};
for ix = 1:2
    v = {vpre,vpost}; mu=mean(v{ix},'omitnan'); sd=std(v{ix},'omitnan');
    errorbar(ax,ix,mu,sd,'o','Color',cols{ix},'MarkerFaceColor',cols{ix},...
        'MarkerSize',9,'LineWidth',2.2,'CapSize',8,'HandleVisibility','off');
end
addStars(ax,vpre,vpost,pval);
ax.XTick=[1 2]; ax.XTickLabel={'PRE','POST'}; ax.XLim=[0.5 2.5];
ylabel(ax,ylbl,'FontSize',9); title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
end
