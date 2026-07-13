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
    '18792',   'L', '2022', '2023'; ... % P1

    % '138603',   'R', '2023', '2024'; ...
    % '97186736', 'R', '2023', '2024'; ...
    % '107777',   'R', '2023', '2024'; ...
    % '7166',     'R', '2023', '2024'; ...
    % '97238605', 'R', '2023', '2024'; ...
    % '13617',    'R', '2023', '2024'; ...
    % '27523',    'R', '2023', '2023'; ...
    % '8589',     'R', '2023', '2024'; ...
};

% ResultsFolder : dossier où sont écrits les Excels de sortie. Le script se
%                 termine (cd) dans ce dossier une fois l'export terminé.
ResultsFolder = fullfile(fileparts(mfilename('fullpath')), 'Results');

% OutputFile : fichier Excel de sortie (contributions HT/GH/ST)
OutputFile = fullfile(ResultsFolder, 'HT_Contributions_Summary.xlsx');

% PatientInfosFile : fichier Excel de sortie (infos démographiques patients)
PatientInfosFile = fullfile(ResultsFolder, 'PatientInfos_Summary.xlsx');

