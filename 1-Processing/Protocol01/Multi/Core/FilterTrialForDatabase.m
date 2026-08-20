function Trial = FilterTrialForDatabase(Trial)
% Garde seulement les tâches nécessaires aux analyses courantes
% (contributions cliniques HT/GH/ST/TX, quaternions) avant sauvegarde dans
% PatientDatabase.mat - réduit fortement le volume par patient (Trial
% contient sinon toutes les tâches de la session : CALIBRATION1-6,
% ANALYTIC1-5, FUNCTIONAL1-4...).
% CALIBRATION3 peut s'appeler STATIC3 sur les sessions plus anciennes (voir
% trialOrder dans Multi/Core/runProtocol01.m) - filtré sur les deux noms.
% Pour ajouter une tâche à garder : l'ajouter à keepTasks.
keepTasks = {'CALIBRATION3', 'STATIC3', 'ANALYTIC1', 'ANALYTIC2'};
Trial = Trial(ismember({Trial.task}, keepTasks));

% Champs lourds jamais relus depuis la base par
% ComputeClinicalContributionsFromDatabase (qui ne lit que
% Joint(*).Euler.rcycle/lcycle) : trajectoires marqueurs brutes (le champ
% le plus lourd) et doublons Segment.rM/.Q (copies des marqueurs, jamais
% utilisées nulle part dans le pipeline, même en live).
for k = 1:numel(Trial)
    if isfield(Trial, 'Marker')
        for m = 1:numel(Trial(k).Marker)
            Trial(k).Marker(m).Trajectory.full   = [];
            Trial(k).Marker(m).Trajectory.rcycle = [];
            Trial(k).Marker(m).Trajectory.lcycle = [];
        end
    end
    if isfield(Trial, 'Vmarker')
        for m = 1:numel(Trial(k).Vmarker)
            Trial(k).Vmarker(m).Trajectory.full   = [];
            Trial(k).Vmarker(m).Trajectory.rcycle = [];
            Trial(k).Vmarker(m).Trajectory.lcycle = [];
        end
    end
    if isfield(Trial, 'Segment')
        for s = 1:numel(Trial(k).Segment)
            Trial(k).Segment(s).rM.full   = [];
            Trial(k).Segment(s).rM.rcycle = [];
            Trial(k).Segment(s).rM.lcycle = [];
            Trial(k).Segment(s).Q.full    = [];
            Trial(k).Segment(s).Q.rcycle  = [];
            Trial(k).Segment(s).Q.lcycle  = [];
        end
    end
end
end
