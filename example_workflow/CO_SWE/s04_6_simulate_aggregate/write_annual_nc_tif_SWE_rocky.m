%% Aggregate daily snow depth outputs into a CF-compliant NetCDF for GIS/GEE
% Rocky Mountain Snow Depth Upscaled to 500m
% Creates CF-compliant, compressed NetCDF4 (for QGIS/GDAL) and multiband GeoTIFF (for GEE)



%% Define paths
addpath /projects/johe7316/Function_Database
data_path  = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/daily_outputs/' num2str(wy)];
input_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data';
save_path  = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/annual_data';
if ~exist(save_path,'dir')
    mkdir(save_path)
end

cd(input_path)
load geo_reference_R_500m.mat
load('rocky_grid_500m.mat')  % loads GRID structure with XX, YY, lat, lon, water_flag

rows   = size(GRID.XX, 1);  % number of rows (y)
cols   = size(GRID.XX, 2);  % number of columns (x)
z_dim  = days_in_year(wy);

%% Precompute water mask in NetCDF orientation [cols x rows]
water_mask_t = logical(GRID.water_flag)';

%% UTM Zone 13N for Rocky Mountain domain
epsg_code = 32613;

%% Create NetCDF4 file (required for compression)
nc_file      = ['SnoLimits_CO_SWE_WY_' num2str(wy) '.nc'];
nc_file_path = fullfile(save_path, nc_file);

if exist(nc_file_path, 'file'), delete(nc_file_path); end

%% Coordinate variables — projected (x, y)
x_coords = GRID.XX(1, :)';  % eastings  [cols x 1]
y_coords = GRID.YY(:, 1);   % northings [rows x 1]

% X
nccreate(nc_file_path, 'x', ...
    'Dimensions', {'x', cols}, ...
    'Datatype',   'single', ...
    'Format',     'netcdf4');
ncwrite(nc_file_path, 'x', single(x_coords));
ncwriteatt(nc_file_path, 'x', 'standard_name', 'projection_x_coordinate');
ncwriteatt(nc_file_path, 'x', 'long_name',     'x coordinate of projection');
ncwriteatt(nc_file_path, 'x', 'units',         'm');
ncwriteatt(nc_file_path, 'x', 'axis',          'X');

% Y
nccreate(nc_file_path, 'y', ...
    'Dimensions', {'y', rows}, ...
    'Datatype',   'single', ...
    'Format',     'netcdf4');
ncwrite(nc_file_path, 'y', single(y_coords));
ncwriteatt(nc_file_path, 'y', 'standard_name', 'projection_y_coordinate');
ncwriteatt(nc_file_path, 'y', 'long_name',     'y coordinate of projection');
ncwriteatt(nc_file_path, 'y', 'units',         'm');
ncwriteatt(nc_file_path, 'y', 'axis',          'Y');

%% Time variable (CF-compliant)
nccreate(nc_file_path, 'time', ...
    'Dimensions', {'time', z_dim}, ...
    'Datatype',   'int32', ...
    'Format',     'netcdf4');
ncwrite(nc_file_path, 'time', int32(0:z_dim-1));
ncwriteatt(nc_file_path, 'time', 'long_name', 'time');
ncwriteatt(nc_file_path, 'time', 'units',     ['days since ' num2str(wy-1) '-10-01 00:00:00']);
ncwriteatt(nc_file_path, 'time', 'calendar',  'gregorian');
ncwriteatt(nc_file_path, 'time', 'axis',      'T');

%% CRS variable (scalar, CF-compliant)
nccreate(nc_file_path, 'crs', 'Datatype', 'int32', 'Dimensions', {}, 'Format', 'netcdf4');
ncwrite(nc_file_path, 'crs', int32(0));
ncwriteatt(nc_file_path, 'crs', 'grid_mapping_name',                'transverse_mercator');
ncwriteatt(nc_file_path, 'crs', 'scale_factor_at_central_meridian', 0.9996);
ncwriteatt(nc_file_path, 'crs', 'longitude_of_central_meridian',    -105.0);  % Zone 13N
ncwriteatt(nc_file_path, 'crs', 'latitude_of_origin',               0.0);
ncwriteatt(nc_file_path, 'crs', 'false_easting',                    500000.0);
ncwriteatt(nc_file_path, 'crs', 'false_northing',                   0.0);
ncwriteatt(nc_file_path, 'crs', 'semi_major_axis',                  6378137.0);
ncwriteatt(nc_file_path, 'crs', 'inverse_flattening',               298.257223563);
ncwriteatt(nc_file_path, 'crs', 'utm_zone_number',                  13);
ncwriteatt(nc_file_path, 'crs', 'utm_northern_hemisphere',          1);
ncwriteatt(nc_file_path, 'crs', 'spatial_ref',                      ['EPSG:' num2str(epsg_code)]);
ncwriteatt(nc_file_path, 'crs', 'proj4_params',                     '+proj=utm +zone=13 +datum=WGS84 +units=m +no_defs');

