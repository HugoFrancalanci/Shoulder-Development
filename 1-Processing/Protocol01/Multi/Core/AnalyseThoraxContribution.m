% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   October 2026 (repris de CorrelatePostureROM)
% -------------------------------------------------------------------------
% Description:   Contribution du thorax à l'élévation du bras (hypothèse H1
%                de l'article), flexion (ANALYTIC1) et scaption (ANALYTIC2),
%                PRE et POST. Thorax par rapport à la gravité.
%
%                1) Mouvement du thorax pendant le geste (feuille
%                   'Cinematique_thorax', exportée par
%                   ComputePostureFromDatabase) :
%                   - flexion / extension : position au repos (Start, contrôle
%                     vs inclinaison PRE), changement entre le repos et le pic
%                     d'élévation HG (Change > 0 = le tronc se redresse) :
%                     moyenne, IC 95 %, % qui se redressent, POST moins PRE
%                     apparié ; Change vs inclinaison PRE
%                   - inclinaison latérale au pic (TXlat_Change > 0 = le tronc
%                     penche du côté opposé au bras) : moyenne, IC 95 %, % qui
%                     penchent du côté opposé
%                2) Amplitude du thorax (feuille 'Cinematique', ROM du signal
%                   signé, flexion / extension et inclinaison latérale)
%                3) Vérification : HG moins HT (ROM et pic) vs changement du
%                   thorax (pente attendue proche de 1) et dispersion de HG
%                   moins HT entre patients. La moyenne de HG moins HT n'est
%                   pas la part du thorax (HT Cardan dans le plan du thorax,
%                   HG YXY élévation 3D) : seules la dispersion et la pente
%                   sont interprétées.
%
%                Pas de figure : les figures de l'article sont dans
%                PlotArticleFigures.
% -------------------------------------------------------------------------
% Inputs  : DataFile    (char) chemin vers Data_posture.xlsx
%           OutputFile  (char, optionnel) Excel de sortie, feuilles
%                       'Thorax_Contribution' et 'Thorax_Flexion' ; '' = pas
%                       d'export
% Outputs : ThxDesc     (struct array) HG moins HT et amplitude du thorax,
%                       une ligne par métrique/tâche/groupe
%           ThxFlex     (struct array) mouvement du thorax au pic, une ligne
%                       par tâche/groupe
% -------------------------------------------------------------------------
% Dependencies : PostureUtils
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [ThxDesc, ThxFlex] = AnalyseThoraxContribution(DataFile, OutputFile)

if nargin < 2, OutputFile = ''; end
U = PostureUtils;
D = U.defs();

P    = U.readSheet(DataFile, 'Posture');
Kthx = U.readSheet(DataFile, 'Cinematique');      % ROM du thorax (signal signé)
Km   = arrayfun(@(md) U.readSheet(DataFile, md.sheet), D.metric, 'UniformOutput', false);

ThxDesc = [];
for iM = 1:numel(D.metric)
    ThxDesc = [ThxDesc, describeHGminusHT(U, D, Km{iM}, Kthx, D.metric(iM))]; %#ok<AGROW>
end
ThxFlex = thoraxMotion(U, D, DataFile, P, Km);

if ~isempty(OutputFile)
    writetable(struct2table(ThxDesc), OutputFile, 'Sheet', 'Thorax_Contribution');
    if ~isempty(ThxFlex)
        writetable(struct2table(ThxFlex), OutputFile, 'Sheet', 'Thorax_Flexion');
    end
    disp(['Feuilles Thorax_Contribution et Thorax_Flexion écrites : ', OutputFile]);
end
end

% =========================================================================
%  HG MOINS HT ET AMPLITUDE DU THORAX (tous les patients de la feuille)
% =========================================================================
function R = describeHGminusHT(U, D, K, Kthx, md)
R = struct('Metric', {}, 'Task', {}, 'Movement', {}, 'Group', {}, 'n', {}, ...
    'HT_mean', {}, 'HT_SD', {}, 'HG_mean', {}, 'HG_SD', {}, ...
    'D_mean', {}, 'D_SD', {}, 'Pct_absD_gt10', {}, ...
    'TX_mean', {}, 'TX_SD', {}, 'r_D_TX', {}, 'p_D_TX', {}, ...
    'TXlat_mean', {}, 'TXlat_SD', {}, 'r_D_TXlat', {}, 'p_D_TXlat', {});
