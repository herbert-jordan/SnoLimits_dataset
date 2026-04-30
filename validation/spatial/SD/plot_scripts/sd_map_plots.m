% ========================================================================
% sd_map_plots.m
% J. Herbert
%
% 8-panel figure: SD maps (row 1) + error maps & depth profile (row 2)
%
%   Row 1: [ ASO Lidar ] [ SnoLimits ] [ UASWE ] [ UCLA SWE ]
%   Row 2: [ Vol/Elev  ] [ SL Error  ] [ UA Err] [ UCLA Err ]
%
%   Error = pred − lidar  |  red = under-prediction, blue = over-prediction
% ========================================================================
clear; clc;

% ========================================================================
% USER CONFIG
% ========================================================================
domain = 1;    % 1 = CA  |  2 = Rocky

% ========================================================================
% PATHS
% ========================================================================
base_path  = fileparts(fileparts(mfilename('fullpath')));

snolimits_path = fullfile(base_path, 'data', 'SnoLimits');
uaswe_path     = fullfile(base_path, 'data', 'UASWE');
ucla_path      = fullfile(base_path, 'data', 'UCLA_SWE');
out_dir        = fullfile(base_path, 'outputs');

domain_str = {'CA', 'rocky'};
region_str = {'CA', 'CO'};

sl_file = fullfile(snolimits_path, ...
    sprintf('%s_SD_500_IDW_pre2020.mat', domain_str{domain}));
ua_dir  = fullfile(uaswe_path, region_str{domain});
uc_dir  = fullfile(ucla_path,  region_str{domain});

% ========================================================================
% 1. SNOLIMITS — load and select flight
% ========================================================================
fprintf('Loading SnoLimits...\n')
load(sl_file);
rf_master = rf_out; clear rf_out;
flts = unique(rf_master.file);

fprintf('\nAvailable flights for %s:\n', region_str{domain})
for ff = 1:numel(flts)
    fprintf('  %2d.  %s\n', ff, char(flts(ff)))
end
flight_idx = input('\nEnter flight number: ');
while ~isnumeric(flight_idx) || flight_idx < 1 || flight_idx > numel(flts)
    warning('Invalid selection. Enter a number between 1 and %d.', numel(flts))
    flight_idx = input('Enter flight number: ');
end
fprintf('  Selected: %s\n\n', char(flts(flight_idx)))

idx    = flts(flight_idx) == rf_master.file;
rf_flt = rf_master(idx, :);

% ========================================================================
% SETTINGS
% ========================================================================
caxis_sd   = [0 3];        % SD color axis (m)
caxis_err  = [-1.5 1.5];   % Error color axis (m)

ua_lat_var  = 'LAT_clip';   ua_lon_var  = 'LON_clip';
uc_lat_var  = 'LAT_clip';   uc_lon_var  = 'LON_clip';

sl_elev_var = 'elev';
ua_elev_var = 'elev';
uc_elev_var = 'elev';

cell_area_sl = 500 * 500;
cell_area_ua = 800 * 800;
cell_area_uc = 500 * 500;

% ========================================================================
% 2. SNOLIMITS data
% ========================================================================
lat_sl   = rf_flt.lat(:);
lon_sl   = rf_flt.lon(:);
lidar_sl = rf_flt.lidar_SD(:);
pred_sl  = rf_flt.pred_SD(:);
lidar_sl(lidar_sl < 0) = nan;

if ismember(sl_elev_var, rf_flt.Properties.VariableNames)
    elev_sl = double(rf_flt.(sl_elev_var)(:));
else
    elev_sl = [];
    warning('SnoLimits elevation field "%s" not found.', sl_elev_var)
end

valid_sl = ~isnan(lat_sl) & ~isnan(lon_sl) & ~isnan(lidar_sl) & ~isnan(pred_sl);
lat_sl   = lat_sl(valid_sl);   lon_sl   = lon_sl(valid_sl);
lidar_sl = lidar_sl(valid_sl); pred_sl  = pred_sl(valid_sl);
if ~isempty(elev_sl), elev_sl = elev_sl(valid_sl); end

