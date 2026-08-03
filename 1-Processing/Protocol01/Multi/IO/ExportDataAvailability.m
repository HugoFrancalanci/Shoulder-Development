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
% Description:   Exports the data availability report (one row per PRE/POST
%                exam, from ComputeDataAvailability.m) to an Excel file,
%                with the same formatting as the user's own tracking Excel:
%                a 2-row header (merged group + sub-columns), rows kept
%                contiguous with no blank row between patients (for easier
%                import/export elsewhere), Numéro/ID Cinésiologie/ID RedCap
%                merged vertically between the PRE row and the POST row.
%
%                Binary columns (1/0) are colored green/red (as requested:
%                1 = green = reported, 0 = red = missing). The
%                "Nombre"/"Type (N)"/"Fs" columns stay as plain text
%                (informative, no color).
%
%                Imagerie / Eligibilité / Notes: added as empty columns
%                (headers only) - filled in by hand by the user, not
%                computed here.
% -------------------------------------------------------------------------
% Inputs  : DataAvail (struct array) from MAIN_MULTI_Protocol_01.m, with -
%           in addition to ComputeDataAvailability.m's fields - Numero, ID,
%           IDRedCap, Examen, Date
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

function ExportDataAvailability(DataAvail, OutputFile)

if isempty(DataAvail)
    disp('ExportDataAvailability: no data to export.');
    return;
end

% -------------------------------------------------------------------------
% COLUMN DEFINITION
% Each group: {group name ('' = identification columns, vertical merge),
% sub-headers, corresponding Row fields ('' = no field, filled by hand),
% colorable (1 = green/red if value is 0/1)}
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
    'Electromyographie', {'Nombre', ...
                   'DELTA D','DELTA G','DELTM D','DELTM G','DELTP D','DELTP G', ...
                   'TRAPS D','TRAPS G','TRAPM D','TRAPM G','TRAPI D','TRAPI G', ...
                   'SERRA D','SERRA G','LATD D','LATD G','Fs'}, ...
                   {'EMG_Nombre', ...
                   'DELTA_R','DELTA_L','DELTM_R','DELTM_L','DELTP_R','DELTP_L', ...
                   'TRAPS_R','TRAPS_L','TRAPM_R','TRAPM_L','TRAPI_R','TRAPI_L', ...
                   'SERRA_R','SERRA_L','LATD_R','LATD_L','EMG_Fs'}, ...
                   logical([0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0]); ...
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
% SPREADSHEET (writecell) - 2 header rows, then 1 row per PRE/POST exam,
% kept contiguous on purpose (no blank row between patients), for easier
% import/export elsewhere.
% -------------------------------------------------------------------------
C = cell(2, nCols);
C(1, 1:length(idCols)) = idCols; % merged vertically further below via COM
col = length(idCols) + 1;
for ig = 1:size(groups,1)
    span = length(groups{ig,2});
    C(1, col) = groups(ig,1);
    C(2, col:col+span-1) = groups{ig,2};
    col = col + span;
end

% Numéro is only filled on the 1st row (PRE) of each patient: used here to
% detect the start of a new patient and to identify the row pairs to merge
% (Numéro/ID/ID RedCap) further below via COM.
mergeRows    = zeros(0, 2); % [PRE row, POST row] to merge
dataRows     = zeros(1, length(DataAvail)); % Excel row of each DataAvail entry
lastPreRow   = [];

for i = 1:length(DataAvail)
    d = DataAvail(i);
    isNewPatient = ~isempty(d.Numero);
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

% writecell/writetable never clear a pre-existing sheet, only overwrite
% the cell range they write to - if a previous run left MORE rows/columns
% (e.g. an older format with blank separator rows), those leftover cells
% would stay behind, invisible until scrolled/stale patient data at the
% bottom. Deleting the file first guarantees a fully fresh sheet.
if isfile(OutputFile), delete(OutputFile); end
writecell(C, OutputFile, 'Sheet', 'DataAvailability');

% -------------------------------------------------------------------------
% COM FORMATTING: header merges + green/red colors
% (best effort: requires Excel installed; the export stays valid without it)
% -------------------------------------------------------------------------
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
    sheet = wb.Sheets.Item('DataAvailability');

    % Vertical merge of the identification columns (Numéro..Date)
    for ic = 1:length(idCols)
        r = sheet.Range([colLetter(ic) '1:' colLetter(ic) '2']);
        r.Merge;
        r.HorizontalAlignment = -4108; % xlCenter
        r.VerticalAlignment   = -4108;
    end

    % Horizontal merge of the group headers
    col = length(idCols) + 1;
    for ig = 1:size(groups,1)
        span = length(groups{ig,2});
        r = sheet.Range([colLetter(col) '1:' colLetter(col+span-1) '1']);
        r.Merge;
        r.HorizontalAlignment = -4108;
        col = col + span;
    end
    sheet.Range(['A2:' colLetter(nCols) '2']).HorizontalAlignment = -4108;

    % Vertical merge of Numéro/ID Cinésiologie/ID RedCap between the PRE
    % row and the POST row of the same patient (columns 1 to 3)
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
            % v > 0 (not strictly v == 1): most colorable columns are
            % binary 0/1, but Rcycle/Lcycle hold an actual cycle count
            % (e.g. 2, 3, 4) - >0 covers both cases correctly.
            if v > 0
                cellRange.Interior.Color = green;
            elseif v == 0
                cellRange.Interior.Color = red;
            end
        end
    end

    sheet.Columns.AutoFit;
    wb.Save;
catch ME
    % fprintf (not warning): MAIN_MULTI_Protocol_01.m does "warning off" at
    % the start of the script, which would make this message invisible otherwise.
    fprintf(2, 'ExportDataAvailability: Excel formatting failed (%s) - 0/1 values shown as plain text.\n', ME.message);
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

function s = colLetter(n)
% Converts a 1-based column index to Excel letter(s) (1->A, 27->AA...)
s = '';
while n > 0
    r = mod(n - 1, 26);
    s = [char(65 + r), s]; %#ok<AGROW>
    n = floor((n - 1) / 26);
end
end
