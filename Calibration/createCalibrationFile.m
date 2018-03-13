function [ calibrationData ] = createCalibrationFile(fiberdiameter, lampFile, spectrumFile, darkSpectrumFile, saveFilename)
%CREATECALIBRATIONFILE Calculates calibration data from a raw spectrum and lamp file
% The calibration file in uJoule/count is calculated from the lamp file
% [uW/nm/cm^2], the integration time [s], the collection area [cm^2] and
% the wavelength spread [nm/pixel].

%% Initialization
lampDirectory = '';
spectrumDirectory = '';
darkSpectrumDirectory = '';
saveFileDirectory = '';

%% Set area
if (~exist('fiberdiameter', 'var'))
    fiberdiameter = inputdlg('Enter fiber diameter [cm]', 'Fiber diameter' , 1, {'0'});
    fiberdiameter = str2num(fiberdiameter{1});
end

%% Select lamp file
if (~exist('lampFile', 'var'))
    [lampFile lampDirectory] = uigetfile({'*.lmp';'*.*'}, 'Select the lamp file');
end

%% Select spectra
% Load one smoothed spectrum
if (~exist('spectrumFile', 'var'))
    [spectrumFile spectrumDirectory] = uigetfile({'*.txt';'*.*'}, 'Select the smoothed spectrum');
end
spect = importdata(strcat(spectrumDirectory, spectrumFile));
Sp = spect.data;
% Integration time
IndexC = strfind(lower(spect.textdata), 'integration time');
Index = find(not(cellfun('isempty', IndexC)));
T = textscan(lower(spect.textdata{Index}), 'integration time (usec): %f'); % usec
T = T{1}/1e6;   % [s]

% Load dark spectrum
if (~exist('darkSpectrumFile', 'var'))
    [darkSpectrumFile darkSpectrumDirectory] = uigetfile({'*.txt';'*.*'}, 'Select the dark spectrum');
end
darkSpect = importdata(strcat(darkSpectrumDirectory, darkSpectrumFile));
Dp = darkSpect.data;

%% Import lamp file and create a spline interpolant fit
lmp = importdata(strcat(lampDirectory,lampFile));             % µW/cm^2/nm
fit = spline(lmp(:,1), lmp(:,2), lmp(1,1):0.01:lmp(end,1));

%% Show fit for verification
figure; hold all;
plot(lmp(:,1), lmp(:,2), '*');
plot(lmp(1,1):0.01:lmp(end,1), fit);
legend('Lamp file', 'Spline interpolant');
xlabel('Wavelength [nm]', 'Interpreter', 'latex');
ylabel('Absolute irradiance [$\mathrm{\mu W/cm^2/nm}$]', 'Interpreter', 'latex');

%% Determine joules per count
A = pi*(fiberdiameter/2)^2;     % cm^2
dLp = Sp(2,1) - Sp(1,1);        % nm
lampIrradiance = spline(lmp(:,1), lmp(:,2), Sp(:,1));   % uW/nm/cm^2
lampIrradiance(Sp(:,1) < lmp(1,1)) = 0; lampIrradiance(Sp(:,1) > lmp(end,1)) = 0;   % Set values outside range to 0

calibrationData.wavelength = Sp(:,1);
calibrationData.ujoulepercount = lampIrradiance*(T * A * dLp)./(Sp(:,2) - Dp(:,2));
calibrationData.integrationtime = T;
calibrationData.A = A;

if (~exist('saveFilename', 'var'))
    [saveFilename saveFileDirectory] = uiputfile('', 'Select filename for saving of calibration file', '.mat');
end
save(strcat(saveFileDirectory, saveFilename), 'calibrationData');

end