basin_str = string(rf_flt.basin(1));
date_str  = datestr(double(rf_flt.date(1)), 'mmmm dd, yyyy');
date_sv   = datestr(double(rf_flt.date(1)), 'yyyy_mm_dd');
basin_sv  = strrep(basin_str, ' ', '');
flight_str = erase(char(rf_flt.file(1)), '.mat');
fprintf('  Flight %d: %s — %s  (%d pts)\n', flight_idx, basin_str, date_str, sum(valid_sl))

% ========================================================================
% 3. UASWE
% ========================================================================
fprintf('Loading UASWE...\n')
orig_dir = pwd;
cd(ua_dir); ua_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
cd(orig_dir);

ua_match = find(contains(ua_names, flight_str, 'IgnoreCase', true), 1);
if isempty(ua_match)
    warning('No UASWE match for "%s".', flight_str); disp(ua_names)
    error('Stopping — fix filename mismatch.')
end
S_ua     = load(ua_names{ua_match});
lat_ua   = double(S_ua.(ua_lat_var)(:));
lon_ua   = double(S_ua.(ua_lon_var)(:));
lidar_ua = double(S_ua.aso_on_ua(:));
pred_ua  = double(S_ua.ua_sd_clip(:));
lidar_ua(lidar_ua < 0) = nan;
elev_ua  = [];
if isfield(S_ua, ua_elev_var), elev_ua = double(S_ua.(ua_elev_var)(:));
else, warning('UASWE elevation field "%s" not found.', ua_elev_var); end
valid_ua = ~isnan(lat_ua) & ~isnan(lon_ua) & ~isnan(lidar_ua) & ~isnan(pred_ua);
lat_ua   = lat_ua(valid_ua);   lon_ua   = lon_ua(valid_ua);
lidar_ua = lidar_ua(valid_ua); pred_ua  = pred_ua(valid_ua);
if ~isempty(elev_ua), elev_ua = elev_ua(valid_ua); end
fprintf('  %d valid pts\n', sum(valid_ua))

% ========================================================================
% 4. UCLA SWE
% ========================================================================
fprintf('Loading UCLA SWE...\n')
cd(uc_dir); uc_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
cd(orig_dir);

uc_match = find(contains(uc_names, flight_str, 'IgnoreCase', true), 1);
if isempty(uc_match)
    warning('No UCLA SWE match for "%s".', flight_str); disp(uc_names)
    error('Stopping — fix filename mismatch.')
end
S_uc     = load(uc_names{uc_match});
lat_uc   = double(S_uc.(uc_lat_var)(:));
lon_uc   = double(S_uc.(uc_lon_var)(:));
lidar_uc = double(S_uc.aso_on_ucla(:));
pred_uc  = double(S_uc.ucla_sd_clip(:));
lidar_uc(lidar_uc < 0) = nan;
elev_uc  = [];
if isfield(S_uc, uc_elev_var), elev_uc = double(S_uc.(uc_elev_var)(:));
else, warning('UCLA SD elevation field "%s" not found.', uc_elev_var); end
valid_uc = ~isnan(lat_uc) & ~isnan(lon_uc) & ~isnan(lidar_uc) & ~isnan(pred_uc);
lat_uc   = lat_uc(valid_uc);   lon_uc   = lon_uc(valid_uc);
lidar_uc = lidar_uc(valid_uc); pred_uc  = pred_uc(valid_uc);
if ~isempty(elev_uc), elev_uc = elev_uc(valid_uc); end
fprintf('  %d valid pts\n', sum(valid_uc))

% ========================================================================
% 5. ERROR STATS
% ========================================================================
[rmse_sl, r2_sl, ~, bias_sl] = calc_ml_stats(lidar_sl, pred_sl);
[rmse_ua, r2_ua, ~, bias_ua] = calc_ml_stats(lidar_ua, pred_ua);
[rmse_uc, r2_uc, ~, bias_uc] = calc_ml_stats(lidar_uc, pred_uc);
stat_str = @(rmse, bias, r2) ...
    sprintf('RMSE = %.3f m   Bias = %.3f m   R² = %.3f', rmse, bias, r2);

% ========================================================================
% 6. SNOW DEPTH VOLUME BY ELEVATION BAND
% ========================================================================
elev_min  = floor(min(elev_sl) / 100) * 100;
elev_max  = ceil(max(elev_sl)  / 100) * 100;
elev_bins = elev_min:100:elev_max;
elev_mid  = elev_bins(1:end-1) + 50;

