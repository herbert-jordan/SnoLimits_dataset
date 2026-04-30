% ========================================================================
% PLOT_ERROR_BOXPLOTS_YEARS_SD.M
% J. Herbert
%
% Box plots of per-flight SD error metrics grouped by year
%   Row 1: Colorado | Row 2: California
%   Cols: RMSE | R2 | Bias
% ========================================================================
clear; clc;

% ========================================================================
% PATHS
% ========================================================================
base_path  = fileparts(fileparts(mfilename('fullpath')));
data_dir  = fullfile(base_path, 'data');
out_dir   = fullfile(base_path, 'outputs');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

load(fullfile(data_dir, 'all_datasets_flight_errors_sd.mat'))  % loads M

% ========================================================================
% CONFIG
% ========================================================================
models  = {'snolimits', 'uaswe', 'ucla'};
labels  = {'SnoLimits', 'UASWE', 'UCLA SWE'};
years   = 2016:2019;
regions = {'CO', 'CA'};

metrics       = {'rmse',     'r2',    'bias'};
metric_labels = {'RMSE (m)', 'R^{2}', 'Bias (m)'};

% Wong colorblind-safe palette
clr = [  0, 114, 178;    % SnoLimits — blue
        204, 121, 167;    % UASWE     — reddish purple
          0, 158, 115] / 255;  % UCLA SWE  — bluish green

% ========================================================================
% BOX POSITIONS
% ========================================================================
n_models = numel(models);
n_years  = numel(years);
grp_step = n_models + 2;

pos_all = zeros(1, n_models * n_years);
yr_ctr  = zeros(1, n_years);
sep_x   = zeros(1, n_years - 1);

for yy = 1:n_years
    base = (yy - 1) * grp_step;
    idx  = (yy - 1) * n_models + (1:n_models);
    pos_all(idx) = base + (1:n_models);
    yr_ctr(yy)   = base + (n_models + 1) / 2;
    if yy < n_years
        sep_x(yy) = base + n_models + (grp_step - n_models + 1) / 2;
    end
end

x_lo = pos_all(1)   - 1;
x_hi = pos_all(end) + 1;

% ========================================================================
% FIGURE
% ========================================================================
fig = figure('Units', 'inches', 'Position', [1 1 18 8]);
t   = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
t.OuterPosition = [0 0 1 1];

for ri = 1:2
    region = regions{ri};

    for mi = 1:3
        metric = metrics{mi};
        ax     = nexttile((ri-1)*3 + mi);

        % --- Build data vectors in year-grouped order -------------------
        all_vals = [];
        grp_vec  = [];
        grp_idx  = 1;

        for yy = 1:n_years
            for mm = 1:n_models
                dates = double(M.(models{mm}).(region).date);
                yrs   = year(dates);
                vals  = double(M.(models{mm}).(region).(metric)(yrs == years(yy)));
                vals  = vals(~isnan(vals));
                all_vals = [all_vals; vals(:)];
                grp_vec  = [grp_vec;  repmat(grp_idx, numel(vals), 1)];
                grp_idx  = grp_idx + 1;
            end
        end

        % --- Boxplot ----------------------------------------------------
        grp_ids = unique(grp_vec);
        pos_sub = pos_all(grp_ids);

        boxplot(ax, all_vals, grp_vec, ...
            'Positions', pos_sub, ...
            'Widths',    0.65,    ...
            'Whisker',   1.5,     ...
            'Symbol',    'k.');
        hold on

        ax.XTickLabel = repmat({''}, 1, n_models * n_years);

        % --- Color boxes ------------------------------------------------
        h = findobj(ax, 'Tag', 'Box');
        for jj = 1:numel(h)
            col_idx = n_models - mod(jj-1, n_models);
            patch(get(h(jj),'XData'), get(h(jj),'YData'), clr(col_idx,:), ...
                'FaceAlpha', 0.55, 'EdgeColor', 'none');
        end

        % --- Year separators --------------------------------------------
        for sx = sep_x
            xline(ax, sx, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);
        end

        % --- Axis formatting --------------------------------------------
        xlim(ax, [x_lo, x_hi])
        ax.XTick              = yr_ctr;
        ax.XTickLabel         = cellstr(num2str(years(:)));
        ax.XTickLabelRotation = 0;
        ax.FontSize           = 10;
        ax.XAxis.FontSize     = 11;
        ax.XAxis.FontWeight   = 'bold';
        ax.Box                = 'on';
        grid(ax, 'off')

        if mi == 1
            ylabel(ax, region, 'FontSize', 13, 'FontWeight', 'bold')
        end
        if ri == 1
            title(ax, metric_labels{mi}, 'FontSize', 13, 'FontWeight', 'bold')
        end
        if strcmp(metric, 'r2')
            ylim(ax, [0 1])
        end
        if strcmp(metric, 'bias')
            yline(ax, 0, 'k-', 'LineWidth', 0.8)
        end

        hold off
    end
end

% ========================================================================
% LEGEND — top left panel
% ========================================================================
ax_first = nexttile(t, 1);
hold(ax_first, 'on')
h_leg = gobjects(n_models, 1);
for mm = 1:n_models
    h_leg(mm) = patch(ax_first, NaN, NaN, clr(mm,:), ...
        'FaceAlpha', 0.55, 'EdgeColor', 'k', 'LineWidth', 0.8);
end
leg = legend(ax_first, h_leg, labels, ...
    'FontSize',    11,      ...
    'Box',         'on',    ...
    'Location',    'northwest');
leg.Title.String     = 'Dataset';
leg.Title.FontSize   = 11;
leg.Title.FontWeight = 'bold';
hold(ax_first, 'off')

% ========================================================================
% SAVE
% ========================================================================
out_file = fullfile(out_dir, 'sd_error_boxplots_2016_2019.png');
exportgraphics(fig, out_file, 'Resolution', 200);
fprintf('Saved: %s\n', out_file)