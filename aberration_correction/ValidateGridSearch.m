%% Demosaicing and hyperspectral ADMM-based correction of chromatic aberration
% Test the grid search method of Song et al. 2016 for selecting
% regularization weights
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
% 'AverageRAWImages.m', so that it does not need to be linearized after
% being loaded.  For image format files, the image will simply be loaded
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
% estimation. The true image is needed to compare the weights selected
% using the grid search method with the weights giving the lowest error
% relative to the true image.
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
% search path can be shown on plots of the L-hypersurface, and of the true
% error hypersurface, depending on the amount of graphical output
% requested. (Sampling these surfaces is computationally-expensive.) After
% sampling the L-hypersurface, further figures give insight into the
% convergence properties of the method. Lastly, additional figures show the
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
%   produced in the camera's colour space. See 'imreadRAW()' for code to
%   convert an image to sRGB after demosaicing.
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
% - This script uses `solvePatchesADMMOptions.reg_options.enabled`, defined
%   in 'SetFixedParameters.m', to determine which regularization weights to
%   set. Note that the number of `true` elements of
%   `solvePatchesADMMOptions.reg_options.enabled` determines the
%   dimensionality of the visualizations output by this script.
% - This script only uses the first row of `patch_sizes`, and the first
%   element of `paddings`, defined in 'SetFixedParameters.m', by using
%   `solvePatchesADMMOptions.patch_options`.
%
% ## References
% - Belge, M, Kilmer, M. E., & Miller, E. L.. "Efficient determination of
%   multiple regularization parameters in a generalized L-curve
%   framework." Inverse Problems, vol. 18, pp. 1161-1183, 2002.
%   doi:10.1088/0266-5611/18/4/314
% - Song, Y., Brie, D., Djermoune, E.-H., & Henrot, S.. "Regularization
%   Parameter Estimation for Non-Negative Hyperspectral Image
%   Deconvolution." IEEE Transactions on Image Processing, vol. 25, no. 11,
%   pp. 5316-5330, 2016. doi:10.1109/TIP.2016.2601489

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created September 5, 2018

% List of parameters to save with results
parameters_list = {
    'true_image_bands_filename',...
    'reverse_dispersion_model_filename',...
    'color_map_filename',...
    'output_directory',...
    'target_patch',...
    'n_samples'...
};

%% Input data and parameters

% Wildcard for 'ls()' to find the image to process.
% '.mat' or image files can be loaded
input_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/kodim19raw.mat';
input_image_variable_name = 'I_raw'; % Used only when loading '.mat' files

% Wildcard for 'ls()' to find the true image.
% '.mat' or image files can be loaded
true_image_wildcard = '/home/llanos/GoogleDrive/ThesisResearch/Data/20180726_Demosaicking_Kodak/PNG_Richard W Franzen/kodim19.png';
true_image_variable_name = 'I_hyper'; % Used only when loading '.mat' files

% Data file containing the colour channels or wavelengths associated with
% the true image
true_image_bands_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/RGBColorMapData.mat';

% Model of dispersion
% Can be empty
reverse_dispersion_model_filename = [];

% Colour space conversion data
color_map_filename = '/home/llanos/GoogleDrive/ThesisResearch/Results/20180828_Kodak_TestingLHypersurface/RGBColorMapData.mat';

% Output directory for all images and saved parameters
output_directory = '/home/llanos/Downloads';

% ## Options for the grid search method of Song et al. 2016

% The top-left corner (row, column) of the image patch to use for
% regularization weights selection. If empty (`[]`), the patch will be
% selected by the user.
target_patch = [335, 321]; %[473, 346];

% ## Parameters controlling graphical output

plot_image_patch = true;
plot_search_path = true;
plot_hypersurfaces = true;

% Number of values of each regularization weight to sample when
% constructing the L-hypersurface
% This can be a scalar, or a vector with a length equal to the number of
% weights (not only the number of active weights)
n_samples = 30;

% Parameters which do not usually need to be changed
run('SetFixedParameters.m')

%% Validate parameters

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
       any(bands_color ~= bands_dispersionfun))
        error('When estimating a colour image, the same colour channels must be used by the model of dispersion.');
    end
    color_weights = sensor_map;
    spectral_weights = eye(length(bands_color));
    color_weights_reference = sensor_map;
else
    [...
        color_weights, spectral_weights, bands, color_weights_reference...
    ] = samplingWeights(...
      sensor_map, bands_color, bands_gt, samplingWeightsOptions, samplingWeightsVerbose...
    );
end

imageFormationOptions.patch_size = [100, 100];
imageFormationOptions.padding = 10;

%% Preprocess input data

