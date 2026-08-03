% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Plots the angle vs % cycle (0-100%) HT/GH/ST curves, PRE
%                vs POST, produced by ComputeHTContributions.m and
%                accumulated in MAIN_MULTI_Protocol_01.m ("Curves").
%
%                Layout: 1 row x 3 columns (HT, GH, ST)
%                  Individual curve per patient/side, transparent
%                  (blue = PRE, red = POST)
%                  Bold mean curve (blue = PRE, red = POST)
%                  Each curve is resampled to 101 points (0-100%) before
%                  averaging, in case the number of cycle points differs
%                  from one patient to another.
% -------------------------------------------------------------------------
% Inputs  : Curves (struct array) from MAIN_MULTI_Protocol_01.m, with
%           fields HT_PRE/HT_POST, GH_PRE/GH_POST, ST_PRE/ST_POST (vectors,
%           or [] if absent)
% Outputs : 1 figure, 3 subplots
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function PlotHTContributionsCurves(Curves)

if isempty(Curves)
    disp('PlotHTContributionsCurves: no data to plot.');
    return;
end

metrics = {'HT', 'GH', 'ST'};
titles  = {'HT (humérothoracique)', 'GH (glénohuméral)', 'ST (scapulothoracique)'};
xgrid   = linspace(0, 100, 101);
colPre  = [0.8500 0.3250 0.0980]; % red
colPost = [0 0.4470 0.7410];   % blue

figure('Name', 'Courbes HT/GH/ST — PRE vs POST', 'Color', 'w');

for m = 1:length(metrics)
    preField  = [metrics{m}, '_PRE'];
    postField = [metrics{m}, '_POST'];

    preCurves  = [];
    postCurves = [];

    subplot(1, length(metrics), m);
    hold on;

    for i = 1:length(Curves)
        pre = resample101(Curves(i).(preField), xgrid);
        if ~isempty(pre)
            h = plot(xgrid, pre, 'Color', colPre, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = 0.25;
            preCurves = [preCurves, pre(:)]; %#ok<AGROW>
        end

        post = resample101(Curves(i).(postField), xgrid);
        if ~isempty(post)
            h = plot(xgrid, post, 'Color', colPost, 'LineWidth', 1, 'HandleVisibility', 'off');
            h.Color(4) = 0.25;
            postCurves = [postCurves, post(:)]; %#ok<AGROW>
        end
    end

    if ~isempty(preCurves)
        plot(xgrid, mean(preCurves, 2, 'omitnan'), 'Color', colPre, 'LineWidth', 3, 'DisplayName', 'PRE (moyenne)');
    end
    if ~isempty(postCurves)
        plot(xgrid, mean(postCurves, 2, 'omitnan'), 'Color', colPost, 'LineWidth', 3, 'DisplayName', 'POST (moyenne)');
    end

    hold off;
    xlim([0 100]);
    xlabel('Cycle (%)');
    ylabel([metrics{m}, ' (deg)']);
    title(titles{m});
    legend('show', 'Location', 'best');
    box on;
end

end

function c = resample101(curve, xgrid)
% Resamples a vector of any length onto the 0-100% grid (101 points), so
% that cycles of different lengths can be averaged together.
c = [];
curve = curve(:);
curve = curve(~isnan(curve));
if length(curve) < 2, return; end
xOrig = linspace(0, 100, length(curve));
c = interp1(xOrig, curve, xgrid, 'linear');
end