numK = U.getCol(K, 'Numero');
for td = D.task
    for g = 1:numel(D.groups)
        colOf = @(joint) sprintf('%s_%s_%s%s', td.key, md.key, joint, D.grpSuffix{g});
        hg = U.getCol(K, colOf('Humerogravitaire'));
        ht = U.getCol(K, colOf('Humerothoracique'));
        tx = U.alignCol(Kthx, sprintf('%s_ROM_Thoracique%s', td.key, D.grpSuffix{g}), numK);
        latName = sprintf('%s_ROM_ThoraciqueLateral%s', td.key, D.grpSuffix{g});
        if U.hasCol(Kthx, latName), tl = U.alignCol(Kthx, latName, numK); else, tl = NaN(size(hg)); end
        v = ~isnan(hg) & ~isnan(ht);
        d = hg(v) - ht(v);
        [rT, pT] = U.pearsonP(hg(v & ~isnan(tx)) - ht(v & ~isnan(tx)), tx(v & ~isnan(tx)));
        [rL, pL] = U.pearsonP(hg(v & ~isnan(tl)) - ht(v & ~isnan(tl)), tl(v & ~isnan(tl)));
        R(end + 1) = struct('Metric', md.name, 'Task', td.name, 'Movement', td.label, 'Group', D.groups{g}, ...
            'n', sum(v), 'HT_mean', mean(ht(v)), 'HT_SD', std(ht(v)), 'HG_mean', mean(hg(v)), 'HG_SD', std(hg(v)), ...
            'D_mean', mean(d), 'D_SD', std(d), 'Pct_absD_gt10', 100 * mean(abs(d) > 10), ...
            'TX_mean', mean(tx, 'omitnan'), 'TX_SD', std(tx, 'omitnan'), 'r_D_TX', rT, 'p_D_TX', pT, ...
            'TXlat_mean', mean(tl, 'omitnan'), 'TXlat_SD', std(tl, 'omitnan'), 'r_D_TXlat', rL, 'p_D_TXlat', pL); %#ok<AGROW>
    end
end
end

% =========================================================================
%  MOUVEMENT DU THORAX AU PIC D'ÉLÉVATION HG
% =========================================================================
% Feuille 'Cinematique_thorax' : <tâche>_TXflex_<Start|Change>_<Pre|Post>
% (négatif = flexion, positif = extension) et <tâche>_TXlat_Change_<...>
% (> 0 = le tronc penche du côté opposé au bras). Appariement par Numero
% sur la feuille Posture.
function R = thoraxMotion(U, D, DataFile, P, Km)
R = [];
try
    Kt = U.readSheet(DataFile, 'Cinematique_thorax');
catch
    disp('Feuille Cinematique_thorax absente : mouvement du thorax ignoré.');
    return;
end
numP = U.getCol(P, 'Numero');
incl = U.getCol(P, 'Inclinaison_thoracique_Pre');
latKey = @(td, g) sprintf('%s_TXlat_Change%s', td.key, D.grpSuffix{g});
hasLat = U.hasCol(Kt, latKey(D.task(1), 1));

R = struct('Task', {}, 'Movement', {}, 'Group', {}, 'n', {}, ...
    'Start_mean', {}, 'Start_SD', {}, 'r_Start_incl', {}, 'p_Start_incl', {}, ...
    'Change_mean', {}, 'Change_CI95_low', {}, 'Change_CI95_high', {}, 'p_Change_vs0', {}, 'Pct_extension', {}, ...
    'ChangePOSTminusPRE_mean', {}, 'ChangePOSTminusPRE_CI95_low', {}, 'ChangePOSTminusPRE_CI95_high', {}, ...
    'p_ChangePOSTminusPRE', {}, ...
    'ROM_slope_HGminusHT_per_degChange', {}, 'ROM_r_HGminusHT_Change', {}, 'ROM_p_HGminusHT_Change', {}, ...
    'Pic_slope_HGminusHT_per_degChange', {}, 'Pic_r_HGminusHT_Change', {}, 'Pic_p_HGminusHT_Change', {}, ...
    'slope_Change_per_degIncl', {}, 'r_Change_incl', {}, 'p_Change_incl', {}, ...
    'Lat_Change_mean', {}, 'Lat_Change_CI95_low', {}, 'Lat_Change_CI95_high', {}, 'p_Lat_Change_vs0', {}, ...
    'Pct_lean_away', {}, ...
    'ROM_slope_HGminusHT_per_degLatChange', {}, 'ROM_r_HGminusHT_LatChange', {}, 'ROM_p_HGminusHT_LatChange', {}, ...
    'Pic_slope_HGminusHT_per_degLatChange', {}, 'Pic_r_HGminusHT_LatChange', {}, 'Pic_p_HGminusHT_LatChange', {});

