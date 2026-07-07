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
% Description:   Grouped bar plot (mean +/- SD) showing (1) the HG elevation range and
%                (2) the proportional contributions of GH, ST and TX segments,
%                PRE vs POST. Stars indicate paired t-test significance.
%                Colours: GH=blue, ST=purple, TX=green; solid=PRE, transparent=POST.
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

function Fig_ContributionsBar(D, cfg)

[~,p_hg] = ttest(D.hg_pre, D.hg_post);
[~,p_gh] = ttest(D.gh_pre, D.gh_post);
[~,p_st] = ttest(D.st_pre, D.st_post);
[~,p_tx] = ttest(D.tx_pre, D.tx_post);

fig = figure('Name','Contributions — Bar plot','Color','w',...
    'Units','normalized','OuterPosition',[0.05 0.1 0.90 0.70]);

tl = tiledlayout(fig,1,2,'TileSpacing','loose','Padding','compact');
title(tl,'Kinematic contributions — ANALYTIC2  |  PRE vs POST',...
    'FontSize',cfg.TITLE_SIZE,'FontWeight','bold','Color',[0.15 0.15 0.15]);
subtitle(tl,'Mean ± SD   |   Red = PRE   Blue = POST',...
    'FontSize',8,'Color',[0.5 0.5 0.5]);

% --- Panel gauche : HG range ---
ax_hg = nexttile(tl,1);
hold(ax_hg,'on'); grid(ax_hg,'on'); box(ax_hg,'off');
ax_hg.GridAlpha=0.18; ax_hg.FontSize=10;

mu_hg=[mean(D.hg_pre,'omitnan'), mean(D.hg_post,'omitnan')];
sd_hg=[std(D.hg_pre,'omitnan'),  std(D.hg_post,'omitnan')];

b=bar(ax_hg,1:2,mu_hg,0.5);
b.FaceColor='flat'; b.CData=[cfg.COL_PRE;cfg.COL_POST];
b.FaceAlpha=0.75; b.EdgeColor='none';
errorbar(ax_hg,1:2,mu_hg,sd_hg,'k.','LineWidth',1.8,'CapSize',8,'HandleVisibility','off');

jit=0.12;
scatter(ax_hg,1+jit*(rand(D.n,1)-0.5),D.hg_pre, 35,cfg.COL_PRE, 'filled','MarkerFaceAlpha',0.5,'MarkerEdgeColor','w','HandleVisibility','off');
scatter(ax_hg,2+jit*(rand(D.n,1)-0.5),D.hg_post,35,cfg.COL_POST,'filled','MarkerFaceAlpha',0.5,'MarkerEdgeColor','w','HandleVisibility','off');

stars_hg=pToStars(p_hg); ymax_hg=max(mu_hg+sd_hg)*1.18;
plot(ax_hg,[1 2],[ymax_hg ymax_hg]*0.96,'-k','LineWidth',0.8,'HandleVisibility','off');
text(ax_hg,1.5,ymax_hg,stars_hg,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);

ax_hg.XTick=[1 2]; ax_hg.XTickLabel={'PRE','POST'}; ax_hg.XLim=[0.4 2.6];
ylabel(ax_hg,'HG elevation range (deg)','FontSize',10);
title(ax_hg,'Humero-gravitaire','FontSize',11,'FontWeight','bold');
hold(ax_hg,'off');

% --- Panel droit : contributions % ---
ax_pct = nexttile(tl,2);
hold(ax_pct,'on'); grid(ax_pct,'on'); box(ax_pct,'off');
ax_pct.GridAlpha=0.18; ax_pct.FontSize=10;

mu_data=[mean(D.gh_pre,'omitnan') mean(D.gh_post,'omitnan');
         mean(D.st_pre,'omitnan') mean(D.st_post,'omitnan');
         mean(D.tx_pre,'omitnan') mean(D.tx_post,'omitnan')];
sd_data=[std(D.gh_pre,'omitnan') std(D.gh_post,'omitnan');
         std(D.st_pre,'omitnan') std(D.st_post,'omitnan');
         std(D.tx_pre,'omitnan') std(D.tx_post,'omitnan')];

bar_colors=[cfg.COL_GH; cfg.COL_ST; cfg.COL_TX];
x_pos=[1 2 3]; offset=0.18;
pre_cells  ={D.gh_pre, D.st_pre, D.tx_pre};
post_cells ={D.gh_post,D.st_post,D.tx_post};
p_vals     ={p_gh, p_st, p_tx};

for ig=1:3
    bar(ax_pct,x_pos(ig)-offset,mu_data(ig,1),0.30,'FaceColor',bar_colors(ig,:),'FaceAlpha',0.85,'EdgeColor','none','HandleVisibility','off');
    errorbar(ax_pct,x_pos(ig)-offset,mu_data(ig,1),sd_data(ig,1),'k.','LineWidth',1.5,'CapSize',6,'HandleVisibility','off');
    bar(ax_pct,x_pos(ig)+offset,mu_data(ig,2),0.30,'FaceColor',bar_colors(ig,:),'FaceAlpha',0.35,'EdgeColor',bar_colors(ig,:),'LineWidth',1.2,'HandleVisibility','off');
    errorbar(ax_pct,x_pos(ig)+offset,mu_data(ig,2),sd_data(ig,2),'k.','LineWidth',1.5,'CapSize',6,'HandleVisibility','off');
    stars_ig=pToStars(p_vals{ig});
    ymax_ig=max(mu_data(ig,:)+sd_data(ig,:))*1.14;
    plot(ax_pct,[x_pos(ig)-offset x_pos(ig)+offset],[ymax_ig ymax_ig]*0.96,'-k','LineWidth',0.8,'HandleVisibility','off');
    text(ax_pct,x_pos(ig),ymax_ig,stars_ig,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.2 0.2 0.2]);
end

h_pre  = bar(ax_pct,NaN,NaN,'FaceColor',[0.55 0.55 0.55],'FaceAlpha',0.85,'EdgeColor','none');
h_post = bar(ax_pct,NaN,NaN,'FaceColor',[0.55 0.55 0.55],'FaceAlpha',0.35,'EdgeColor',[0.4 0.4 0.4],'LineWidth',1.2);
legend(ax_pct,[h_pre,h_post],{'PRE','POST'},'Location','northeast','FontSize',9,'Box','off');

ax_pct.XTick=x_pos; ax_pct.XTickLabel={'GH','ST','TX'}; ax_pct.XLim=[0.4 3.6];
ylabel(ax_pct,'Contribution (%)','FontSize',10);
title(ax_pct,'GH / ST / Thorax contributions','FontSize',11,'FontWeight','bold');
hold(ax_pct,'off');
end

function s=pToStars(p)
if p<0.001,s='*'; elseif p<0.01,s='*'; elseif p<0.05,s='*'; else,s='ns'; end
end
