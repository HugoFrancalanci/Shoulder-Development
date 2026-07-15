% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Exporte le rapport de disponibilité des données (une ligne
%                par examen PRE/POST, depuis ComputeDataAvailability.m) dans
%                un fichier Excel, avec la même mise en forme que le tableau
%                Excel de suivi de l'utilisateur : en-tête à 2 lignes
%                (groupe fusionné + sous-colonnes), une ligne vide avant
%                chaque NOUVEAU patient (pas entre les lignes PRE et POST
%                d'un même patient), Numéro/ID Cinésiologie/ID RedCap
%                fusionnés verticalement entre la ligne PRE et la ligne POST.
%
%                Les colonnes binaires (1/0) sont coloriées en vert/rouge
%                (comme demandé : 1 = vert = rapporté, 0 = rouge = manquant).
%                Les colonnes "Nombre"/"Type (N)"/"Fs" restent en texte
%                brut (informatif, pas de couleur).
%
%                Imagerie / Eligibilité / Notes : colonnes ajoutées vides
%                (juste les en-têtes) — remplies à la main par l'utilisateur,
%                pas calculées ici.
% -------------------------------------------------------------------------
% Inputs  : DataAvail (struct array) depuis MAIN_MULTI_Protocol_01.m, avec
%           en plus des champs de ComputeDataAvailability.m : Numero, ID,
%           IDRedCap, Examen, Date
%           OutputFile (char) chemin du fichier Excel de sortie
% Outputs : Fichier Excel écrit sur disque
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function ExportDataAvailability(DataAvail, OutputFile)

if isempty(DataAvail)
    disp('ExportDataAvailability : aucune donnée à exporter.');
    return;
end

% -------------------------------------------------------------------------
% DÉFINITION DES COLONNES
% Chaque groupe : {nom du groupe ('' = colonnes identification, fusion
% verticale), sous-en-têtes, champs Row correspondants ('' = pas de champ,
% rempli à la main), colorable (1 = vert/rouge si valeur 0/1)}
% -------------------------------------------------------------------------
idCols = {'Numéro','ID Cinésiologie','ID RedCap','Examen','Date'};
idFields = {'Numero','ID','IDRedCap','Examen','Date'};

groups = { ...
    'Mouvements', {'Rcycle','Lcycle','Analytical 1','Analytical 2','Analytical 3','Analytical 4', ...
                   'Functional 1','Functional 2','Functional 3','Functional 4', ...
                   'Calibration 1','Calibration 2','Calibration 3','Calibration 4','Calibration 5','Calibration 6'}, ...
                  {'Rcycle','Lcycle','Analytic1','Analytic2','Analytic3','Analytic4', ...
                   'Functional1','Functional2','Functional3','Functional4', ...
                   'Calibration1','Calibration2','Calibration3','Calibration4','Calibration5','Calibration6'}, ...
                  true(1,16); ...
    'Posture', {'CV7','TV3','TV5','TV8','S1'}, {'C7','TV3','TV5','TV8','S1'}, true(1,5); ...
    'Cinématique', {'Nombre','Cluster S','Type (N)','Cluster A','Type (N)','F','Type (N)','Scapula','Humérus','Thorax','Fs'}, ...
                   {'Kin_Nombre','ClusterAC','ClusterAC_Type','ClusterA','ClusterA_Type','ClusterFA','ClusterFA_Type','Kin_Scapula','Kin_Humerus','Kin_Thorax','Kin_Fs'}, ...
                   logical([0 1 0 1 0 1 0 1 1 1 0]); ...
    'Electromyographie', {'Nombre','DELTA','DELTM','DELTP','TRAPS','TRAPM','TRAPI','SERRA','LATD','Fs'}, ...
                   {'EMG_Nombre','DELTA','DELTM','DELTP','TRAPS','TRAPM','TRAPI','SERRA','LATD','EMG_Fs'}, ...
                   logical([0 1 1 1 1 1 1 1 1 0]); ...
    'Puissance', {'Nombre','Force'}, {'Force_Nombre','Force'}, true(1,2); ...
    'Imagerie', {'Scapula','Humérus','Elbow','Landmarks'}, {'','','',''}, false(1,4); ...
    'Eligibilité', {'Posture','Cinématique','Electromyographie','Imagerie'}, {'','','',''}, false(1,4); ...
    'Notes', {'Reprocess .mat','Anonyme'}, {'',''}, false(1,2); ...
};

subLabels  = [idCols, groups{:,2}];
fieldNames = [idFields, groups{:,3}];
colorable  = [false(1,length(idCols)), groups{:,4}];
nCols = length(subLabels);

% -------------------------------------------------------------------------
% FEUILLE DE CALCUL (writecell) — 2 lignes d'en-tête + 1 ligne vide/patient
% -------------------------------------------------------------------------
C = cell(2, nCols);
C(1, 1:length(idCols)) = idCols; % fusionné verticalement plus bas via COM
col = length(idCols) + 1;
for ig = 1:size(groups,1)
    span = length(groups{ig,2});
    C(1, col) = groups(ig,1);
    C(2, col:col+span-1) = groups{ig,2};
    col = col + span;
end

blankRow = repmat({''}, 1, nCols);

% Numéro n'est rempli que sur la 1re ligne (PRE) de chaque patient : sert
% ici à détecter le début d'un nouveau patient (ligne vide avant, PAS entre
% PRE et POST) et à repérer les paires de lignes à fusionner (Numéro/ID/ID
% RedCap) plus bas via COM.
mergeRows    = zeros(0, 2); % [ligne PRE, ligne POST] à fusionner
dataRows     = zeros(1, length(DataAvail)); % ligne Excel de chaque entrée DataAvail
lastPreRow   = [];

