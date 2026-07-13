% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Résumé démographique/clinique d'un patient, à partir des
%                sorties de ImportSessionData.m (Patient, Session,
%                Pathology). Age et IMC sont recalculés ici (runProtocol01
%                ne retourne pas le struct Clinical d'ImportSessionData).
%
%                ID = initiale du premier prénom (si plusieurs) + initiale
%                du nom de famille (ex: "Jean-Pierre Dupont" -> "JD").
%                Genre : 1 = Femme, 0 = Homme, NaN si non reconnu.
%                Laterality : 1 = Gauche, 0 = Droit, NaN si Bilateral/non
%                reconnu (côté atteint/opéré, Pathology.Diagnosis.side).
%                ASA n'est pas disponible dans Session.xlsx : laissé vide.
%
%                Age/Height/Mass/BMI sont propres à LA SESSION passée en
%                entrée (PRE ou POST) — à appeler une fois par condition,
%                pas juste une fois par patient (voir MAIN_MULTI_Protocol_01.m).
%
%                EVA_formula : moyenne des scores de douleur (EVA) des 4
%                tâches ANALYTIC, sous forme de FORMULE Excel texte (ex:
%                "=(4+4+4+4)/4") - ExportPatientInfos.m l'écrit comme
%                vraie formule Excel (cliquer sur la cellule montre le
%                détail). Priorité au côté atteint (Laterality). Si ce
%                côté n'a AUCUNE valeur (patients plus anciens où un seul
%                côté était rempli dans Session.xlsx, pas toujours celui
%                attendu) ou si Laterality est inconnue/bilatérale, on se
%                replie sur l'autre côté SEULEMENT s'il a des données -
%                EVA_fallback (logique) est alors mis à true pour que
%                ExportPatientInfos.m marque visuellement la cellule
%                (elle ne représente pas le côté atteint, il ne faut pas
%                la confondre avec une vraie mesure du côté atteint).
%                Vide seulement si aucun des deux côtés n'a de valeur.
%                Les scores bruts viennent de Session.Pain (déjà présents
%                dans Session, pas besoin de Clinical).
% -------------------------------------------------------------------------
% Inputs  : Patient, Session, Pathology (struct) depuis runProtocol01/ImportSessionData
% Outputs : Info (struct) avec les champs ID, Age, Gender, Height, Mass,
%           BMI, ASA, Laterality, EVA_formula, EVA_fallback
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
% Moyenne des EVA des 4 tâches ANALYTIC. Priorité au côté atteint ; repli
% sur l'autre côté UNIQUEMENT s'il a des données et que le côté atteint
% n'en a aucune (usedFallback=true dans ce cas, à signaler visuellement -
% ce n'est PAS une mesure du côté atteint). '' si aucun côté n'a de valeur.
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
    % Latéralité inconnue : si un seul côté a des données, on le prend
    % (marqué comme repli, puisqu'on ne sait pas si c'est le côté atteint)
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
% Premier prénom (si plusieurs, séparés par espace/tiret) + nom -> initiales
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
    g = 1; % Femme / Female
elseif startsWith(s, 'h') || startsWith(s, 'm')
    g = 0; % Homme / Male
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
