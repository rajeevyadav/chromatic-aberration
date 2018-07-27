function [dispersionfun, varargout] = makeDispersionForImage(dispersion_data, varargin)
% MAKEDISPERSIONFORIMAGE Create an image-specific dispersion model
%
% ## Syntax
% dispersionfun = makeDispersionForImage(dispersion_data [, I, transform_data])
% [dispersionfun, I_roi] = makeDispersionForImage(dispersion_data, I, transform_data)
%
% ## Description
% dispersionfun = makeDispersionForImage(dispersion_data [, I, transform_data])
%   Returns a functional form of the dispersion model
% [dispersionfun, I_roi] = makeDispersionForImage(dispersion_data, I, transform_data)
%   Additionally returns the portion of the image within the domain of the
%   dispersion model
%
% ## Input Arguments
%
% dispersion_data -- Dispersion model
%   A model of dispersion, modelling the warping from the reference
%   wavelength band or colour channel to the other wavelength bands or
%   colour channels.
%
% I -- Image
%   A 2D or 3D array containing an image. The dispersion model is to be
%   applied to this image.
%
% transform_data -- Spatial coordinate conversion information
%   The `transform_data` output argument of 'loadDispersionModel()', used
%   to create the input arguments for 'modelSpaceTransform()'.
%
% ## Output Arguments
%
% dispersionfun -- Functional model of dispersion
%   A function, with the semantics of the `dispersionfun` output argument
%   of 'makeDispersionfun()'. If `I` and `transform_data` are passed,
%   `dispersionfun` will be made compatible with the coordinate system of
%   the image `I`, according to the data in `transform_data`. Otherwise,
%   `dispersionfun = makeDispersionfun(dispersion_data)`.
%
% I_roi -- Region of interest
%   A rectangular sub-image containing the portion of `I` in the valid
%   domain of the dispersion model.
%
% ## Notes
% - Either both `I` and `transform_data` must be passed, or neither must be
%   passed.
%
% See also makeDispersionfun, loadDispersionModel, modelSpaceTransform

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created July 26, 2018

narginchk(1, 3);

if isempty(varargin)
    nargoutchk(1, 1);
    dispersionfun = makeDispersionfun(dispersion_data);
else
    nargoutchk(1, 2);
    if length(varargin) < 2
        error('Either both the image `I` and the coordinate conversion data `transform_data` must be passed, or neither must be passed.');
    end
    I = varargin{1};
    transform_data = varargin{2};
    [roi, T_roi] = modelSpaceTransform(size(I), transform_data.model_space, transform_data.fill);
    dispersionfun = makeDispersionfun(dispersion_data, T_roi);
    if nargout > 1
        varargout = {I(roi(1):roi(2), roi(3):roi(4), :)};
    end
end

end

