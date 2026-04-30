% ========================================================================
% calculate_flight_errors_sd.m
% J. Herbert
%
% Loops through all lidar validation files for each model, computes
% per-flight error metrics (RMSE, R2, bias), and saves a struct.
%
% Output: all_datasets_flight_errors_sd.mat
%   M.snolimits.CO.rmse, .r2, .bias, .date, .basin
%   M.uaswe.CO.rmse, ...
%   M.ucla.CO.rmse, ...
% ========================================================================
clear; clc;

% ========================================================================
% PATHS
% ========================================================================
base_path  = fileparts(fileparts(mfilename('fullpath')));

snolimits_path = fullfile(base_path,'data', 'SnoLimits');
uaswe_path     = fullfile(base_path,'data', 'UASWE');
ucla_path      = fullfile(base_path,'data','UCLA_SWE');
out_dir        = fullfile(base_path, 'data');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

regions    = {'CO', 'CA'};
domain_str = {'rocky', 'CA'};

% Field names in UASWE / UCLA comparison files
ua_lidar_var = 'aso_on_ua';
ua_pred_var  = 'ua_sd_clip';
uc_lidar_var = 'aso_on_ucla';
uc_pred_var  = 'ucla_sd_clip';

% ========================================================================
% INITIALIZE OUTPUT STRUCT
% ========================================================================
model_names = {'snolimits', 'uaswe', 'ucla'};
M = struct();
for mm = 1:numel(model_names)
    for rr = 1:numel(regions)
        M.(model_names{mm}).(regions{rr}).rmse  = [];
        M.(model_names{mm}).(regions{rr}).r2    = [];
        M.(model_names{mm}).(regions{rr}).bias  = [];
        M.(model_names{mm}).(regions{rr}).date  = [];
        M.(model_names{mm}).(regions{rr}).basin = {};
    end
end

% ========================================================================
% LOOP OVER REGIONS
% ========================================================================
for rr = 1:numel(regions)
    region = regions{rr};
    fprintf('\n======= %s =======\n', region)

    % ── Load SnoLimits ────────────────────────────────────────────────────
    sl_file = fullfile(snolimits_path, ...
        sprintf('%s_SD_500_IDW_pre2020.mat', domain_str{rr}));
    load(sl_file);
    rf_master = rf_out; clear rf_out;
    flts = unique(rf_master.file);

    % ── Load comparison file lists with full paths ────────────────────────
    orig_dir = pwd;
    cd(fullfile(uaswe_path, region)); ua_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
    cd(fullfile(ucla_path,  region)); uc_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
    cd(orig_dir);

    comp_models = {
        'uaswe', ua_names, ua_lidar_var, ua_pred_var, 1;
        'ucla',  uc_names, uc_lidar_var, uc_pred_var, 1;
    };

    % ── Loop over flights ─────────────────────────────────────────────────
    for ff = 1:numel(flts)
        idx    = flts(ff) == rf_master.file;
        rf_flt = rf_master(idx, :);

        fdate      = double(rf_flt.date(1));
        fbasin     = char(rf_flt.basin(1));
        flight_str = erase(char(rf_flt.file(1)), '.mat');

        fprintf('\n  Flight %d/%d: %s — %s\n', ff, numel(flts), fbasin, datestr(fdate, 'yyyy-mm-dd'))

        % ── SnoLimits ────────────────────────────────────────────────────
        lidar = rf_flt.lidar_SD(:);
        pred  = rf_flt.pred_SD(:);
        lidar(lidar < 0) = nan;
        valid = ~isnan(lidar) & ~isnan(pred);

        if sum(valid) >= 5
            [rmse, r2, ~, bias] = calc_ml_stats(lidar(valid), pred(valid));
            M.snolimits.(region).rmse  = [M.snolimits.(region).rmse;  rmse];
            M.snolimits.(region).r2    = [M.snolimits.(region).r2;    r2];
            M.snolimits.(region).bias  = [M.snolimits.(region).bias;  bias];
            M.snolimits.(region).date  = [M.snolimits.(region).date;  fdate];
            M.snolimits.(region).basin = [M.snolimits.(region).basin; {fbasin}];
            fprintf('    SnoLimits  RMSE=%.3f  R2=%.3f  Bias=%.3f\n', rmse, r2, bias)
        end

        % ── Comparison models ─────────────────────────────────────────────
        for cc = 1:size(comp_models, 1)
            mdl     = comp_models{cc, 1};
            names   = comp_models{cc, 2};
            ldr_var = comp_models{cc, 3};
            prd_var = comp_models{cc, 4};
            scale   = comp_models{cc, 5};

            match = find(contains(names, flight_str, 'IgnoreCase', true), 1);
            if isempty(match)
                fprintf('    %-10s no file match for "%s" — skipping\n', mdl, flight_str)
                continue
            end

            S = load(names{match});
            if ~isfield(S, ldr_var) || ~isfield(S, prd_var)
                error('Model "%s" file "%s" missing field.\nAvailable: %s', ...
                    mdl, names{match}, strjoin(fieldnames(S), ', '))
            end

            lidar = double(S.(ldr_var)(:));
            pred  = double(S.(prd_var)(:)) / scale;
            lidar(lidar < 0) = nan;
            valid = ~isnan(lidar) & ~isnan(pred);

            if sum(valid) < 5
                fprintf('    %-10s insufficient valid pts — skipping\n', mdl)
                continue
            end

            [rmse, r2, ~, bias] = calc_ml_stats(lidar(valid), pred(valid));
            M.(mdl).(region).rmse  = [M.(mdl).(region).rmse;  rmse];
            M.(mdl).(region).r2    = [M.(mdl).(region).r2;    r2];
            M.(mdl).(region).bias  = [M.(mdl).(region).bias;  bias];
            M.(mdl).(region).date  = [M.(mdl).(region).date;  fdate];
            M.(mdl).(region).basin = [M.(mdl).(region).basin; {fbasin}];
            fprintf('    %-10s RMSE=%.3f  R2=%.3f  Bias=%.3f\n', mdl, rmse, r2, bias)
        end
    end
end

% ========================================================================
% SAVE
% ========================================================================
out_file = fullfile(out_dir, 'all_datasets_flight_errors_sd.mat');
save(out_file, 'M');
fprintf('\nSaved: %s\n', out_file)

% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================
function names = get_names(path)
    if nargin < 1 || isempty(path)
        path = pwd;
    end
    cd(path)
    if exist('.DS_Store', 'file'), delete('.DS_Store'); end
    dircon = dir;
    names  = {dircon.name};
    names  = names(3:end)';
    flag   = true(1, length(names));
    for ii = 1:length(names)
        if strncmp(char(names(ii)), '._', 2)
            flag(ii) = false;
        end
    end
    names = names(flag);
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