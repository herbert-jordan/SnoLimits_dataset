% ========================================================================
% PLOT_ERROR_BOXPLOTS_YEARS.M
% J. Herbert | big jorbo edition
%
% Box plots of per-flight error metrics grouped by year, with:
%   - Boxes grouped by year (3 models side-by-side per year)
%   - Vertical dashed separators between year groups
%   - Year labels at the top of each panel
%   - Shared legend (no per-box x labels)
% ========================================================================
clear; clc;

load('/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/data_paper/dataset_comparisons/data/all_models_flight_errors_struct.mat')

models  = {'snolimits', 'uaswe', 'parbal'};
labels  = {'SnoLimits', 'UASWE', 'ParBal'};
years   = 2021:2024;
regions = {'CO', 'CA'};

metrics       = {'rmse',    'r2',    'bias'};
metric_labels = {'RMSE (m)', 'R^{2}', 'Bias (m)'};

% --- Wong colorblind-safe palette ---
clr = [  0, 158, 115;    % SnoLimits — bluish green
        204, 121, 167;    % UASWE     — reddish purple
        213,  94,   0] / 255;  % ParBal    — vermillion

% ========================================================================
% BOX POSITIONS  (clean integer-step scheme)
%   Year 1: positions 1, 2, 3   → centre 2,  separator at 4
%   Year 2: positions 5, 6, 7   → centre 6,  separator at 8
%   Year 3: positions 9, 10, 11 → centre 10
%   Gap of 1 blank unit between groups; separator at gap midpoint
% ========================================================================
n_models = numel(models);
n_years  = numel(years);
grp_step = n_models + 2;   % positions advance by this each year (3 boxes + 2 gap)

pos_all = zeros(1, n_models * n_years);
yr_ctr  = zeros(1, n_years);
sep_x   = zeros(1, n_years - 1);

for yy = 1:n_years
    base = (yy - 1) * grp_step;
    idx  = (yy - 1) * n_models + (1:n_models);
    pos_all(idx) = base + (1:n_models);
    yr_ctr(yy)   = base + (n_models + 1) / 2;   % midpoint of group
    if yy < n_years
        sep_x(yy) = base + n_models + (grp_step - n_models + 1) / 2;  % true midpoint of gap
    end
end

x_lo = pos_all(1)   - 1;
x_hi = pos_all(end) + 1;

% ========================================================================
% FIGURE
% ========================================================================
fig = figure('Units', 'inches', 'Position', [1 1 18 8]);
t   = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
t.OuterPosition = [0 0 0.88 1];

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
        boxplot(ax, all_vals, grp_vec, ...
            'Positions', pos_all, ...
            'Widths',    0.65,    ...
            'Whisker',   1.5,     ...
            'Symbol',    'k.');
        hold on

        % Suppress default x tick labels
        ax.XTickLabel = repmat({''}, 1, n_models * n_years);

        % --- Color boxes ------------------------------------------------
        % findobj returns boxes in reverse draw order, so last-drawn first.
        % Boxes are drawn model-by-model within each year:
        %   last box = ParBal (model 3), then UASWE (2), SnoLimits (1), repeat.
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
        % Year labels as XTick labels at the bottom
        ax.XTick          = yr_ctr;
        ax.XTickLabel     = cellstr(num2str(years(:)));
        ax.XTickLabelRotation = 0;
        ax.FontSize       = 10;
        ax.XAxis.FontSize = 11;
        ax.XAxis.FontWeight = 'bold';
        ax.Box            = 'on';
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
% SHARED LEGEND
% ========================================================================
ax_leg = axes('Position', [0.895 0.25 0.001 0.5], 'Visible', 'off');
hold(ax_leg, 'on');
h_leg = gobjects(n_models, 1);
for mm = 1:n_models
    h_leg(mm) = patch(ax_leg, NaN, NaN, clr(mm,:), ...
        'FaceAlpha', 0.55, 'EdgeColor', 'k', 'LineWidth', 0.8);
end
leg = legend(ax_leg, h_leg, labels, ...
    'FontSize',  12,   ...
    'Box',       'on', ...
    'Location',  'west');
leg.Title.String   = 'Dataset';
leg.Title.FontSize = 12;
leg.Title.FontWeight = 'bold';

% ========================================================================
% SAVE
% ========================================================================
% out_dir  = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/data_paper/dataset_comparisons';
% out_file = fullfile(out_dir, 'SWE_error_boxplots_years.png');
% exportgraphics(fig, out_file, 'Resolution', 200);
% fprintf('Saved: %s\n', out_file)