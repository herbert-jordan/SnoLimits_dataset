% ========================================================================
% PLOT_POLAR_SD.M
% J. Herbert
%
% 2 × 4 layout: rows = CO / CA
% cols = ASO Lidar | SnoLimits | UASWE | UCLA SWE
% ========================================================================
clear; clc;

% ========================================================================
% PATHS
% ========================================================================
base_path  = fileparts(fileparts(mfilename('fullpath')));

snolimits_path = fullfile(base_path,'data', 'SnoLimits');
uaswe_path     = fullfile(base_path,'data', 'UASWE');
ucla_path      = fullfile(base_path,'data', 'UCLA_SWE');
out_dir        = fullfile(base_path,'outputs');

% ========================================================================
% CONFIG  (per-region)
% ========================================================================
az_edges  = 0:deg2rad(10):2*pi;
az_offset = pi/2;
rot       = @(th) mod(th + az_offset, 2*pi);
bg_color  = [0.9 0.9 0.9];
cmap      = turbo(256);

cfg.CO.elev_edges = 2000:250:4000;
cfg.CO.clims      = [0 2.5];
cfg.CO.r_ticks    = 2500:500:3500;

cfg.CA.elev_edges = 1000:250:4000;
cfg.CA.clims      = [0 3];
cfg.CA.r_ticks    = 1500:500:3500;

% ========================================================================
% 1. LOAD SNOLIMITS
% ========================================================================
fprintf('Loading SnoLimits...\n')
S_ca = load(fullfile(snolimits_path, 'CA_SD_500_IDW_pre2020.mat'));    rf_ca = S_ca.rf_out;
S_co = load(fullfile(snolimits_path, 'rocky_SD_500_IDW_pre2020.mat')); rf_co = S_co.rf_out;

rf_ca.lidar_SD(rf_ca.lidar_SD < 0) = nan;
rf_co.lidar_SD(rf_co.lidar_SD < 0) = nan;

clean = @(t) t(~(isnan(t.lidar_SD) | isnan(t.pred_SD)), :);
rf_ca = clean(rf_ca);
rf_co = clean(rf_co);

sl.CO.elev  = double(rf_co.elev);        sl.CA.elev  = double(rf_ca.elev);
sl.CO.north = double(rf_co.northness);   sl.CA.north = double(rf_ca.northness);
sl.CO.east  = double(rf_co.eastness);    sl.CA.east  = double(rf_ca.eastness);
sl.CO.lidar = double(rf_co.lidar_SD);    sl.CA.lidar = double(rf_ca.lidar_SD);
sl.CO.pred  = double(rf_co.pred_SD);     sl.CA.pred  = double(rf_ca.pred_SD);

fprintf('  CO: %d  CA: %d valid obs\n', height(rf_co), height(rf_ca))

% ========================================================================
% 2. LOAD UASWE
% ========================================================================
fprintf('Loading UASWE...\n')
[ua.CA.elev, ua.CA.north, ua.CA.east, ua.CA.pred, ua.CA.lidar] = load_comparison_dir( ...
    fullfile(uaswe_path, 'CA'), 'aso_on_ua', 'ua_sd_clip', 1);
[ua.CO.elev, ua.CO.north, ua.CO.east, ua.CO.pred, ua.CO.lidar] = load_comparison_dir( ...
    fullfile(uaswe_path, 'CO'), 'aso_on_ua', 'ua_sd_clip', 1);
fprintf('  CO: %d  CA: %d valid px\n', numel(ua.CO.pred), numel(ua.CA.pred))

% ========================================================================
% 3. LOAD UCLA SWE
% ========================================================================
fprintf('Loading UCLA SWE...\n')
[uc.CA.elev, uc.CA.north, uc.CA.east, uc.CA.pred, uc.CA.lidar] = load_comparison_dir( ...
    fullfile(ucla_path, 'CA'), 'aso_on_ucla', 'ucla_sd_clip', 1);
[uc.CO.elev, uc.CO.north, uc.CO.east, uc.CO.pred, uc.CO.lidar] = load_comparison_dir( ...
    fullfile(ucla_path, 'CO'), 'aso_on_ucla', 'ucla_sd_clip', 1);
