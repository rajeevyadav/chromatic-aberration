%% Evaluate demosaicking, spectral reconstruction, and/or chromatic aberration correction
% Run algorithms on a dataset to evaluate demosaicking, spectral
% reconstruction, and/or chromatic aberration correction
%
% ## Usage
% Modify the parameters, the first code section below, then run.
%
% ## Input
%
% The dataset determines the data to be loaded, the algorithms to be
% tested, and the types of evaluations to perform, as encapsulated by the
% 'describeDataset()' function.
%
% The documentation in the scripts 'CorrectByHyperspectralADMM.m' and
% 'CorrectByWarping.m' contains more information on the formats of the
% various types of data associated with the datasets.
%
% This script also runs 'SetFixedParameters.m' to set the values of
% seldomly-changed parameters. These parameters are briefly documented in
% 'SetFixedParameters.m'.
%
% In contrast with 'CorrectByHyperspectralADMM.m', the wavelengths at which
% hyperspectral images are to be sampled are either determined from ground
% truth hyperspectral data, or are otherwise set by 'SetFixedParameters.m',
% but are not loaded from colour space conversion data, or dispersion model
% data.
%
% ## Output
%
% ### Estimated images
%
% The following types of images are created for each input image, depending
% on the image estimation algorithms. The filename of the input image,
% concatenated with a string of parameter information, is represented by
% '*' below:
% - '*_roi.tif' and '*_roi.mat': A cropped version of the input image
%   (stored in the variable 'I_raw'), containing the portion used as input.
%   This region of interest was determined using the domain of the model of
%   dispersion associated with the dataset. If no model of dispersion is
%   associated with the dataset, the cropped region is the entire input
%   image. All of the other output images listed below are limited to the
%   region shown in this output image.
% - '*_latent.mat': The estimated latent spectral image (stored in the
%   variable 'I_latent') corresponding to the input image.
% - '*_rgb.tif' and '*_rgb.mat': A colour image (stored in the variable
%   'I_rgb'). If it was not estimated directly, it was created by
%   converting the latent image to the RGB colour space of the input image.
%
% ### Data file output
%
% #### Intermediate data and parameters
% A '.mat' file containing the following variables, as appropriate:
% - 'bands': A vector containing the wavelengths of the spectral
%   bands used in hyperspectral image estimation.
% - 'bands_spectral': A vector containing the wavelengths of the spectral
%   bands associated with ground truth hyperspectral images.
% - 'sensor_map_resampled': A resampled version of the 'sensor_map'
%   variable loaded from colour space conversion data, used for
%   hyperspectral image estimation. 'sensor_map_resampled' is the spectral
%   response functions of the camera (or, more generally, of the output
%   3-channel colour space) approximated at the wavelengths in `bands`.
% - 'sensor_map_spectral': A resampled version of the 'sensor_map'
%   variable loaded from colour space conversion data, used to convert
%   ground truth spectral images to color. 'sensor_map_spectral' is the
%   spectral response functions of the camera (or, more generally, of the
%   output 3-channel colour space) approximated at the wavelengths in
%   `bands_spectral`.
% - 'admm_algorithms': A structure describing the ADMM algorithms being
%   evaluated, created by 'SetAlgorithms.m'.
% - 'demosaic_algorithms': A structure describing the demosaicking
%   algorithms being evaluated, created by 'SetAlgorithms.m'.
% 
% Additionally, the file contains the values of all parameters listed in
% `parameters_list`, which is initialized in this file, and then augmented
% by 'SetFixedParameters.m'.
%
% The file is saved as 'RunOnDataset_${dataset_name}.mat'.
%
% #### Evaluation results
%
% For each image, RGB error metrics and (if applicable) spectral error
% metrics are output in the form of CSV files. Each CSV file contains
% results for all algorithms tested. The RGB error metrics are saved as
% '*_evaluateRGB.csv', whereas the spectral error metrics are saved as
% '*_evaluateSpectral.csv'.
%
% Error metrics are also aggregated across images, and saved as
% '${dataset_name}_evaluateRGB.csv' and
% '${dataset_name}_evaluateSpectral.csv'.
%
% ## Notes
% - This script only uses the first row of `patch_sizes`, and the first
%   element of `paddings`, defined in 'SetFixedParameters.m'.
% - This script ignores the `downsampling_factor` parameter defined in
%   'SetFixedParameters.m'.
%
% ## References
%
% The adaptive residual interpolation demosaicking algorithm
% ('third_party/Sensors_ARI/') was developed by Yusuke Monno and Daisuke
% Kiku, and was retrieved from
% http://www.ok.sc.e.titech.ac.jp/res/DM/RI.html
%
% It is described in:
%
%   Yusuke Monno, Daisuke Kiku, Masayuki Tanaka, and Masatoshi Okutomi,
%   "Adaptive Residual Interpolation for Color and Multispectral Image
%   Demosaicking," Sensors, vol.17, no.12, pp.2787-1-21, 2017.

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created July 27, 2018

