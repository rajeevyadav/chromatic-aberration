%% Ray tracing simulation of chromatic aberration
% Simulate the chromatic point spread function of a thick (biconvex) lens.
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
% ## References
% - Ray-sphere intersection testing:
%   - http://www.ccs.neu.edu/home/fell/CSU540/programs/RayTracingFormulas.htm
%   - https://www.siggraph.org/education/materials/HyperGraph/raytrace/rtinter1.htm
%   - https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
% - Uniform sampling of the surface of a sphere:
%   http://mathworld.wolfram.com/SpherePointPicking.html

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created June 7, 2017

%% Input data and parameters

% Raytracing parameters
% Refer to the documentation of `doubleSphericalLens` for details
ray_params.source_position = [0, 0, 10];
ray_params.radius_front = 2.0;
ray_params.theta_aperture_front = pi / 2;
ray_params.radius_back = 3.0;
ray_params.theta_aperture_back = pi / 6;
ray_params.d_lens = -4;
ray_params.n_incident_rays = 1000;
ray_params.sample_random = false;
ray_params.ior_environment = 1.0;
ray_params.ior_lens = 1.52;
ray_params.d_film = 10;

% Ray interpolation parameters
% Refer to the documentation of `densifyRays` for details
image_bounds = [-10 -10 20 20];
image_sampling = [400, 400];

% Debugging Flags
verbose_ray_tracing = false;
verbose_ray_interpolation = true;

%% Calculate lens imaging properties

[ imageFn, f, f_prime ] = opticsFromLens(...
    ray_params.ior_environment,...
    ray_params.ior_lens,...
    ray_params.ior_environment,...
    ray_params.radius_front, ray_params.radius_back,...
    ray_params.d_lens...
);

%% Trace rays through the lens

[ ...
    image_position, ray_irradiance, ~, incident_position_cartesian ...
] = doubleSphericalLens( ray_params, verbose_ray_tracing );

%% Form rays into an image

[ max_position, max_irradiance, I ] = densifyRays(...
    incident_position_cartesian,...
    ray_params.radius_front,...
    image_position,...
    ray_irradiance,...
    image_bounds, image_sampling,...
    verbose_ray_interpolation ...
);