%% 2D auxiliary coordinate variables — latitude and longitude
% GRID.lat and GRID.lon are [rows x cols]; transpose to [cols x rows] for NetCDF
lat_2d = GRID.lat';
lon_2d = GRID.lon';

% Latitude
nccreate(nc_file_path, 'lat', ...
    'Dimensions', {'x', cols, 'y', rows}, ...
    'Datatype',   'single', ...
    'Format',     'netcdf4');
ncwrite(nc_file_path, 'lat', single(lat_2d));
ncwriteatt(nc_file_path, 'lat', 'standard_name', 'latitude');
ncwriteatt(nc_file_path, 'lat', 'long_name',     'latitude');
ncwriteatt(nc_file_path, 'lat', 'units',         'degrees_north');

% Longitude
nccreate(nc_file_path, 'lon', ...
    'Dimensions', {'x', cols, 'y', rows}, ...
    'Datatype',   'single', ...
    'Format',     'netcdf4');
ncwrite(nc_file_path, 'lon', single(lon_2d));
ncwriteatt(nc_file_path, 'lon', 'standard_name', 'longitude');
ncwriteatt(nc_file_path, 'lon', 'long_name',     'longitude');
ncwriteatt(nc_file_path, 'lon', 'units',         'degrees_east');

%% Snow depth variable — NetCDF4 + DEFLATE compression
x_chunk = min(100, cols);
y_chunk = min(100, rows);

nccreate(nc_file_path, 'swe', ...
    'Dimensions',   {'x', cols, 'y', rows, 'time', z_dim}, ...
    'Datatype',     'single', ...
    'Format',       'netcdf4', ...
    'ChunkSize',    [x_chunk, y_chunk, 1], ...
    'DeflateLevel', 4, ...
    'Shuffle',      true, ...
    'FillValue',    single(NaN));

ncwriteatt(nc_file_path, 'swe', 'long_name',     'Snow water equivalent');
ncwriteatt(nc_file_path, 'swe', 'units',         'm');
ncwriteatt(nc_file_path, 'swe', 'description',   '500m swe (m)');
ncwriteatt(nc_file_path, 'swe', 'grid_mapping',  'crs');
ncwriteatt(nc_file_path, 'swe', 'coordinates',   'lon lat x y');
ncwriteatt(nc_file_path, 'swe', 'flag_values',   single(-1));
ncwriteatt(nc_file_path, 'swe', 'flag_meanings', 'water');
ncwriteatt(nc_file_path, 'swe', 'valid_min',     single(0));

%% Global attributes
ncwriteatt(nc_file_path, '/', 'title',       ['Rocky Mountain SWE WY' num2str(wy)]);
ncwriteatt(nc_file_path, '/', 'institution', 'University of Colorado Boulder');
ncwriteatt(nc_file_path, '/', 'source',      'RF model outputs');
ncwriteatt(nc_file_path, '/', 'Conventions', 'CF-1.8');
ncwriteatt(nc_file_path, '/', 'history',     ['Created ' datestr(now)]);

%% Loop through daily files — write NetCDF and accumulate GeoTIFF array
cd(data_path)
all_days = nan(cols, rows, z_dim, 'single');

for ii = 1:z_dim
    fprintf('Processing day %d / %d\n', ii, z_dim);
    load(['output_500m_' num2str(wy) '_' num2str(ii) '.mat']);  % loads out_500

    swe_day = single(out_500m)';           % transpose to [cols x rows]
    swe_day(water_mask_t) = single(-1);   % flag water pixels

    ncwrite(nc_file_path, 'swe', swe_day, [1, 1, ii]);
    all_days(:, :, ii) = swe_day;         % already transposed, water pixels flagged
end

disp('NetCDF aggregation complete.');

%% Export multiband GeoTIFF for GEE
geotiff_file = fullfile(save_path, ['SnoLimits_CO_SWE_WY_' num2str(wy) '.tif']);

geotiffwrite(geotiff_file, permute(all_days, [2 1 3]), R, ...
    'CoordRefSysCode', epsg_code);

disp(['GeoTIFF export complete: ' geotiff_file]);
cd(save_path)