% Author       : F. Moissenet
%                Kinesiology Laboratory (K-LAB)
%                University of Geneva
%                https://www.unige.ch/medecine/kinesiology
% License      : Creative Commons Attribution-NonCommercial 4.0 International License 
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code  : To be defined
% Reference    : To be defined
% Date         : July 2022
% -------------------------------------------------------------------------
% Description  : To be defined
% Inputs       : To be defined
% Outputs      : To be defined
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution - icycle
% NonCommercial 4.0 International License. To view a copy of this license, 
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to 
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function Trial = InitialiseForceSignals(c3dFiles,Trial,Analog,Event,mass,calibration)

if contains(Trial.file,'CALIBRATION4')
    disp('  - Calibrage des données du capteur de force');
    if isfield(Event,'Remote')
        % Get calibration values 
        weight                    = mass*9.81; % (N)
        fmax                      = mean(Analog.FORCE);
        Trial.Fsensor.label       = 'Force sensor';
        Trial.Fsensor.calibration = weight/(mean(Analog.FORCE(fix(Event.Remote(1)*Trial.fanalog):fix(Event.Remote(2)*Trial.fanalog),1)));
        Trial.Fsensor.Force.value = permute(Analog.FORCE*Trial.Fsensor.calibration,[2,3,1]); % N
        Trial.Fsensor.Force.units = 'N';
    else
        Trial.Fsensor.label = 'Force sensor';
        Trial.Fsensor.calibration = 0;
        Trial.Fsensor.Force.value = []; % N
        Trial.Fsensor.Force.units = 'N';        
    end
elseif contains(c3dFiles.name,'CALIBRATION5') || contains(c3dFiles.name,'CALIBRATION6') || ...
       contains(c3dFiles.name,'ISOMETRIC1') || contains(c3dFiles.name,'ISOMETRIC2') % Isometric tasks only (ISOMETRIC1/2 : older-session alias for CALIBRATION5/6)
    if ~isempty(getCurrentTask())
        % Worker parfor (pipeline multi, MAIN_MULTI_Protocol_01.m) : pas
        % d'affichage utilisable pour la figure/ginput ci-dessous, qui
        % resterait bloquee indefiniment. Meme protection que
        % Core/CutCycles.m pour la selection manuelle des cycles.
        disp(['  [!] Calibrage capteur de force pour ', c3dFiles.name, ...
            ' necessite une selection manuelle (ginput) indisponible dans un ', ...
            'worker parallele - a traiter en pipeline solo pour calibration manuelle.']);
        Trial.Fsensor.label = 'Force sensor';
        Trial.Fsensor.calibration = calibration;
        Trial.Fsensor.Force.value = []; % N
        Trial.Fsensor.Force.units = 'N';
    else
        disp('  - Calibrage des données du capteur de force');
        figure;
        plot(Analog.FORCE);
        title('Sélectionner le début et la fin de la ligne de base');
        baseline = ginput(2);
        close gcf;
        Trial.Fsensor.label = 'Force sensor';
        Trial.Fsensor.calibration = calibration;
        Trial.Fsensor.Force.value = permute((Analog.FORCE-mean(Analog.FORCE(baseline(1):baseline(2))))*calibration,[2,3,1]); % N
        Trial.Fsensor.Force.units = 'N';
    end
else
    Trial.Fsensor.label = 'Force sensor';
    Trial.Fsensor.calibration = calibration;
    Trial.Fsensor.Force.value = []; % N
    Trial.Fsensor.Force.units = 'N';
end  