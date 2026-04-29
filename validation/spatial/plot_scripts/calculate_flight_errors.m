% ========================================================================
% calculate_flight_errors.m
% J. Herbert
%
% Loops through all lidar validation files for each model, computes
% per-flight error metrics (RMSE, R2, bias), and saves a struct.
%
% Output: all_models_flight_errors_struct.mat
%   M.snolimits.CO.rmse, .r2, .bias, .date, .basin
%   M.uaswe.CO.rmse, ...
%   M.parbal.CO.rmse, ...
%   M.ucla.CO.rmse, ...
% ========================================================================
clear; clc;

% ========================================================================
% PATHS
% ========================================================================
base_path  = fileparts(fileparts(mfilename('fullpath')));

snolimits_path = fullfile(base_path,'data', 'SnoLimits');
parbal_path    = fullfile(base_path,'data', 'ParBal');
uaswe_path     = fullfile(base_path,'data', 'UASWE');
ucla_path      = fullfile(base_path,'data', 'UCLA_SWE');
out_dir        = fullfile(base_path,'data');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

regions    = {'CO', 'CA'};
domain_str = {'rocky', 'CA'};   % matches SnoLimits filename convention

% Field names in ParBal / UASWE / UCLA comparison files
pb_lidar_var  = 'aso_on_parbal';
pb_pred_var   = 'parbal_swe_clip';   % divide by 1000 — stored in mm
ua_lidar_var  = 'aso_on_ua';
ua_pred_var   = 'ua_swe_clip';
uc_lidar_var  = 'aso_on_ucla';       % update if different
uc_pred_var   = 'ucla_swe_clip';     % update if different

% ========================================================================
% INITIALIZE OUTPUT STRUCT
% ========================================================================
model_names = {'snolimits', 'uaswe', 'parbal', 'ucla'};
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

    % ── SnoLimits ────────────────────────────────────────────────────────
    fprintf('Processing SnoLimits...\n')
    sl_file = fullfile(snolimits_path, ...
        sprintf('%s_SWE_500_IDW_pre2020.mat', domain_str{rr}));
    load(sl_file);
    rf_master = rf_out; clear rf_out;
    flts = unique(rf_master.file);

    for ff = 1:numel(flts)
        idx    = flts(ff) == rf_master.file;
        rf_flt = rf_master(idx, :);

        lidar = rf_flt.lidar_SWE(:);
        pred  = rf_flt.pred_SWE(:);
        lidar(lidar < 0) = nan;

        valid = ~isnan(lidar) & ~isnan(pred);
        if sum(valid) < 5, continue; end

        [rmse, r2, ~, bias] = calc_ml_stats(lidar(valid), pred(valid));

        M.snolimits.(region).rmse  = [M.snolimits.(region).rmse;  rmse];
        M.snolimits.(region).r2    = [M.snolimits.(region).r2;    r2];
        M.snolimits.(region).bias  = [M.snolimits.(region).bias;  bias];
        M.snolimits.(region).date  = [M.snolimits.(region).date;  double(rf_flt.date(1))];
        M.snolimits.(region).basin = [M.snolimits.(region).basin; {char(rf_flt.basin(1))}];

        fprintf('  SL  %s — %s  RMSE=%.3f  R2=%.3f  Bias=%.3f\n', ...
            char(rf_flt.basin(1)), datestr(double(rf_flt.date(1)), 'yyyy-mm-dd'), rmse, r2, bias)
    end

% ── Load comparison file lists ────────────────────────────────────────
    orig_dir = pwd;
    cd(fullfile(uaswe_path,  region)); ua_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
    cd(fullfile(parbal_path, region)); pb_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
    cd(fullfile(ucla_path,   region)); uc_names = cellfun(@(f) fullfile(pwd,f), get_names, 'UniformOutput', false);
    cd(orig_dir);

    comp_models = {
        'uaswe',  ua_names, ua_lidar_var, ua_pred_var,  1;
        'parbal', pb_names, pb_lidar_var, pb_pred_var,  1000;
        'ucla',   uc_names, uc_lidar_var, uc_pred_var,  1;
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
        lidar = rf_flt.lidar_SWE(:);
        pred  = rf_flt.pred_SWE(:);
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
out_file = fullfile(out_dir, 'all_datasets_flight_errors.mat');
save(out_file, 'M');
fprintf('\nSaved: %s\n', out_file)


% this function will retrieve the names of all the files in a directory 
function names = get_names(path)

    % if no input provided, use the current directory
    if nargin < 1 || isempty(path)
        path = pwd;
    end

    cd(path)

    if exist('.DS_Store','file')   % fixed capitalization (Macs use .DS_Store)
        delete('.DS_Store')
    end  

    dircon = dir; 
    names = {dircon.name}; 
    names = names(3:end); % removes '.' and '..'

    names = names';

    % get rid of meta file names from SSD disk
    flag = true(1,length(names));
    for ii = 1:length(names)
        temp = char(names(ii));
        if strncmp(temp,'._',2)
            flag(ii) = false;
        end
    end

    names = names(flag);

end
