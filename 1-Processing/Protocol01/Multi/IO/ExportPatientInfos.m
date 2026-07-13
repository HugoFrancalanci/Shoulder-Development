% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Exporte le résumé démographique/clinique des patients
%                (PatientInfos, depuis ComputePatientInfos.m) dans un
%                fichier Excel, avec le même format que les exports REDCap
%                (redcap_common.py) : en-tête "Patient" fusionné sur toutes
%                les colonnes, puis une ligne vide avant chaque patient
%                pour faciliter le copier-coller.
%
%                Deux blocs identiques côte à côte (PRE puis POST), chacun
%                avec Numéro/ID/Genre/ASA/Latéralité répétés :
%                  Numéro, ID, Age_PRE,  Genre, Taille_PRE,  Masse_PRE,  IMC_PRE,  EVA_PRE,  ASA, Latéralité,
%                  Numéro, ID, Age_POST, Genre, Taille_POST, Masse_POST, IMC_POST, EVA_POST, ASA, Latéralité
%                Genre : 1=Femme/0=Homme. Latéralité : 1=Gauche/0=Droit.
%
%                EVA_PRE/EVA_POST sont écrites comme de VRAIES formules
%                Excel (ex: "=(4+4+4+4)/4", depuis
%                Multi/Core/ComputePatientInfos.m) : la cellule affiche la
%                moyenne calculée, mais cliquer dessus montre le détail
%                des 4 valeurs ANALYTIC utilisées. Si EVA_*_fallback est
%                vrai (côté atteint sans donnée, replié sur l'autre côté -
%                voir ComputePatientInfos.m), la cellule est marquée en
%                orange + un commentaire Excel explique que ce n'est PAS
%                le côté atteint, pour ne jamais la confondre avec une
%                vraie mesure de ce côté.
% -------------------------------------------------------------------------
% Inputs  : PatientInfos (struct array) depuis MAIN_MULTI_Protocol_01.m,
%           avec les champs ID, Gender, Laterality, ASA, Age_PRE/POST,
%           Height_PRE/POST, Mass_PRE/POST, BMI_PRE/POST, EVA_PRE/POST,
%           EVA_PRE_fallback/EVA_POST_fallback
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

function ExportPatientInfos(PatientInfos, OutputFile)

if isempty(PatientInfos)
    disp('ExportPatientInfos : aucune donnée à exporter.');
    return;
end

labels = { ...
    'Numéro', 'ID', 'Age_PRE',  'Genre', 'Taille_PRE',  'Masse_PRE',  'IMC_PRE',  'EVA_PRE',  'ASA', 'Latéralité', ...
    'Numéro', 'ID', 'Age_POST', 'Genre', 'Taille_POST', 'Masse_POST', 'IMC_POST', 'EVA_POST', 'ASA', 'Latéralité'};
nCols  = length(labels);
COL_EVA_PRE  = find(strcmp(labels, 'EVA_PRE'),  1);
COL_EVA_POST = find(strcmp(labels, 'EVA_POST'), 1);

C = cell(0, nCols);
C(1, :) = [{'Patient'}, repmat({''}, 1, nCols - 1)];
C(2, :) = labels;

blankRow = repmat({''}, 1, nCols);

for i = 1:length(PatientInfos)
    p = PatientInfos(i);
    C(end+1, :) = blankRow; %#ok<AGROW>
    C(end+1, :) = { ...
        i, p.ID, r2(p.Age_PRE),  p.Gender, r2(p.Height_PRE),  r2(p.Mass_PRE),  r2(p.BMI_PRE),  p.EVA_PRE,  p.ASA, p.Laterality, ...
        i, p.ID, r2(p.Age_POST), p.Gender, r2(p.Height_POST), r2(p.Mass_POST), r2(p.BMI_POST), p.EVA_POST, p.ASA, p.Laterality}; %#ok<AGROW>
end

writecell(C, OutputFile, 'Sheet', 'PatientInfos');

% Fusion de la ligne d'en-tête "Patient", et écriture des EVA_PRE/POST
% comme de vraies formules Excel (best effort : nécessite Excel installé
% via COM ; l'export reste valide, juste sans ces deux à-côtés, si ça échoue)
try
    excel = actxserver('Excel.Application');
    excel.Visible = false;
    wb = excel.Workbooks.Open(OutputFile);
    sheet = wb.Sheets.Item('PatientInfos');

    range = sheet.Range(['A1:', char(64 + nCols), '1']);
    range.Merge;
    range.HorizontalAlignment = -4108; % xlCenter

    for i = 1:length(PatientInfos)
        dataRow = 2 * i + 2; % 2 lignes d'en-tête, puis (blanc, donnée) par patient
        p = PatientInfos(i);
        writeEvaCell(sheet, COL_EVA_PRE,  dataRow, p.EVA_PRE,  p.EVA_PRE_fallback);
        writeEvaCell(sheet, COL_EVA_POST, dataRow, p.EVA_POST, p.EVA_POST_fallback);
    end

    wb.Save;
    wb.Close(false);
    excel.Quit;
    delete(excel);
catch
    % Excel/COM indisponible : l'Excel reste utilisable, juste sans la
    % fusion visuelle de l'en-tête ni les formules EVA (valeurs affichées
    % comme texte brut à la place)
end

disp(['Excel exporté : ', OutputFile]);

end

function v = r2(v)
% Arrondit à 2 décimales (NaN reste NaN)
if isnumeric(v)
    v = round(v, 2);
end
end

function writeEvaCell(sheet, col, row, formula, isFallback)
% Écrit la formule EVA dans la cellule ; si isFallback, marque la cellule
% en orange + ajoute un commentaire Excel ("côté non-atteint") pour
% qu'elle ne soit jamais confondue avec une vraie mesure du côté atteint.
if isempty(formula), return; end
cell = sheet.Range(sprintf('%s%d', char(64 + col), row));
cell.Formula = formula;
if isFallback
    cell.Interior.Color = 230 + 126*256 + 34*65536; % orange (BGR), R230 G126 B34
    try
        cell.AddComment(['Côté non-atteint (données du côté atteint ', ...
            'indisponibles pour ce patient) - à ne pas confondre avec ', ...
            'une mesure du côté atteint.']);
    catch
        % Commentaire optionnel : la couleur seule suffit si ça échoue
    end
end
end
