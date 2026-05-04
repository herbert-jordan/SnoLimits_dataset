% =========================================================================
% PLOT_SCATTER_UCLA_VS_SNOLIMITS_CO_CA.M
% Scatter: UCLA vs SnoLimits for NSE and KGE
% Top row: Colorado Mar-Jun | Bottom row: California Mar-Jun
% =========================================================================
clear; clc;

cd(fileparts(mfilename('fullpath')));
cd ..
cd data

T_co = readtable('CO_nse_kge_marjun.csv');
T_ca = readtable('CA_nse_kge_marjun.csv');

% ── Style ─────────────────────────────────────────────────────────────────
clr_co = [213, 94,  0  ] / 255;   % CO — vermillion
clr_ca = [0,   158, 115] / 255;   % CA — bluish green
mk_sz  = 40;
alpha  = 0.6;

rows   = {'Colorado',   'California'};
tables = {T_co,          T_ca        };
colors = {clr_co,        clr_ca      };

metrics       = {'nse',  'kge' };
metric_labels = {'NSE',  'KGE' };

% ── Figure ────────────────────────────────────────────────────────────────
fig = figure('Units', 'inches', 'Position', [1 1 12 10]);
t   = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for rr = 1:2          % rows: CO, CA
    T   = tables{rr};
    clr = colors{rr};

    for mm = 1:2      % cols: NSE, KGE
        ax = nexttile((rr-1)*2 + mm);
        hold on

        sl_vals   = T.(['sl_'   metrics{mm}]);
        ucla_vals = T.(['ucla_' metrics{mm}]);

        sl_vals(sl_vals     < -1) = -1;
        ucla_vals(ucla_vals < -1) = -1;

        % --- scatter ---
        scatter(ax, ucla_vals, sl_vals, mk_sz, clr, 'filled', ...
            'MarkerFaceAlpha', alpha, 'MarkerEdgeColor', 'none');

        % --- 1:1 line ---
        ax_lim = [-1 1];
        plot(ax, ax_lim, ax_lim, 'k--', 'LineWidth', 1.2);

        % --- stats ---
        valid  = ~isnan(sl_vals) & ~isnan(ucla_vals);
        cc     = corrcoef(sl_vals(valid), ucla_vals(valid));
        r2     = cc(1,2)^2;

        % Bias: positive = SnoLimits higher (better)
        bias     = mean(sl_vals(valid)) - mean(ucla_vals(valid));
        med_sl   = median(sl_vals,   'omitnan');
        med_ucla = median(ucla_vals, 'omitnan');

        txt = sprintf('Median:\nSnoLimits: %.2f\nUCLA:  %.2f\n\nR²: %.2f\nBias: %.2f', ...
                      med_sl, med_ucla, r2, bias);
        text(ax, 0.47, -0.4, txt, ...
            'FontSize',          10,    ...
            'VerticalAlignment', 'top', ...
            'FontWeight',        'bold');

        % --- formatting ---
        xlim(ax, ax_lim);  ylim(ax, ax_lim);
        axis(ax, 'square');
        ax.Box      = 'on';
        ax.FontSize = 11;
        ax.GridAlpha = 0.25;

        if mm == 1
            ylabel(ax, {rows{rr}, 'SnoLimits'}, ...
                'FontSize', 12, 'FontWeight', 'bold')
        end
        if rr == 1
            title(ax, metric_labels{mm}, 'FontSize', 13, 'FontWeight', 'bold')
        end
        xlabel(ax, 'UCLA SWE', 'FontSize', 12, 'FontWeight', 'bold')

        hold off
    end
end

% ── Save ──────────────────────────────────────────────────────────────────
out_dir  = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML';
out_file = fullfile(out_dir, 'scatter_ucla_vs_snolimits_CO_CA_marjun.png');
exportgraphics(fig, out_file, 'Resolution', 200);
fprintf('Saved: %s\n', out_file);