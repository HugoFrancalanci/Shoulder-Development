% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   May 2026
% -------------------------------------------------------------------------
% Description:   Import Session.xlsx file data.
%                Base K-LAB version extended with:
%                  - Multi-format date parsing (dd.MM.yyyy, dd-MMM-yyyy, etc.)
%                  - Clinical struct (age, BMI, EVA per ANALYTIC task)
%                  - Session.patientHeight_cm and Session.patientHeight_m
%                  - Automatic console summar
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - 
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [Patient, Session, Pathology, Clinical] = ImportSessionData()

% -------------------------------------------------------------------------
% READ SESSION.XLSX
% -------------------------------------------------------------------------
tSession = readtable('Session.xlsx', 'Range', 'A4:F57');

% -------------------------------------------------------------------------
% PATIENT
% -------------------------------------------------------------------------
Patient.ID        = cell2mat(table2array(tSession(1,2)));
Patient.lastname  = cell2mat(table2array(tSession(2,2)));
Patient.firstname = cell2mat(table2array(tSession(3,2)));
Patient.gender    = cell2mat(table2array(tSession(4,2)));

% Date of birth 
Patient.dob = parseDate(cell2mat(table2array(tSession(5,2))));

% -------------------------------------------------------------------------
% PATHOLOGY
% -------------------------------------------------------------------------
Pathology.Diagnosis.side     = cell2mat(table2array(tSession(9,2)));
Pathology.Diagnosis.d1       = cell2mat(table2array(tSession(10,2)));
Pathology.Diagnosis.d2       = cell2mat(table2array(tSession(11,2)));
Pathology.Diagnosis.d3       = cell2mat(table2array(tSession(12,2)));
Pathology.Diagnosis.d4       = cell2mat(table2array(tSession(13,2)));
Pathology.Diagnosis.d5       = cell2mat(table2array(tSession(14,2)));
Pathology.PlanedSurgery.i1   = cell2mat(table2array(tSession(15,2)));
Pathology.PlanedSurgery.i2   = cell2mat(table2array(tSession(16,2)));
Pathology.PlanedSurgery.i3   = cell2mat(table2array(tSession(17,2)));
Pathology.PlanedSurgery.i4   = cell2mat(table2array(tSession(18,2)));
Pathology.PlanedSurgery.i5   = cell2mat(table2array(tSession(19,2)));
Pathology.PreviousSurgery.i1 = cell2mat(table2array(tSession(20,2)));
Pathology.PreviousSurgery.i2 = cell2mat(table2array(tSession(21,2)));
Pathology.PreviousSurgery.i3 = cell2mat(table2array(tSession(22,2)));
Pathology.PreviousSurgery.i4 = cell2mat(table2array(tSession(23,2)));
Pathology.PreviousSurgery.i5 = cell2mat(table2array(tSession(24,2)));

% -------------------------------------------------------------------------
% SESSION
% -------------------------------------------------------------------------
Session.ID            = cell2mat(table2array(tSession(26,2)));
Session.physician     = cell2mat(table2array(tSession(27,2)));
Session.operator      = cell2mat(table2array(tSession(28,2)));

% Session date 
Session.date          = parseDate(cell2mat(table2array(tSession(29,2))));

Session.objective     = cell2mat(table2array(tSession(30,2)));
Session.protocol      = cell2mat(table2array(tSession(32,2)));
Session.markerHeight1 = 0.0095;   % m, scapula/clavicle markers
Session.markerHeight2 = 0.0140;   % m, thorax/humerus markers

% Body mass
if iscell(table2array(tSession(6,2)))
    Session.patientBodyMass = str2num(cell2mat(table2array(tSession(6,2)))); % kg
else
    Session.patientBodyMass = table2array(tSession(6,2)); % kg
end

% Height — stored in both cm and m
if iscell(table2array(tSession(7,2)))
    Session.patientHeight_cm = str2num(cell2mat(table2array(tSession(7,2))));
else
    Session.patientHeight_cm = table2array(tSession(7,2));
end
Session.patientHeight   = Session.patientHeight_cm * 1e-2; % m (K-LAB compatibility)
Session.patientHeight_m = Session.patientHeight_cm * 1e-2; % m

% Comments
Session.comments = cell2mat(table2array(tSession(51,1)));

% Raw pain scores — robust to mixed types, empty cells, and decimal separators
try
    Session.Pain.label = table2array(tSession(35:47,1));
catch
    Session.Pain.label = {};
end

Session.Pain.Rvalue = NaN(13,1);
raw = table2array(tSession(35:47,2));
if iscell(raw)
    for ip = 1:length(raw)
        v = raw{ip};
        if isnumeric(v) && ~isempty(v)
            Session.Pain.Rvalue(ip) = v;
        elseif ischar(v) || isstring(v)
            n = str2double(strrep(char(v),',','.'));
            if ~isnan(n), Session.Pain.Rvalue(ip) = n; end
        end
    end
else
    for ip = 1:size(raw,1)
        if ~isnan(raw(ip)), Session.Pain.Rvalue(ip) = raw(ip); end
    end
end

