% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026
% -------------------------------------------------------------------------
% Description:   Illustrations des mesures de l'article E02_01_Posture, sur
%                un patient réel, avec une silhouette schématique du patient
%                (formes grises séparées, modifiables dans Inkscape) :
%                  1) inclinaison thoracique : angle 3D entre TV8 vers CV7
%                     et la verticale, assis (début d'ANALYTIC2) et debout
%                     (CALIBRATION3), vue sagittale à la même échelle ;
%                  2) SIR : vue de dessus dans le repère du thorax, axe de
%                     la scapula (SRS vers SAA) vs axe médio-latéral du
%                     thorax = 1re rotation Y de la séquence YXZ ;
%                  3) HG et HT : au repos et au pic d'élévation, en flexion
%                     (vue sagittale, HT = rotation Z de ZXY) et en scaption
%                     (vue de face, HT = rotation X de XZY) ; HG = élévation
%                     X de la séquence YXY dans le repère gravitaire ; courbes
%                     HG, HT et thorax au cours de l'essai ;
%                  4) contribution du thorax : axe du thorax au repos et
%                     au pic, flexion signée sur le cycle moyen (repos, au
%                     pic, changement, ROM signé vs ROM sur la valeur
%                     absolue) et HG moins HT vs orientation signée du
%                     thorax.
%                Les sessions PRE (posture) et POST (HG, HT) du patient sont
%                retraitées par runProtocol01 depuis une copie locale montée
%                sur un lecteur virtuel (BTK échoue sur les chemins
%                accentués ou trop longs). Toutes les valeurs affichées
%                viennent du pipeline (PostureSummary, Joint.Euler) ; le
%                dessin est une projection plane qui sert à l'illustration.
%                Textes des figures sans tiret ni tiret long.
% -------------------------------------------------------------------------
% Inputs  : Folder           (struct) .toolbox (et .deps, déduit sinon)
%           PatientSelection (cell) de userCommands_Multi.m (ligne = Numero)
%           DataFolder       (char) dossier racine des données patients
%           DataFile         (char) Data_posture.xlsx (choix du patient)
%           OutputFolder     (char) dossier des figures (PNG, PDF, SVG)
%           Numero           (double, optionnel) patient ; vide = patient
%                            représentatif choisi automatiquement (type B,
%                            inclinaison assis et debout et SIR proches de la
%                            moyenne, session PRE non corrigée pour le SXS)
% Outputs : Info (struct) patient retenu et valeurs affichées
%           + 4 figures exportées en PNG, PDF vectoriel et SVG
% -------------------------------------------------------------------------
% Dependencies : runProtocol01.m, BTK
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Info = PlotMeasureIllustrations(Folder, PatientSelection, DataFolder, DataFile, OutputFolder, Numero)

if nargin < 6, Numero = []; end
if ~isfield(Folder, 'deps'), Folder.deps = fullfile(fileparts(Folder.toolbox), 'dependencies'); end
if ~isfolder(OutputFolder), mkdir(OutputFolder); end

% -------------------------------------------------------------------------
% PATIENT
% -------------------------------------------------------------------------
P = readtable(DataFile, 'Sheet', 'Posture', 'VariableNamingRule', 'preserve');
P = P(~isnan(P.Numero), :);
if isempty(Numero)
    inc = P.Inclinaison_thoracique_Pre; sir = P.Rotation_scapulaire_interne_Pre;
    stand = P.Inclinaison_thoracique_Pre_Calibration3;
    % sessions PRE dont le SXS a été reconstruit (DetectSXSCorrection)
    fixedPRE = [20 27 30 41 47 71 90 101 103:115 117:121 158];
    score = abs(inc - mean(inc)) / std(inc) + abs(sir - mean(sir)) / std(sir) + ...
            abs(stand - mean(stand)) / std(stand);
    score(~strcmp(P.Moroder_type_pre, 'B') | ismember(P.Numero, fixedPRE)) = Inf;
    [~, iBest] = min(score);
    Numero = P.Numero(iBest);
end
side = upper(strtrim(char(string(PatientSelection{Numero, 2}))));
if strcmp(side, '1'), side = 'L'; elseif strcmp(side, '0'), side = 'R'; end
Info.Numero = Numero; Info.Side = side;
fprintf('Illustrations : patient n°%d (côté %s)\n', Numero, side);

% -------------------------------------------------------------------------
% SESSIONS RETRAITÉES PAR LE PIPELINE
% -------------------------------------------------------------------------
Tpre  = processSession(Folder, sessionFolder(PatientSelection, DataFolder, Numero, 3), {'ANALYTIC2', 'CALIBRATION3', 'STATIC3'});
Tpost = processSession(Folder, sessionFolder(PatientSelection, DataFolder, Numero, 4), {'ANALYTIC1', 'ANALYTIC2'});

