%% Demosaicing and hyperspectral ADMM-based correction of chromatic aberration
% Test the grid search method of Song et al. 2016 for selecting
% regularization weights, but minimizing the true error, or the error with
% respect to a demosaicking result.
%
% ## Usage
% Modify the parameters, the first code section below, then run.
%
% ## Input
%
% ### Input images
%
% #### RAW image
% A RAW image to be demosaiced and corrected for chromatic aberration.
%
% The image is expected to have been preprocessed, such as using
% 'PreprocessRAWImages.m', so that it does not need to be linearized after
% being loaded. For image format files, the image will simply be loaded
% with the Image Processing Toolbox 'imread()' function. For '.mat' files,
% the variable to be loaded must be provided in the script parameters.
%
% The image is expected to have 3 colour channels (Red, Green, Blue)
% (represented in a Bayer pattern as a 2D array). However, the colour
% channels can correspond to narrowband wavelength ranges - This script
% will input a mapping from the colour space of the latent image to the
% colour space of the RAW image.
%
% #### True image
% A spectral or colour image serving as the ground truth for image
% estimation. If `use_demosaic` is `false`, the reference image is also
% used to select the weights giving the lowest error.
%
% The true image must be associated with a '.mat' file containing a vector
% with the variable 'bands'. 'bands' must have the same length as the third
% dimension of the true image, and must contain the colour channel indices
% or wavelengths corresponding to the true image.
%
% ### Model of dispersion
%
% A '.mat' file containing several variables, which is the output of
% 'RAWDiskDispersion.m', 'DoubleConvexThickLensDispersion.m' or
% 'BimaterialImages.m', for example. The following variables are required:
% - 'dispersion_data': A model of chromatic aberration, modeling the warping
%   from the reference colour channel or wavelength band to the other
%   colour channels or wavelength bands. `dispersion_data` can be converted to
%   a function form using `dispersionfun = makeDispersionfun(dispersion_data)`.
% - 'model_from_reference': A parameter of the above scripts, which
%   determines the frame of reference for the model of chromatic
%   aberration. It must be set to `false`.
% - 'bands': A vector containing the wavelengths or colour channel indices
%   to use as the `lambda` input argument of 'dispersionfunToMatrix()'.
%   `bands` is the wavelength or colour channel information needed to
%   evaluate the dispersion model.
%
% The following two additional variables are optional. If they are present,
% they will be used for the following purposes:
% - Conversion between the coordinate system in which the model of chromatic
%   aberration was constructed and the image coordinate system.
% - Limiting the correction of chromatic aberration to the region in which
%   the model is valid.
% The first variable, 'model_space' is a structure with same form as the
% `model_space` input argument of 'modelSpaceTransform()'. The second
% variable, `fill`, can be omitted, in which case it defaults to `false`.
% `fill` corresponds to the `fill` input argument of
% 'modelSpaceTransform()'. Refer to the documentation of
% 'modelSpaceTransform.m' for details.
%
% ### Colour space conversion data
% A '.mat' file containing several variables, which is the output of
% 'SonyColorMap.m', for example. The following variables are required:
% - 'sensor_map': A 2D array, where `sensor_map(i, j)` is the sensitivity
%   of the i-th colour channel or spectral band in the input images to the
%   j-th colour channel or spectral band of the latent images. For example,
%   `sensor_map` is a matrix mapping discretized spectral power
%   distributions to RGB colours.
% - 'channel_mode': A Boolean value indicating whether the latent colour
%   space is a set of colour channels (true) or a set of spectral bands
%   (false).
% - 'bands': A vector containing the wavelengths or colour channel indices
%   corresponding to the second dimension of 'sensor_map'.
%
% ## Output
%
% ### Graphical output
%
% Figures are opened showing the search path taken by the grid search
% method of Song et al. 2016 for selecting regularization weights. The
% search path can be shown on plots of the true error hypersurface,
% depending on the amount of graphical output requested. (Sampling this
% surface is computationally-expensive.) Additional figures show the
% location of the image patch used for selecting the regularization
% weights, and compare the true and estimated patches.
%
% Graphical output relating to the grid search method will not be produced
% if there are more than three regularization weights to be chosen.
%
% ### Data file output
%
% A '.mat' file containing the following variables:
%
% - 'bands': A vector containing the wavelengths or colour channel
%   indices at which the estimated latent image is sampled.
% - 'bands_color': The 'bands' variable loaded from the colour space
%   conversion data file, for reference.
% - 'bands_gt': A vector containing the wavelengths or colour channel
%   indices at which the true latent image is sampled, loaded from the file
%   referred to by the variable, `true_image_bands_filename`, defined in
%   the parameters section below.
% - 'color_weights': A matrix for converting pixels in the latent image to
%   colour, as determined by the 'sensor_map' variable loaded from the
%   colour space conversion data file, and by the type of numerical
%   intergration to perform.
% - 'spectral_weights': A matrix for converting pixels in the latent image
%   to the spectral, or colour channel space, of the true latent image.
% - 'color_weights_reference': A matrix for converting pixels in the true
%   latent image to colour, as determined by the 'sensor_map' variable
%   loaded from the colour space conversion data file, and by the type of
%   numerical intergration to perform.
% - 'input_image_filename': The input image filename found using the
%   wildcard provided in the parameters section of the script.
% - 'true_image_filename': The true latent image filename found using the
%   wildcard provided in the parameters section of the script.
% 
% Additionally, the file contains the values of all parameters in the first
% section of the script below, for reference. (Specifically, those listed
% in `parameters_list`, which should be updated if the set of parameters is
% changed.)
%
% ## Notes
% - The image colour space is not altered by this script; RGB images are
%   produced in the camera's colour space.
% - This script does not distinguish between wavelength bands and colour
%   channels. One can use this script to estimate either a latent
%   hyperspectral image, or a latent aberration-free RGB image (free from
%   lateral chromatic aberration). A latent hyperspectral image can be
%   sharper, in theory, whereas a latent RGB image will retain the
%   within-channel chromatic aberration of the input image. The reason for
%   this difference is the summation of multiple spectral bands into each
%   channel of an RGB image, in contrast to the identity mapping of the
%   colours of a latent RGB image into the colours of the aberrated RGB
%   image. Summation allows multiple sharp bands to form a blurred colour
%   channel.
% - This script uses `solvePatchesADMMOptions.reg_options.enabled` defined
%   in 'SetFixedParameters.m' to determine which regularization weights to
%   set. Note that the number of `true` elements of
%   `solvePatchesADMMOptions.reg_options.enabled` determines the
%   dimensionality of the visualizations output by this script.
% - This script only uses the first row of `patch_sizes`, and the first
%   element of `paddings`, defined in 'SetFixedParameters.m', by using
%   `solvePatchesADMMOptions.patch_options`.
%
% ## References
% - Song, Y., Brie, D., Djermoune, E.-H., & Henrot, S.. "Regularization
%   Parameter Estimation for Non-Negative Hyperspectral Image
%   Deconvolution." IEEE Transactions on Image Processing, vol. 25, no. 11,
%   pp. 5316-5330, 2016. doi:10.1109/TIP.2016.2601489

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created September 7, 2018