Session.Pain.Lvalue = NaN(13,1);
raw = table2array(tSession(35:47,3));
if iscell(raw)
    for ip = 1:length(raw)
        v = raw{ip};
        if isnumeric(v) && ~isempty(v)
            Session.Pain.Lvalue(ip) = v;
        elseif ischar(v) || isstring(v)
            n = str2double(strrep(char(v),',','.'));
            if ~isnan(n), Session.Pain.Lvalue(ip) = n; end
        end
    end
else
    for ip = 1:size(raw,1)
        if ~isnan(raw(ip)), Session.Pain.Lvalue(ip) = raw(ip); end
    end
end

% -------------------------------------------------------------------------
% CLINICAL — age, BMI, EVA per ANALYTIC task
% -------------------------------------------------------------------------
% Age computed at session date
try
    Clinical.age = years(Session.date - Patient.dob);
catch
    Clinical.age = NaN;
end

% BMI
if Session.patientHeight_m > 0
    Clinical.BMI = Session.patientBodyMass / Session.patientHeight_m^2;
else
    Clinical.BMI = NaN;
end

% Pain scores classified by ANALYTIC task
analyticPainMap = {
    'Elevation_sagittal', 'ANALYTIC1';
    'Elevation_coronal',  'ANALYTIC2';
    'Rotation_external',  'ANALYTIC3';
    'Rotation_internal',  'ANALYTIC4';
};

Clinical.Pain = struct();
for ap = 1:size(analyticPainMap,1)
    task = analyticPainMap{ap,2};
    Clinical.Pain.(task).label = analyticPainMap{ap,1};
    Clinical.Pain.(task).right = NaN;
    Clinical.Pain.(task).left  = NaN;
end

for ip = 1:length(Session.Pain.label)
    lbl = Session.Pain.label{ip};
    for ap = 1:size(analyticPainMap,1)
        if strcmpi(lbl, analyticPainMap{ap,1})
            task = analyticPainMap{ap,2};
            Clinical.Pain.(task).right = Session.Pain.Rvalue(ip);
            Clinical.Pain.(task).left  = Session.Pain.Lvalue(ip);
            break;
        end
    end
end

% -------------------------------------------------------------------------
% CONSOLE SUMMARY
% -------------------------------------------------------------------------
disp(' ');
disp(['  Patient   : ', Patient.ID]);
disp(['  Session   : ', datestr(Session.date, 'dd.mm.yyyy')]);
disp(['  Age       : ',    sprintf('%.2f', Clinical.age),        ' yrs', ...
      '  Gender : ', Patient.gender, ...
      '  Height : ', sprintf('%.2f', Session.patientHeight_cm),  ' cm', ...
      '  Weight : ', sprintf('%.2f', Session.patientBodyMass),   ' kg', ...
      '  BMI : ',    sprintf('%.2f', Clinical.BMI)]);
disp(['  Protocol  : ', Session.protocol]);
diagLines = {Pathology.Diagnosis.d1, Pathology.Diagnosis.d2, Pathology.Diagnosis.d3, ...
             Pathology.Diagnosis.d4, Pathology.Diagnosis.d5};
diagLines = diagLines(~cellfun(@isempty, strtrim(diagLines)));
if isempty(diagLines)
    disp('  Diagnosis : (non renseigné)');
else
    disp(['  Diagnosis : ', strjoin(diagLines, ' / ')]);
end
prevLines = {Pathology.PreviousSurgery.i1, Pathology.PreviousSurgery.i2, Pathology.PreviousSurgery.i3, ...
             Pathology.PreviousSurgery.i4, Pathology.PreviousSurgery.i5};
prevLines = prevLines(~cellfun(@isempty, strtrim(prevLines)));
if isempty(prevLines)
    disp('  Previous surgery : pas d''antécédents chirurgicaux');
else
    disp(['  Previous surgery : ', strjoin(prevLines, ' / ')]);
end
disp('  Pain (EVA) :');
tasks = {'ANALYTIC1','ANALYTIC2','ANALYTIC3','ANALYTIC4'};
for ip = 1:length(tasks)
    tk = tasks{ip};
    if isfield(Clinical.Pain, tk)
        p = Clinical.Pain.(tk);
        disp(sprintf('    %s : R=%.1f  L=%.1f', tk, p.right, p.left));
    end
end

end

% -------------------------------------------------------------------------
%  MULTI-FORMAT DATE PARSING
% -------------------------------------------------------------------------
function d = parseDate(raw)
% Accepts dd.MM.yyyy, dd-MMM-yyyy, dd/MM/yyyy, MM/dd/yyyy, yyyy-MM-dd
% and numeric Excel serial dates
d = NaT;
if isempty(raw), return; end
try
    if isdatetime(raw),                    d = raw; return; end
    if isnumeric(raw) && ~isnan(raw)
        d = datetime(raw, 'ConvertFrom', 'excel'); return;
    end
    if ischar(raw) || isstring(raw)
        s = strtrim(char(raw));
        fmts = {'dd.MM.yyyy','dd-MMM-yyyy','dd/MM/yyyy', ...
                'MM/dd/yyyy','yyyy-MM-dd','dd-MM-yyyy'};
        for f = 1:length(fmts)
            try
                d = datetime(s, 'InputFormat', fmts{f});
                return;
            catch
            end
        end
    end
catch
end
end