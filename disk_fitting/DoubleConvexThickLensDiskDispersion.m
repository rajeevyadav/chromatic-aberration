%% Chromatic aberration calibration from raytracing simulation
% Obtain a dispersion model corresponding to a thick (biconvex) lens
% projecting an image onto a sensor. Calibrate the dispersion model from
% disks fitted to simulated point spread functions that vary with spatial
% coordinates and wavelength.
%
% ## Usage
% Modify the parameters, the first code section below, then run.
%
% ## Input
%
% Refer to the first code section below.
%
% ## Output
%
% Graphical output from 'plotXYLambdaPolyfit()'.
%
% ## References
% - Baek, S.-H., Kim, I., Gutierrez, D., & Kim, M. H. (2017). "Compact
%   single-shot hyperspectral imaging using a prism." ACM Transactions
%   on Graphics (Proc. SIGGRAPH Asia 2017), 36(6), 217:1–12.
%   doi:10.1145/3130800.3130896
% - V. Rudakova and P. Monasse. "Precise Correction of Lateral Chromatic
%   Aberration in Images," Lecture Notes on Computer Science, 8333, pp.
%   12–22, 2014.

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created April 19, 2018

%% Input data and parameters
% Refer to the documentation of `lensParamsToRayParams` for details

% ## Raytracing parameters

% ### Lens parameters
% Based on
% '/home/llanos/GoogleDrive/ThesisResearch/Data and Results/20180226_SmallFLLenses_EdmundOptics/3mmDiameter4dot5mmFLUncoatedDoubleConvexLens_prnt_32022.pdf'
lens_params.lens_radius = 3 / 2;
lens_params.axial_thickness = 2;
lens_params.radius_front = 4.29;
lens_params.radius_back = lens_params.radius_front;

ray_params.n_incident_rays = 5000000;
ray_params.sample_random = true;
ray_params.ior_environment = 1.0;

% #### Index of refraction
% The focal length specification wavelength is 587.6 nm
% The lens is made of SCHOTT N-BK7 glass

% Constants for SCHOTT N-BK7 glass retrieved from the SCHOTT glass
% datasheet provided at
% https://refractiveindex.info/?shelf=glass&book=BK7&page=SCHOTT
sellmeierConstants.B_1 = 1.03961212;
sellmeierConstants.B_2 = 0.231792344;
sellmeierConstants.B_3 = 1.01046945;
sellmeierConstants.C_1 = 0.00600069867;
sellmeierConstants.C_2 = 0.0200179144;
sellmeierConstants.C_3 = 103.560653;

lens_params.wavelengths = linspace(300, 1100, 100);
lens_params.ior_lens = sellmeierDispersion(lens_params.wavelengths, sellmeierConstants);

% Index of the wavelength/index of refraction to be used to position the
% image plane
[~, ior_lens_reference_index] = min(abs(lens_params.wavelengths - 587.6));

% Obtained using the quantum efficiencies presented in
% '/home/llanos/GoogleDrive/ThesisResearch/Equipment/FLEA3/20170508_FL3_GE_EMVA_Imaging Performance Specification.pdf'
% Image sensor: Sony ICX655, 2/3", Color (page 19)
lens_params.wavelengths_to_rgb = sonyQuantumEfficiency(lens_params.wavelengths);

% Normalize, for improved colour saturation
lens_params.wavelengths_to_rgb = lens_params.wavelengths_to_rgb ./...
    max(max(lens_params.wavelengths_to_rgb));

% ### Ray interpolation parameters
image_sampling = [250, 250];

% ## Scene setup
scene_params.theta_min = deg2rad(0);
scene_params.theta_max = deg2rad(20);
scene_params.n_lights = [15 15];
scene_params.light_distance_factor_focused = 2;
scene_params.light_distance_factor_larger = [4, 0];
scene_params.light_distance_factor_smaller = [1.5, 0];
scene_params.preserve_angle_over_depths = true;

% ## Disk fitting
bayer_pattern = [];
cleanup_radius = 2; % Morphological operations radius for 'findAndFitDisks()'
findAndFitDisks_options.bright_disks = true;
findAndFitDisks_options.mask_as_threshold = true;

% ## Dispersion model generation
dispersion_fieldname = 'center';
max_degree_xy = min(12, min(scene_params.n_lights) - 1);
max_degree_lambda = min(12, length(lens_params.wavelengths) - 1);

% ## Debugging Flags
plot_light_positions = false;

verbose_ray_tracing = false;
verbose_ray_interpolation = false;
display_each_psf = true;

findAndFitDisksVerbose.verbose_disk_search = true;
findAndFitDisksVerbose.verbose_disk_refinement = true;
findAndFitDisksVerbose.display_final_centers = true;

statsToDisparityVerbose.display_raw_values = true;
statsToDisparityVerbose.display_raw_disparity = true;
statsToDisparityVerbose.filter = struct(...
    dispersion_fieldname, true...
);

xylambdaPolyfitVerbose = true;
plot_polynomial_model = true;
if plot_polynomial_model
    n_lambda_plot = min(20, length(lens_params.wavelengths));
end

%% Create light sources

lens_params_scene = lens_params;
lens_params_scene.ior_lens = lens_params.ior_lens(ior_lens_reference_index);
[...
    X_lights, z_film, lights_filter, depth_factors...
] = imagingScenario(...
    lens_params_scene, ray_params.ior_environment, scene_params, plot_light_positions...
);

%% Run the simulation

ray_params = lensParamsToRayParams(ray_params, lens_params, z_film);
n_ior_lens = length(lens_params.ior_lens);

% Remove filtered-out light positions
X_lights = X_lights(lights_filter, :);
n_lights = size(X_lights, 1);

centers = struct(dispersion_fieldname, cell(n_lights, n_ior_lens));
for i = 1:n_lights
    ray_params.source_position = X_lights(i, :);
    for k = 1:n_ior_lens
        ray_params.ior_lens = lens_params.ior_lens(k);
        [ ...
            image_position, ray_irradiance ...
        ] = doubleSphericalLens( ray_params, verbose_ray_tracing );

        [ I, mask, image_bounds ] = densifyRaysImage(...
            image_position, ray_irradiance,...
            [], image_sampling,...
            verbose_ray_interpolation...
        );
    
        if display_each_psf
            figure
            ax = gca;
            imagesc(ax,...
                [image_bounds(1), image_bounds(1) + image_bounds(3)],...
                [image_bounds(2) + image_bounds(4), image_bounds(2)],...
                I...
                );
            colormap gray
            ax.YDir = 'normal';
            xlabel('X');
            ylabel('Y');
            c = colorbar;
            c.Label.String = 'Irradiance';
            title(...
                sprintf('Estimated PSF for a point source at position\n[%g, %g, %g] (%g focal lengths, IOR %g)',...
                X_lights(i, 1), X_lights(i, 2), X_lights(i, 3),...
                depth_factors, ray_params.ior_lens...
                ));
            axis equal
        end
        
        centers(i, k) = findAndFitDisks(...
            I, mask, bayer_pattern, image_bounds, cleanup_radius, findAndFitDisks_options,...
            findAndFitDisksVerbose...
        );
    end
end