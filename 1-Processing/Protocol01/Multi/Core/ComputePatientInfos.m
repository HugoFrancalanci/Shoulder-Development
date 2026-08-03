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
% Description:   Demographic/clinical summary for one patient, from the
%                outputs of ImportSessionData.m (Patient, Session,
%                Pathology). Age and BMI are recomputed here (runProtocol01
%                does not return ImportSessionData's Clinical struct).
%
%                ID = first-first-name initial (if several) + last-name
%                initial (e.g. "Jean-Pierre Dupont" -> "JD").
%                Gender: 1 = Female, 0 = Male, NaN if not recognised.
%                Laterality: 1 = Left, 0 = Right, NaN if Bilateral/not
%                recognised (affected/operated side, Pathology.Diagnosis.side).
%                ASA is not available in Session.xlsx: left empty.
%
%                Age/Height/Mass/BMI are specific to THE SESSION passed as
%                input (PRE or POST) - call once per condition, not just
%                once per patient (see MAIN_MULTI_Protocol_01.m).
%
%                EVA_formula: mean of the pain scores (EVA) across the 4
%                ANALYTIC tasks, as a text Excel FORMULA (e.g.
%                "=(4+4+4+4)/4") - ExportPatientInfos.m writes it as a real
%                Excel formula (clicking the cell shows the detail).
%                Priority to the affected side (Laterality). If that side
%                has NO value at all (older patients where only one side
%                was filled in Session.xlsx, not always the expected one)
%                or if Laterality is unknown/bilateral, falls back to the
%                other side ONLY if it has data - EVA_fallback (logical) is
%                then set to true so ExportPatientInfos.m visually flags
%                the cell (it does not represent the affected side, it
%                must not be mistaken for an actual affected-side measure).
%                Empty only if neither side has a value. Raw scores come
%                from Session.Pain (already present in Session, no need
%                for Clinical).
% -------------------------------------------------------------------------
% Inputs  : Patient, Session, Pathology (struct) from runProtocol01/ImportSessionData
% Outputs : Info (struct) with fields ID, Age, Gender, Height, Mass, BMI,
%           ASA, Laterality, EVA_formula, EVA_fallback
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Info = ComputePatientInfos(Patient, Session, Pathology)

Info.ID = initialsID(Patient.firstname, Patient.lastname);

try
    Info.Age = years(Session.date - Patient.dob);
catch
    Info.Age = NaN;
end

Info.Gender = genderToBinary(Patient.gender);
Info.Height = Session.patientHeight_cm;
Info.Mass   = Session.patientBodyMass;

if isfield(Session, 'patientHeight_m') && Session.patientHeight_m > 0
    Info.BMI = Session.patientBodyMass / Session.patientHeight_m^2;
else
    Info.BMI = NaN;
end

Info.ASA        = '';
Info.Laterality = sideToBinary(Pathology.Diagnosis.side);

[Info.EVA_formula, Info.EVA_fallback] = painEvaFormula(Session, Info.Laterality);

end

function [f, usedFallback] = painEvaFormula(Session, laterality)
% Mean EVA across the 4 ANALYTIC tasks. Priority to the affected side;
% falls back to the other side ONLY if it has data and the affected side
% has none (usedFallback=true in that case, to be flagged visually - this
% is NOT a measure of the affected side). '' if neither side has a value.
f = '';
usedFallback = false;
if ~isfield(Session, 'Pain') || ~isfield(Session.Pain, 'label')
    return;
end

analyticPainMap = { ...
    'Elevation_sagittal', ...
    'Elevation_coronal', ...
    'Rotation_external', ...
    'Rotation_internal', ...
};

valsR = collectPainVals(Session, analyticPainMap, 'right');
valsL = collectPainVals(Session, analyticPainMap, 'left');

if laterality == 1
    primary = valsL; secondary = valsR;
elseif laterality == 0
    primary = valsR; secondary = valsL;
else
    primary = []; secondary = [];
    % Unknown laterality: if only one side has data, use it (flagged as a
    % fallback, since we don't know if it's the affected side)
    if ~isempty(valsR) && isempty(valsL)
        secondary = valsR;
    elseif ~isempty(valsL) && isempty(valsR)
        secondary = valsL;
    end
end

vals = primary;
if isempty(vals) && ~isempty(secondary)
    vals = secondary;
    usedFallback = true;
end

if isempty(vals), return; end

terms = arrayfun(@(x) sprintf('%g', x), vals, 'UniformOutput', false);
f = ['=(', strjoin(terms, '+'), ')/', num2str(length(vals))];
end

function vals = collectPainVals(Session, analyticPainMap, side)
vals = [];
for ip = 1:length(analyticPainMap)
    idx = find(strcmpi(Session.Pain.label, analyticPainMap{ip}), 1);
    if isempty(idx), continue; end
    if strcmp(side, 'left')
        v = Session.Pain.Lvalue(idx);
    else
        v = Session.Pain.Rvalue(idx);
    end
    if ~isnan(v)
        vals(end+1) = v; %#ok<AGROW>
    end
end
end

function id = initialsID(firstname, lastname)
% First first-name (if several, separated by space/hyphen) + last-name -> initials
id = '';
firstToken = regexp(strtrim(firstname), '[^\s\-]+', 'match', 'once');
lastToken  = regexp(strtrim(lastname),  '[^\s\-]+', 'match', 'once');
if ~isempty(firstToken) && ~isempty(lastToken)
    id = upper([firstToken(1), lastToken(1)]);
end
end

function g = genderToBinary(gender)
g = NaN;
s = lower(strtrim(gender));
if isempty(s), return; end
if startsWith(s, 'f')
    g = 1; % Female
elseif startsWith(s, 'h') || startsWith(s, 'm')
    g = 0; % Male
end
end

function s = sideToBinary(side)
s = NaN;
v = lower(strtrim(side));
if any(strcmp(v, {'gauche', 'left', 'l'}))
    s = 1;
elseif any(strcmp(v, {'droit', 'droite', 'right', 'r'}))
    s = 0;
end
end