% -------------------------------------------------------------------------
% 1) INCLINAISON THORACIQUE
% -------------------------------------------------------------------------
tA = getTrial(Tpre, {'ANALYTIC2'}); tC = getTrial(Tpre, {'CALIBRATION3', 'STATIC3'});
views = {tA, 'Assis (début de l''essai ANALYTIC2)', true; tC, 'Debout (CALIBRATION3)', false};
fig1 = figure('Color', 'w', 'Position', [0 0 1500 760]);
axs = gobjects(1, 2);
for iv = 1:2
    t = views{iv, 1}; M = markersAt(t, 1:min(100, t.n1));
    th = t.Joint(11).PostureSummary.thoracic_curvature_angle;
    Info.(sprintf('Inclination_%s', ternary(iv == 1, 'Seated', 'Standing'))) = th;
    [pr, ~] = planes(t, M.TV8);
    ax = subplot(1, 2, iv); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on'); axs(iv) = ax;
    sagittalSilhouette(ax, M, pr, views{iv, 3}, side, []);
    names = intersect({'SJN', 'SME', 'SXS', 'CV7', 'TV3', 'TV5', 'TV8', 'S1'}, fieldnames(M), 'stable');
    xy = cell2mat(cellfun(@(f) pr(M.(f)), names(:), 'UniformOutput', false));
    scatter(ax, xy(:, 1), xy(:, 2), 50, [0.3 0.3 0.3], 'filled');
    for i = 1:numel(names), text(ax, xy(i, 1) + 8, xy(i, 2) - 8, names{i}, 'FontSize', 9); end
    c7 = pr(M.CV7); L = norm(c7);
    plot(ax, [0 0], [0 1.2 * L], '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5);
    quiver(ax, 0, 0, c7(1), c7(2), 0, 'Color', [0.89 0.17 0.46], 'LineWidth', 3, 'MaxHeadSize', 0.15);
    drawArc(ax, [0 0], [0 1], c7, 0.45 * L, [0.69 0.09 0.35]);
    text(ax, -12, 0.45 * L + 10, sprintf('%.1f°', th), 'HorizontalAlignment', 'right', ...
        'Color', [0.69 0.09 0.35], 'FontSize', 14, 'FontWeight', 'bold');
    text(ax, -8, 1.2 * L, 'verticale', 'FontSize', 9, 'Color', [0.2 0.2 0.2], 'HorizontalAlignment', 'right');
    axis(ax, 'tight');
    xlabel(ax, 'antérieur (mm)'); ylabel(ax, 'vertical (mm)');
    title(ax, {views{iv, 2}, sprintf('angle 3D entre TV8 vers CV7 et la verticale : %.1f°', th)}, 'FontSize', 11);
end
sameScale(axs);
sgtitle(fig1, sprintf('Inclinaison thoracique, patient n°%d (PRE) : vue sagittale, moyenne des 100 premières images', Numero), 'FontSize', 13);
footnote(fig1, ['Angle calculé en 3D (sans projection) ; la vue sagittale sert à l''illustration. 0° = thorax vertical. ', ...
    'Silhouette schématique : seuls le tronc et les marqueurs viennent des mesures.']);
exportAll(fig1, fullfile(OutputFolder, 'Illustration_inclinaison_thoracique'));

% -------------------------------------------------------------------------
% 2) SIR (vue de dessus dans le repère du thorax)
% -------------------------------------------------------------------------
M = markersAt(tA, 1:min(100, tA.n1));
Tt = thoraxFrame(M);
loc = @(p) Tt(:, 1:3)' * (p - Tt(:, 4));
tv  = @(p) [loc(p)' * [0; 0; 1], loc(p)' * [1; 0; 0]];
sirPipe = [tA.Joint(11).PostureSummary.SIR_R, tA.Joint(11).PostureSummary.SIR_L];
eR = eulerYXZ(Tt(:, 1:3)' * scapFrame(M, 'R'));
eL = eulerYXZ(Tt(:, 1:3)' * scapFrame(M, 'L')); eL = [180 - eL(1), eL(2), -eL(3)];   % convention gauche (Joint 8)
Info.SIR_R = sirPipe(1); Info.SIR_L = sirPipe(2);
fprintf('SIR pipeline R %.1f / L %.1f ; recalcul R %.1f / L %.1f\n', sirPipe, abs(eR(1)), abs(eL(1)));

fig2 = figure('Color', 'w', 'Position', [0 0 1500 760]);
ax = subplot(1, 2, 1); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on');
transverseSilhouette(ax, M, tv);
thx = {'SJN', 'SXS', 'CV7', 'TV8'};
pt = cell2mat(cellfun(@(f) tv(M.(f)), thx(:), 'UniformOutput', false));
scatter(ax, pt(:, 1), pt(:, 2), 50, [0.3 0.3 0.3], 'filled');
for i = 1:numel(thx), text(ax, pt(i, 1) + 8, pt(i, 2) + 8, thx{i}, 'FontSize', 9); end
plot(ax, [-260 260], [0 0], '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.5);
text(ax, 255, 14, 'axe médio-latéral du thorax', 'FontSize', 9, 'HorizontalAlignment', 'right');
cols = [0.89 0.17 0.46; 0 0.45 0.74];
for s = 1:2
    sd = 'R'; if s == 2, sd = 'L'; end
    q = cell2mat(cellfun(@(f) tv(M.([sd f])), {'SAA'; 'SRS'; 'SIA'}, 'UniformOutput', false));
    plot(ax, q([1 2 3 1], 1), q([1 2 3 1], 2), '-', 'Color', cols(s, :) * 0.5 + 0.5, 'LineWidth', 1);
    scatter(ax, q(:, 1), q(:, 2), 50, cols(s, :), 'filled');
    lab = {'SAA', 'SRS', 'SIA'}; sg = 1 - 2 * (s == 2);
    for i = 1:3
        text(ax, q(i, 1) + sg * 8, q(i, 2) + 10 * (i == 1) - 10 * (i > 1), [sd lab{i}], 'FontSize', 8, ...
            'Color', cols(s, :), 'HorizontalAlignment', ternary(s == 1, 'left', 'right'));
    end
    quiver(ax, q(2, 1), q(2, 2), q(1, 1) - q(2, 1), q(1, 2) - q(2, 2), 0, 'Color', cols(s, :), 'LineWidth', 3, 'MaxHeadSize', 0.3);
    base = [sg 0];
    drawArc(ax, q(2, :), base, q(1, :) - q(2, :), 70, cols(s, :));
    plot(ax, q(2, 1) + [0 110 * sg], q(2, 2) + [0 0], ':', 'Color', cols(s, :), 'LineWidth', 1.5);
    text(ax, q(2, 1) + 55 * sg, q(2, 2) - 75, sprintf('SIR %.1f°', sirPipe(s)), 'Color', cols(s, :), ...
        'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
xlabel(ax, 'médio-latéral, droite > 0 (mm)'); ylabel(ax, 'antérieur (mm)');
title(ax, {'Vue de dessus dans le repère du thorax', 'axe de la scapula SRS vers SAA vs axe médio-latéral du thorax'}, 'FontSize', 11);
ax2 = subplot(1, 2, 2); axis(ax2, 'off');
text(ax2, 0, 1.0, 'Calcul de la SIR (approximation cinématique)', 'VerticalAlignment', 'top', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
text(ax2, 0, 0.94, {'1. Repère du thorax (Wu et al. 2005) :', ...
    '    Y = milieu(CV7, SJN) moins milieu(TV8, SXS) (vers le haut)', ...
    '    Z = normale au plan SJN, CV7, milieu(TV8, SXS) (vers la droite)', '    X = Y x Z (antérieur)', '', ...
    '2. Repère de la scapula :', '    Z = SAA moins SRS (épine vers acromion)', ...
    '    X = normale au plan SIA, SRS, SAA', '    Y = Z x X', '', ...
    '3. Rotation scapula / thorax décomposée en YXZ (ISB) :', ...
    sprintf('    droite : Y = %.1f°, X = %.1f°, Z = %.1f°', eR), ...
    sprintf('    gauche : Y = %.1f°, X = %.1f°, Z = %.1f°', eL), '', ...
    '4. SIR = |Y| (protraction / rotation interne de la scapula),', ...
    '    moyenne des 100 premières images (repos)', '', ...
    'Moroder (CT, couché) : angle entre l''axe de la scapula', ...
    'et l''axe sagittal vertébral, mesuré en coupe axiale.', ...
    'Notre SIR en est une approximation en charge, non validée.'}, ...
    'VerticalAlignment', 'top', 'FontSize', 11, 'Interpreter', 'none');
sgtitle(fig2, sprintf('Rotation interne scapulaire (SIR), patient n°%d (PRE, assis, ANALYTIC2)', Numero), 'FontSize', 13);
exportAll(fig2, fullfile(OutputFolder, 'Illustration_SIR'));

% -------------------------------------------------------------------------
% 3) HG ET HT (POST) : repos, pic, courbes
% -------------------------------------------------------------------------
if strcmp(side, 'R'), jHT = 1; jHG = 12; gj = 'RGJC'; ej = 'REJC'; else, jHT = 6; jHG = 13; gj = 'LGJC'; ej = 'LEJC'; end
cHG = [0 0.45 0.74]; cHT = [0.85 0.33 0.10]; cTX = [0.45 0.45 0.45];
% thorax : flexion (Joint 11 DOF3 Z) dans les deux tâches, comme le pipeline
taskDef = {'ANALYTIC1', 'flexion', 3, 'vue sagittale', 'flexion du thorax'; ...
           'ANALYTIC2', 'scaption', 1, 'vue de face', 'flexion du thorax'};
fig3 = figure('Color', 'w', 'Position', [0 0 1900 1150]);
for it = 1:2
    t = getTrial(Tpost, taskDef(it, 1));
    hg = abs(squeeze(t.Joint(jHG).Euler.full(1, 1, :)));
    ht = abs(squeeze(t.Joint(jHT).Euler.full(1, taskDef{it, 3}, :)));
    tx = squeeze(t.Joint(11).Euler.full(1, 3, :));
    [~, fPk] = max(hg);
    rest = 1:min(20, t.n1);
    Mr = markersAt(t, rest);
    [prS, prF] = planes(t, Mr.TV8);
    pr = prS; if it == 2, pr = prF; end
    axr = gobjects(1, 2);
    for ip = 1:2
        if ip == 1, fr = rest; lbl = 'Repos (début de l''essai)'; else, fr = fPk; lbl = 'Pic d''élévation HG'; end
        Mf = markersAt(t, fr);
        ax = subplot(2, 3, (it - 1) * 3 + ip); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on'); axr(ip) = ax;
        G = pr(Mf.(gj)); E = pr(Mf.(ej)); W = pr(wristOf(Mf, side));
        if it == 1
            sagittalSilhouette(ax, Mf, pr, true, side, [G; E; W]);
        else
            os = ternary(side == 'R', 'L', 'R');
            Go = pr(Mf.([os 'GJC'])); Eo = pr(Mf.([os 'EJC'])); Wo = pr(wristOf(Mf, os));
            frontalSilhouette(ax, Mf, pr, [G; E; W], [Go; Eo; Wo]);
        end
        % axes : verticale et axe long du thorax passant par le centre huméral
        Tth = mean(t.Segment(4).T.full(1:3, 1:3, fr), 3);
        tDown = pr(Mf.(gj) - 1000 * Tth(:, 2)) - G; tDown = tDown / norm(tDown);
        hDir = (E - G) / norm(E - G);
        R1 = 260;
        plot(ax, G(1) + [0 0], G(2) + [0 -R1], '--', 'Color', cHG, 'LineWidth', 1.5);
        plot(ax, G(1) + [0 R1 * tDown(1)], G(2) + [0 R1 * tDown(2)], '--', 'Color', cHT, 'LineWidth', 1.5);
        plot(ax, [G(1) E(1)], [G(2) E(2)], '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 3);
        scatter(ax, [G(1) E(1)], [G(2) E(2)], 45, [0.15 0.15 0.15], 'filled');
        text(ax, G(1) + 10, G(2) + 18, 'centre huméral', 'FontSize', 8);
        text(ax, E(1) + 10, E(2) - 12, 'coude', 'FontSize', 8);
        vHG = mean(hg(fr)); vHT = mean(ht(fr)); vTX = mean(tx(fr));
        drawArc(ax, G, [0 -1], hDir, 120, cHG);
        drawArc(ax, G, tDown, hDir, 175, cHT);
        % valeurs dans le coin du panneau (couleurs des arcs)
        text(ax, 0.04, 0.97, sprintf('HG %.1f°', vHG), 'Units', 'normalized', ...
            'Color', cHG, 'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
        text(ax, 0.04, 0.90, sprintf('HT %.1f°', vHT), 'Units', 'normalized', ...
            'Color', cHT, 'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
        axis(ax, 'tight');
        xlabel(ax, ternary(it == 1, 'antérieur (mm)', 'latéral, droite du patient à gauche (mm)')); ylabel(ax, 'vertical (mm)');
        title(ax, {sprintf('%s, %s', capital(taskDef{it, 2}), lbl), sprintf('%s : %+.1f°', taskDef{it, 5}, vTX)}, 'FontSize', 10);
    end
    sameScale(axr);
    for ip = 1:2, ylim(axr(ip), ylim(axr(ip)) + [0 260]); end   % place pour les valeurs en haut
    % courbes au cours de l'essai
    ax = subplot(2, 3, (it - 1) * 3 + 3); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    tt = (0:numel(hg) - 1) / t.fmarker;
    plot(ax, tt, hg, '-', 'Color', cHG, 'LineWidth', 2, 'DisplayName', 'HG, élévation / gravité');
    plot(ax, tt, ht, '-', 'Color', cHT, 'LineWidth', 2, 'DisplayName', 'HT, élévation / thorax');
    plot(ax, tt, tx, '-', 'Color', cTX, 'LineWidth', 1.5, 'DisplayName', capital(taskDef{it, 5}));
    xline(ax, tt(fPk), ':k', 'HandleVisibility', 'off');
    yline(ax, 0, ':k', 'HandleVisibility', 'off');
    legend(ax, 'Location', 'northwest', 'FontSize', 8);
    xlabel(ax, 'temps (s)'); ylabel(ax, 'angle (deg)');
    title(ax, {sprintf('%s : au cours de l''essai', capital(taskDef{it, 2})), ...
        sprintf('au pic : HG %.1f°, HT %.1f° (écart %+.1f°)', hg(fPk), ht(fPk), hg(fPk) - ht(fPk))}, 'FontSize', 10);
    Info.(sprintf('HG_peak_%s', taskDef{it, 2})) = hg(fPk);
    Info.(sprintf('HT_peak_%s', taskDef{it, 2})) = ht(fPk);
end
sgtitle(fig3, sprintf(['HG (humérus / gravité) et HT (humérus / thorax), patient n°%d (POST, assis) : ', ...
    'flexion (ligne 1), scaption (ligne 2)'], Numero), 'FontSize', 13);
footnote(fig3, ['HG (bleu, arc depuis la verticale) : élévation X de la séquence YXY de l''humérus dans le repère ', ...
    'gravitaire (verticale du laboratoire, direction antérieure du plan du thorax au repos). HT (orange, arc depuis ', ...
    'l''axe du thorax) : flexion = rotation Z (ZXY), scaption = rotation X (XZY). Valeurs du pipeline ; tracés projetés.']);
exportAll(fig3, fullfile(OutputFolder, 'Illustration_HG_HT'));

% -------------------------------------------------------------------------
% 4) CONTRIBUTION DU THORAX (POST) : flexion signée et HG moins HT
% -------------------------------------------------------------------------
% Mêmes définitions que le pipeline, cycle par cycle puis moyenne :
%   repos   = thorax au début du cycle (moyenne des 3 premières images)
%   au pic  = thorax à l'image du pic d'élévation HG
%   changement = au pic moins repos (> 0 = le tronc se redresse)
%   ROM     = max moins min du signal signé (pas de abs)
cf = ternary(side == 'R', 'rcycle', 'lcycle');
cTXc = [0.89 0.17 0.46]; cD = [0.45 0.20 0.60];
fig4 = figure('Color', 'w', 'Position', [0 0 1900 1150]);
for it = 1:2
    t = getTrial(Tpost, taskDef(it, 1));
    TXc = cyc(t.Joint(11).Euler, cf, 3); HGc = abs(cyc(t.Joint(jHG).Euler, cf, 1));
    HTc = abs(cyc(t.Joint(jHT).Euler, cf, taskDef{it, 3}));
    nc = min([size(TXc, 2), size(HGc, 2), size(HTc, 2)]);
    st = NaN(1, nc); pk = NaN(1, nc); romS = NaN(1, nc); romA = NaN(1, nc);
    for c = 1:nc
        st(c) = mean(TXc(1:3, c), 'omitnan');
        [~, ip] = max(HGc(:, c)); pk(c) = TXc(ip, c);
        romS(c) = max(TXc(:, c)) - min(TXc(:, c));
        a = abs(TXc(:, c)); romA(c) = max(a) - min(a);
    end
    V.start = mean(st); V.peak = mean(pk); V.change = mean(pk - st); V.romS = mean(romS); V.romA = mean(romA);
    Info.(sprintf('TX_change_%s', taskDef{it, 2})) = V.change;
    Info.(sprintf('TX_ROM_%s', taskDef{it, 2})) = V.romS;
    txm = mean(TXc(:, 1:nc), 2, 'omitnan'); hgm = mean(HGc(:, 1:nc), 2, 'omitnan'); htm = mean(HTc(:, 1:nc), 2, 'omitnan');
    [~, ipm] = max(hgm); x = linspace(0, 100, numel(txm));

    % col 1 : axe du thorax au repos et au pic (vue sagittale), silhouette au pic
    hgF = abs(squeeze(t.Joint(jHG).Euler.full(1, 1, :))); [~, fPk] = max(hgF); rest = 1:min(20, t.n1);
    Mr = markersAt(t, rest); Mp = markersAt(t, fPk);
    [prS, ~] = planes(t, Mr.TV8);
    ax = subplot(2, 3, (it - 1) * 3 + 1); hold(ax, 'on'); axis(ax, 'equal'); box(ax, 'on');
    G = prS(Mp.(gj)); E = prS(Mp.(ej)); W = prS(wristOf(Mp, side));
    sagittalSilhouette(ax, Mp, prS, true, side, [G; E; W]);
    txF = squeeze(t.Joint(11).Euler.full(1, 3, :));
    base = prS(Mr.TV8);
    aR = prS(Mr.CV7) - base; aP = prS(Mp.CV7) - prS(Mp.TV8); L = 1.4 * norm(aR);
    plot(ax, base(1) + [0 0], base(2) + [0 L], ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2);
    plot(ax, base(1) + [0 L * aR(1) / norm(aR)], base(2) + [0 L * aR(2) / norm(aR)], '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 2);
    plot(ax, base(1) + [0 L * aP(1) / norm(aP)], base(2) + [0 L * aP(2) / norm(aP)], '-', 'Color', cTXc, 'LineWidth', 3);
    drawArc(ax, base, aR, aP, 0.75 * L, cTXc);
    text(ax, 0.04, 0.97, sprintf('repos %+.1f°', mean(txF(rest))), 'Units', 'normalized', 'Color', [0.35 0.35 0.35], ...
        'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    text(ax, 0.04, 0.91, sprintf('au pic %+.1f°', txF(fPk)), 'Units', 'normalized', 'Color', cTXc, ...
        'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    text(ax, 0.04, 0.85, sprintf('changement %+.1f°', txF(fPk) - mean(txF(rest))), 'Units', 'normalized', 'Color', cTXc, ...
        'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    axis(ax, 'tight'); yl = ylim(ax); ylim(ax, yl + [-30 300]);
    xlabel(ax, 'antérieur (mm)'); ylabel(ax, 'vertical (mm)');
    title(ax, {sprintf('%s : axe du thorax (TV8 vers CV7)', capital(taskDef{it, 2})), ...
        'repos (gris, tirets) et pic d''élévation HG (couleur)'}, 'FontSize', 10);

    % col 2 : flexion signée du thorax sur le cycle moyen
    ax = subplot(2, 3, (it - 1) * 3 + 2); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    plot(ax, x, abs(txm), ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.5, 'DisplayName', 'valeur absolue (repliée)');
    plot(ax, x, txm, '-', 'Color', cTXc, 'LineWidth', 2.5, 'DisplayName', 'flexion du thorax, signée');
    yline(ax, 0, 'k', 'HandleVisibility', 'off');
    scatter(ax, x(1), txm(1), 60, [0.35 0.35 0.35], 'filled', 'DisplayName', 'repos');
    scatter(ax, x(ipm), txm(ipm), 60, cTXc, 'filled', 'DisplayName', 'au pic d''élévation HG');
    quiver(ax, x(ipm), txm(1), 0, txm(ipm) - txm(1), 0, 'Color', cTXc, 'LineWidth', 1.8, 'MaxHeadSize', 0.4, 'HandleVisibility', 'off');
    plot(ax, [x(1) x(ipm)], txm(1) * [1 1], '--', 'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off');
    xr = 103; plot(ax, [xr xr], [min(txm) max(txm)], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 2, 'HandleVisibility', 'off');
    plot(ax, xr + [-1.5 1.5], min(txm) * [1 1], 'k-', xr + [-1.5 1.5], max(txm) * [1 1], 'k-', 'HandleVisibility', 'off');
    text(ax, xr + 2, mean([min(txm) max(txm)]), 'ROM', 'FontSize', 9);
    xlim(ax, [0 112]); legend(ax, 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', 8);
    xlabel(ax, '% du cycle'); ylabel(ax, 'flexion du thorax (deg, > 0 = extension)');
    title(ax, {sprintf('changement repos vers pic : %+.1f° ; ROM signé : %.1f°', V.change, V.romS), ...
        sprintf('(ROM sur la valeur absolue : %.1f°, sous-estimé)', V.romA)}, 'FontSize', 10);

    % col 3 : HG moins HT et orientation du thorax (signée) sur le cycle
    % moyen. À un instant donné, HG moins HT se compare à l'ORIENTATION du
    % thorax par rapport à la verticale (pas à son changement depuis le
    % repos) ; près du repos, elle dépend surtout de la définition des
    % angles (HG élévation 3D, HT rotation plane en valeur absolue).
    ax = subplot(2, 3, (it - 1) * 3 + 3); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    dm = hgm - htm;
    plot(ax, x, dm, '-', 'Color', cD, 'LineWidth', 2.5, 'DisplayName', 'HG moins HT');
    plot(ax, x, txm, '-', 'Color', cTXc, 'LineWidth', 2, 'DisplayName', 'flexion du thorax, signée');
    yline(ax, 0, 'k', 'HandleVisibility', 'off'); xline(ax, x(ipm), ':k', 'HandleVisibility', 'off');
    scatter(ax, x(ipm) * [1 1], [dm(ipm) txm(ipm)], 50, [cD; cTXc], 'filled', 'HandleVisibility', 'off');
    legend(ax, 'Location', 'southoutside', 'FontSize', 8);
    xlabel(ax, '% du cycle'); ylabel(ax, 'angle (deg)');
    if sign(dm(ipm)) == sign(txm(ipm))
        msg = 'au pic : même signe, même ordre de grandeur';
    else
        msg = 'au pic : signes opposés (définition des angles)';
    end
    title(ax, {sprintf('au pic : HG moins HT %+.1f°, thorax %+.1f°', dm(ipm), txm(ipm)), msg}, 'FontSize', 10);
end
sgtitle(fig4, sprintf(['Contribution du thorax, patient n°%d (POST, assis) : flexion (ligne 1), scaption (ligne 2), ', ...
    'cycle moyen des %d cycles'], Numero, nc), 'FontSize', 13);
footnote(fig4, ['Thorax : flexion par rapport au repère gravitaire (Joint 11, DOF Z), signée (négatif = flexion, positif = ', ...
    'extension). Repos = 3 premières images du cycle ; au pic = image du pic d''élévation HG ; ROM = max moins min du signal ', ...
    'signé (la valeur absolue replie la courbe quand elle passe par zéro). Près du repos, HG moins HT reflète surtout la ', ...
    'définition des angles (HG élévation 3D, HT rotation plane en valeur absolue).']);
exportAll(fig4, fullfile(OutputFolder, 'Illustration_contribution_thorax'));
fprintf('Figures : %s\n', OutputFolder);

end

% =========================================================================
%  SESSIONS
% =========================================================================
% Dossier de session PRE (col = 3) ou POST (col = 4) du patient Numero
function s = sessionFolder(PatientSelection, DataFolder, Numero, col)
id = num2str(PatientSelection{Numero, 1}); key = num2str(PatientSelection{Numero, col});
pd = dir(DataFolder); pd = pd([pd.isdir] & contains({pd.name}, id));
if isempty(pd), error('PlotMeasureIllustrations:noPatient', 'Dossier patient introuvable (n°%d).', Numero); end
sd = dir(fullfile(DataFolder, pd(1).name)); sd = sd([sd.isdir] & startsWith({sd.name}, key));
if isempty(sd), error('PlotMeasureIllustrations:noSession', 'Session introuvable (n°%d).', Numero); end
s = fullfile(DataFolder, pd(1).name, sd(1).name);
end

% Copie locale de la session, montée sur un lecteur virtuel (chemin court,
% sans accent), traitée par runProtocol01 ; seuls les essais demandés sont
% gardés
function T = processSession(Folder, src, tasks)
tmp = tempname; copyfile(src, tmp);
drv = '';
for L = 'TUVWXYZ'
    if ~isfolder([L ':\']), drv = [L ':']; break; end
end
system(sprintf('subst %s "%s"', drv, tmp));
oldDir = pwd;
cleanUp = onCleanup(@() cleanSession(drv, tmp, oldDir));
Folder.data = [drv '\'];
Trial = runProtocol01(Folder);
T = Trial(ismember({Trial.task}, tasks));
close all;
end

function cleanSession(drv, tmp, oldDir)
cd(oldDir);
system(sprintf('subst %s /d', drv));
if isfolder(tmp), rmdir(tmp, 's'); end
end

function t = getTrial(T, aliases)
t = T(find(ismember({T.task}, aliases), 1));
end

% Positions moyennes (mm, [3 x 1]) des marqueurs et marqueurs virtuels sur
% les frames demandées
function M = markersAt(t, frames)
M = struct();
for src = {'Marker', 'Vmarker'}
    for k = 1:numel(t.(src{1}))
        lab = t.(src{1})(k).label; tr = t.(src{1})(k).Trajectory.full;
        if isempty(lab) || isempty(tr), continue; end
        M.(lab) = 1000 * mean(tr(:, 1, frames), 3, 'omitnan');
    end
end
end

% Cycles [n x nCycles] d'un DOF (Joint.Euler) ; repli sur l'autre côté si
% vide (thorax, joint unique)
function c = cyc(E, cf, dof)
if ~isfield(E, cf) || isempty(E.(cf))
    if cf(1) == 'r', cf = 'lcycle'; else, cf = 'rcycle'; end
end
c = squeeze(E.(cf)(1, dof, :, :));
if isvector(c), c = c(:); end
c = c(:, any(~isnan(c), 1));
end

function w = wristOf(M, s)
w = (M.([s 'USP']) + M.([s 'RSP'])) / 2;
end

% Projections (mm) : sagittale (antérieur, vertical) et de face (droite du
% patient à gauche, vertical), dans le repère gravitaire Segment(8), origine O
function [prS, prF] = planes(t, O)
G = t.Segment(8).T.full(1:3, 1:3, 1);
X = G(:, 1); Y = G(:, 2); Z = G(:, 3);
prS = @(p) [dot(p - O, X), dot(p - O, Y)];
prF = @(p) [dot(p - O, -Z), dot(p - O, Y)];
end

% =========================================================================
%  GÉOMÉTRIE
% =========================================================================
function T = thoraxFrame(M)
Y = unit((M.CV7 + M.SJN) / 2 - (M.TV8 + M.SXS) / 2);
Z = unit(cross(M.SJN - (M.TV8 + M.SXS) / 2, M.CV7 - (M.TV8 + M.SXS) / 2));
X = unit(cross(Y, Z));
T = [X Y Z M.SJN];
end

function R = scapFrame(M, s)
AA = M.([s 'SAA']); RS = M.([s 'SRS']); IA = M.([s 'SIA']);
Z = unit(AA - RS); X = unit(cross(RS - IA, AA - IA)); Y = unit(cross(Z, X));
R = [X Y Z];
end

% R = Ry(y) Rx(x) Rz(z) : angles [y x z] en degrés (comme R2mobileYXZ_array3)
function e = eulerYXZ(R)
e = [atan2d(R(1, 3), R(3, 3)), asind(-R(2, 3)), atan2d(R(2, 1), R(2, 2))];
end

function u = unit(v)
u = v / norm(v);
end

% =========================================================================
%  SILHOUETTES (formes grises simples, un objet par partie du corps)
% =========================================================================
% Vue sagittale : tronc posé sur les marqueurs du rachis et du sternum, cou
% et tête dans le prolongement, jambes (assis sur un tabouret ou debout),
% bras : ballant par défaut, ou réel si arm = [épaule ; coude ; poignet]
function sagittalSilhouette(ax, M, pr, seated, side, arm)
skin = [0.80 0.80 0.80]; limbC = [0.86 0.86 0.86]; edgeC = [0.65 0.65 0.65];
g  = @(f) pr(M.(f));
c  = g('CV7'); t8 = g('TV8'); s1 = g('S1'); j = g('SJN'); x = g('SXS');
d  = (c - t8) / norm(c - t8);
dn = (d + [0 1]) / norm(d + [0 1]);
hip = s1 + [120 -90];
if seated
    knee = hip + [430 -10]; ankle = knee + [-20 -440]; toe = ankle + [150 -25];
    seatY = hip(2) - 75; floorY = ankle(2) - 30;
    fill(ax, hip(1) + [-200 230 230 -200], seatY + [0 0 -28 -28], [0.92 0.92 0.92], 'EdgeColor', edgeC);
    for lx = [hip(1) - 180, hip(1) + 200]
        fill(ax, lx + [0 22 22 0], [seatY - 28, seatY - 28, floorY, floorY], [0.92 0.92 0.92], 'EdgeColor', edgeC);
    end
else
    knee = hip + [15 -440]; ankle = knee + [-15 -430]; toe = ankle + [170 -20];
end
limb(ax, hip, knee, 140, skin); limb(ax, knee, ankle, 100, skin); limb(ax, ankle, toe, 60, skin);
P = c + [-6 0];
for f = {'TV3', 'TV5'}
    if isfield(M, f{1}), P = [P; g(f{1}) + [-6 0]]; end %#ok<AGROW>
end
P = [P; t8 + [-6 0]; s1 + [-6 0]; s1 + [30 -80]; hip + [130 -30]; x + [30 -170]; x + [8 -20]];
if isfield(M, 'SME'), P = [P; g('SME') + [6 0]]; end
P = [P; j + [6 0]];
fillSmooth(ax, P, skin);
nb1 = c + 0.10 * (j - c); nb2 = c + 0.80 * (j - c);
fill(ax, [nb1(1), nb1(1) + 95 * dn(1), nb2(1) + 95 * dn(1), nb2(1)], ...
         [nb1(2), nb1(2) + 95 * dn(2), nb2(2) + 95 * dn(2), nb2(2)], skin, 'EdgeColor', 'none');
headEllipse(ax, (nb1 + nb2) / 2 + 185 * dn, dn, skin);
if isempty(arm)
    if isfield(M, [side 'CAJ']), sh = g([side 'CAJ']); else, sh = c + 0.5 * (j - c) + [0 -40]; end
    elb = sh + [15 -290];
    if seated, wr = elb + [250 30]; else, wr = elb + [30 -250]; end
else
    sh = arm(1, :); elb = arm(2, :); wr = arm(3, :);
end
limb(ax, sh, elb, 85, limbC, edgeC); limb(ax, elb, wr, 70, limbC, edgeC);
end

% Vue de face : tronc entre les acromions et le bassin, cou, tête, jambes
% (assis), bras réels des deux côtés
function frontalSilhouette(ax, M, pr, armA, armB)
skin = [0.80 0.80 0.80]; limbC = [0.86 0.86 0.86]; edgeC = [0.65 0.65 0.65];
j = pr(M.SJN); s1 = pr(M.S1); ra = pr(M.RCAJ); la = pr(M.LCAJ);
hw = abs(ra(1) - la(1)) / 2; cx = (ra(1) + la(1)) / 2;
yW = s1(2) - 40;
for sg = [-1 1]
    hip = [cx + sg * 0.45 * hw, yW - 40];
    limb(ax, hip, hip + [sg * 15 -120], 150, skin);
    limb(ax, hip + [sg * 15 -120], hip + [sg * 25 -560], 100, skin);
end
yS = (ra(2) + la(2)) / 2;
P = [cx - 0.35 * hw, yS + 35; ra + [-15 5]; ra + [-25 -90]; [cx - 0.80 * hw, yW + 150]; [cx - 0.78 * hw, yW]; ...
     [cx + 0.78 * hw, yW]; [cx + 0.80 * hw, yW + 150]; la + [25 -90]; la + [15 5]; cx + 0.35 * hw, yS + 35];
if ra(1) > la(1), P(:, 1) = 2 * cx - P(:, 1); end
fillSmooth(ax, P, skin);
fill(ax, cx + [-45 45 45 -45], [j(2) - 10, j(2) - 10, j(2) + 110, j(2) + 110], skin, 'EdgeColor', 'none');
headEllipse(ax, [cx, j(2) + 200], [0 1], skin);
limb(ax, armA(1, :), armA(2, :), 85, limbC, edgeC); limb(ax, armA(2, :), armA(3, :), 70, limbC, edgeC);
limb(ax, armB(1, :), armB(2, :), 85, limbC, edgeC); limb(ax, armB(2, :), armB(3, :), 70, limbC, edgeC);
end

% Vue de dessus dans le repère du thorax : contour du tronc passant par le
% sternum, le rachis et les acromions, tête et bras en coupe
function transverseSilhouette(ax, M, tv)
skin = [0.82 0.82 0.82]; edgeC = [0.65 0.65 0.65];
front = max([tv(M.SJN); tv(M.SXS)], [], 1); back = min([tv(M.TV8); tv(M.CV7)], [], 1);
fr = front(2) + 20; bk = back(2) - 20;
pts = [0 fr];
for s = 'RL'
    sg = 1 - 2 * (s == 'L');
    aa = tv(M.([s 'SAA'])); ia = tv(M.([s 'SIA']));
    pts = [pts; 0.55 * aa(1), fr - 25; aa(1) + sg * 40, aa(2) + 20; aa(1) + sg * 35, aa(2) - 45; ...
           ia(1) + sg * 20, ia(2) - 30; 0.35 * ia(1), bk + 8]; %#ok<AGROW>
end
pts = [pts; 0 bk];
c0 = [0, (fr + bk) / 2];
[~, o] = sort(atan2(pts(:, 2) - c0(2), pts(:, 1) - c0(1)));
fillSmooth(ax, pts(o, :), skin);
for s = 'RL'
    sg = 1 - 2 * (s == 'L');
    disk(ax, tv(M.([s 'SAA'])) + [sg * 55, -15], 48, [0.88 0.88 0.88], edgeC);
end
disk(ax, [0, (tv(M.SJN) * [0; 1] + tv(M.CV7) * [0; 1]) / 2 - 10], 82, [0.74 0.74 0.74], 'none');
end

function headEllipse(ax, hc, dn, col)
a = atan2(dn(1), dn(2)); tt = linspace(0, 2 * pi, 80);
ex = 92 * cos(tt); ey = 112 * sin(tt);
fill(ax, hc(1) + ex * cos(a) + ey * sin(a), hc(2) - ex * sin(a) + ey * cos(a), col, 'EdgeColor', 'none');
end

function limb(ax, p1, p2, w, col, edgeC)
if nargin < 6, edgeC = 'none'; end
v = (p2 - p1) / norm(p2 - p1); nrm = [-v(2) v(1)] * w / 2;
fill(ax, [p1(1) + nrm(1), p2(1) + nrm(1), p2(1) - nrm(1), p1(1) - nrm(1)], ...
         [p1(2) + nrm(2), p2(2) + nrm(2), p2(2) - nrm(2), p1(2) - nrm(2)], col, 'EdgeColor', edgeC);
disk(ax, p1, w / 2, col, 'none'); disk(ax, p2, w / 2, col, 'none');
end

function disk(ax, c, r, col, edgeC)
t = linspace(0, 2 * pi, 60);
fill(ax, c(1) + r * cos(t), c(2) + r * sin(t), col, 'EdgeColor', edgeC);
end

% Contour fermé lissé (pchip périodique sur la longueur de corde)
function fillSmooth(ax, P, col)
k = size(P, 1);
Q = [P(end - 1:end, :); P; P(1:2, :)];
t = [0; cumsum(sqrt(sum(diff(Q).^2, 2)))];
S = interp1(t, Q, linspace(t(3), t(3 + k), 200), 'pchip');
fill(ax, S(:, 1), S(:, 2), col, 'EdgeColor', 'none');
end

% Arc de cercle de centre c entre les directions u et v (plan de la figure)
function drawArc(ax, c, u, v, r, col)
a1 = atan2(u(2), u(1)); a2 = atan2(v(2), v(1));
da = mod(a2 - a1 + pi, 2 * pi) - pi;
a = a1 + linspace(0, da, 50);
plot(ax, c(1) + r * cos(a), c(2) + r * sin(a), '-', 'Color', col, 'LineWidth', 2);
end

% =========================================================================
%  MISE EN FORME ET EXPORT
% =========================================================================
function sameScale(axs)
XL = cell2mat(get(axs(:), 'XLim')); YL = cell2mat(get(axs(:), 'YLim'));
span = max(diff(XL, 1, 2)) + 100;
for i = 1:numel(axs)
    xlim(axs(i), mean(XL(i, :)) + [-span span] / 2);
    ylim(axs(i), [min(YL(:, 1)) - 30, max(YL(:, 2)) + 30]);
end
end

function footnote(fig, s)
annotation(fig, 'textbox', [0 0 1 0.04], 'String', s, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontSize', 9, 'Interpreter', 'none');
end

% PNG + PDF vectoriel + SVG (Inkscape)
function exportAll(fig, base)
exportgraphics(fig, [base '.png'], 'Resolution', 150);
exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
set(fig, 'Renderer', 'painters');
print(fig, [base '.svg'], '-dsvg');
end

function s = capital(s)
s(1) = upper(s(1));
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