% List of parameters to save with results
parameters_list = {
    'true_image_bands_filename',...
    'reverse_dispersion_model_filename',...
    'color_map_filename',...
    'use_demosaic',...
    'output_directory',...
    'target_patch',...
    'n_samples'...
};

%% Input data and parameters

% Wildcard for 'ls()' to find the image to process.
% '.mat' or image files can be loaded
input_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180817_TestSpectralDataset/dataset/lacelike*raw.tif';
input_image_variable_name = 'I_raw'; % Used only when loading '.mat' files

% Wildcard for 'ls()' to find the true image.
% '.mat' or image files can be loaded
true_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180817_TestSpectralDataset/dataset/lacelike_0016_hyper.mat';
true_image_variable_name = 'I_hyper'; % Used only when loading '.mat' files

% Data file containing the colour channels or wavelengths associated with
% the true image
true_image_bands_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180817_TestSpectralDataset/dataset/BimaterialImagesData.mat';

% Model of dispersion
% Can be empty
reverse_dispersion_model_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180817_TestSpectralDataset/dataset/BimaterialImagesData.mat';

% Colour space conversion data
color_map_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180817_TestSpectralDataset/dataset/NikonD5100ColorMapData.mat';

% Select regularization weights by comparing with the true image (`false`)
% or with a demosaicking result (`true`)
use_demosaic = true;

