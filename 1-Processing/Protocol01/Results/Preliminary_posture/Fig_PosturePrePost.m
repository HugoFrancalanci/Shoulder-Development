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
% Description:   Paired dotplot comparing Posture angle PRE vs POST, displayed separately
%                for seated (left panel) and standing (right panel) positions.
%                Mean +/- SD shown as error bars. Stars indicate paired
%                t-test significance.
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

function Fig_PosturePrePost(D, cfg)

[~,p_assis]  = ttest(D.Posture_assis_pre,  D.Posture_assis_post);
[~,p_debout] = ttest(D.Posture_debout_pre, D.Posture_debout_post);

fig = figure('Name','Posture — PRE vs POST','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.55 0.70]);

tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
title(tl,'Posture angle — PRE vs POST',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Red = PRE   Blue = POST   Line = individual patient',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

ax1 = nexttile(tl,1);
plotPrePost(ax1, D.Posture_assis_pre,  D.Posture_assis_post,  D.n, ...
    cfg.COL_PRE, cfg.COL_POST, 'Posture angle (deg)', 'Seated — PRE vs POST',  p_assis);

ax2 = nexttile(tl,2);
plotPrePost(ax2, D.Posture_debout_pre, D.Posture_debout_post, D.n, ...
    cfg.COL_PRE, cfg.COL_POST, 'Posture angle (deg)', 'Standing — PRE vs POST', p_debout);
end

function plotPrePost(ax, vpre, vpost, n, cPre, cPost, ylbl, ttl, pval)
hold(ax,'on'); grid(ax,'on'); box(ax,'off');
ax.GridAlpha=0.2; ax.FontSize=9;
for i=1:n
    plot(ax,[1 2],[vpre(i) vpost(i)],'-','Color',[0.65 0.65 0.65 0.45],'LineWidth',0.9,'HandleVisibility','off');
end
scatter(ax,ones(n,1),  vpre, 55,cPre, 'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax,2*ones(n,1),vpost,55,cPost,'filled','MarkerFaceAlpha',0.6,'MarkerEdgeColor','w','HandleVisibility','off');
cols={cPre,cPost};
for ix=1:2
    v={vpre,vpost}; mu=mean(v{ix},'omitnan'); sd=std(v{ix},'omitnan');
    errorbar(ax,ix,mu,sd,'o','Color',cols{ix},'MarkerFaceColor',cols{ix},...
        'MarkerSize',9,'LineWidth',2.2,'CapSize',8,'HandleVisibility','off');
end
stars=pToStars(pval); ymax=max([vpre;vpost])*1.07;
plot(ax,[1 2],[ymax ymax]*0.98,'-k','LineWidth',0.8,'HandleVisibility','off');
text(ax,1.5,ymax,stars,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);
ax.XTick=[1 2]; ax.XTickLabel={'PRE','POST'}; ax.XLim=[0.5 2.5];
ylabel(ax,ylbl,'FontSize',9); title(ax,ttl,'FontSize',10,'FontWeight','bold');
hold(ax,'off');
end

function s=pToStars(p)
if p<0.001,s='*'; elseif p<0.01,s='*'; elseif p<0.05,s='*'; else,s='ns'; end
end
