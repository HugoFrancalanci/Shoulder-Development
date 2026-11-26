% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Convention de signe des courbes et des valeurs (HG, HT, GH,
%                ST, TX), commune à toutes les fonctions qui lisent les
%                angles d'Euler du DOF principal (Compute*Contributions,
%                ComputeCurveQualityFromDatabase, CheckCurvesFromDatabase,
%                PlotMeanCurvesFromDatabase, ExportSHRCurvesFromDatabase).
%                Remplace abs() et la correction des courbes ST / TX
%                inversées (ApplyInversionCorrectionSTTX, retirée le
%                26.11.2026).
%
%                Problème : abs() replie toute courbe qui passe par zéro
%                (thorax en flexion de -10 à +5 deg, ST qui part d'un repos
%                positif, bras qui démarre légèrement derrière zéro) : forme
%                en V ou en W, amplitude sous-estimée, sens biomécanique
%                perdu (toutes les courbes vont vers le haut).
%
%                Constat sur les 207 épaules (registre, 26.11.2026) : le
%                sens du mouvement du DOF principal est fixé par
%                l'articulation, la tâche et le côté (96 à 100 % des
%                courbes ; les autres sont des sauts de cardan, des
%                élévations quasi nulles ou un vrai mouvement inverse du
%                thorax). Il suffit donc d'un signe fixe :
%
%                  courbe anatomique  x = Miroir(côté) * brut, chaque cycle
%                     ramené entre -180 et 180 deg autour de sa médiane
%                     (Orientation.recentre : tours de 360 deg)
%                     convention du côté droit (ISB) pour les deux côtés :
%                     seul HT en flexion (DOF3 Z) a le signe opposé à
%                     gauche ; signe conservé, jamais replié. Exemples :
%                     ST rotation latérale (vers le haut) négative, HT
%                     élévation en scaption négative, HT flexion positive.
%                  sens du mouvement  s = Sens(articulation, tâche), +1 / -1
%                     dans cette convention ; NaN = pas de sens fixe
%                     (thorax en rotation axiale).
%                  amplitude = max - min de s * x sur le cycle retenu
%                     (BestCycle.range) : jamais repliée.
%                  pic       = valeur atteinte dans le sens du mouvement,
%                     max de s * x (BestCycle.peak), positive.
%                Les valeurs (amplitude, pic) restent des grandeurs
%                positives ; les courbes gardent le signe anatomique.
%                Une courbe dont l'excursion va contre Sens est gardée telle
%                quelle (vrai mouvement inverse ou artefact) et signalée par
%                les contrôles de forme (BestCycle.shape, qualité des courbes).
%
%                Validation : Multi/README.md, section « Convention de signe ».
% -------------------------------------------------------------------------
% Usage   : x = Orientation.anat(brut, art, tache, cote)  [points x cycles]
%           s = Orientation.sens(art, tache)              (+1, -1 ou NaN)
%           y = Orientation.oriente(brut, art, tache, cote)  s * x (NaN : x)
%             art   : 'HG' | 'HT' | 'GH' | 'ST' | 'TX'
%             tache : 'ANALYTIC1'...'ANALYTIC4' (ou indice 1 à 4)
%             cote  : 'R' | 'L'
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

classdef Orientation

properties (Constant)
    Taches = {'ANALYTIC1', 'ANALYTIC2', 'ANALYTIC3', 'ANALYTIC4'};
    % Signe appliqué au côté gauche pour revenir à la convention du côté
    % droit, par tâche (ANALYTIC1 à 4)
    MiroirGauche = struct('HG', [1 1 1 1], 'HT', [-1 1 1 1], 'GH', [1 1 1 1], 'ST', [1 1 1 1], 'TX', [1 1 1 1]);
    % Sens du mouvement dans cette convention, par tâche : élévations
    % (flexion, scaption) puis rotations (externe, interne)
    Sens = struct('HG', [-1 -1 -1 1], 'HT', [1 -1 -1 1], 'GH', [1 -1 -1 1], ...
                  'ST', [-1 -1 -1 1], 'TX', [1 1 NaN NaN]);
    % Mesuré le 26.11.2026 sur les 207 épaules (cycle retenu, pré et post,
    % 414 courbes par côté et tâche) : part des courbes dans ce sens
    %   HG  élévations 99 %, aucune ne passe par zéro ; RE 76 %, RI 94 %
    %   HT  99 à 100 % (sauts de cardan n°118, 177 ; élévation quasi nulle n°12, 84, 34)
    %   GH  96 à 99 % ; ST 99 à 100 % ; TX élévations 95 à 98 %
    %   TX  rotations 60 à 75 % : pas de sens fixe (NaN)
end

methods (Static)

function x = anat(brut, art, tache, cote)
x = Orientation.recentre(brut);
if isempty(x), return; end
if strcmp(cote, 'L')
    x = Orientation.MiroirGauche.(art)(Orientation.indice(tache)) * x;
end
end

function s = sens(art, tache)
s = Orientation.Sens.(art)(Orientation.indice(tache));
end

function y = oriente(brut, art, tache, cote)
y = Orientation.anat(brut, art, tache, cote);
s = Orientation.sens(art, tache);
if ~isnan(s), y = s * y; end
end

% Cycle décalé d'un tour : chaque colonne (cycle) est ramenée d'un multiple
% de 360 deg pour que sa médiane soit entre -180 et 180 (GH en rotation
% interne stocké vers 350 deg au lieu de -10 deg). Forme inchangée, donc
% amplitude et rotation depuis le départ inchangées.
function x = recentre(x)
if isempty(x), return; end
x = x - 360 * round(median(x, 1, 'omitnan') / 360);
end

function i = indice(tache)
if isnumeric(tache), i = tache; return; end
i = find(strcmp(Orientation.Taches, tache), 1);
if isempty(i), error('Orientation:tache', 'Tâche inconnue : %s', tache); end
end

end
end
