% ========================================================================
% swe_map_plots.m
% J. Herbert
%
% 10-panel figure: SWE maps (row 1) + error maps & volume profile (row 2)
%
%   Row 1: [ ASO Lidar ] [ SnoLimits ] [ UASWE ] [ ParBal ] [ UCLA SWE ]
%   Row 2: [ Vol/Elev  ] [ SL Error  ] [ UA Err] [ PB Err ] [ UCLA Err ]
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
base_path = fileparts(fileparts(mfilename('fullpath')));

snolimits_path = fullfile(base_path, 'data');
parbal_path    = fullfile(base_path, 'dataset_comparisons', 'ParBal');
uaswe_path     = fullfile(base_path, 'dataset_comparisons', 'UASWE');
ucla_path      = fullfile(base_path, 'dataset_comparisons', 'UCLA_SWE');
out_dir        = fullfile(base_path, 'outputs');

domain_str = {'CA', 'rocky'};
region_str = {'CA', 'CO'};

sl_file = fullfile(snolimits_path, ...
    sprintf('%s_SWE_500_IDW_pre2020.mat', domain_str{domain}));
pb_dir  = fullfile(parbal_path, region_str{domain});
ua_dir  = fullfile(uaswe_path,  region_str{domain});
uc_dir  = fullfile(ucla_path,   region_str{domain});

% ========================================================================
% 1. SNOLIMITS — load and select flight
% ========================================================================
fprintf('Loading SnoLimits...\n')
load(sl_file);
rf_master = rf_out; clear rf_out;
flts = unique(rf_master.file);

% ── Flight selection ─────────────────────────────────────────────────────
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
% ─────────────────────────────────────────────────────────────────────────

idx    = flts(flight_idx) == rf_master.file;
rf_flt = rf_master(idx, :);

% ========================================================================
% SETTINGS
% ========================================================================
caxis_swe  = [0 1];       % SWE color axis (m)
caxis_err  = [-0.5 0.5];  % Error color axis (m)

pb_lat_var  = 'LAT_clip';   pb_lon_var  = 'LON_clip';
ua_lat_var  = 'LAT_clip';   ua_lon_var  = 'LON_clip';
uc_lat_var  = 'LAT_clip';   uc_lon_var  = 'LON_clip';

sl_elev_var = 'elev';
pb_elev_var = 'elev';
ua_elev_var = 'elev';
uc_elev_var = 'elev';

cell_area_sl = 500 * 500;
cell_area_pb = 500 * 500;
cell_area_ua = 800 * 800;
cell_area_uc = 500 * 500;   % update to actual UCLA resolution

% ========================================================================
% 1. SNOLIMITS
% ========================================================================
fprintf('Loading SnoLimits...\n')
load(sl_file);
rf_master = rf_out; clear rf_out;
flts   = unique(rf_master.file);
idx    = flts(flight_idx) == rf_master.file;
rf_flt = rf_master(idx, :);

lat_sl   = rf_flt.lat(:);
lon_sl   = rf_flt.lon(:);
lidar_sl = rf_flt.lidar_SWE(:);
pred_sl  = rf_flt.pred_SWE(:);
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
fprintf('  Flight %d: %s — %s  (%d pts)\n', flight_idx, basin_str, date_str, sum(valid_sl))

% ========================================================================
% 2. PARBAL
% ========================================================================
fprintf('Loading ParBal...\n')
cd(pb_dir); pb_names = get_names;
flight_str = erase(char(rf_flt.file(1)), '.mat');
pb_match = find(contains(pb_names, flight_str, 'IgnoreCase', true), 1);
if isempty(pb_match)
    warning('No ParBal match for "%s".', flight_str); disp(pb_names)
    error('Stopping — fix filename mismatch.')