vol_lidar_sl = elev_volume(elev_sl, lidar_sl, elev_bins, cell_area_sl);
vol_pred_sl  = elev_volume(elev_sl, pred_sl,  elev_bins, cell_area_sl);
vol_pred_ua  = elev_volume(elev_ua, pred_ua,  elev_bins, cell_area_ua);
vol_pred_uc  = elev_volume(elev_uc, pred_uc,  elev_bins, cell_area_uc);

% Wong palette
clr_lidar = [0,   0,   0  ];
clr_sl    = [0,   114, 178] / 255;
clr_ua    = [204, 121, 167] / 255;
clr_uc    = [0,   158, 115] / 255;

% ========================================================================
% 7. FIGURE  (2 rows × 4 cols)
% ========================================================================
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 20 12], 'Visible', 'on');
t   = tiledlayout(2, 4, 'TileSpacing', 'compact');

annotation(fig, 'textbox', [0, 0.96, 1, 0.04], ...
    'String',              basin_str + ":  " + date_str, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment',   'middle', ...
    'FontSize',            16, ...
    'FontWeight',          'bold', ...
    'EdgeColor',           'none', ...
    'BackgroundColor',     'none');

lat_lim = [min(lat_sl)-0.01, max(lat_sl)+0.01];
lon_lim = [min(lon_sl)-0.01, max(lon_sl)+0.01];

% ── ROW 1: SD MAPS ───────────────────────────────────────────────────────
sd_panels = { ...
    lat_sl, lon_sl, lidar_sl, 'ASO Lidar',  ''; ...
    lat_sl, lon_sl, pred_sl,  'SnoLimits',  stat_str(rmse_sl, bias_sl, r2_sl); ...
    lat_ua, lon_ua, pred_ua,  'UASWE',      stat_str(rmse_ua, bias_ua, r2_ua); ...
    lat_uc, lon_uc, pred_uc,  'UCLA SWE',   stat_str(rmse_uc, bias_uc, r2_uc)};

geo_ax = gobjects(1, 8);