fprintf('  CO: %d  CA: %d valid px\n', numel(uc.CO.pred), numel(uc.CA.pred))

% ========================================================================
% 4. ASSEMBLE DATASETS
%    regions: 1=CO, 2=CA
%    models:  1=Lidar, 2=SnoLimits, 3=UASWE, 4=UCLA SWE
%    4 values per model: elev, north, east, val
% ========================================================================
regions      = {'CO', 'CA'};
model_labels = {'ASO Lidar', 'SnoLimits', 'UASWE', 'UCLA SWE'};
n_cols       = 4;

datasets = { ...
    sl.CO.elev, sl.CO.north, sl.CO.east, sl.CO.lidar, ...
    sl.CO.elev, sl.CO.north, sl.CO.east, sl.CO.pred,  ...
    ua.CO.elev, ua.CO.north, ua.CO.east, ua.CO.pred,  ...
    uc.CO.elev, uc.CO.north, uc.CO.east, uc.CO.pred;  ...
    sl.CA.elev, sl.CA.north, sl.CA.east, sl.CA.lidar, ...
    sl.CA.elev, sl.CA.north, sl.CA.east, sl.CA.pred,  ...
    ua.CA.elev, ua.CA.north, ua.CA.east, ua.CA.pred,  ...
    uc.CA.elev, uc.CA.north, uc.CA.east, uc.CA.pred};

