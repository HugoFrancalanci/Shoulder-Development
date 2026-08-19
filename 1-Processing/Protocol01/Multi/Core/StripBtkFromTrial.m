% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   August 2026
% -------------------------------------------------------------------------
% Description:   Retire le champ .btk de chaque élément de Trial avant
%                sauvegarde dans PatientDatabase.mat (voir userCommands_Multi.m
%                SaveDatabase). .btk est un handle brut vers l'acquisition
%                C3D ouverte par BTK (objet C++ wrappé), pas une structure
%                de données : il ne se sauvegarde pas de façon réutilisable
%                dans un .mat, et redevient invalide après rechargement.
%
%                Tout le reste de Trial (.Marker, .Vmarker, .Segment,
%                .Joint, .Rcycle/.Lcycle, .SHR, .task, .file...) est du
%                texte/numérique classique et se sauvegarde normalement -
%                c'est déjà tout ce dont une analyse posturale/clinique/
%                fonctionnelle a besoin (les valeurs cinématiques sont
%                déjà calculées à ce stade). Seule une fonction qui a
%                besoin de relire le C3D brut (ex: DefineSegments.m pour
%                SCoRE, ComputeDataAvailability.m pour l'EMG) ne peut plus
%                fonctionner sur un Trial rechargé depuis PatientDatabase.mat.
% -------------------------------------------------------------------------
% Inputs  : Trial (struct array) depuis runProtocol01
% Outputs : Trial (struct array) identique, sans le champ .btk
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Trial = StripBtkFromTrial(Trial)
if isfield(Trial, 'btk')
    Trial = rmfield(Trial, 'btk');
end
end
