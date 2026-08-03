% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Exports the patients' demographic/clinical summary
%                (PatientInfos, from ComputePatientInfos.m) to an Excel
%                file, in the same format as the REDCap exports
%                (redcap_common.py): a "Patient" header merged across all
%                columns, then a blank row before each patient to make
%                copy/paste easier.
%
%                Two identical blocks side by side (PRE then POST), each
%                with Numéro/ID/Genre/ASA/Latéralité repeated (column
%                labels kept in French to match the rest of the Excel
%                deliverables the team uses):
%                  Numéro, ID, Age_PRE,  Genre, Taille_PRE,  Masse_PRE,  IMC_PRE,  EVA_PRE,  ASA, Latéralité,
%                  Numéro, ID, Age_POST, Genre, Taille_POST, Masse_POST, IMC_POST, EVA_POST, ASA, Latéralité
%                Genre: 1=Female/0=Male. Latéralité: 1=Left/0=Right.
%
%                EVA_PRE/EVA_POST are written as REAL Excel formulas (e.g.
%                "=(4+4+4+4)/4", from Multi/Core/ComputePatientInfos.m):
%                the cell displays the computed mean, but clicking it shows
%                the detail of the 4 ANALYTIC values used. If EVA_*_fallback
%                is true (affected side has no data, fell back to the other
%                side - see ComputePatientInfos.m), the cell is flagged
%                orange + an Excel comment explains it is NOT the affected
%                side, so it is never mistaken for an actual measure of
%                that side.
% -------------------------------------------------------------------------
% Inputs  : PatientInfos (struct array) from MAIN_MULTI_Protocol_01.m, with
%           fields ID, Gender, Laterality, ASA, Age_PRE/POST,
%           Height_PRE/POST, Mass_PRE/POST, BMI_PRE/POST, EVA_PRE/POST,
%           EVA_PRE_fallback/EVA_POST_fallback
%           OutputFile (char) output Excel file path
% Outputs : Excel file written to disk
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
    disp('ExportPatientInfos: no data to export.');
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

% Merges the "Patient" header row, and writes EVA_PRE/POST as real Excel
% formulas (best effort: requires Excel installed via COM; the export
% stays valid, just without these two extras, if this fails).
% excel/wb declared BEFORE the try: if the formatting crashes partway
% through, the cleanup block below must still be able to close them -
% otherwise Excel stays open in the background (invisible, Visible=false)
% and accumulates on every script run.
excel = [];
wb = [];
try
    excel = actxserver('Excel.Application');
    excel.Visible = false;
    excel.DisplayAlerts = false; % avoids a blocking dialog if a Merge touches non-empty cells
    wb = excel.Workbooks.Open(OutputFile);
    sheet = wb.Sheets.Item('PatientInfos');

    range = sheet.Range(['A1:', char(64 + nCols), '1']);
    range.Merge;
    range.HorizontalAlignment = -4108; % xlCenter

    for i = 1:length(PatientInfos)
        dataRow = 2 * i + 2; % 2 header rows, then (blank, data) per patient
        p = PatientInfos(i);
        writeEvaCell(sheet, COL_EVA_PRE,  dataRow, p.EVA_PRE,  p.EVA_PRE_fallback);
        writeEvaCell(sheet, COL_EVA_POST, dataRow, p.EVA_POST, p.EVA_POST_fallback);
    end

    wb.Save;
catch ME
    % fprintf (not warning): MAIN_MULTI_Protocol_01.m does "warning off" at
    % the start of the script, which would make this message invisible otherwise.
    fprintf(2, 'ExportPatientInfos: Excel formatting failed (%s) - values shown as plain text.\n', ME.message);
end

% Guaranteed cleanup (even if the formatting above failed partway through)
% so a ghost Excel process is never left running in the background.
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

disp(['Excel exported: ', OutputFile]);

end

function v = r2(v)
% Rounds to 2 decimals (NaN stays NaN)
if isnumeric(v)
    v = round(v, 2);
end
end

function writeEvaCell(sheet, col, row, formula, isFallback)
% Writes the EVA formula into the cell; if isFallback, flags the cell
% orange + adds an Excel comment ("côté non-atteint") so it is never
% mistaken for an actual measure of the affected side.
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
        % Comment is optional: the color alone is enough if this fails
    end
end
end
