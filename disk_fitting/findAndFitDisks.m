function [ centers ] = findAndFitDisks(I, mask, align, image_bounds, radius, options, varargin)
% FINDANDFITDISKS  Fit ellipses to blobs in an image
%
% ## Syntax
% centers = findAndFitDisks(...
%   I, mask, align, image_bounds, radius, options [, verbose]...
% )
%
% ## Description
% centers = findAndFitDisks(...
%   I, mask, align, image_bounds, radius, options [, verbose]...
% )
%   Returns the centres of ellipses fit to blobs in the image
%
% ## Input Arguments
%
% I -- Image
%   A 2D array representing either a RAW image, or an image from a
%   monochromatic sensor (including a non-mosaicked image for a narrow
%   wavelength band).
%
% mask -- Region of interest
%   A 2D logical array the same size as `I`, indicating the region in which
%   the function will look for blobs.
%
%   If `mask` is empty, the entire image will be processed.
%
% align -- Bayer pattern format
%   A four-character character vector, specifying the Bayer tile pattern.
%   For example, 'gbrg'. If the image is not mosaicked, an empty array
%   (`[]`) should be passed.
%
%   This argument has the same form as the `sensorAlignment` input argument
%   of `demosaic()`.
%
% image_bounds -- Image domain
%   The rectangular domain of the image in world coordinates.
%   `image_bounds` is a vector containing the following elements:
%   1 - The x-coordinate of the bottom left corner of the image
%   2 - The y-coordinate of the bottom left corner of the image
%   3 - The width of the image (size in the x-dimension)
%   4 - The height of the image (size in the y-dimension)
%
%   `image_bounds` is used to convert the coordinates in `centres` from
%   image space to world space. `image_bounds` is useful if this function
%   is being called on different sub-images, as the results of the
%   different calls will be in a common frame of reference if
%   `image_bounds` is updated appropriately between calls. If
%   `image_bounds` is empty, no coordinate conversion will be performed.
%
% radius -- Binary image cleanup radius
%   The radius of the disk structuring element that will be used during
%   morphological operations to clean up an intermediate binary image prior
%   to identifying blobs.
%
% options -- Data processing options
%   A structure with the following fields:
%   - mask_as_threshold: If `true`, `mask` will be used as the initial
%     binary image containing the blobs themselves, rather than indicating
%     the region in which to search for blobs.
%   - bright_disks: If `true`, the function will look for bright blobs on a
%     dark background. Otherwise, the function will look for dark blobs on
%     a bright background.
%   - group_channels: If `true`, all colour channels in a mosaicked image
%     will be processed together. This situation corresponds to a colour
%     camera taking a picture through a narrowband colour filter, for
%     example. If `false`, separate ellipses will be fit for each colour
%     channel, to allow for studying displacements between colour channels.
%     This field is optional if `align` is empty.
%
% verbose -- Debugging flags
%   If recognized fields of `verbose` are true, corresponding graphical
%   output will be generated for debugging purposes.
%
%   All debugging flags default to false if `verbose` is not passed.
%
% ## Output Arguments
%
% centers -- Ellipse centres
%   A structure array, where each element has a field, 'center', storing a
%   two-element vector of the x and y-coordinates of an ellipse. The
%   ellipses have been fit to blobs in the image.
%
%   The coordinates in `centers` are pixel coordinates, if `image_bounds`
%   is empty, or world coordinates, if `image_bounds` is not empty.
%
%   `centers` has dimensions n x m, where 'n' is the number of blobs. 'm'
%   is `1`, if `align` is empty, or if `align` is not empty, but
%   `options.group_channels` is `true`. Otherwise, 'm' is three (for the
%   three colour channels of an RGB image).
%
% ## Algorithm
%
% - Blobs are detected by analyzing the binary image produced by Otsu
%   thresholding of the region of interest (`mask`) in the image. A
%   different threshold is calculated for each colour channel, in the case
%   of a mosaicked image, but the binary images from all colour channels
%   are merged prior to blob detection.
% - Initial ellipses are fit using the MATLAB 'regionprops()' function.
%
% See also refineDisk, ellipseModel, plotEllipse, regionprops, otsuthresh, imopen, imclose

% Bernard Llanos
% Supervised by Dr. Y.H. Yang
% University of Alberta, Department of Computing Science
% File created April 20, 2018

nargoutchk(1,1);
narginchk(6,7);