% Output directory for all images and saved parameters
output_directory = '/home/llanos/Downloads';

% ## Options for the grid search method of Song et al. 2016

% The top-left corner (row, column) of the image patch to use for
% regularization weights selection. If empty (`[]`), the patch will be
% selected by the user.
target_patch = [239, 157];

% ## Parameters controlling graphical output

plot_image_patch = true;
plot_search_path = true;
plot_hypersurface = true;

% Number of values of each regularization weight to sample when
% constructing the error surface
% This can be a scalar, or a vector with a length equal to the number of
% weights (not only the number of active weights)
n_samples = 30;

% Parameters which do not usually need to be changed
run('SetFixedParameters.m')

%% Validate and adjust parameters

solvePatchesADMMOptions.reg_options.demosaic = use_demosaic;

if use_fixed_weights
    error('Automatic regularization weight selection is disabled by `use_fixed_weights`.');
end

%% Load the images

enabled_weights = solvePatchesADMMOptions.reg_options.enabled;
n_weights = length(enabled_weights);
if ~isscalar(n_samples) && isvector(n_samples) && length(n_samples) ~= n_weights
    error('If `n_samples is a vector, it must have as many elements as there are weights, %d.', n_weights);
end

input_image_filename = listFiles(input_image_wildcard);
[I_raw, name] = loadImage(input_image_filename{1}, input_image_variable_name);

if ~ismatrix(I_raw)
    error('Expected a RAW image, represented as a 2D array, not a higher-dimensional array.');
end

true_image_filename = listFiles(true_image_wildcard);
I_gt = loadImage(true_image_filename{1}, true_image_variable_name);

bands_variable_name = 'bands';
load(true_image_bands_filename, bands_variable_name);
if ~exist(bands_variable_name, 'var')
    error('No wavelength band or colour channel information is associated with the true image.')
end
bands_gt = bands;

%% Load calibration data

has_dispersion = ~isempty(reverse_dispersion_model_filename);
if has_dispersion
    [...
        dispersion_data, bands_dispersionfun, transform_data...
    ] = loadDispersionModel(reverse_dispersion_model_filename, false, false);
end

bands = [];
model_variables_required = { 'sensor_map', 'channel_mode' };
load(color_map_filename, model_variables_required{:}, bands_variable_name);
if ~all(ismember(model_variables_required, who))
    error('One or more of the required colour space conversion variables is not loaded.')
end
if isempty(bands)
    error('No (non-empty) variable `bands` loaded from colour space conversion data.');
end

bands_color = bands;

if channel_mode
    if has_dispersion && ...
       ((length(bands_color) ~= length(bands_dispersionfun)) ||...
       any(bands_color(:) ~= bands_dispersionfun(:)))
        error('When estimating a colour image, the same colour channels must be used by the model of dispersion.');
    end
    color_weights = sensor_map;
    spectral_weights = eye(length(bands_color));
    color_weights_reference = sensor_map;
else
    [...
        color_weights, spectral_weights, bands, color_weights_reference...
    ] = findSampling(...
      sensor_map, bands_color, bands_gt, findSamplingOptions, findSamplingVerbose...
    );
end

imageFormationOptions.patch_size = [100, 100];
imageFormationOptions.padding = 10;

%% Preprocess input data

% Crop images to the region of valid dispersion
if has_dispersion
    [dispersionfun, I_raw] = makeDispersionForImage(...
        dispersion_data, I_raw, transform_data, true...
    );