for td = D.task
    chPre = [];
    for g = 1:numel(D.groups)
        st = U.alignCol(Kt, sprintf('%s_TXflex_Start%s', td.key, D.grpSuffix{g}), numP);
        ch = U.alignCol(Kt, sprintf('%s_TXflex_Change%s', td.key, D.grpSuffix{g}), numP);
        if hasLat, lc = U.alignCol(Kt, latKey(td, g), numP); else, lc = NaN(size(ch)); end
        k = numel(R) + 1;
        R(k).Task = td.name; R(k).Movement = td.label; R(k).Group = D.groups{g};
        v = ~isnan(ch); R(k).n = sum(v);

        % Position au repos (contrôle : plus incliné = thorax plus fléchi)
        R(k).Start_mean = mean(st, 'omitnan'); R(k).Start_SD = std(st, 'omitnan');
        vs = ~isnan(st) & ~isnan(incl);
        [R(k).r_Start_incl, R(k).p_Start_incl] = U.pearsonP(incl(vs), st(vs));

        % Extension au pic, et POST moins PRE apparié
        [R(k).Change_mean, R(k).Change_CI95_low, R(k).Change_CI95_high, R(k).p_Change_vs0] = U.meanCI(ch(v));
        R(k).Pct_extension = 100 * mean(ch(v) > 0);
        [R(k).ChangePOSTminusPRE_mean, R(k).ChangePOSTminusPRE_CI95_low, ...
         R(k).ChangePOSTminusPRE_CI95_high, R(k).p_ChangePOSTminusPRE] = deal(NaN);
        if g == 1
            chPre = ch;
        else
            vp = ~isnan(chPre) & ~isnan(ch);
            [R(k).ChangePOSTminusPRE_mean, R(k).ChangePOSTminusPRE_CI95_low, ...
             R(k).ChangePOSTminusPRE_CI95_high, R(k).p_ChangePOSTminusPRE] = U.meanCI(ch(vp) - chPre(vp));
        end

        % Vérification : HG moins HT vs extension et vs inclinaison latérale
        for iM = 1:numel(D.metric)
            md = D.metric(iM);
            colOf = @(joint) sprintf('%s_%s_%s%s', td.key, md.key, joint, D.grpSuffix{g});
            Dd = U.alignCol(Km{iM}, colOf('Humerogravitaire'), numP) - U.alignCol(Km{iM}, colOf('Humerothoracique'), numP);
            vd = ~isnan(Dd) & ~isnan(ch);
            R(k).([md.name, '_slope_HGminusHT_per_degChange']) = U.slopeTest(ch(vd), Dd(vd));
            [R(k).([md.name, '_r_HGminusHT_Change']), R(k).([md.name, '_p_HGminusHT_Change'])] = U.pearsonP(ch(vd), Dd(vd));
            vl = ~isnan(Dd) & ~isnan(lc);
            R(k).([md.name, '_slope_HGminusHT_per_degLatChange']) = U.slopeTest(lc(vl), Dd(vl));
            [R(k).([md.name, '_r_HGminusHT_LatChange']), R(k).([md.name, '_p_HGminusHT_LatChange'])] = U.pearsonP(lc(vl), Dd(vl));
        end

        % Inclinaison latérale au pic
        [R(k).Lat_Change_mean, R(k).Lat_Change_CI95_low, R(k).Lat_Change_CI95_high, R(k).p_Lat_Change_vs0] = ...
            U.meanCI(lc(~isnan(lc)));
        R(k).Pct_lean_away = 100 * mean(lc(~isnan(lc)) > 0);
        if ~hasLat, R(k).Pct_lean_away = NaN; end

        % Les patients plus inclinés se redressent-ils davantage ?
        vi = ~isnan(ch) & ~isnan(incl);
        R(k).slope_Change_per_degIncl = U.slopeTest(incl(vi), ch(vi));
        [R(k).r_Change_incl, R(k).p_Change_incl] = U.pearsonP(incl(vi), ch(vi));
    end
end
end