% Crop images to the region of valid dispersion
if has_dispersion
    [dispersionfun, I_raw] = makeDispersionForImage(...
        dispersion_data, I_raw, transform_data...
    );
else
    dispersionfun = [];
end
image_sampling = size(I_raw);

if has_dispersion
    roi = modelSpaceTransform(...
        [size(I_gt, 1), size(I_gt, 2)],...
        transform_data.model_space, transform_data.fill...
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
        max(1, round(y) - floor(options.patch_size(1) / 2)),...
        max(1, round(x) - floor(options.patch_size(2) / 2))...
    ];
    close(fg);
end
solvePatchesADMMOptions.patch_options.target_patch = target_patch;

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
if n_active_weights < 4
    
    to_all_weights = find(enabled_weights);
    err_filter = [true, enabled_weights];
    n_iter = size(weights_search.weights, 1);
    
    % Display the search path for the chosen weights
    if plot_search_path
        weights_path = weights_search.weights(:, enabled_weights);
        log_weights = log10(weights_path);
        log_weights_diff = [diff(log_weights, 1, 1); zeros(1, n_active_weights)];
        err_path = weights_search.err(:, err_filter);
        err_path_diff = [diff(err_path, 1, 1); zeros(1, size(err_path, 2))];
        
        figure;
        hold on
        if n_active_weights == 1
            iter_index = 1:n_iter;
            plot(...
                iter_index,...
                log_weights,...
                'Marker', 'o'...
            );
            xlabel('Iteration number')
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
        elseif n_active_weights == 2
            quiver(...
                log_weights(:, 1), log_weights(:, 2),...
                log_weights_diff(:, 1), log_weights_diff(:, 2),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
        elseif n_active_weights == 3
            quiver3(...
                log_weights(:, 1), log_weights(:, 2), log_weights(:, 3),...
                log_weights_diff(:, 1), log_weights_diff(:, 2), log_weights_diff(:, 3),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel(sprintf('log_{10}(weight %d)', to_all_weights(3)))
        else
            error('Unexpected number of active weights.');
        end
        title('Search path for the selected weights, in weights space')
        hold off
        
        figure;
        hold on
        if n_active_weights == 1
            quiver(...
                err_path(:, 2), err_path(:, 1),...
                err_path_diff(:, 2), err_path_diff(:, 1),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('regularization norm %d', to_all_weights(1)))
            ylabel('residual')
        elseif n_active_weights == 2
            quiver3(...
                err_path(:, 2), err_path(:, 3), err_path(:, 1),...
                err_path_diff(:, 2), err_path_diff(:, 3), err_path_diff(:, 1),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('regularization norm %d', to_all_weights(1)))
            ylabel(sprintf('regularization norm %d', to_all_weights(2)))
            zlabel('residual')
        elseif n_active_weights == 3
            quiver3(...
                err_path(:, 2), err_path(:, 3), err_path(:, 4),...
                err_path_diff(:, 2), err_path_diff(:, 3), err_path_diff(:, 4),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('regularization norm %d', to_all_weights(1)))
            ylabel(sprintf('regularization norm %d', to_all_weights(2)))
            zlabel(sprintf('regularization norm %d', to_all_weights(3)))
        else
            error('Unexpected number of active weights.');
        end
        title('Search path for the selected weights, in error space')
        hold off
    end
    
    % Sample the L-hypersurface and the true error hypersurface
    if plot_hypersurfaces && n_active_weights < 3
        
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
            image_sampling_f, align_f, dispersion_f, color_weights,...
            n_bands, enabled_weights, solvePatchesADMMOptions.admm_options...
        );
        in_penalties = initPenalties(in_admm.M_Omega_Phi, in_admm.G);
        
        % Test the combinations of weights
        all_err_samples = zeros(n_samples_all, n_weights + 1);
        all_mse_samples = zeros(n_samples_all, 1);
        I_patch_gt = reshape(I_gt(patch_lim(1, 1):patch_lim(2, 1), patch_lim(1, 2):patch_lim(2, 2), :), [], 1);
        for s = 1:n_samples_all
            weights_s = all_weights_samples(s, :);
            [in_admm, weights_s] = initBaek2017Algorithm2LowMemory(...
                in_admm, weights_s, solvePatchesADMMOptions.admm_options...
            );
            in_admm = baek2017Algorithm2LowMemory(...
                align_f, n_bands, I_raw_f, weights_s,...
                solvePatchesADMMOptions.admm_options, in_admm...
            );
            
            in_penalties = penalties(...
                in_admm.J, in_admm.I, in_admm.M_Omega_Phi, in_admm.G,...
                solvePatchesADMMOptions.admm_options.norms, in_penalties...
            );
            all_err_samples(s, :) = in_penalties.err;
            all_mse_samples(s) = immse(in_admm.I, I_patch_gt);
        end
        all_err_samples_plot = all_err_samples(:, err_filter);
        log_all_mse_samples = log10(all_mse_samples);
        
        % Also obtain mean-square-error values for the search path
        path_mse_samples = zeros(n_iter, 1);
        for s = 1:n_iter
            weights_s = weights_search.weights(s, :);
            [in_admm, weights_s] = initBaek2017Algorithm2LowMemory(...
                in_admm, weights_s, solvePatchesADMMOptions.admm_options...
            );
            in_admm = baek2017Algorithm2LowMemory(...
                align_f, n_bands, I_raw_f, weights_s,...
                solvePatchesADMMOptions.admm_options, in_admm...
            );
            
            path_mse_samples(s) = immse(in_admm.I, I_patch_gt);
        end
        log_path_mse_samples = log10(path_mse_samples);
        log_path_mse_samples_diff = [diff(log_path_mse_samples, 1); 0];
        
        % Find out which points are on the Pareto front
        pareto_front_filter = false(n_samples_all, 1);
        for s = 1:n_samples_all
            err_s = all_err_samples(s, err_filter);
            comp_err = all_err_samples(:, err_filter) - repmat(err_s, n_samples_all, 1);
            pareto_front_filter(s) = all(any(comp_err > 0, 2) | all(comp_err >= 0, 2), 1);
        end
        
        % Plotting
        figure;
        hold on
        title('Response surface with search path for the selected weights')
        origin_plot = weights_search.origin(err_filter);
        if n_active_weights == 1
            plot(...
                all_err_samples(:, 2), all_err_samples(:, 1)...
            );
            scatter(...
                all_err_samples(pareto_front_filter, 2), all_err_samples(pareto_front_filter, 1),...
                [], [0, 1, 0], 'filled'...
            );
            scatter(...
                all_err_samples(~pareto_front_filter, 2), all_err_samples(~pareto_front_filter, 1),...
                [], [1, 0, 0], 'filled'...
            );
            plot(origin_plot(2), origin_plot(1), 'k*');
        elseif n_active_weights == 2
            tri = delaunay(all_err_samples(:, 2), all_err_samples(:, 3));
            trisurf(...
                tri, all_err_samples(:, 2), all_err_samples(:, 3),...
                all_err_samples(:, 1), double(pareto_front_filter),...
                'FaceAlpha', 0.5 ...
            );
            plot3(origin_plot(2), origin_plot(3), origin_plot(1), 'ko');
        else
            error('Unexpected number of active weights.');
        end
        if n_active_weights == 1
            quiver(...
                err_path(:, 2), err_path(:, 1),...
                err_path_diff(:, 2), err_path_diff(:, 1),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('regularization norm %d', to_all_weights(1)))
            ylabel('residual')
            legend('Response surface', 'Pareto front', 'Non-Pareto front', 'MDC origin', 'Search path');
        elseif n_active_weights == 2
            quiver3(...
                err_path(:, 2), err_path(:, 3), err_path(:, 1),...
                err_path_diff(:, 2), err_path_diff(:, 3), err_path_diff(:, 1),...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('regularization norm %d', to_all_weights(1)))
            ylabel(sprintf('regularization norm %d', to_all_weights(2)))
            zlabel('residual')
            legend('Response surface (Pareto front coloured)', 'MDC origin', 'Search path');
        else
            error('Unexpected number of active weights.');
        end
        axis equal
        hold off
        
        figure;
        hold on
        title('Patch log_{10}(MSE) surface with search path for the selected weights')
        if n_active_weights == 1
            plot(...
                log_all_weights_samples(:, 1), log_all_mse_samples,...
                'Marker', 'o'...
            );
            scatter(...
                log_all_weights_samples(pareto_front_filter, 1), log_all_mse_samples(pareto_front_filter),...
                [], [0, 1, 0], 'filled'...
            );
            scatter(...
                log_all_weights_samples(~pareto_front_filter, 1), log_all_mse_samples(~pareto_front_filter),...
                [], [1, 0, 0], 'filled'...
            );
        elseif n_active_weights == 2
            tri = delaunay(log_all_weights_samples(:, 1), log_all_weights_samples(:, 2));
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
                log_all_mse_samples, double(pareto_front_filter),...
                'FaceAlpha', 0.5 ...
            );
        else
            error('Unexpected number of active weights.');
        end
        if n_active_weights == 1
            quiver(...
                log_weights(:, 1), log_path_mse_samples,...
                log_weights_diff(:, 1), log_path_mse_samples_diff,...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel('log_{10}(Mean square error) wrt ground truth patch')
            legend('Patch log_{10}(MSE) surface', 'Pareto front', 'Non-Pareto front', 'Search path');
        elseif n_active_weights == 2
            quiver3(...
                log_weights(:, 1), log_weights(:, 2), log_path_mse_samples,...
                log_weights_diff(:, 1), log_weights_diff(:, 2), log_path_mse_samples_diff,...
                'AutoScale', 'off'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel('log_{10}(Mean square error) wrt ground truth patch')
            legend('Patch log_{10}(MSE) surface (Pareto front coloured)', 'Search path');
        else
            error('Unexpected number of active weights.');
        end
        hold off
        
        % Look at the minimum distance function of Song et al. 2016.
        mdc_all_weights = sqrt(sum(...
            ((all_err_samples(:, err_filter) - repmat(weights_search.origin(err_filter), n_samples_all, 1))...
            ./ (repmat(weights_search.err_max(err_filter), n_samples_all, 1) - repmat(weights_search.origin(err_filter), n_samples_all, 1))...
            ).^2, 2 ...
        ));
        figure;
        hold on
        if n_active_weights == 1
            plot(...
                log_all_weights_samples,...
                mdc_all_weights,...
                'Marker', 'o'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel('Distance to origin')
        elseif n_active_weights == 2
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2), mdc_all_weights...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel('Distance to origin');
        else
            error('Unexpected number of active weights.');
        end
        title('Distance to the origin of the minimum distance function')
        hold off
        
        figure;
        hold on
        title('Patch log_{10}(MSE) surface compared with minimum distance function')
        log_all_mse_samples_scaled = (log_all_mse_samples - min(log_all_mse_samples))...
            / (max(log_all_mse_samples) - min(log_all_mse_samples));
        if n_active_weights == 1
            plot(...
                log_all_weights_samples(:, 1), log_all_mse_samples_scaled,...
                '-or'...
            );
        elseif n_active_weights == 2
            tri = delaunay(log_all_weights_samples(:, 1), log_all_weights_samples(:, 2));
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
                log_all_mse_samples_scaled, ones(n_samples_all, 1),...
                'FaceAlpha', 0.5 ...
            );
        else
            error('Unexpected number of active weights.');
        end
        mdc_all_weights_scaled = (mdc_all_weights - min(mdc_all_weights))...
            / (max(mdc_all_weights) - min(mdc_all_weights));
        if n_active_weights == 1
            plot(...
                log_all_weights_samples,...
                mdc_all_weights_scaled,...
                '-sg'...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel('Normalized value')
        elseif n_active_weights == 2
            trisurf(...
                tri, log_all_weights_samples(:, 1), log_all_weights_samples(:, 2),...
                mdc_all_weights_scaled, zeros(n_samples_all, 1),...
                'FaceAlpha', 0.5 ...
            );
            xlabel(sprintf('log_{10}(weight %d)', to_all_weights(1)))
            ylabel(sprintf('log_{10}(weight %d)', to_all_weights(2)))
            zlabel('Normalized value');
        else
            error('Unexpected number of active weights.');
        end
        log_path_mse_samples_scaled = (log_path_mse_samples - min(log_all_mse_samples))...
            / (max(log_all_mse_samples) - min(log_all_mse_samples));
        log_path_mse_samples_scaled_diff = [diff(log_path_mse_samples_scaled, 1); 0];
        if n_active_weights == 1
            quiver(...
                log_weights(:, 1), log_path_mse_samples_scaled,...
                log_weights_diff(:, 1), log_path_mse_samples_scaled_diff,...
                'AutoScale', 'off', 'Color', [0, 0, 1]...
            );
        elseif n_active_weights == 2
            quiver3(...
                log_weights(:, 1), log_weights(:, 2), log_path_mse_samples_scaled,...
                log_weights_diff(:, 1), log_weights_diff(:, 2), log_path_mse_samples_scaled_diff,...
                'AutoScale', 'off', 'Color', [0, 0, 1]...
            );
        else
            error('Unexpected number of active weights.');
        end
        legend('log_{10}(MSE)', 'Minimum distance function', 'Search path')
        hold off
        
    elseif plot_hypersurfaces
        warning('The response surface and the MSE hypersurface cannot be plotted when there are more than two active regularization terms.');
    end

elseif plot_search_path || plot_hypersurfaces
    warning('Graphical output cannot be generated when there are more than four active regularization terms.');
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
save_data_filename = fullfile(output_directory, 'ValidateGridSearch.mat');
save(save_data_filename, save_variables_list{:});