else
    dispersionfun = [];
end
image_sampling = size(I_raw);

if has_dispersion
    roi = modelSpaceTransform(...
        [size(I_gt, 1), size(I_gt, 2)],...
        transform_data.model_space, transform_data.fill, true...
    );
    if ~isempty(roi)
        I_gt = I_gt(roi(1):roi(2), roi(3):roi(4), :);
    end
end
if any([size(I_gt, 1), size(I_gt, 2)] ~= image_sampling)
    error([
        'The RAW version of the image has different spatial dimensions fro',...
        'm the true latent image.'...
    ]);
end

%% Grid search method for regularization weight selection

patch_size = patch_sizes(1, :);
padding = paddings(1);

if isempty(target_patch)
    fg = figure;
    imshow(I_raw);
    title('Choose the center of the image patch')
    [x,y] = ginput(1);
    target_patch = [
        max(1, round(y) - floor(patch_size(1) / 2)),...
        max(1, round(x) - floor(patch_size(2) / 2))...
    ];
    target_patch(mod(target_patch, 2) ~= 1) = target_patch(mod(target_patch, 2) ~= 1) + 1;
    close(fg);
end
solvePatchesADMMOptions.patch_options.target_patch = target_patch;

if use_demosaic
    [...
        I_patch, ~, ~, ~, ~, ~, weights_search...
    ] = solvePatchesADMM(...
      [], I_raw, bayer_pattern, dispersionfun,...
      color_weights, bands,...
      solvePatchesADMMOptions.admm_options,...
      solvePatchesADMMOptions.reg_options,...
      solvePatchesADMMOptions.patch_options,...
      solvePatchesADMMVerbose...
    );
else
    I_in.I = I_gt;
    I_in.spectral_weights = spectral_weights;
    [...
        I_patch, ~, ~, ~, ~, ~, weights_search...
    ] = solvePatchesADMM(...
      I_in, I_raw, bayer_pattern, dispersionfun,...
      color_weights, bands,...
      solvePatchesADMMOptions.admm_options,...
      solvePatchesADMMOptions.reg_options,...
      solvePatchesADMMOptions.patch_options,...
      solvePatchesADMMVerbose...
    );
end
[patch_lim, trim] = patchBoundaries(image_sampling, patch_size, padding, target_patch);
patch_lim_interior = [patch_lim(1, :) + trim(1, :) - 1; patch_lim(1, :) + trim(2, :) - 1];

%% Visualize the grid search method

% Display the target patch
if plot_image_patch
    [...
        I_rgb_gt, I_rgb_gt_warped,...
    ] = imageFormation(...
        I_gt, color_weights_reference, imageFormationOptions,...
        dispersionfun, bands_gt...
    );

    image_sampling_patch_exterior = diff(patch_lim, 1, 1) + 1;
    image_sampling_patch_interior = diff(patch_lim_interior, 1, 1) + 1;
    I_annotated = insertShape(...
        I_rgb_gt_warped, 'Rectangle',...
        [
            patch_lim(1, 2), patch_lim(1, 1), image_sampling_patch_exterior(2), image_sampling_patch_exterior(1);
            patch_lim_interior(1, 2), patch_lim_interior(1, 1), image_sampling_patch_interior(2), image_sampling_patch_interior(1)
        ],...
        'LineWidth', 2 ...
    );

    figure;
    imshow(I_annotated);
    title('Image patch used for weights estimation');
    
    % Compare the input and output patches
    I_patch_rgb_gt = I_rgb_gt(patch_lim_interior(1, 1):patch_lim_interior(2, 1), patch_lim_interior(1, 2):patch_lim_interior(2, 2), :);
    I_patch_rgb = imageFormation(I_patch, color_weights, imageFormationOptions);
    
    figure;
    imshowpair(I_patch_rgb_gt, I_patch_rgb, 'montage');
    title('True image patch vs. estimated image patch');
end

