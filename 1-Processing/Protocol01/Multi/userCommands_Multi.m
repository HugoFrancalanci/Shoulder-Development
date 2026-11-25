% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   August 2026
% -------------------------------------------------------------------------
% Configuration lue par MAIN_MULTI_Protocol_01.m avant de lancer le
% traitement. Modifier ce fichier pour choisir les patients et le côté à
% traiter, sans toucher au script principal.
% -------------------------------------------------------------------------

% DataFolder : dossier racine contenant un sous-dossier par patient.
% Choisi automatiquement selon l'ordinateur
switch getenv('COMPUTERNAME')
    case 'FRANCALANCIPHD'
        DataFolder = 'C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\01_Data\01_Etudes\E02_Classification_rTSA\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data';
    case 'CD-8K18T74'
        DataFolder = 'C:\Users\francala\OneDrive - Université de Genève\PhD Hugo\05_Ressources\01_Data\01_Etudes\E02_Classification_rTSA\Clinique\Données\KLAB-UPPERLIMB-PROTOCOL01\Data';
    otherwise
        DataFolder = ''; % machine inconnue : demandé via fenêtre au lancement
end

% RegistreURL : adresse du registre local (Registre_Epaule, python serve.py).
% Il fournit la cohorte (PatientSelection ci-dessous lue sur le site) et
% reçoit les résultats en fin de run (ExportRegistre). '' pour s'en passer ;
% s'il ne répond pas (fermé, autre machine), la liste écrite ci-dessous sert.
RegistreURL = 'http://127.0.0.1:8765';