end
S_pb     = load(pb_names{pb_match});
lat_pb   = double(S_pb.(pb_lat_var)(:));
lon_pb   = double(S_pb.(pb_lon_var)(:));
lidar_pb = double(S_pb.aso_on_parbal(:));
pred_pb  = double(S_pb.parbal_swe_clip(:)) / 1000;
lidar_pb(lidar_pb < 0) = nan;
elev_pb  = [];
if isfield(S_pb, pb_elev_var), elev_pb = double(S_pb.(pb_elev_var)(:));
else, warning('ParBal elevation field "%s" not found.', pb_elev_var); end
valid_pb = ~isnan(lat_pb) & ~isnan(lon_pb) & ~isnan(lidar_pb) & ~isnan(pred_pb);
lat_pb   = lat_pb(valid_pb);   lon_pb   = lon_pb(valid_pb);
lidar_pb = lidar_pb(valid_pb); pred_pb  = pred_pb(valid_pb);
if ~isempty(elev_pb), elev_pb = elev_pb(valid_pb); end
fprintf('  %d valid pts\n', sum(valid_pb))

% ========================================================================
% 3. UASWE
% ========================================================================
fprintf('Loading UASWE...\n')
cd(ua_dir); ua_names = get_names;
ua_match = find(contains(ua_names, flight_str, 'IgnoreCase', true), 1);
if isempty(ua_match)
    warning('No UASWE match for "%s".', flight_str); disp(ua_names)
    error('Stopping — fix filename mismatch.')
end
S_ua     = load(ua_names{ua_match});
lat_ua   = double(S_ua.(ua_lat_var)(:));
lon_ua   = double(S_ua.(ua_lon_var)(:));
lidar_ua = double(S_ua.aso_on_ua(:));
pred_ua  = double(S_ua.ua_swe_clip(:));
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
cd(uc_dir); uc_names = get_names;
uc_match = find(contains(uc_names, flight_str, 'IgnoreCase', true), 1);
if isempty(uc_match)
    warning('No UCLA SWE match for "%s".', flight_str); disp(uc_names)
    error('Stopping — fix filename mismatch.')
end
S_uc     = load(uc_names{uc_match});
lat_uc   = double(S_uc.(uc_lat_var)(:));
lon_uc   = double(S_uc.(uc_lon_var)(:));
lidar_uc = double(S_uc.aso_on_ucla(:));     % update field name if different
pred_uc  = double(S_uc.ucla_swe_clip(:));   % update field name if different
lidar_uc(lidar_uc < 0) = nan;
elev_uc  = [];
if isfield(S_uc, uc_elev_var), elev_uc = double(S_uc.(uc_elev_var)(:));
else, warning('UCLA SWE elevation field "%s" not found.', uc_elev_var); end
valid_uc = ~isnan(lat_uc) & ~isnan(lon_uc) & ~isnan(lidar_uc) & ~isnan(pred_uc);
lat_uc   = lat_uc(valid_uc);   lon_uc   = lon_uc(valid_uc);
lidar_uc = lidar_uc(valid_uc); pred_uc  = pred_uc(valid_uc);
if ~isempty(elev_uc), elev_uc = elev_uc(valid_uc); end
fprintf('  %d valid pts\n', sum(valid_uc))

% ========================================================================
% 5. ERROR STATS
% ========================================================================
[rmse_sl, r2_sl, ~, bias_sl] = calc_ml_stats(lidar_sl, pred_sl);
[rmse_pb, r2_pb, ~, bias_pb] = calc_ml_stats(lidar_pb, pred_pb);
[rmse_ua, r2_ua, ~, bias_ua] = calc_ml_stats(lidar_ua, pred_ua);
[rmse_uc, r2_uc, ~, bias_uc] = calc_ml_stats(lidar_uc, pred_uc);
stat_str = @(rmse, bias, r2) ...
    sprintf('RMSE = %.3f m   Bias = %.3f m   R² = %.3f', rmse, bias, r2);

% ========================================================================
% 6. SNOW VOLUME BY ELEVATION BAND
% ========================================================================
elev_min  = floor(min(elev_sl) / 100) * 100;
elev_max  = ceil(max(elev_sl)  / 100) * 100;
elev_bins = elev_min:100:elev_max;
elev_mid  = elev_bins(1:end-1) + 50;

