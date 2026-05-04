% =========================================================================
% PLOT_PEAK_SWE_2x2.M
% 2x2 density scatter of peak SWE
% Row 1: Colorado (SnoLimits | UCLA SWE)
% Row 2: California (SnoLimits | UCLA SWE)
% =========================================================================
clear; clc;


cd(fileparts(mfilename('fullpath')));
cd ..
cd data

load peak_swe_CO.mat   % loads out_co
load peak_swe_CA.mat   % loads out_ca

% ── Settings ──────────────────────────────────────────────────────────────
nbins   = 100;
ax_max  = 1.8;
edges_x = linspace(0, ax_max, nbins+1);
edges_y = linspace(0, ax_max, nbins+1);

% ── Layout ────────────────────────────────────────────────────────────────
% {out, x_field, y_field, row_label, col_label}
panels = {
    out_co, 'tru_peak_swe', 'est_peak_swe',  'Colorado',    'SnoLimits';
    out_co, 'tru_peak_swe', 'ucla_peak_swe', 'Colorado',    'UCLA SWE';
    out_ca, 'tru_peak_swe', 'est_peak_swe',  'California',  'SnoLimits';
    out_ca, 'tru_peak_swe', 'ucla_peak_swe', 'California',  'UCLA SWE';
};

f = figure;
f.Position = [50 50 1000 900];
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for pp = 1:4

    out     = panels{pp, 1};
    x_field = panels{pp, 2};
    y_field = panels{pp, 3};
    region  = panels{pp, 4};
    model   = panels{pp, 5};

    xv_all = out.(x_field)(:);
    yv_all = out.(y_field)(:);

    valid = ~isnan(xv_all) & ~isnan(yv_all);
    xv    = xv_all(valid);
    yv    = yv_all(valid);

    % --- density ---
    N  = histcounts2(xv, yv, edges_x, edges_y);
    [~, xi] = histc(xv, edges_x);
    [~, yi] = histc(yv, edges_y);
    xi = min(max(xi, 1), nbins);
    yi = min(max(yi, 1), nbins);
    density = double(N(sub2ind(size(N), xi, yi)));
    [density_sorted, idx] = sort(density);

    % --- plot ---
    ax = nexttile(pp);
    scatter(ax, xv(idx), yv(idx), 12, density_sorted, 'filled');
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = 'Density';
    hold(ax, 'on');
    plot(ax, [0 ax_max], [0 ax_max], '--k', 'LineWidth', 2);
    hold(ax, 'off');

    xlim(ax, [0 ax_max]); ylim(ax, [0 ax_max]);
    axis(ax, 'square'); grid(ax, 'off');
    ax.FontSize = 11;
    ax.Box = 'on';

    xlabel(ax, 'Peak SWE: snow station (m)',          'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax, ['Peak SWE: ' model ' (m)'],     'FontSize', 12, 'FontWeight', 'bold');
    title(ax,  [region ' — ' model],             'FontSize', 13, 'FontWeight', 'bold');

    % --- stats ---
    [RMSE, R2, ~, Rbias] = calc_ml_stats(xv_all, yv_all);
    text(ax, 0.05, ax_max - 0.05, ...
        sprintf('RMSE = %.2f\nR^2 = %.2f\nRbias = %.2f', RMSE, R2, Rbias), ...
        'FontSize', 11, 'FontWeight', 'bold', ...
        'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k');

end

% ── Save ──────────────────────────────────────────────────────────────────
out_dir  = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML';
out_file = fullfile(out_dir, 'peak_swe_2x2.png');
exportgraphics(f, out_file, 'Resolution', 200);
fprintf('Saved: %s\n', out_file);