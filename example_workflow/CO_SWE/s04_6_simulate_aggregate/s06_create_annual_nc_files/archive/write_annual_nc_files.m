%% Aggregate daily snow depth outputs into a CF-compliant NetCDF for GIS/GEE
% Rocky Mountain Snow Depth Upscaled to 500m
% Creates CF-compliant NetCDF with UTM projection metadata for QGIS/GEE

clear; clc;

% local or remote run
blanca = 0;

% define water year
wy = 2024;

%% define paths
if blanca == 1
    addpath /projects/johe7316/Function_Database
else
    data_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow/s06_upscale/outputs/2024';
    input_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/input_data';
    save_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow/s08_create_annual_nc_files';
end

%% load the grid (GRID.XX, GRID.YY in UTM Zone 13N, meters)
cd(input_path)
load('rocky_grid_500m.mat')  

GRID.XX = GRID.XX';
GRID.YY = GRID.YY';

rows = size(GRID.XX,2);  % number of rows
cols = size(GRID.XX,1);  % number of columns
z_dim = days_in_year(wy);

%%% FOR TESTING (remove this in production)
z_dim = 10;

%% create NetCDF file
nc_file = ['Rocky_SD_500m_' num2str(wy) '.nc'];
nc_file_path = fullfile(save_path, nc_file);

if exist(nc_file_path,'file')
    delete(nc_file_path)
end

%% Coordinate variables
x_coords = GRID.XX(:,1);  % eastings along columns
y_coords = GRID.YY(1,:);  % northings along rows

% X coordinate
nccreate(nc_file_path, 'x', 'Dimensions', {'x', length(x_coords)}, 'Datatype', 'single');
ncwrite(nc_file_path, 'x', single(x_coords));
ncwriteatt(nc_file_path, 'x', 'standard_name', 'projection_x_coordinate');
ncwriteatt(nc_file_path, 'x', 'long_name', 'x coordinate of projection');
ncwriteatt(nc_file_path, 'x', 'units', 'm');

% Y coordinate
nccreate(nc_file_path, 'y', 'Dimensions', {'y', length(y_coords)}, 'Datatype', 'single');
ncwrite(nc_file_path, 'y', single(y_coords));
ncwriteatt(nc_file_path, 'y', 'standard_name', 'projection_y_coordinate');
ncwriteatt(nc_file_path, 'y', 'long_name', 'y coordinate of projection');
ncwriteatt(nc_file_path, 'y', 'units', 'm');

%% Time variable (CF-compliant)
time_values = 0:z_dim-1;  % days since water year start
nccreate(nc_file_path, 'time', 'Dimensions', {'time', z_dim}, 'Datatype', 'int32');
ncwrite(nc_file_path, 'time', int32(time_values));

ncwriteatt(nc_file_path, 'time', 'long_name', 'time');
ncwriteatt(nc_file_path, 'time', 'units', ['days since ' num2str(wy-1) '-10-01 00:00:00']);
ncwriteatt(nc_file_path, 'time', 'calendar', 'gregorian');

%% Projection variable (scalar, CF-compliant)
nccreate(nc_file_path, 'crs', 'Datatype', 'int32', 'Dimensions', {}); 
ncwrite(nc_file_path, 'crs', int32(0));  % dummy value, CF requires variable

ncwriteatt(nc_file_path, 'crs', 'grid_mapping_name', 'transverse_mercator');
ncwriteatt(nc_file_path, 'crs', 'scale_factor_at_central_meridian', 0.9996);
ncwriteatt(nc_file_path, 'crs', 'longitude_of_central_meridian', -105); % adjust for UTM Zone 13N if needed
ncwriteatt(nc_file_path, 'crs', 'latitude_of_origin', 0.0);
ncwriteatt(nc_file_path, 'crs', 'false_easting', 500000.0);
ncwriteatt(nc_file_path, 'crs', 'false_northing', 0.0);
ncwriteatt(nc_file_path, 'crs', 'semi_major_axis', 6378137.0);
ncwriteatt(nc_file_path, 'crs', 'inverse_flattening', 298.257223563);
ncwriteatt(nc_file_path, 'crs', 'utm_zone_number', 13);
ncwriteatt(nc_file_path, 'crs', 'utm_northern_hemisphere', 1);
ncwriteatt(nc_file_path, 'crs', 'spatial_ref', 'EPSG:32613');
ncwriteatt(nc_file_path, 'crs', 'proj4_params', '+proj=utm +zone=13 +datum=WGS84 +units=m +no_defs');

%% Snow depth variable
nccreate(nc_file_path, 'snow_depth', ...
    'Dimensions', {'x', cols, 'y', rows, 'time', z_dim}, ...
    'Datatype', 'single');

ncwriteatt(nc_file_path, 'snow_depth', 'long_name', 'Snow Depth');
ncwriteatt(nc_file_path, 'snow_depth', 'units', 'm');
ncwriteatt(nc_file_path, 'snow_depth', 'description', 'Upscaled 500m snow depth');
ncwriteatt(nc_file_path, 'snow_depth', 'grid_mapping', 'crs');  % link to projection
ncwriteatt(nc_file_path, 'snow_depth', 'coordinates', 'x y time');

%% Global attributes
ncwriteatt(nc_file_path, '/', 'title', ['Rocky Mountain Snow Depth WY ' num2str(wy)]);
ncwriteatt(nc_file_path, '/', 'institution', 'University of Colorado Boulder');
ncwriteatt(nc_file_path, '/', 'source', 'RF model outputs');
ncwriteatt(nc_file_path, '/', 'history', ['Created on ' datestr(now)]);

%% Loop through daily files and write
cd(data_path)
for ii = 1:z_dim
    disp(['Processing day ' num2str(ii)]);
    load(['output_500m_' num2str(wy) '_' num2str(ii) '.mat']);  % contains out_500

    % Write daily slice (x = columns, y = rows, time = ii)
    ncwrite(nc_file_path, 'snow_depth', single(out_500'), [1 1 ii]);
end

disp('NetCDF aggregation complete and CF-compliant!');
cd(save_path)