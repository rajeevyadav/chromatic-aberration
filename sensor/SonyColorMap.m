%% Sony ICX655, 2/3" colour quantum efficiency
% Sample Red, Green, and Blue quantum efficiencies from the data for the Sony
% ICX655, 2/3" camera sensor provided by FLIR.
%
% ## Usage
% Modify the parameters, the first code section below, then run.
%
% ## Input
%
% The image file 'FL3_GE_50S5C_quantumEfficiencyData.png' was copied from
% the FLIR FLEA3 GigE Vision Imaging Performance Specification document
% (saved as
% '/home/llanos/GoogleDrive/ThesisResearch/Equipment/FLEA3/20170508_FL3_GE_EMVA_Imaging
% Performance Specification.pdf', and downloaded from
% https://www.ptgrey.com/). The image contains quantum efficiency data for
% the Sony ICX655, 2/3" sensor used in FL3-GE-50S5C-C cameras.
%
% FLIR was unwilling to provide numerical data to supplement the graph, and
% recommended that each camera's spectral sensitivity be calibrated.
%
% ## Output
%
% ### Graphical output
% - A plot of the sensor quantum efficiency curves for comparison with the
%   input data.
%
% ### Sensor quantum efficiency data
%
% A '.mat' file containing the following variables:
% - 'sensor_map': A 2D array, where `sensor_map(i, j)` is the sensitivity
%   of the i-th colour channel (Red, Green, or Blue) to light of the j-th
%   wavelength.
% - 'bands': A vector containing the wavelengths corresponding to the
%   columns of `sensor_map`.
%
% Additionally, the file contains the values of all parameters in the first
% section of the script below, for reference. (Specifically, those listed
% in `parameters_list`, which should be updated if the set of parameters is
% changed.)
%
% ## Notes

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created May 29, 2018

% List of parameters to save with results
parameters_list = {
        'data_source',...
        'bands'...
    };

%% Input data and parameters

fn_name = 'sonyQuantumEfficiency';
bands = linspace(200, 1200, 1000);

%% Load the data

data_source = which(fn_name);

qe = sonyQuantumEfficiency(bands);
qe_percent = qe * 100;

sensor_map = qe.';

%% Visualization

figure;
hold on
plot(bands, qe_percent(:, 1), 'r');
plot(bands, qe_percent(:, 2), 'g');
plot(bands, qe_percent(:, 3), 'b');
hold off
xlabel('Wavelength [nm]')
ylabel('Quantum efficiency [%]')
title('Sony ICX655, 2/3" colour quantum efficiency')
legend('Red', 'Green', 'Blue')

%% Save to a file
save_variables_list = [ parameters_list, {...
        'sensor_map'...
    } ];
uisave(save_variables_list,'SonyColorMapData');