for i = 1:length(DataAvail)
    d = DataAvail(i);
    isNewPatient = ~isempty(d.Numero);
    if isNewPatient
        C(end+1, :) = blankRow; %#ok<AGROW>
    end
    row = cell(1, nCols);
    for ic = 1:nCols
        fn = fieldNames{ic};
        if isempty(fn)
            row{ic} = '';
        else
            row{ic} = d.(fn);
        end
    end
    C(end+1, :) = row; %#ok<AGROW>
    dataRows(i) = size(C, 1);
    if isNewPatient
        lastPreRow = size(C, 1);
    elseif ~isempty(lastPreRow)
        mergeRows(end+1, :) = [lastPreRow, size(C, 1)]; %#ok<AGROW>
    end
end

writecell(C, OutputFile, 'Sheet', 'DataAvailability');

% -------------------------------------------------------------------------
% MISE EN FORME COM : fusions d'en-tête + couleurs vert/rouge
% (best effort : nécessite Excel installé ; l'export reste valide sans ça)
% -------------------------------------------------------------------------
% excel/wb déclarés AVANT le try : si la mise en forme plante en cours de
% route, le bloc cleanup ci-dessous doit quand même pouvoir les fermer -
% sinon Excel reste ouvert en arrière-plan (invisible, Visible=false) et
% s'accumule à chaque exécution du script.
excel = [];
wb = [];
try
    excel = actxserver('Excel.Application');
    excel.Visible = false;
    excel.DisplayAlerts = false; % évite un dialogue bloquant si un Merge touche des cellules non vides
    wb = excel.Workbooks.Open(OutputFile);
    sheet = wb.Sheets.Item('DataAvailability');

    % Fusion verticale des colonnes identification (Numéro..Date)
    for ic = 1:length(idCols)
        r = sheet.Range([colLetter(ic) '1:' colLetter(ic) '2']);
        r.Merge;
        r.HorizontalAlignment = -4108; % xlCenter
        r.VerticalAlignment   = -4108;
    end

    % Fusion horizontale des en-têtes de groupe
    col = length(idCols) + 1;
    for ig = 1:size(groups,1)
        span = length(groups{ig,2});
        r = sheet.Range([colLetter(col) '1:' colLetter(col+span-1) '1']);
        r.Merge;
        r.HorizontalAlignment = -4108;
        col = col + span;
    end
    sheet.Range(['A2:' colLetter(nCols) '2']).HorizontalAlignment = -4108;

    % Fusion verticale Numéro/ID Cinésiologie/ID RedCap entre la ligne PRE
    % et la ligne POST d'un même patient (colonnes 1 à 3)
    for im = 1:size(mergeRows, 1)
        for ic = 1:3
            r = sheet.Range([colLetter(ic) num2str(mergeRows(im,1)) ':' colLetter(ic) num2str(mergeRows(im,2))]);
            r.Merge;
            r.VerticalAlignment = -4108; % xlCenter
        end
    end

    green = 198 + 239*256 + 206*65536; % RGB(198,239,206) BGR-encoded
    red   = 255 + 199*256 + 206*65536; % RGB(255,199,206) BGR-encoded

    for i = 1:length(DataAvail)
        dataRow = dataRows(i);
        for ic = 1:nCols
            if ~colorable(ic), continue; end
            v = C{dataRow, ic};
            if ~isnumeric(v) || isnan(v), continue; end
            cellRange = sheet.Range([colLetter(ic) num2str(dataRow)]);
            if v == 1
                cellRange.Interior.Color = green;
            elseif v == 0
                cellRange.Interior.Color = red;
            end
        end
    end

    sheet.Columns.AutoFit;
    wb.Save;
catch ME
    % fprintf (pas warning) : MAIN_MULTI_Protocol_01.m fait "warning off" en
    % début de script, ce qui rendrait ce message invisible sinon.
    fprintf(2, 'ExportDataAvailability : mise en forme Excel échouée (%s) - valeurs 0/1 en texte brut.\n', ME.message);
end

% Nettoyage garanti (même si la mise en forme ci-dessus a échoué en cours
% de route) pour ne jamais laisser un processus Excel fantôme en arrière-plan.
try
    if ~isempty(wb), wb.Close(false); end
catch
end
try
    if ~isempty(excel)
        excel.Quit;
        delete(excel);
    end
catch
end

disp(['Excel exporté : ', OutputFile]);

end

function s = colLetter(n)
% Convertit un index de colonne 1-based en lettre(s) Excel (1->A, 27->AA...)
s = '';
while n > 0
    r = mod(n - 1, 26);
    s = [char(65 + r), s]; %#ok<AGROW>
    n = floor((n - 1) / 26);
end
end
