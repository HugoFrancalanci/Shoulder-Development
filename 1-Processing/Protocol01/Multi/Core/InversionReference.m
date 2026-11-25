% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Référence figée de la correction des courbes ST et TX
%                inversées (ApplyInversionCorrectionSTTX.m) : courbe
%                moyenne gardée (101 points) et angle de repos, par analyse
%                (Clinique, Fonctionnel), population (Operees,
%                Asymptomatiques), tâche et métrique (ST, TX). Calculée une
%                fois sur la cohorte complète, puis utilisée par tous les
%                projets : la valeur corrigée d'une épaule ne dépend plus
%                des autres épaules du run. Fichier texte (CSV « ; »)
%                versionné avec le code, une ligne par courbe moyenne.
%
%                'lire'   : [Ref, RefAsym] = InversionReference('lire', Fichier, Analyse)
%                           vide si le fichier ou l'analyse manque (la
%                           correction reprend alors la référence du groupe)
%                'ecrire' : InversionReference('ecrire', Fichier, Analyse, Ref, RefAsym)
%                           remplace les lignes de cette analyse
% -------------------------------------------------------------------------
% Inputs  : action  (char) 'lire' ou 'ecrire'
%           Fichier (char) chemin du CSV (userCommands_Multi.m :
%                   InversionReferenceFile)
%           Analyse (char) 'Clinique' ou 'Fonctionnel'
%           Ref, RefAsym (struct array) sorties RefOut de
%                   ApplyInversionCorrectionSTTX (épaules opérées,
%                   asymptomatiques)
% Outputs : Ref, RefAsym (struct array Task, Metric, N, Repos, Modele)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function varargout = InversionReference(action, Fichier, Analyse, Ref, RefAsym)

populations = {'Operees', 'Asymptomatiques'};
vide = struct('Task', {}, 'Metric', {}, 'N', {}, 'Repos', {}, 'Modele', {});

switch action
    case 'lire'
        varargout = {vide, vide};
        if isempty(Fichier) || ~isfile(Fichier)
            fprintf('Correction inversée (%s) : pas de référence figée, référence du groupe\n', Analyse);
            return;
        end
        T = readtable(Fichier, 'Delimiter', ';', 'TextType', 'char', 'VariableNamingRule', 'preserve');
        for p = 1:2
            S = T(strcmp(T.Analyse, Analyse) & strcmp(T.Population, populations{p}), :);
            R = vide;
            for i = 1:height(S)
                R(end+1) = struct('Task', S.Task{i}, 'Metric', S.Metric{i}, 'N', S.N(i), ...
                    'Repos', S.Repos(i), 'Modele', S{i, compose('P%03d', 1:101)}); %#ok<AGROW>
            end
            varargout{p} = R;
        end
        if isempty(varargout{1}) && isempty(varargout{2})
            fprintf('Correction inversée (%s) : analyse absente de %s, référence du groupe\n', Analyse, Fichier);
        else
            dates = T.Date(strcmp(T.Analyse, Analyse));
            fprintf('Correction inversée (%s) : référence figée du %s (%s)\n', Analyse, string(dates(1), 'yyyy-MM-dd'), Fichier);
        end

    case 'ecrire'
        lignes = {};
        date = char(datetime('now', 'Format', 'yyyy-MM-dd'));
        refs = {Ref, RefAsym};
        for p = 1:2
            for r = refs{p}(:)'
                lignes(end+1, :) = [{Analyse, populations{p}, r.Task, r.Metric, r.N, r.Repos, date}, num2cell(r.Modele(:)')]; %#ok<AGROW>
            end
        end
        noms = [{'Analyse', 'Population', 'Task', 'Metric', 'N', 'Repos', 'Date'}, compose('P%03d', 1:101)];
        Nouv = cell2table(lignes, 'VariableNames', noms);
        if isfile(Fichier)
            T = readtable(Fichier, 'Delimiter', ';', 'TextType', 'char', 'VariableNamingRule', 'preserve');
            Nouv = [T(~strcmp(T.Analyse, Analyse), :); Nouv];
        end
        writetable(Nouv, Fichier, 'Delimiter', ';');
        fprintf('Correction inversée (%s) : référence figée écrite (%d courbes moyennes, %s)\n', Analyse, size(lignes, 1), Fichier);
end

end