% ========================================================================
% 5. FIGURE  (2 rows × 4 cols)
% ========================================================================
fig   = figure('Position', [100 100 1400 750], 'Color', 'w');
tiled = tiledlayout(fig, 2, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');

for ri = 1:2
    region = regions{ri};

    elev_edges = cfg.(region).elev_edges;
    clims      = cfg.(region).clims;
    r_ticks    = cfg.(region).r_ticks;
    rmax       = max(elev_edges);
    rmin       = min(elev_edges);

    for mi = 1:n_cols

        col   = (mi - 1) * 4 + 1;
        elev  = datasets{ri, col};
        north = datasets{ri, col+1};
        east  = datasets{ri, col+2};
        sd    = datasets{ri, col+3};

        valid = elev >= rmin & elev <= rmax & ~isnan(sd);
        az    = rot(atan2(east(valid), north(valid)));
        ev    = elev(valid);
        sv    = sd(valid);

        [Z, mask] = binPolarMean(ev, az, sv, elev_edges, az_edges);

        ax = nexttile(tiled, (ri-1)*n_cols + mi);
        polarPcolorEdges(ax, az_edges, elev_edges, Z, true, bg_color, mask, clims, false);
        colormap(ax, cmap);
        caxis(ax, clims);

        if mi == n_cols
            cb = colorbar(ax, 'eastoutside');
            cb.Label.String   = 'Mean Snow Depth (m)';
            cb.Label.FontSize = 11;
            cb.FontSize       = 10;
        end

        if ri == 1
            title(ax, model_labels{mi}, 'FontWeight', 'bold', 'FontSize', 13)
        end

        hold(ax, 'on')

        % Elevation rings
        for r = r_ticks
            th = linspace(0, 2*pi, 200);
            [x, y] = pol2cart(th, rmax - r);
            plot(ax, x, y, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        end

        % Elevation labels
        for r = r_ticks
            [tx, ty] = pol2cart(-pi/2, rmax - r);
            text(ax, tx, ty, sprintf('%d m', r), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'top', ...
                'FontSize', 7, 'FontWeight', 'bold', ...
                'Color', [0.5 0.5 0.5], 'Clipping', 'off');
        end

        % Azimuth spokes
        th_ticks  = 0:pi/4:(2*pi - pi/4);
        spoke_len = (rmax - rmin) * 0.95;
        for th = th_ticks
            [x, y] = pol2cart([th th], [0 spoke_len]);
            plot(ax, x, y, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        end

        % North label
        [tx, ty] = pol2cart(-pi/2, -(rmax - rmin) * 1.08);
        text(ax, tx, ty-300, 'N', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', 11, 'FontWeight', 'bold', 'Color', 'w');

        % Outer circle
        outer_radius = rmax - rmin;
        axis(ax, 'equal', 'off');
        xlim(ax, [-outer_radius outer_radius]);
        ylim(ax, [-outer_radius outer_radius]);
        [xo, yo] = pol2cart(linspace(0, 2*pi, 360), outer_radius);
        plot(ax, xo, yo, 'k-', 'LineWidth', 0.6);

        hold(ax, 'off')
    end
end

annotation(fig, 'textbox', [0.15, 0.71, 0.04, 0.44], 'String', 'Colorado', ...
    'FontSize', 13, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);
annotation(fig, 'textbox', [0.15, 0.21, 0.04, 0.44], 'String', 'California', ...
    'FontSize', 13, 'FontWeight', 'bold', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Rotation', 90);

% ========================================================================
% SAVE
% ========================================================================
out_file = fullfile(out_dir, 'polar_sd_CO_CA_rows.png');
exportgraphics(fig, out_file, 'Resolution', 200);
fprintf('\nSaved → %s\n', out_file)

% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================
function [elev_out, north_out, east_out, pred_out, lidar_out] = load_comparison_dir(dir_path, aso_var, pred_var, pred_scale)
    cd(dir_path);
    names     = get_names;
    elev_out  = [];  north_out = [];  east_out  = [];
    pred_out  = [];  lidar_out = [];
    for ii = 1:numel(names)
        S     = load(names{ii});
        pred  = double(S.(pred_var)) * pred_scale;
        lidar = double(S.(aso_var));
        elev  = double(S.elev);
        nrth  = double(S.northness);
        east  = double(S.eastness);
        pred  = pred(:);  lidar = lidar(:);
        elev  = elev(:);  nrth  = nrth(:);  east = east(:);
        bad   = isnan(pred) | isnan(lidar) | isnan(elev);
        pred(bad) = [];  lidar(bad) = [];  elev(bad) = [];
        nrth(bad) = [];  east(bad)  = [];
        elev_out  = [elev_out;  elev];   north_out = [north_out; nrth];
        east_out  = [east_out;  east];   pred_out  = [pred_out;  pred];
        lidar_out = [lidar_out; lidar];
    end
end

function [Z, mask] = binPolarMean(elev, az, val, elev_edges, az_edges)
    nE = numel(elev_edges) - 1;   nA = numel(az_edges) - 1;
    Z  = nan(nE, nA);   mask = false(nE, nA);
    az_idx   = discretize(az,   az_edges);
    elev_idx = discretize(elev, elev_edges);
    for ii = 1:nE
        for jj = 1:nA
            m = (elev_idx == ii) & (az_idx == jj);
            if any(m)
                Z(ii,jj)    = mean(val(m), 'omitnan');
                mask(ii,jj) = true;
            end
        end
    end
end

function polarPcolorEdges(ax, theta_edges, rho_edges, Z, invert_radius, nodata_color, data_mask, climits, add_cbar)
    if nargin < 5 || isempty(invert_radius), invert_radius = true; end
    if nargin < 6 || isempty(nodata_color),  nodata_color  = [0.92 0.92 0.92]; end
    if nargin < 7 || isempty(data_mask),     data_mask     = isfinite(Z); end
    if nargin < 8 || isempty(climits),       climits       = [0 3]; end
    if nargin < 9,  add_cbar = false; end
    axes(ax); %#ok<LAXES>
    [TH, R] = meshgrid(theta_edges, rho_edges);
    Rplot   = invert_radius * (max(rho_edges) - R) + (~invert_radius) * R;
    [X, Y]  = pol2cart(TH, Rplot);
    Zpad    = [Z, Z(:,end)];        Zpad    = [Zpad;    Zpad(end,:)];
    MaskPad = [data_mask, data_mask(:,end)]; MaskPad = [MaskPad; MaskPad(end,:)];
    set(ax, 'Color', nodata_color);
    h = pcolor(ax, X, Y, Zpad);
    set(h, 'EdgeColor', 'none', 'AlphaData', double(MaskPad), 'AlphaDataMapping', 'none');
    shading(ax, 'flat');
    axis(ax, 'equal'); axis(ax, 'off');
    caxis(ax, climits);
    if add_cbar, colorbar(ax); end
end