% Parse input arguments
if ~isempty(varargin)
    verbose = varargin{1};
    verbose_disk_search = verbose.verbose_disk_search;
    verbose_disk_refinement = verbose.verbose_disk_fitting;
    display_final_centers = verbose.display_final_centers;
else
    verbose_disk_search = false;
    verbose_disk_refinement = false;
    display_final_centers = false;
end

image_height = size(I, 1);
image_width = size(I, 2);
if size(I, 3) ~= 1
    error('This function processes RAW RGB images or greyscale images only, not demosaicked images.');
end

% Binarize the image
single_channel = isempty(align);
if single_channel
    n_channels = 1;
    channel_mask = true(image_height, image_width);
else
    n_channels = 3;
    channel_mask = bayerMask(image_height, image_width, align);
end

bw = false(image_height, image_width, n_channels);
for c = 1:n_channels
    if isempty(mask)
        mask_c = channel_mask(:, :, c);
    else
        mask_c = mask & channel_mask(:, :, c);
    end
    if ~isempty(mask) && options.mask_as_threshold
        bw(:, :, c) = mask_c;
    elseif isempty(mask) && options.mask_as_threshold
        error('`mask` is empty, but `options.mask_as_threshold` is true.');
    else
        counts_c = histcounts(I(mask_c));
        threshold_c = otsuthresh(counts_c);
        if options.bright_disks
            bw(:, :, c) = imbinarize(I,threshold_c) & mask_c;
        else
            bw(:, :, c) = ~imbinarize(I,threshold_c) & mask_c;
        end
    end
    if verbose_disk_search
        figure;
        imshow(bw(:, :, c));
        title(sprintf('Binary image for colour channel %d', c));
    end
end

% Extract binary regions across all colour channels
bw_fused = any(bw, 3);
% Morphologial operations to remove small regions and fill holes
if radius > 0
    se = strel('disk',radius);
    bw_fused_cleaned = imopen(bw_fused, se);
    bw_fused_cleaned = imclose(bw_fused_cleaned, se);
    if verbose_disk_search
        figure;
        imshowpair(bw_fused, bw_fused_cleaned, 'montage');
        title('Binary image for all channels, before (left) and after (right) morphological cleanup');
    end
else
    bw_fused_cleaned = bw_fused;
end

ellipse_stats = regionprops(...
    bw_fused_cleaned,...
    'Centroid', 'MajorAxisLength', 'MinorAxisLength', 'Orientation',...
    'BoundingBox'...
    );
n_ellipses = length(ellipse_stats);
if verbose_disk_search
    fg = figure;
    imshow(I);
    for i = 1:n_ellipses
        [~, ~, ellipse_to_world_i] = ellipseModel(...
            [ellipse_stats(i).MajorAxisLength ellipse_stats(i).MinorAxisLength] / 2,...
            deg2rad(ellipse_stats(i).Orientation),...
            ellipse_stats(i).Centroid,...
            0,...
            [0 1],...
            true...
        );
        plotEllipse(ellipse_to_world_i, fg);
    end
    title('Initial detected ellipses')
end

% For later conversion from pixel to world coordinates
convert_coordinates = ~isempty(image_bounds);
if convert_coordinates
    pixel_width = (image_bounds(3) - image_bounds(1)) / image_width;
    pixel_height = (image_bounds(4) - image_bounds(2)) / image_height;
end

% Improve disk fitting
split_channels = (~single_channel && ~options.group_channels);
if split_channels
    n_channels_out = n_channels;
else
    n_channels_out = 1;
end
centers = struct('center', cell(n_ellipses, n_channels_out));
centers_matrix = zeros(n_ellipses, 2, n_channels_out);

for i = 1:n_ellipses
    % Assume that no colour channel has an entirely zero response in bright
    % areas of other colour channels
    for c = 1:n_channels_out
        center_ic = ellipse_stats(i).Centroid;
        centers_matrix(i, :, c) = center_ic;
        if convert_coordinates
            center_ic = image_bounds(1:2) + [
                pixel_width * center_ic(1);
                pixel_height * (image_height - center_ic(2))
                ];
        end
        centers(i, c).center = center_ic;
    end
end

if display_final_centers
    for c = 1:n_channels_out
        figure;
        imshow(I);
        hold on
        scatter(centers_matrix(:, 1, c), centers_matrix(:, 2, c), 'bo');
        hold off
        if split_channels
            title(sprintf('Refined disk centres for channel %d', c));
        else
            title('Refined disk centres');
        end
    end
end

end
