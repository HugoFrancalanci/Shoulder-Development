% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Stockage par projet : copie dans le dossier du projet les
%                fichiers d'entrée d'une séance, tels qu'ils ont servi au
%                calcul : les C3D de Processed\ (marqueurs ; le centre de
%                rotation est recalculé par le pipeline, voir
%                Core/DefineSegments.m) et Session.xlsx. Les sorties du
%                rapport clinique (Report\, .mat de la séance) ne sont pas
%                copiées. Les originaux de Data\ ne sont jamais modifiés.
% -------------------------------------------------------------------------
% Inputs  : sessionPath (char) dossier de la séance dans Data\<patient>\
%           destination (char) Patients\<n°>_<ID>_<côté>\<PRE|POST> du projet
% Outputs : nCopies (double) nombre de fichiers copiés
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function nCopies = CopySessionInputs(sessionPath, destination)

if ~isfolder(destination), mkdir(destination); end
fichiers = dir(fullfile(sessionPath, 'Processed', '*.c3d'));
session  = dir(fullfile(sessionPath, 'Session.xlsx'));
fichiers = [fichiers; session];
for i = 1:numel(fichiers)
    copyfile(fullfile(fichiers(i).folder, fichiers(i).name), fullfile(destination, fichiers(i).name), 'f');
end
nCopies = numel(fichiers);

end