% List of parameters to save with results
parameters_list = {
        'dataset_name',...
        'output_directory'...
    };

%% Input data and parameters

dataset_name = 'kodak';

% Describe algorithms to run
run('SetAlgorithms.m')

% Output directory for all images and saved parameters
output_directory = '/home/llanos/Downloads';

% Produce console output to describe the processing in this script
verbose = true;

% ## Parameters which do not usually need to be changed
run('SetFixedParameters.m')

% Check for problematic parameters
if add_border
    % Estimating a border area results in images which are usually not
    % registered with the ground truth.
    error('Estimating a border around images prevents quantitative evaluation.');
end

%% Preprocess the dataset

dp = describeDataset(dataset_name);

run('PreprocessDataset.m')

%% Process the images

n_weights = size(weights, 1);
patch_size = patch_sizes(1, :);
padding = paddings(1);

e_rgb_tables = cell(n_images, 1);
e_spectral_tables = cell(n_images, 1);

% Fixed options for ADMM
solvePatchesOptions.add_border = add_border;
baek2017Algorithm2Options.add_border = false;
solvePatchesOptions.patch_size = patch_size;
solvePatchesOptions.padding = padding;

for i = 1:n_images
    if verbose
        fprintf('[RunOnDataset, image %d] Starting\n', i);
    end

    % Generate or load input images, and instantiate dispersion information
    run('LoadAndConvertImage.m');
        
    saveImages(...
        output_directory, names{i},...
        I_raw_gt, '_roi', 'I_raw'...
    );
    
    % Compare the aberrated image to the original
    
    if isempty(I_rgb_gt_warped)
        e_rgb_table = [];
    else
        % Evaluate the aberrated image as a baseline
        e_rgb_table = evaluateAndSaveRGB(...
            I_rgb_gt_warped, I_rgb_gt, dp, names{i}, 'Aberrated',...
            fullfile(output_directory, [names{i} '_aberrated'])...
        );
    end
    
    admm_algorithm_fields = fieldnames(admm_algorithms);
    n_admm_algorithms = length(admm_algorithm_fields);
    n_spectral_evaluations = 0;
    if has_spectral && can_evaluate_spectral
        for f = 1:n_admm_algorithms
            algorithm = admm_algorithms.(admm_algorithm_fields{f});
            if algorithm.enabled && algorithm.spectral
                n_spectral_evaluations = n_spectral_evaluations + 1;
            end
        end
        n_spectral_evaluations = n_spectral_evaluations * n_weights;
    end
    if ~isempty(I_spectral_gt_warped)
        n_spectral_evaluations = n_spectral_evaluations + 1;
    end
    if n_spectral_evaluations > 0
        evaluation_plot_colors = jet(n_spectral_evaluations);
        if isempty(I_spectral_gt_warped)
            evaluation_plot_colors_admm = evaluation_plot_colors;
        else
            evaluation_plot_colors_admm = evaluation_plot_colors(2:end, :);
        end
    end
    if isempty(I_spectral_gt_warped)
        e_spectral_table = [];
        fg_spectral = struct;
        all_alg_names = {};
    else
        dp.evaluation.global_spectral.plot_color = evaluation_plot_colors(1, :);
        all_alg_names = {'Aberrated'};
        [e_spectral_table, fg_spectral] = evaluateAndSaveSpectral(...
            I_spectral_gt_warped, I_spectral_gt, bands_spectral,...
            dp, names{i}, all_alg_names{1},...
            fullfile(output_directory, [names{i} '_aberrated'])...
        );
    end
    
    % Run the algorithms
    
    % ADMM
    color_ind = 1;
    for w = 1:n_weights
        for f = 1:n_admm_algorithms
            algorithm = admm_algorithms.(admm_algorithm_fields{f});
            if ~algorithm.enabled
                continue;
            end
            
            if algorithm.spectral
                if has_color_map
                    if channel_mode
                        baek2017Algorithm2Options.int_method = 'none';
                        solvePatchesOptions.int_method = 'none';
                    else
                        baek2017Algorithm2Options.int_method = int_method;
                        solvePatchesOptions.int_method = int_method;
                    end
                else
                    continue;
                end
            else
                baek2017Algorithm2Options.int_method = 'none';
                solvePatchesOptions.int_method = 'none';
            end
            
            weights_f = weights(w, :);
            weights_f(~algorithm.priors) = 0;
            
            baek2017Algorithm2Options_f = mergeStructs(...
                baek2017Algorithm2Options, algorithm.options, false, true...
            );
    
            name_params = sprintf(...
                '%s_patch%dx%d_pad%d_weights%ew%ew%e_',...
                algorithm.file, patch_size(1), patch_size(2), padding,...
                weights_f(1), weights_f(2), weights_f(3)...
                );
            alg_name_params = sprintf(...
                '%s, patch %d x %d, padding %d, weights (%g, %g, %g)',...
                algorithm.file, patch_size(1), patch_size(2), padding,...
                weights_f(1), weights_f(2), weights_f(3)...
                );
            if algorithm.spectral
                name_params = [...
                    names{i}, sprintf('_bands%d_', n_bands), name_params...
                    ];
                alg_name_params = [...
                    alg_name_params, sprintf(', %d bands', n_bands)...
                    ];
                [...
                    I_latent, ~, I_rgb...
                ] = solvePatchesAligned(...
                    I_raw_gt, bayer_pattern, df_spectral_reverse,...
                    sensor_map_resampled,...
                    bands, solvePatchesOptions, @baek2017Algorithm2,...
                    {...
                        weights_f, rho,...
                        baek2017Algorithm2Options_f, baek2017Algorithm2Verbose...
                    }...
                );
                saveImages(...
                    output_directory, name_params,...
                    I_latent, 'latent', 'I_latent',...
                    I_rgb, 'latent_rgb', 'I_rgb'...
                );
            
                % Spectral evaluation
                if can_evaluate_spectral
                    dp.evaluation.global_spectral.plot_color =...
                        evaluation_plot_colors_admm(color_ind, :);
                    color_ind = color_ind + 1;
                    all_alg_names{end + 1} = algorithm.name;
                    [e_spectral_table_current, fg_spectral] = evaluateAndSaveSpectral(...
                        I_latent, I_spectral_gt, bands, dp, names{i},...
                        alg_name_params,...
                        fullfile(output_directory, name_params(1:(end-1))),...
                        fg_spectral...
                    );
                    if ~isempty(e_spectral_table)
                        e_spectral_table = union(e_spectral_table_current, e_spectral_table);
                    else
                        e_spectral_table = e_spectral_table_current;
                    end
                end
            else
                name_params = [...
                    names{i}, '_RGB_', name_params...
                ];
                alg_name_params = [...
                    alg_name_params, ', RGB'...
                ];
                I_rgb = solvePatchesAligned(...
                    I_raw_gt, bayer_pattern, df_rgb_reverse,...
                    sensor_map_rgb,...
                    bands_rgb, solvePatchesOptions, @baek2017Algorithm2,...
                    {...
                        weights_f, rho,...
                        baek2017Algorithm2Options_f, baek2017Algorithm2Verbose...
                    }...
                );
                saveImages(...
                    output_directory, name_params,...
                    I_rgb, 'rgb', 'I_rgb'...
                );
            end
            
            % RGB evaluation
            e_rgb_table_current = evaluateAndSaveRGB(...
                I_rgb, I_rgb_gt, dp, names{i}, alg_name_params,...
                fullfile(output_directory, name_params(1:(end-1)))...
            );
            if ~isempty(e_rgb_table)
                e_rgb_table = union(e_rgb_table_current, e_rgb_table);
            else
                e_rgb_table = e_rgb_table_current;
            end
        end
    end
    
    % Demosaicking and colour channel warping
    demosaic_algorithm_fields = fieldnames(demosaic_algorithms);
    W_forward = [];
    for f = 1:length(demosaic_algorithm_fields)
        algorithm = demosaic_algorithms.(demosaic_algorithm_fields{f});
        if ~algorithm.enabled
            continue;
        end
    
        if ischar(algorithm.fn)
            if strcmp(algorithm.fn, 'matlab')
                I_raw_int = im2uint16(I_raw_gt);
                I_rgb_warped = im2double(demosaic(I_raw_int, bayer_pattern));
            elseif strcmp(algorithm.fn, 'ARI')
                I_rgb_warped = demosaic_ARI(...
                    repmat(I_raw_gt, 1, 1, n_channels_rgb), bayer_pattern...
                );
            else
                error('Unrecognized demosaicking algorithm name.');
            end
        else
            I_rgb_warped = algorithm.fn(I_raw_gt, bayer_pattern);
        end
        saveImages(...
            output_directory, names{i},...
            I_rgb_warped, sprintf('_%s', algorithm.file), 'I_rgb'...
        );
    
        % RGB evaluation
        e_rgb_table_current = evaluateAndSaveRGB(...
            I_rgb_warped, I_rgb_gt, dp, names{i}, algorithm.name,...
            fullfile(output_directory, [names{i} '_' algorithm.file])...
        );
        if ~isempty(e_rgb_table)
            e_rgb_table = union(e_rgb_table_current, e_rgb_table);
        else
            e_rgb_table = e_rgb_table_current;
        end
            
        if has_dispersion_rgb
            
            if isempty(W_forward)
                if verbose
                    fprintf('[RunOnDataset, image %d] Calculating the forward colour dispersion matrix...\n', i);
                end
                W_forward = dispersionfunToMatrix(...
                    df_rgb_forward, bands_rgb, image_sampling, image_sampling,...
                    [0, 0, image_sampling(2),  image_sampling(1)], false...
                    );
                if verbose
                    fprintf('\t...done\n');
                end
            end
    
            I_rgb = warpImage(I_rgb_warped, W_forward, image_sampling);
            saveImages(...
                output_directory, names{i},...
                I_rgb, sprintf('_%s_channelWarp', algorithm.file), 'I_rgb'...
            );
        
            % RGB evaluation
            e_rgb_table_current = evaluateAndSaveRGB(...
                I_rgb, I_rgb_gt, dp, names{i},...
                sprintf('%s, warp-corrected', algorithm.name),...
                fullfile(output_directory, [names{i} '_' algorithm.file '_channelWarp'])...
            );
            if ~isempty(e_rgb_table)
                e_rgb_table = union(e_rgb_table_current, e_rgb_table);
            else
                e_rgb_table = e_rgb_table_current;
            end
        end
    end

    % Write evaluations to a file
    if ~isempty(e_rgb_table)
        writetable(...
            e_rgb_table,...
            fullfile(output_directory, [names{i}, '_evaluateRGB.csv'])...
        );
        e_rgb_tables{i} = e_rgb_table;
    end
    if ~isempty(e_spectral_table)
        writetable(...
            e_spectral_table,...
            fullfile(output_directory, [names{i}, '_evaluateSpectral.csv'])...
        );
        % Also save completed figures
        evaluateAndSaveSpectral(output_directory, dp, names{i}, all_alg_names, fg_spectral);
        e_spectral_tables{i} = e_spectral_table;
    end

    if verbose
        fprintf('[RunOnDataset, image %d] Finished\n', i);
    end
