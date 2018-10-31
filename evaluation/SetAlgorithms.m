%% List of algorithms to test
% This script creates the 'admm_algorithms' structure used by
% 'RunOnDataset.m' and 'SelectWeightsForDataset.m', and the
% 'demosaic_algorithms' structure used by 'RunOnDataset.m'.

% ADMM family algorithms
admm_algorithms.spectralL1L1 = struct(...
    'name', 'Spectral L1L1',... % Pretty name for tables and graphs
    'file', 'L1L1',... % Short name for filenames
    'enabled', false,... % Whether or not to run the algorithm
    'spectral', true,... % Estimate spectral or colour images
    'priors', [true, true, false],... % Priors to enable (`false` means the corresponding weight will be zero)
    'options', struct('norms', [true, true, false], 'nonneg', false)... % Custom options for baek2017Algorithm2()
);
admm_algorithms.spectralL1L1NonNeg = struct(...
    'name', 'Spectral L1L1NonNeg',...
    'file', 'L1L1NonNeg',...
    'enabled', false,...
    'spectral', true,...
    'priors', [true, true, false],...
    'options', struct('norms', [true, true, false], 'nonneg', true)...
);
admm_algorithms.spectralL2NonNeg = struct(...
    'name', 'Spectral L2NonNeg',...
    'file', 'L2NonNeg',...
    'enabled', true,...
    'spectral', true,...
    'priors', [true, false, false],...
    'options', struct('norms', [false, false, false], 'nonneg', true)...
);
admm_algorithms.spectralL2 = struct(...
    'name', 'Spectral L2',...
    'file', 'L2',...
    'enabled', false,...
    'spectral', true,...
    'priors', [true, false, false],...
    'options', struct('norms', [false, false, false], 'nonneg', false)...
);

admm_algorithms.colorL1L1 = struct(...
    'name', 'Color L1L1',...
    'file', 'L1L1',...
    'enabled', false,...
    'spectral', false,...
    'priors', [true, true, false],...
    'options', struct('norms', [true, true, false], 'nonneg', false)...
);
admm_algorithms.colorL1L1NonNeg = struct(...
    'name', 'Color L1L1NonNeg',...
    'file', 'L1L1NonNeg',...
    'enabled', false,...
    'spectral', false,...
    'priors', [true, true, false],...
    'options', struct('norms', [true, true, false], 'nonneg', true)...
);
admm_algorithms.colorL2NonNeg = struct(...
    'name', 'Color L2NonNeg',...
    'file', 'L2NonNeg',...
    'enabled', true,...
    'spectral', false,...
    'priors', [true, false, false],...
    'options', struct('norms', [false, false, false], 'nonneg', true)...
);
admm_algorithms.colorL2 = struct(...
    'name', 'Color L2',...
    'file', 'L2',...
    'enabled', false,...
    'spectral', false,...
    'priors', [true, false, false],...
    'options', struct('norms', [false, false, false], 'nonneg', false)...
);

% Demosaicking algorithms
demosaic_algorithms.bilinear = struct(...
    'name', 'Bilinear demosaicking',... % Bilinear interpolation for demosaicking
    'file', 'bilinear',...
    'enabled', true,...
    'fn', @bilinearDemosaic... % Function to call
);
demosaic_algorithms.matlab = struct(...
    'name', 'MATLAB demosaicking',... % MATLAB's built-in demosaic() function
    'file', 'MATLABdemosaic',...
    'enabled', false,...
    'fn', 'matlab'... % Special handling is required for this algorithm
);
demosaic_algorithms.ari = struct(...
    'name', 'ARI demosaicking',... % Adaptive residual interpolation
    'file', 'ARI',...
    'enabled', true,...
    'fn', 'ARI'... % Special handling is required for this algorithm
);