n_active_weights = sum(enabled_weights);
to_all_weights = find(enabled_weights);
n_iter = size(weights_search.weights, 1);

% Display the search path for the chosen weights
if n_active_weights < 4 && plot_search_path
    weights_path = weights_search.weights(:, enabled_weights);
    log_weights = log10(weights_path);
    log_weights_diff = [diff(log_weights, 1, 1); zeros(1, n_active_weights)];
    log_err_path = log10(weights_search.criterion);
    log_err_path_diff = [diff(log_err_path, 1, 1); zeros(1, size(log_err_path, 2))];

    figure;
    hold on
    if n_active_weights == 1
        iter_index = 1:n_iter;
        plot(...
            iter_index,...
            log_weights,...
            'Marker', 'o', 'Color', zeros(1, 3)...
        );
        xlabel('Iteration number')
        ylabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
    elseif n_active_weights == 2
        quiver(...
            log_weights(:, 1), log_weights(:, 2),...
            log_weights_diff(:, 1), log_weights_diff(:, 2),...
            'AutoScale', 'off', 'Color', zeros(1, 3)...
        );
        xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
    elseif n_active_weights == 3
        quiver3(...
            log_weights(:, 1), log_weights(:, 2), log_weights(:, 3),...
            log_weights_diff(:, 1), log_weights_diff(:, 2), log_weights_diff(:, 3),...
            'AutoScale', 'off', 'Color', zeros(1, 3)...
        );
        xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
        zlabel(sprintf('log_{10}(weight %d)', to_all_weights(3)))
    else
        error('Unexpected number of active weights.');
    end
    title('Search path for the selected weights, in weights space')
    hold off
    
elseif plot_search_path
    warning('The search path cannot be plotted in weights space when there are more than three active regularization terms.');
end

