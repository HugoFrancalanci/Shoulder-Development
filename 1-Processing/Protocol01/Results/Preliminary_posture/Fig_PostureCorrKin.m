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
% Description:   Scatter plots with linear regression lines showing Pearson correlations
%                between the seated Posture angle and (1) thoracic compensation
%                (TX%) and (2) HG elevation range, for PRE and POST groups.
%                Arrows connect each patient PRE to POST. Statistical values
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

function Fig_PostureCorrKin(D, cfg)

fig = figure('Name','Posture vs compensation et mobilité','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.80 0.60]);

tl = tiledlayout(fig,1,2,'TileSpacing','loose','Padding','compact');
title(tl,'Posture angle vs thoracic compensation and HG mobility — PRE vs POST',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Red = PRE   Blue = POST   Dashed = linear fit   |   See console for r, p-values',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

ax1 = nexttile(tl,1);
plotScatterReg(ax1, D.Posture_assis_pre, D.tx_pre, D.Posture_assis_post, D.tx_post, D.n,...
    cfg.COL_PRE, cfg.COL_POST,...
    'Posture angle (deg)', 'Thorax contribution (%TX)', 'Posture vs TX% — thoracic compensation');

ax2 = nexttile(tl,2);
plotScatterReg(ax2, D.Posture_assis_pre, D.hg_pre, D.Posture_assis_post, D.hg_post, D.n,...
    cfg.COL_PRE, cfg.COL_POST,...
    'Posture angle (deg)', 'HG elevation range (deg)', 'Posture vs HG range — global mobility');
end

function plotScatterReg(ax, xpre, ypre, xpost, ypost, n, cPre, cPost, xlbl, ylbl, ttl)
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