vol_lidar_sl = elev_volume(elev_sl, lidar_sl, elev_bins, cell_area_sl);
vol_pred_sl  = elev_volume(elev_sl, pred_sl,  elev_bins, cell_area_sl);
vol_pred_pb  = elev_volume(elev_pb, pred_pb,  elev_bins, cell_area_pb);
vol_pred_ua  = elev_volume(elev_ua, pred_ua,  elev_bins, cell_area_ua);
vol_pred_uc  = elev_volume(elev_uc, pred_uc,  elev_bins, cell_area_uc);

% Wong palette
clr_lidar = [0,   0,   0  ];
clr_sl    = [0,   114, 178] / 255;
clr_ua    = [204, 121, 167] / 255;
clr_pb    = [213, 94,  0  ] / 255;
clr_uc    = [0,   158, 115] / 255;   % bluish green

% ========================================================================
% 7. FIGURE  (2 rows × 5 cols)
% ========================================================================
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 24 12], 'Visible', 'on');
t   = tiledlayout(2, 5, 'TileSpacing', 'compact');

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

% ── ROW 1: SWE MAPS ──────────────────────────────────────────────────────
swe_panels = { ...
    lat_sl, lon_sl, lidar_sl, 'ASO Lidar',  '';                            ...
    lat_sl, lon_sl, pred_sl,  'SnoLimits',  stat_str(rmse_sl, bias_sl, r2_sl); ...
    lat_ua, lon_ua, pred_ua,  'UASWE',      stat_str(rmse_ua, bias_ua, r2_ua); ...
    lat_pb, lon_pb, pred_pb,  'ParBal',     stat_str(rmse_pb, bias_pb, r2_pb); ...
    lat_uc, lon_uc, pred_uc,  'UCLA SWE',   stat_str(rmse_uc, bias_uc, r2_uc)};

geo_ax = gobjects(1, 10);