% ProjectCode : code du projet du registre (page Projets). Le registre donne
% les épaules retenues par ce projet (critères et exclusions) avec leur
% numéro ; le run est rangé dans ProjectsRoot\<ProjectCode> (plus bas).
% 'COHORTE' = toutes les épaules du registre (run de référence lu par le
% site). EPAULE_PROJET (variable d'environnement) le remplace pour un essai.
ProjectCode = 'COHORTE';
if ~isempty(getenv('EPAULE_PROJET')), ProjectCode = getenv('EPAULE_PROJET'); end

% PatientSelection : {ID patient, côté à traiter, date PRE, date POST}
%   ID patient : identifiant retrouvé comme sous-chaîne du nom du dossier
%                patient 
%   Côté       : 1 = Gauche (L), 0 = Droit (R)
%   Date PRE/POST : date complète 'YYYYMMDD' (ex: '20231003') ou juste
%                l'année 'YYYY' (ex: '2023'). Le script prend le dossier 
%                de session dont le nom commence par cette valeur.
PatientSelection = { ...
    '18792', 'L', '2022', '2023'; ... % 1
    '23370', 'L', '20220523', '20221213'; ... % 2
    '75042', 'R', '2022', '2023'; ... % 3
    '30432', 'R', '2022', '2025'; ... % 4
    '356971', 'R', '2022', '2023'; ... % 5
    '416617', 'R', '2022', '2023'; ... % 6
    '10102', 'R', '2022', '2023'; ... % 7
    '399423', 'R', '20220623', '20231010'; ... % 8
    '124681', 'L', '2022', '2023'; ... % 9
    '321022', 'R', '2022', '2023'; ... % 10
    '496545', 'R', '2022', '2024'; ... % 11
    '165415', 'R', '2022', '2023'; ... % 12
    '605904', 'R', '2022', '2023'; ... % 13
    '7375', 'L', '2022', '2023'; ... % 14
    '265244', 'R', '2022', '2023'; ... % 15
    '728495', 'L', '20220929', '20231107'; ... % 16
    '166206', 'R', '2022', '2023'; ... % 17
    '920506', 'R', '2022', '2023'; ... % 18
    '865139', 'R', '2022', '2023'; ... % 19
    '53972', 'R', '2022', '2024'; ... % 20
    '97438620', 'L', '2022', '2023'; ... % 21
    '1081778', 'R', '20221020', '20231019'; ... % 22
    '232367', 'L', '2022', '2023'; ... % 23
    '27148', 'L', '2022', '2023'; ... % 24
    '283057', 'L', '2022', '2023'; ... % 25
    '185255', 'R', '2022', '2023'; ... % 26
    '733366', 'L', '2022', '2023'; ... % 27
    '135407', 'L', '20221110', '20231114'; ... % 28
    '937635', 'R', '2022', '2023'; ... % 29
    '31463', 'R', '2022', '2024'; ... % 30
    '371245', 'R', '20221117', '20231212'; ... % 31
    '104625', 'L', '2022', '2024'; ... % 32
    '97629279', 'R', '2022', '2023'; ... % 33
    '397885', 'R', '2022', '2023'; ... % 34
    '35477', 'L', '2022', '2024'; ... % 35
    '562760', 'L', '2022', '2024'; ... % 36
    '394183', 'L', '2023', '2024'; ... % 37
    '508762', 'R', '2023', '2024'; ... % 38
    '97573449', 'R', '2023', '2024'; ... % 39
    '303574', 'L', '2023', '2024'; ... % 40
    '138603', 'R', '2023', '2024'; ... % 41
    '97186736', 'R', '2023', '2024'; ... % 42
    '107777', 'R', '2023', '2024'; ... % 43
    '7166', 'R', '20230209', '20240319'; ... % 44
    '97238605', 'R', '2023', '2024'; ... % 45
    '13617', 'R', '2023', '2024'; ... % 46
    '27523', 'R', '20230328', '20240514'; ... % 47
    '8589', 'R', '2023', '2024'; ... % 48
    '973018', 'R', '2023', '2024'; ... % 49
    '135407', 'R', '20230411', '20240430'; ... % 50
    '97865728', 'L', '2023', '2024'; ... % 51
    '97333474', 'L', '2023', '2024'; ... % 52
    '53789', 'L', '2023', '2024'; ... % 53
    '97492179', 'L', '2023', '2024'; ... % 54
    '3676', 'R', '2023', '2024'; ... % 55
    '372287', 'L', '2023', '2024'; ... % 56
    '146544', 'R', '2023', '2024'; ... % 57
    '727530', 'R', '2023', '2024'; ... % 58
    '125865', 'L', '2023', '2024'; ... % 59
    '79823', 'R', '2023', '2024'; ... % 60
    '37092', 'L', '2023', '2024'; ... % 61
    '371245', 'L', '20230613', '20240910'; ... % 62
    '977799', 'R', '2023', '2024'; ... % 63
    '609367', 'L', '2023', '2024'; ... % 64
    '301190', 'L', '2023', '2024'; ... % 65
    '211673', 'R', '2023', '2024'; ... % 66
    '471512', 'L', '2023', '2024'; ... % 67
    '340724', 'R', '2023', '2024'; ... % 68
    '132227', 'L', '2023', '2024'; ... % 69
    '98868156', 'L', '2023', '2024'; ... % 70
    '151607', 'R', '20230914', '20241203'; ... % 71
    '575232', 'R', '2023', '2024'; ... % 72
    '426335', 'R', '2023', '2025'; ... % 73
    '265219', 'L', '2023', '2024'; ... % 74
    '98638206', 'L', '2023', '2024'; ... % 75
    '736691', 'R', '2023', '2024'; ... % 76
    '944315', 'R', '2023', '2025'; ... % 77
    '178816', 'L', '2023', '2024'; ... % 78
    '159676', 'L', '2023', '2024'; ... % 79
    '17081', 'R', '2023', '2024'; ... % 80
    '97137559', 'R', '2023', '2024'; ... % 81
    '279782', 'L', '2023', '2024'; ... % 82
    '97751608', 'L', '2023', '2025'; ... % 83
    '227712', 'R', '2023', '2025'; ... % 84
    '59006', 'L', '2023', '2024'; ... % 85
    '18175', 'R', '2023', '2025'; ... % 86
    '73563', 'R', '2023', '2024'; ... % 87
    '97044379', 'R', '2023', '2024'; ... % 88
    '27523', 'L', '20231219', '20250121'; ... % 89
    '151607', 'L', '20240109', '20260108'; ... % 90
    '376804', 'R', '2024', '2025'; ... % 91
    '98779103', 'R', '2024', '2025'; ... % 92
    '846648', 'R', '2024', '2025'; ... % 93
    '977471', 'R', '2024', '2025'; ... % 94
    '98645431', 'R', '2024', '2025'; ... % 95
    '593818', 'R', '2024', '2025'; ... % 96
    '96054868', 'L', '2024', '2025'; ... % 97
    '108260', 'R', '2024', '2025'; ... % 98
    '428051', 'R', '2024', '2025'; ... % 99
    '97396479', 'L', '2024', '2025'; ... % 100
    '161051', 'R', '2024', '2025'; ... % 101
    '408557', 'L', '2024', '2025'; ... % 102
    '735715', 'L', '20240312', '20250619'; ... % 103
    '224427', 'R', '2024', '2025'; ... % 104
    '792089', 'L', '2024', '2025'; ... % 105
    '320829', 'R', '2024', '2025'; ... % 106
    '19922', 'R', '2024', '2025'; ... % 107
    '97078784', 'L', '2024', '2025'; ... % 108
    '102587', 'L', '2024', '2025'; ... % 109
    '137840', 'R', '2024', '2025'; ... % 110
    '98722678', 'L', '2024', '2025'; ... % 111
    '949121', 'R', '2024', '2025'; ... % 112
    '247112', 'R', '2024', '2025'; ... % 113
    '844544', 'R', '2024', '2025'; ... % 114
    '589725', 'L', '2024', '2025'; ... % 115
    '418338', 'R', '2024', '2025'; ... % 116
    '728495', 'R', '20240611', '20250826'; ... % 117
    '105745', 'L', '2024', '2025'; ... % 118
    '97047208', 'R', '2024', '2025'; ... % 119
    '91448', 'L', '2024', '2025'; ... % 120
    '1037973', 'L', '2024', '2025'; ... % 121
    '97516068', 'R', '2024', '2025'; ... % 122
    '32981', 'R', '2024', '2025'; ... % 123
    '98938674', 'R', '2024', '2025'; ... % 124
    '342134', 'R', '2024', '2025'; ... % 125
    '309357', 'R', '20240718', '20251113'; ... % 126
    '739322', 'L', '2024', '2025'; ... % 127
    '841306', 'L', '2024', '2025'; ... % 128
    '196276', 'L', '2024', '2025'; ... % 129
    '84788', 'R', '2024', '2025'; ... % 130
    '97185403', 'L', '20240829', '20251111'; ... % 131
    '108340', 'R', '2024', '2025'; ... % 132
    '364239', 'L', '2024', '2025'; ... % 133
    '122206', 'L', '20240912', '20251014'; ... % 134
    '351538', 'R', '2024', '2025'; ... % 135
    '727608', 'R', '2024', '2025'; ... % 136
    '309124', 'R', '2024', '2025'; ... % 137
    '403855', 'R', '2024', '2025'; ... % 138
    '617113', 'R', '2024', '2025'; ... % 139
    '78323', 'L', '2024', '2025'; ... % 140
    '150695', 'R', '2024', '2025'; ... % 141
    '634964', 'R', '20241008', '20251118'; ... % 142
    '95059', 'R', '2024', '2025'; ... % 143
    '137512', 'R', '2024', '2025'; ... % 144
    '206708', 'R', '2024', '2025'; ... % 145
    '1081453', 'R', '2024', '2025'; ... % 146
    '97206595', 'R', '2024', '2025'; ... % 147
    '58471', 'R', '2024', '2026'; ... % 148
    '270331', 'L', '2024', '2025'; ... % 149
    '869743', 'R', '2024', '2026'; ... % 150
    '408670', 'R', '2024', '2025'; ... % 151
    '567097', 'R', '20241210', '20260120'; ... % 152
    '86669', 'L', '2024', '2026'; ... % 153
    '501057', 'R', '2024', '2026'; ... % 154
    '4895', 'L', '2024', '2026'; ... % 155
    '96044917', 'R', '2025', '2026'; ... % 156
    '236839', 'L', '2025', '2026'; ... % 157
    '565328', 'R', '2025', '2026'; ... % 158
    '347304', 'L', '2025', '2026'; ... % 159
    '218604', 'R', '2025', '2026'; ... % 160
    '135853', 'L', '2025', '2026'; ... % 161
    '96080264', 'L', '2025', '2026'; ... % 162
    '97150272', 'R', '20250311', '20260217'; ... % 163
    '558792', 'R', '2025', '2026'; ... % 164
    '511398', 'L', '2025', '2026'; ... % 165
    '549386', 'L', '2025', '2026'; ... % 166
    '423', 'L', '2025', '2026'; ... % 167
    '98723993', 'L', '2025', '2026'; ... % 168
    '977846', 'L', '2025', '2026'; ... % 169
    '97133054', 'L', '2025', '2026'; ... % 170
    '513344', 'L', '20250401', '20260428'; ... % 171
    '14061', 'R', '2025', '2026'; ... % 172
    '155208', 'L', '2025', '2026'; ... % 173
    '229421', 'L', '2025', '2026'; ... % 174
    '589478', 'L', '20250415', '20260428'; ... % 175
    '958013', 'L', '20250429', '20260507'; ... % 176
    '98799235', 'R', '2025', '2026'; ... % 177
    '473433', 'R', '2025', '2026'; ... % 178
    '728109', 'R', '2025', '2026'; ... % 179
    '307818', 'L', '2025', '2026'; ... % 180
    '66072', 'R', '2025', '2026'; ... % 181
    '762166', 'R', '2025', '2026'; ... % 182
    '102356', 'L', '2025', '2026'; ... % 183
    '97138429', 'R', '2025', '2026'; ... % 184
    '80941', 'R', '2025', '2026'; ... % 185
    '869980', 'R', '2025', '2026'; ... % 186
    '570037', 'R', '2025', '2026'; ... % 187
    '99007140', 'L', '2025', '2026'; ... % 188
    '226091', 'R', '2025', '2026'; ... % 189
    '97718970', 'R', '20250429', '20260908'; ... % 190
    '97718970', 'L', '20250923', '20260908'; ... % 191
    '97026904', 'R', '2025', '2026'; ... % 192
    '260554', 'R', '2025', '2026'; ... % 193
    '97209231', 'L', '20250710', '20261006'; ... % 194
    '196956', 'R', '2025', '2026'; ... % 195
    '533941', 'R', '2025', '2026'; ... % 196
    '98034326', 'R', '2025', '2026'; ... % 197
    '161464', 'L', '2025', '2026'; ... % 198
    '131995', 'R', '2024', '2026'; ... % 199
    '589478', 'R', '20251007', '20261020'; ... % 200
    '400634', 'L', '2025', '2026'; ... % 201
    '43746', 'R', '2025', '2026'; ... % 202
    '461957', 'R', '2025', '2026'; ... % 203
    '97050204', 'R', '2025', '2026'; ... % 204
    '36535', 'L', '2025', '2026'; ... % 205
    '2269', 'R', '2025', '2026'; ... % 206
    };

% PatientNumbers : numéro du registre de chaque ligne de PatientSelection
% (dossiers Patients\<n°>_<ID>_<côté> et colonne Numero des résultats). La
% liste ci-dessus est la cohorte complète dans l'ordre des numéros.
PatientNumbers = (1:size(PatientSelection, 1))';

% Épaules du projet lues sur le registre (nouvelles épaules comprises). Si le
% registre ne répond pas, la liste ci-dessus sert, pour COHORTE seulement :
% un autre projet a besoin du registre pour connaître ses épaules.
if ~isempty(RegistreURL)
    try
        Reg = webread([RegistreURL, '/api/matlab/patient_selection'], 'projet', ProjectCode, weboptions('Timeout', 3));
        ok = isstruct(Reg) && all(isfield(Reg, {'numero', 'id', 'cote', 'pre', 'post'}));
    catch ME
        Reg = struct('erreur', ['registre injoignable (', ME.message, ')']); ok = false;
    end
    if ok
        PatientSelection = [{Reg.id}', {Reg.cote}', {Reg.pre}', {Reg.post}'];
        PatientNumbers   = [Reg.numero]';
        fprintf('Projet %s : %d épaules lues sur le registre\n', ProjectCode, size(PatientSelection, 1));
    elseif strcmpi(ProjectCode, 'COHORTE')
        fprintf('Registre : %s, liste de userCommands_Multi.m gardée (%d épaules)\n', ...
            char(strjoin(string(struct2cell(Reg)), ' ')), size(PatientSelection, 1));
    else
        error('Projet %s : épaules non lues sur le registre (%s). Lancer le registre ou choisir ProjectCode = ''COHORTE''.', ...
            ProjectCode, char(strjoin(string(struct2cell(Reg)), ' ')));
    end
end

% EPAULE_LIGNES (variable d'environnement, ex. '1:3') : essai sur quelques
% lignes de PatientSelection (chaque épaule garde son numéro du registre)
if ~isempty(getenv('EPAULE_LIGNES'))
    lignesEssai      = str2num(getenv('EPAULE_LIGNES')); %#ok<ST2NM>
    PatientSelection = PatientSelection(lignesEssai, :);
    PatientNumbers   = PatientNumbers(lignesEssai);
    fprintf('Essai : %d épaules (EPAULE_LIGNES = %s, n° %s)\n', size(PatientSelection, 1), ...
        getenv('EPAULE_LIGNES'), mat2str(PatientNumbers'));
end

% AsymptomaticSelection : épaules asymptomatiques (côté controlatéral)
% retenues parmi les 182 patients de PatientSelection.
%   {ID patient, côté asymptomatique, condition retenue, date de session}
AsymptomaticSelection = { ...
    '18792', 'R', 'POST', '2023'; ... % 1
    '399423', 'L', 'POST', '20231010'; ... % 8
    '496545', 'L', 'POST', '2024'; ... % 11
    '166206', 'L', 'POST', '2023'; ... % 17
    '865139', 'L', 'POST', '2023'; ... % 19
    '97438620', 'R', 'POST', '2023'; ... % 21
    '937635', 'L', 'POST', '2023'; ... % 29
    '973018', 'L', 'POST', '2024'; ... % 49
    '977799', 'L', 'POST', '2024'; ... % 63
    '211673', 'L', 'POST', '2024'; ... % 66
    '98868156', 'R', 'PRE', '2023'; ... % 70
    '98638206', 'R', 'POST', '2024'; ... % 75
    '944315', 'L', 'POST', '2025'; ... % 77
    '17081', 'L', 'PRE', '2023'; ... % 80
    '977471', 'L', 'PRE', '2024'; ... % 94
    '593818', 'L', 'PRE', '2024'; ... % 96
    '161051', 'L', 'PRE', '2024'; ... % 101
    '19922', 'L', 'PRE', '2024'; ... % 107
    '84788', 'L', 'PRE', '2024'; ... % 130
    '403855', 'L', 'PRE', '2024'; ... % 138
    '869743', 'L', 'PRE', '2024'; ... % 150
    '408670', 'L', 'POST', '2025'; ... % 151
    '86669', 'R', 'POST', '2026'; ... % 153
    '565328', 'L', 'PRE', '2025'; ... % 158
    '558792', 'L', 'POST', '2026'; ... % 164
    '66072', 'L', 'POST', '2026'; ... % 181
    };

% SkipKinematics : true pour sauter le calcul cinématique
SkipKinematics = false;

% ResultsFolder : dossier où sont écrits les Excels de sortie et le PatientDatabase.mat.
switch getenv('COMPUTERNAME')
    case 'FRANCALANCIPHD' 
        ResultsFolder = 'C:\Users\franc\OneDrive - Université de Genève\PhD Hugo\05_Ressources\01_Data\01_Etudes\E02_01_Posture_rTSA';
    case 'CD-8K18T74'
        ResultsFolder = 'C:\Users\francala\OneDrive - Université de Genève\PhD Hugo\05_Ressources\01_Data\01_Etudes\E02_01_Posture_rTSA\Processing CD-8K18T74';
    otherwise
        ResultsFolder = ''; % machine inconnue : demandé via fenêtre au lancement
end

% STOCKAGE PAR PROJET (décision du 25.11.2026) : un dossier par projet sur le
% bureau du PC, hors OneDrive, qui devient la référence du projet une fois
% terminé (tous les Excels sources du projet au même endroit, Valeurs\) :
%   ProjectsRoot\<ProjectCode>\
%     Patients\<n°>_<ID>_<côté>\   PRE\ et POST\ : copie des C3D de Processed\
%                                  et de Session.xlsx utilisés ; <ID>_<côté>.mat
%                                  (un .mat par épaule au lieu des parties)
%     Valeurs\                     Excels de sortie (ResultsFolder) et, dans
%                                  Valeurs\Cache, les valeurs calculées une fois
%                                  et relues par les sections de résultats
%     projet.json                  réglages du run, commit du code, replis sur Rab
% StockageProjet = false : ancien stockage (ResultsFolder ci-dessus, base en
% parties). ProjectCode : voir plus haut (projet du registre). Le registre
% lit le dossier du même nom (page du projet).
StockageProjet = true;
ProjectsRoot   = fullfile(getenv('USERPROFILE'), 'Desktop', 'Projets_epaule');
ProjectFolder  = fullfile(ProjectsRoot, ProjectCode);
if StockageProjet
    ResultsFolder = fullfile(ProjectFolder, 'Valeurs');
end
% CopyInputFiles : copie des C3D de Processed\ et de Session.xlsx dans le projet
CopyInputFiles = StockageProjet;
% RecomputeValues : true pour recalculer depuis les .mat même si Valeurs\Cache
% est à jour (sinon recalcul seulement quand un .mat est plus récent)
RecomputeValues = false;
CacheFolder     = fullfile(ResultsFolder, 'Cache');
% InversionReferenceFile : référence figée de la correction des courbes ST et
% TX inversées (Core/InversionReference.m) : courbes moyennes et repos de la
% cohorte complète, pour que la valeur corrigée d'une épaule ne dépende pas
% des autres épaules du projet. BuildInversionReference = true la recalcule
% sur le run (cohorte complète uniquement) et réécrit le fichier.
InversionReferenceFile  = fullfile(Folder.toolbox, 'Multi', 'InversionReference_STTX.csv');
BuildInversionReference = false;

% OutputFile : fichier Excel de sortie (contributions cliniques HT/GH/ST/TX)
OutputFile = fullfile(ResultsFolder, 'ClinicalContributions_Summary.xlsx');

% FunctionalOutputFile : fichier Excel de sortie (contributions fonctionnelles HG/GH/ST/TX)
FunctionalOutputFile = fullfile(ResultsFolder, 'FunctionalContributions_Summary.xlsx');

% CoRQualityOutputFile : fichier Excel de sortie (qualité de reconstruction du CoR, SCoRE)
CoRQualityOutputFile = fullfile(ResultsFolder, 'CoRQuality_Summary.xlsx');

% CurveQualityOutputFile : fichier Excel de sortie (validité des courbes HT/HG/GH/ST/TX)
CurveQualityOutputFile = fullfile(ResultsFolder, 'CurveQuality_Summary.xlsx');

% SHRCurvesOutputFile : fichier Excel de sortie (courbes HT/GH/ST point par
% point PRE/POST, ExportSHRCurvesFromDatabase)
SHRCurvesOutputFile = fullfile(ResultsFolder, 'SHR_Curves.xlsx');
% SHRAbstractFolder : dossier de l'abstract ISB 2027 (SHR_Curves.xlsx validé
% copié ici ; TestSHRFormulas y lit les courbes et écrit SHR_Formulas.xlsx).
% Chemin relatif au profil Windows pour fonctionner sur les deux machines
SHRAbstractFolder = fullfile(getenv('USERPROFILE'), 'OneDrive - Université de Genève', 'PhD Hugo', ...
    '04_Outputs', '02_Conferences', 'Congress', '2027_International Society of Biomechanics', ...
    'Abstract', 'Abstract 3', 'Data');
% SHRFigureFolder / SHRTableFolder : figures (PNG, PDF) et tableaux Word de
% l'abstract, à côté de Data
SHRFigureFolder = fullfile(fileparts(SHRAbstractFolder), 'Figures');
SHRTableFolder  = fullfile(fileparts(SHRAbstractFolder), 'Tables');

% PostureOutputFile : fichier Excel de sortie (inclinaison thoracique + Moroder)
PostureOutputFile = fullfile(ResultsFolder, 'Posture_Summary.xlsx');

% PostureDataFile : Excel trié à la main (feuilles Posture, Cinematique...
% et _Asym), entrée de CorrelatePostureROM, InclinationClassification,
% AsymptomaticComparison et PlotMeanCurvesFromDatabase ; gardé sur OneDrive
% (hors du dépôt GitHub). Chemin relatif au profil Windows pour fonctionner
% sur les deux machines. CorrelationROMOutputFile : sortie commune de
% CorrelatePostureROM (H2), AnalyseThoraxContribution (H1) et
% PostureSecondaryAnalyses (une feuille par analyse)
PostureDataFile          = fullfile(getenv('USERPROFILE'), 'OneDrive - Université de Genève', 'PhD Hugo', ...
    '01_Etude', '02_Sub-projects 2', 'E02_Classification_rTSA', 'E02_01 Posture rTSA', 'Results', ...
    'Data_posture.xlsx');
% (octobre 2026 : élévations sur le meilleur des 3 cycles, voir BestCycle.m ;
% l'ancienne version, moyenne des 3 cycles, est archivée dans
% Results/02_Pre-article_posture/Preliminary_data_posture.xlsx)
CorrelationROMOutputFile = fullfile(Folder.toolbox, 'Multi', 'Results', 'Correlation_Posture_ROM.xlsx');
% InclinationOutputFile : sortie de InclinationClassification (stratification
% de l'inclinaison et seuil critique)
InclinationOutputFile    = fullfile(Folder.toolbox, 'Multi', 'Results', 'Inclination_Classification.xlsx');
% AsymptomaticOutputFile : sortie de AsymptomaticComparison (épaules saines
% controlatérales, feuilles _Asym de PostureDataFile)
AsymptomaticOutputFile   = fullfile(Folder.toolbox, 'Multi', 'Results', 'Asymptomatic_Comparison.xlsx');
% ArticleFigureFolder : figures de l'article (PlotArticleFigures, une par
% fichier, PDF / SVG / PNG), à côté de PostureDataFile (OneDrive)
ArticleFigureFolder      = fullfile(fileparts(PostureDataFile), 'Figures_article');
% CurveCheckFolder : sorties de CheckCurvesFromDatabase (QC_courbes.xlsx,
% figures), à côté de PostureDataFile (OneDrive)
CurveCheckFolder         = fullfile(fileparts(PostureDataFile), 'Controle_courbes');
% Stockage par projet : dans Valeurs\ du projet, avec les autres sorties
if StockageProjet, CurveCheckFolder = fullfile(ResultsFolder, 'Controle_courbes'); end

% PatientInfosFile : fichier Excel de sortie (infos démographiques patients)
PatientInfosFile = fullfile(ResultsFolder, 'PatientInfos_Summary.xlsx');

% DataAvailabilityFile : fichier Excel de sortie (disponibilité des données)
DataAvailabilityFile = fullfile(ResultsFolder, 'DataAvailability_Summary.xlsx');

% ContralateralEligibilityFile : fichier Excel de sortie
ContralateralEligibilityFile = fullfile(ResultsFolder, 'ContralateralEligibility_Summary.xlsx');

% RegistreFolder : export des résultats par épaule pour le registre local
% (resultats.csv, courbes.csv, run.json, voir IO/ExportRegistre.m)
RegistreFolder = fullfile(ResultsFolder, 'Registre');

% SaveDatabase : true pour sauvegarder .mat
SaveDatabase = true;
if StockageProjet
    DatabaseFile = fullfile(ProjectFolder, 'Patients'); % dossier : un .mat par épaule
else
    DatabaseFile = fullfile(ResultsFolder, sprintf('Database_%d_E02_01_Posture_rTSA.mat', size(PatientSelection, 1)));
end

% NumDatabaseParts : nombre de fichiers .mat sur lesquels repartir la
% cohorte. 37 -> BatchSize=5 (PC portable --> moins puissant (25 minutes)). Tour CD-8K18T74 : 16 ->
% BatchSize=12 (Tour --> plus rapide (16 minutes)).
switch getenv('COMPUTERNAME')
    case 'CD-8K18T74'
        NumDatabaseParts = 18; % 206 patients -> BatchSize = 12
    otherwise
        NumDatabaseParts = 42; % 206 patients -> BatchSize = 5
end

% BatchSize : nombre de patients traités en parallele (parfor) avant
% d'ecrire sur disque et de vider la RAM.
BatchSize = ceil(size(PatientSelection, 1) / NumDatabaseParts);
if ~isempty(getenv('EPAULE_LIGNES')), BatchSize = size(PatientSelection, 1); end % essai : un seul paquet


