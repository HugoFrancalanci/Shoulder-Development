% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
% Date       :   November 2026
% -------------------------------------------------------------------------
% Description:   Calcul une fois, puis relecture. Les fonctions ...FromDatabase
%                relisent toute la base (.mat) à chaque appel, ce qui est
%                long. CachedCompute garde toutes leurs sorties dans
%                <CacheFolder>\<Name>.mat (quelques Mo) et les relit
%                directement aux appels suivants, tant que la base n'a pas
%                changé : recalcul seulement si un .mat de la base est plus
%                récent que le cache, ou si Recompute = true. Les Excels de
%                sortie des fonctions restent écrits lors du calcul (copie
%                lisible des mêmes valeurs).
%
%                Exemple (section « Curve analysis » de MAIN_MULTI) :
%                  [ClinRes, ClinAsym, ClinCurves, ClinAsymCurves] = CachedCompute( ...
%                      'Clinique', CacheFolder, RecomputeValues, DatabaseFile, ...
%                      @ComputeClinicalContributionsFromDatabase, DatabaseFile, OutputFile, ...)
% -------------------------------------------------------------------------
% Inputs  : Name         (char) nom du cache (Clinique, Posture...)
%           CacheFolder  (char) dossier des caches (Valeurs\Cache du projet)
%           Recompute    (logical) true : recalcul forcé
%           DatabaseFile (char) base lue par la fonction (dossier Patients\
%                        du projet ou fichier des parties) : sa date décide
%                        du recalcul ; cell {base, fichier...} pour ajouter
%                        d'autres dépendances (référence figée)
%           Fun          (function handle) fonction ...FromDatabase
%           varargin     arguments de Fun
% Outputs : varargout    sorties de Fun (toutes calculées et gardées)
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function varargout = CachedCompute(Name, CacheFolder, Recompute, DatabaseFile, Fun, varargin)

cacheFile = fullfile(CacheFolder, [Name, '.mat']);
nOut = nargout(Fun);
if nOut < 0, nOut = max(nargout, 1); end   % fonction à sorties variables

% Relecture si le cache existe et qu'aucun .mat de la base n'est plus récent
if ~Recompute && isfile(cacheFile)
    infoCache = dir(cacheFile);
    if infoCache.datenum >= newestDatabaseDate(DatabaseFile)
        S = load(cacheFile, 'Sorties');
        if numel(S.Sorties) >= nargout
            fprintf('%s : valeurs relues (%s)\n', Name, cacheFile);
            varargout = S.Sorties(1:nargout);
            return;
        end
    end
end

% Calcul depuis la base, puis sauvegarde de toutes les sorties
Sorties = cell(1, nOut);
[Sorties{:}] = Fun(varargin{:});
if ~isfolder(CacheFolder), mkdir(CacheFolder); end
save(cacheFile, 'Sorties', '-v7.3');
fprintf('%s : valeurs calculées et gardées (%s)\n', Name, cacheFile);
varargout = Sorties(1:nargout);

end

% Date du .mat le plus récent de la base (dossier Patients\ par épaule, ou
% fichier unique / parties _partXofY) ; Inf si rien n'est trouvé (recalcul).
% Cell : base + autres fichiers dont dépend le calcul (référence figée...)
function d = newestDatabaseDate(DatabaseFile)
if iscell(DatabaseFile)
    d = newestDatabaseDate(DatabaseFile{1});
    for k = 2:numel(DatabaseFile)
        if isfile(DatabaseFile{k}), f = dir(DatabaseFile{k}); d = max(d, f.datenum); end
    end
    return;
end
if isfolder(DatabaseFile)
    f = dir(fullfile(DatabaseFile, '*', '*.mat'));
else
    [dossier, nom, ext] = fileparts(DatabaseFile);
    f = [dir(DatabaseFile); dir(fullfile(dossier, [nom, '_part*of*', ext]))];
end
if isempty(f), d = Inf; else, d = max([f.datenum]); end
end
