%% =========================================================================
%  IDW_AGGREGATE_RF_OUTPUTS.M
%  J. Herbert | 2025
%
%  Purpose:
%  Aggregates regional Random Forest outputs from multiple files by applying
%  inverse-distance weighting (IDW) across SNOTEL sites at each pixel.
%
%  Adds UA (UA_SD, UA_SWE, UA_SD_800, UA_SWE_800) and physiographic
%  variables that are static per pixel (fveg, elev, slope, etc.).
%
%  Output: rf_out (aggregated table)
% =========================================================================

clear; clc; tic

% -------------------- USER INPUT -----------------------------------------
save_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/500m_testing/CO/SWE/regional/';
in_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/500m_testing/CO/SWE/regional/output';


cd(in_path)
names = get_names;

for ii = 1:length(names)
    load(names{ii})
    if ii == 1
        temp = rf_out;
    else
        temp = [temp;rf_out];
    end
end
rf_out = temp;

% -------------------- EXTRACT VARIABLES ----------------------------------
lat = rf_out.lat;
lon = rf_out.lon;
date       = rf_out.date;
file       = rf_out.file;
basin      = rf_out.basin;
site       = rf_out.site;
dist       = rf_out.dist;
dowy       = rf_out.dowy;

% model and lidar variables
pred_SWE    = rf_out.pred_SWE;
snotel_SWE  = rf_out.snotel_SWE;
lidar_SWE   = rf_out.lidar_SWE;

% UA and static variables
UA_SWE_800  = rf_out.UA_SWE_800;
UA_SD_800  = rf_out.UA_SD_800;
parbal = rf_out.parbal;

fSCA        = rf_out.fSCA;
fveg        = rf_out.fveg;
elev        = rf_out.elev;
northness   = rf_out.northness;
eastness    = rf_out.eastness;
TPI         = rf_out.TPI;
Sx          = rf_out.Sx;
slope       = rf_out.slope;
XX          = rf_out.XX;
YY          = rf_out.YY;

fSCA_8day = rf_out.fSCA_8day;
deciduous_frac = rf_out.deciduous_frac;
mixed_frac = rf_out.mixed_forest_frac;
evergreen_frac = rf_out.evergreen_frac;
snow_persistence = rf_out.snow_persistence;

% -------------------- GROUP BY PIXEL + FILE ------------------------------
[G, lat_vals, lon_vals] = findgroups(lat, lon, file);

% -------------------- COMPUTE INVERSE-DISTANCE WEIGHTS -------------------
inverse_weights = 1 ./ dist;

% -------------------- APPLY IDW ------------------------------------------
pred_SWE   = splitapply(@(x, w) sum(x .* w, 'omitnan') ./ sum(w, 'omitnan'), ...
                       pred_SWE, inverse_weights, G);
snotel_SWE = splitapply(@(x, w) sum(x .* w, 'omitnan') ./ sum(w, 'omitnan'), ...
                       snotel_SWE, inverse_weights, G);

% -------------------- STATIC + MEAN VARIABLES ----------------------------
lidar_SWE_group = splitapply(@(x) mode(x), lidar_SWE, G);
file_group     = splitapply(@(x) unique(x), file, G);
basin_group    = splitapply(@(x) unique(x), basin, G);
dowy_group     = splitapply(@(x) unique(x), dowy, G);
date_group     = splitapply(@(x) unique(x), date, G);
XX_group       = splitapply(@(x) unique(x), XX, G);
YY_group       = splitapply(@(x) unique(x), YY, G);

% --- UA variables ---
UA_SWE_800_group = splitapply(@(x) mean(x,'omitnan'), UA_SWE_800, G);
UA_SD_800_group = splitapply(@(x) mean(x,'omitnan'), UA_SD_800, G);
parbal_group = splitapply(@(x) mean(x,'omitnan'), parbal, G);

% --- Physiographic (static) variables ---
fSCA_group      = splitapply(@(x) x(1), fSCA, G);
fveg_group      = splitapply(@(x) x(1), fveg, G);
elev_group      = splitapply(@(x) x(1), elev, G);
northness_group = splitapply(@(x) x(1), northness, G);
eastness_group  = splitapply(@(x) x(1), eastness, G);
TPI_group       = splitapply(@(x) x(1), TPI, G);
Sx_group        = splitapply(@(x) x(1), Sx, G);
slope_group     = splitapply(@(x) x(1), slope, G);

% --- NEW static physiographic variables ---
fSCA_8day_group         = splitapply(@(x) x(1), fSCA_8day, G);
deciduous_frac_group    = splitapply(@(x) x(1), deciduous_frac, G);
mixed_frac_group        = splitapply(@(x) x(1), mixed_frac, G);
evergreen_frac_group    = splitapply(@(x) x(1), evergreen_frac, G);
snow_persistence_group  = splitapply(@(x) x(1), snow_persistence, G);

% -------------------- BUILD FINAL OUTPUT TABLE ---------------------------
rf_out = table(lat_vals, lon_vals, ...
               pred_SWE, snotel_SWE, lidar_SWE_group, ...
               parbal_group, UA_SD_800_group, UA_SWE_800_group, ...
               file_group, basin_group, ...
               fSCA_group, fveg_group, elev_group, northness_group, eastness_group, ...
               TPI_group, Sx_group, slope_group, ...
               fSCA_8day_group, deciduous_frac_group, mixed_frac_group, evergreen_frac_group, snow_persistence_group, ...
               XX_group, YY_group, dowy_group, date_group, ...
               'VariableNames', {'lat','lon','pred_SWE','snotel_SWE','lidar_SWE', ...
                                 'parbal','UA_SD_800','UA_SWE_800', ...
                                 'file','basin', ...
                                 'fSCA','fveg','elev','northness','eastness', ...
                                 'TPI','Sx','slope', ...
                                 'fSCA_8day','deciduous_frac','mixed_frac','evergreen_frac','snow_persistence', ...
                                 'XX','YY','dowy','date'});

% -------------------- SAVE OUTPUT ----------------------------------------

save_str = ['rocky_regional_SWE_500_IDW_nodowy2.mat'];

cd(save_path)
save(save_str, 'rf_out', '-v7.3');

toc
disp(['✅ Saved aggregated file: ', fullfile(save_path, save_str)])