% Sample the error hypersurface
if n_active_weights < 3 && plot_hypersurface
    
    I_gt = bilinearDemosaic(I_raw, bayer_pattern, solvePatchesADMMOptions.reg_options.demosaic_channels);

    % Generate combinations of weights to test
    if isscalar(n_samples)
        n_samples_full = repmat(n_samples, n_active_weights, 1);
    else
        n_samples_full = n_samples(enabled_weights);
    end
    active_weights_samples = cell(n_active_weights, 1);
    for w = 1:n_active_weights
        active_weights_samples{w} = logspace(...
            log10(solvePatchesADMMOptions.reg_options.minimum_weights(to_all_weights(w))),...
            log10(solvePatchesADMMOptions.reg_options.maximum_weights(to_all_weights(w))),...
            n_samples_full(w)...
        ).';
    end
    n_samples_all = prod(n_samples_full);
    all_weights_samples = zeros(n_samples_all, n_weights);
    for w = 1:n_active_weights
        all_weights_samples(:, to_all_weights(w)) = repmat(...
            repelem(active_weights_samples{w}, prod(n_samples_full((w + 1):end))),...
            prod(n_samples_full(1:(w-1))), 1 ...
        );
    end
    all_weights_samples_plot = all_weights_samples(:, enabled_weights);
    log_all_weights_samples = log10(all_weights_samples_plot);

    % Construct arguments for the image estimation algorithm
    if isempty(bayer_pattern)
        align_f = [];
    else
        align_f = offsetBayerPattern(patch_lim(1, :), bayer_pattern);
    end
    image_sampling_f = diff(patch_lim, 1, 1) + 1;
    if has_dispersion
        dispersion_f = dispersionfunToMatrix(...
            dispersionfun, bands, image_sampling_f, image_sampling_f,...
            [0, 0, image_sampling_f(2), image_sampling_f(1)], true,...
            [patch_lim(2, 1), patch_lim(1, 1)] - 1 ...
            );
    else
        dispersion_f = [];
    end
    I_raw_f = I_raw(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :);
    n_bands = length(bands);
    in_admm = initBaek2017Algorithm2LowMemory(...
        I_raw_f, align_f, dispersion_f, color_weights,...
        enabled_weights, solvePatchesADMMOptions.admm_options...
    );

    % Test the combinations of weights
    all_mse_samples = zeros(n_samples_all, 1);
    all_demosaic_mse_samples = zeros(n_samples_all, 1);
    I_patch_gt = reshape(I_gt(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :), [], 1);
    I_in_f.I = I_gt(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :);
    I_in_f.spectral_weights = color_weights(solvePatchesADMMOptions.reg_options.demosaic_channels, :);
    in_weightsLowMemory = initWeightsLowMemory(I_in_f, dispersion_f, 0);
    for s = 1:n_samples_all
        weights_s = all_weights_samples(s, :);
        [in_admm, weights_s] = initBaek2017Algorithm2LowMemory(...
            in_admm, weights_s, solvePatchesADMMOptions.admm_options...
        );
        in_admm = initBaek2017Algorithm2LowMemory(in_admm);
        in_admm = baek2017Algorithm2LowMemory(...
            weights_s, solvePatchesADMMOptions.admm_options, in_admm...
        );
        all_mse_samples(s) = immse(...
            channelConversion(in_admm.I, spectral_weights, 1),...
            I_patch_gt...
        );
        all_demosaic_mse_samples(s) = immse(...
             in_weightsLowMemory.Omega_Phi * in_admm.I,...
             reshape(I_in_f.I, [], 1)...
         );
    end
    log_all_mse_samples = log10(all_mse_samples);
    log_all_demosaic_mse_samples = log10(all_demosaic_mse_samples);

    % Plotting
    spectral_mse_color = [1, 0, 0];
    demosaic_mse_color = [0, 1, 0];
    
    figure;
    hold on
    title('Patch log_{10}(MSE) surface with search path for the selected weights')
    if n_active_weights == 1
        plot(...
            log_all_weights_samples(:, 1), log_all_mse_samples,...
            'Marker', 'o', 'Color', spectral_mse_color...
        );
        plot(...
            log_all_weights_samples(:, 1), log_all_demosaic_mse_samples,...
            'Marker', 'o', 'Color', demosaic_mse_color...
        );
    elseif n_active_weights == 2
        tri = delaunay(log_all_weights_samples(:, 1), log_all_weights_samples(:, 2));
        trisurf(...
            tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
            log_all_mse_samples,...
            'FaceAlpha', 0.5, 'FaceColor', spectral_mse_color...
        );
        trisurf(...
            tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
            log_all_demosaic_mse_samples,...
            'FaceAlpha', 0.5, 'FaceColor', demosaic_mse_color...
        );
    else
        error('Unexpected number of active weights.');
    end
    if n_active_weights == 1
        quiver(...
            log_weights(:, 1), log_err_path,...
            log_weights_diff(:, 1), log_err_path_diff,...
            'AutoScale', 'off', 'Color', [0, 0, 1]...
        );
        xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        ylabel('log_{10}(Mean square error) wrt ground truth patch')
    elseif n_active_weights == 2
        quiver3(...
            log_weights(:, 1), log_weights(:, 2), log_err_path,...
            log_weights_diff(:, 1), log_weights_diff(:, 2), log_err_path_diff,...
            'AutoScale', 'off', 'Color', [0, 0, 1]...
        );
        xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
        zlabel('log_{10}(Mean square error) wrt ground truth patch')
    else
        error('Unexpected number of active weights.');
    end
    legend('Patch log_{10}(MSE) surface', 'Patch log_{10}(Green MSE) surface', 'Search path');
    hold off
    
elseif plot_search_path
    warning('The error surfaces cannot be plotted when there are more than two active regularization terms.');
end

%% Save parameters and additional data to a file
save_variables_list = [ parameters_list, {...
        'bands',...
        'bands_color',...
        'bands_gt',...
        'color_weights',...
        'spectral_weights',...
        'color_weights_reference',...
        'input_image_filename',...
        'true_image_filename'...
    } ];
save_data_filename = fullfile(output_directory, 'ValidateTrainWeights.mat');
save(save_data_filename, save_variables_list{:});