end

%% Save results for all images

e_rgb_tables = e_rgb_tables(~cellfun(@isempty, e_rgb_tables, 'UniformOutput', true));
if ~isempty(e_rgb_tables)
    e_rgb_summary_table = mergeRGBTables(e_rgb_tables);
    writetable(...
        e_rgb_summary_table,...
        fullfile(output_directory, [dataset_name, '_evaluateRGB.csv'])...
    );
end

e_spectral_tables = e_spectral_tables(~cellfun(@isempty, e_spectral_tables, 'UniformOutput', true));
if ~isempty(e_spectral_tables)
    e_spectral_summary_table = mergeSpectralTables(e_spectral_tables);
    writetable(...
        e_spectral_summary_table,...
        fullfile(output_directory, [dataset_name, '_evaluateSpectral.csv'])...
    );
end

%% Save parameters and additional data to a file
save_variables_list = [ parameters_list, {...
    'bands', 'admm_algorithms', 'demosaic_algorithms'...
} ];
if has_spectral
    save_variables_list = [save_variables_list, {'bands_spectral'}];
end
if has_color_map
    save_variables_list = [save_variables_list, {'sensor_map_resampled'}];
    if has_spectral
        save_variables_list = [save_variables_list, {'sensor_map_spectral'}];
    end
end
save_data_filename = fullfile(output_directory, ['RunOnDataset_' dataset_name '.mat']);
save(save_data_filename, save_variables_list{:});