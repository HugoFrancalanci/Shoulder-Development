% -------------------------------------------------------------------------
% MULTI-PATIENT USER COMMANDS
% -------------------------------------------------------------------------
% Configuration lue par MAIN_MULTI_Protocol_01.m avant de lancer le
% traitement. Modifier ce fichier pour choisir les patients et le côté à
% traiter, sans toucher au script principal.
% -------------------------------------------------------------------------

% DataFolder : dossier racine contenant un sous-dossier par patient
%              (chaque sous-dossier patient contient lui-même un
%              sous-dossier par session, ex: une date PRE et une date POST)
DataFolder = 'C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\01_Data\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data';

% PatientSelection : {ID patient, côté à traiter, date PRE, date POST}
%   ID patient : identifiant retrouvé comme sous-chaîne du nom du dossier
%                patient 
%   Côté       : 1 = Gauche (L), 0 = Droit (R)
%                (accepte aussi 'R', 'L' ou 'RL' pour les deux côtés)
%   Date PRE/POST : date complète 'YYYYMMDD' (ex: '20231003') ou juste
%                l'année 'YYYY' (ex: '2023'). Le script prend le dossier 
%                de session dont le nom commence par cette valeur. Toujours 
%                renseigner les deux, même si le patient a plus de 2 sessions 
%                sur le disque : seules les dates indiquées ici sont traitées.
%                Attention : une année seule doit correspondre à une seule
%                session sur le disque, sinon c'est ambigu.
PatientSelection = { ...
    '18792', 'L', '2022', '2023'; ...
    '23370', 'L', '2022', '2022'; ...
    '53972', 'R', '2022', '2024'; ...
    '31463', 'R', '2022', '2024'; ...
};

% OutputFile : fichier Excel de sortie
OutputFile = fullfile(fileparts(mfilename('fullpath')), 'HT_Contributions_Summary.xlsx');