for pp = 1:4
    ax_tmp = nexttile(t, pp);
    pos    = ax_tmp.Position;
    delete(ax_tmp);

    if pp == 3
        pt_size = auto_pt_size(numel(sd_panels{pp,1}), 0.9);
    else
        pt_size = auto_pt_size(numel(sd_panels{pp,1}));
    end

    geo_ax(pp) = geoaxes('Position', pos);
    geoscatter(geo_ax(pp), sd_panels{pp,1}, sd_panels{pp,2}, ...
        pt_size, sd_panels{pp,3}, 'filled', 'Marker', 's')
    geolimits(geo_ax(pp), lat_lim, lon_lim)
    geobasemap(geo_ax(pp), 'none')
    colormap(geo_ax(pp), 'parula')
    caxis(geo_ax(pp), caxis_sd)

    if pp == 4
        cb = colorbar(geo_ax(pp));
        cb.Label.String = 'Snow Depth (m)';  cb.FontSize = 13;
    end
    if pp > 1
        geo_ax(pp).LatitudeAxis.Visible  = 'off';
        geo_ax(pp).LongitudeAxis.Visible = 'off';
    end
    if isempty(sd_panels{pp,5})
        title(geo_ax(pp), sd_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
    else
        title(geo_ax(pp), sd_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
        subtitle(geo_ax(pp), sd_panels{pp,5}, 'FontSize', 10, 'FontWeight', 'normal')
    end
end

% ── ROW 2, PANEL 1: DEPTH VOLUME BY ELEVATION ────────────────────────────
ax_vol = nexttile(t, 5);
hold(ax_vol, 'on')
plot(ax_vol, cumsum(vol_lidar_sl), elev_mid, '-',  'Color', clr_lidar, 'LineWidth', 2.5)
plot(ax_vol, cumsum(vol_pred_sl),  elev_mid, '-',  'Color', clr_sl,    'LineWidth', 2)
plot(ax_vol, cumsum(vol_pred_ua),  elev_mid, '--', 'Color', clr_ua,    'LineWidth', 2)
plot(ax_vol, cumsum(vol_pred_uc),  elev_mid, '--', 'Color', clr_uc,    'LineWidth', 2)

leg_entries = {};
if ~isempty(vol_lidar_sl), leg_entries{end+1} = 'ASO Lidar'; end
if ~isempty(vol_pred_sl),  leg_entries{end+1} = 'SnoLimits'; end
if ~isempty(vol_pred_ua),  leg_entries{end+1} = 'UASWE';     end
if ~isempty(vol_pred_uc),  leg_entries{end+1} = 'UCLA SWE';  end
legend(ax_vol, leg_entries, 'Location', 'southeast', 'Box', 'off', 'FontSize', 13)
xlabel(ax_vol, 'Cumulative Snow Volume (km³)', 'FontSize', 13)
ylabel(ax_vol, 'Elevation (m)',                'FontSize', 13)
title(ax_vol,  'Volume by Elevation Band',     'FontSize', 13, 'FontWeight', 'bold')
ylim(ax_vol, [elev_min elev_max])
grid(ax_vol, 'off'); box(ax_vol, 'on')
hold(ax_vol, 'off')

% ── ROW 2, PANELS 2-4: ERROR MAPS ────────────────────────────────────────
err_panels = { ...
    lat_sl, lon_sl, pred_sl - lidar_sl, 'SnoLimits Error'; ...
    lat_ua, lon_ua, pred_ua - lidar_ua, 'UASWE Error';     ...
    lat_uc, lon_uc, pred_uc - lidar_uc, 'UCLA SWE Error'};

for pp = 1:3
    ax_tmp = nexttile(t, pp + 5);
    pos    = ax_tmp.Position;
    delete(ax_tmp);

    if pp == 2
        pt_size = auto_pt_size(numel(err_panels{pp,1}), 0.9);
    else
        pt_size = auto_pt_size(numel(err_panels{pp,1}));
    end

    geo_ax(pp+5) = geoaxes('Position', pos);
    geoscatter(geo_ax(pp+5), err_panels{pp,1}, err_panels{pp,2}, ...
        pt_size, err_panels{pp,3}, 'filled', 'Marker', 's')
    geolimits(geo_ax(pp+5), lat_lim, lon_lim)
    geobasemap(geo_ax(pp+5), 'none')
    colormap(geo_ax(pp+5), slanCM('coolwarm'))
    caxis(geo_ax(pp+5), caxis_err)

    if pp == 3
        cb = colorbar(geo_ax(pp+5));
        cb.Label.String = 'Error (m)';  cb.FontSize = 12;
    end
    geo_ax(pp+5).LatitudeAxis.Visible  = 'off';
    geo_ax(pp+5).LongitudeAxis.Visible = 'off';
    title(geo_ax(pp+5), err_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
end

% ========================================================================
% SAVE
% ========================================================================
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
out_file = fullfile(out_dir, sprintf('%s_%s.png', basin_sv, date_sv));
exportgraphics(fig, out_file, 'Resolution', 200);
fprintf('\nSaved → %s\n', out_file)

% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================
function vol = elev_volume(elev, swe, elev_bins, cell_area)
    nbins = numel(elev_bins) - 1;
    if isempty(elev), vol = zeros(nbins,1); return; end
    vol = zeros(nbins, 1);
    for bb = 1:nbins
        in_bin  = elev >= elev_bins(bb) & elev < elev_bins(bb+1);
        vol(bb) = nansum(swe(in_bin) * cell_area);
    end
    vol = vol / 1e9;
end

function pt_sz = auto_pt_size(n, fill_frac)
    if nargin < 2, fill_frac = 0.8; end
    ax_w_pts = 4.0 * 72;
    ax_h_pts = 4.5 * 72;
    pt_sz = fill_frac * (ax_w_pts * ax_h_pts) / n;
    pt_sz = max(1, min(pt_sz, 150));
end

function [RMSE, R2, RMAD, Rbias] = calc_ml_stats(x, y)
    round_num = 3;
    x = x(:); y = y(:);
    good = ~isnan(x) & ~isnan(y);
    x = x(good); y = y(good);
    RMSE  = round(rmse(x, y), round_num);
    RMAD  = round(mean(abs(x - y), 'omitnan') / mean(x, 'omitnan'), round_num);
    Rbias = round(mean(y, 'omitnan') - mean(x, 'omitnan'), round_num);
    if var(x) < 1e-10 || var(y) < 1e-10
        R2 = NaN;
    else
        linmdl = fitlm(x, y);
        R2 = round(linmdl.Rsquared.Ordinary, round_num);
    end
end