for pp = 1:5
    ax_tmp = nexttile(t, pp);
    pos    = ax_tmp.Position;
    delete(ax_tmp);

    % UASWE tends to be sparser — slightly larger markers
    if pp == 3
        pt_size = auto_pt_size(numel(swe_panels{pp,1}), 0.9);
    else
        pt_size = auto_pt_size(numel(swe_panels{pp,1}));
    end

    geo_ax(pp) = geoaxes('Position', pos);
    geoscatter(geo_ax(pp), swe_panels{pp,1}, swe_panels{pp,2}, ...
        pt_size, swe_panels{pp,3}, 'filled', 'Marker', 's')
    geolimits(geo_ax(pp), lat_lim, lon_lim)
    geobasemap(geo_ax(pp), 'none')
    colormap(geo_ax(pp), 'parula')
    caxis(geo_ax(pp), caxis_swe)

    if pp == 5
        cb = colorbar(geo_ax(pp));
        cb.Label.String = 'SWE (m)';  cb.FontSize = 13;
    end
    if pp > 1
        ax = gca;
        ax.LatitudeAxis.Visible  = 'off';
        ax.LongitudeAxis.Visible = 'off';
    end
    if isempty(swe_panels{pp,5})
        title(geo_ax(pp), swe_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
    else
        title(geo_ax(pp), swe_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
        subtitle(geo_ax(pp), swe_panels{pp,5}, 'FontSize', 10, 'FontWeight', 'normal')
    end
end

% ── ROW 2, PANEL 1: SNOW VOLUME BY ELEVATION ─────────────────────────────
ax_vol = nexttile(t, 6);
hold(ax_vol, 'on')
plot(ax_vol, cumsum(vol_lidar_sl), elev_mid, '-',  'Color', clr_lidar, 'LineWidth', 2.5)
plot(ax_vol, cumsum(vol_pred_sl),  elev_mid, '-',  'Color', clr_sl,    'LineWidth', 2)
plot(ax_vol, cumsum(vol_pred_ua),  elev_mid, '--', 'Color', clr_ua,    'LineWidth', 2)
plot(ax_vol, cumsum(vol_pred_pb),  elev_mid, '--', 'Color', clr_pb,    'LineWidth', 2)
plot(ax_vol, cumsum(vol_pred_uc),  elev_mid, '--', 'Color', clr_uc,    'LineWidth', 2)

leg_entries = {};
if ~isempty(vol_lidar_sl), leg_entries{end+1} = 'ASO Lidar'; end
if ~isempty(vol_pred_sl),  leg_entries{end+1} = 'SnoLimits'; end
if ~isempty(vol_pred_ua),  leg_entries{end+1} = 'UASWE';     end
if ~isempty(vol_pred_pb),  leg_entries{end+1} = 'ParBal';    end
if ~isempty(vol_pred_uc),  leg_entries{end+1} = 'UCLA SWE';  end
legend(ax_vol, leg_entries, 'Location', 'southeast', 'Box', 'off', 'FontSize', 13)
xlabel(ax_vol, 'Cumulative Snow Water Volume (km³)', 'FontSize', 13)
ylabel(ax_vol, 'Elevation (m)',                      'FontSize', 13)
title(ax_vol,  'Volume by Elevation Band',           'FontSize', 13, 'FontWeight', 'bold')
ylim(ax_vol, [elev_min elev_max])
grid(ax_vol, 'off'); box(ax_vol, 'on')
hold(ax_vol, 'off')

% ── ROW 2, PANELS 2-5: ERROR MAPS ────────────────────────────────────────
err_panels = { ...
    lat_sl, lon_sl, pred_sl - lidar_sl, 'SnoLimits Error'; ...
    lat_ua, lon_ua, pred_ua - lidar_ua, 'UASWE Error';     ...
    lat_pb, lon_pb, pred_pb - lidar_pb, 'ParBal Error';    ...
    lat_uc, lon_uc, pred_uc - lidar_uc, 'UCLA SWE Error'};

for pp = 1:4
    ax_tmp = nexttile(t, pp + 6);
    pos    = ax_tmp.Position;
    delete(ax_tmp);

    if pp == 2
        pt_size = auto_pt_size(numel(err_panels{pp,1}), 0.9);
    else
        pt_size = auto_pt_size(numel(err_panels{pp,1}));
    end

    geo_ax(pp+6) = geoaxes('Position', pos);
    geoscatter(geo_ax(pp+6), err_panels{pp,1}, err_panels{pp,2}, ...
        pt_size, err_panels{pp,3}, 'filled', 'Marker', 's')
    geolimits(geo_ax(pp+6), lat_lim, lon_lim)
    geobasemap(geo_ax(pp+6), 'none')
    colormap(geo_ax(pp+6), slanCM('coolwarm'))
    caxis(geo_ax(pp+6), caxis_err)

    if pp == 4
        cb = colorbar(geo_ax(pp+6));
        cb.Label.String = 'Error (m)';  cb.FontSize = 12;
    end
    ax = gca;
    ax.LatitudeAxis.Visible  = 'off';
    ax.LongitudeAxis.Visible = 'off';
    title(geo_ax(pp+6), err_panels{pp,4}, 'FontSize', 13, 'FontWeight', 'bold')
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
    if isempty(elev), vol = []; return; end
    nbins = numel(elev_bins) - 1;
    vol   = zeros(nbins, 1);
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


% this function calculates the ML performance stats
function [RMSE, R2, RMAD, Rbias] = calc_ml_stats(x,y) 

    round_num = 3;

    % calculate stats 
    RMSE = round(rmse(x,y),round_num);
    linmdl = fitlm(x,y);
    R2 = round(linmdl.Rsquared.Ordinary,round_num);
    RMAD = round(mean(abs(x - y),'omitnan')/mean(x,'omitnan'),round_num);
    % Rbias = round(mean(y - x,'omitnan')/mean(x,'omitnan'),round_num) * 100;
    Rbias = round(mean(y,'omitnan')-mean(x,'omitnan'),round_num); 

end