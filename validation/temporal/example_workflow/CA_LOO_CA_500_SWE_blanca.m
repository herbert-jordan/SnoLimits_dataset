% ==============================================================
% LOO_IDW_RADIUS_SWE_USING_TD_SITE_WY2001_2025_NEW_MODEL.M
%
% Uses per-site tables:
%   td_site_###_<name>_WYxxxx_yyyy.mat  (table: td_site)
%
% For each TEST SNOTEL site:
%   1) Load td_site for TEST -> master timeline + true SWE
%   2) Find neighbor sites within radius
%   3) For each neighbor site:
%        - load neighbor td_site
%        - load site-specific SWE RF model if it exists (by index in filename),
%          else use regional SWE model
%        - build X in EXACT predictor order via mdl.PredictorNames
%        - predict delta SWE and add neighbor SWE baseline (SWE)
%   4) Day-by-day IDW combine:
%        A) swe_idw         = IDW of model-predicted SWE
%        B) swe_idw_snotel  = IDW of neighbor SNOTEL SWE (raw values)
%      Also saves per-day contributors + weights:
%        contrib_site_inds, contrib_swe_snotel, contrib_swe_model, contrib_w
%   5) Save output table
%
% Notes:
%   - Uses sno_tbl.XX/YY (meters) for distance
%   - Model predictor name "Snotel SD" is WRONG; it is neighbor SNOTEL SWE baseline
%   - Model predictor "fSCA 7 day" is mapped to td_site.fsca_8day (name mismatch ok)
%   - P and T are NORMALS (static): use first value / static and replicate
%   - snow_persistence + forest fractions are STATIC and replicated
%
% J. Herbert | big jorbo edition
% ==============================================================

% -------------------------------------------------------------------------
% USER SETTINGS
% -------------------------------------------------------------------------
wys = 2001:2025;

radius_km = 50;
radius_m  = radius_km * 1000;

p_idw = 2;
min_neighbors = 1;

% test_site_inds = 1:155;   % <-- set as needed

% -------------------------------------------------------------------------
% PATHS
% -------------------------------------------------------------------------
dynamic_dir = '/projects/johe7316/ML/LOO_snotel/CA/SWE_500/dynamic_data';
models_dir  = '/pl/active/smyth_da/Herbert_ML/CA_domain/SWE_workflow/RF_models/combo';
regional_model_file = '/pl/active/smyth_da/Herbert_ML/CA_domain/SWE_workflow/RF_models/reg_model_CA_SWE_500.mat';

load CA_snotel_physio.mat   % sno_tbl

out_dir = '/projects/johe7316/ML/LOO_snotel/CA/SWE_500/save';
if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

% -------------------------------------------------------------------------
% MODELS
% -------------------------------------------------------------------------
model_path_map = build_model_path_map(models_dir);

if ~isfile(regional_model_file)
    error('Regional SWE model file not found: %s', regional_model_file);
end
mdl_regional = load_model_object(regional_model_file);

% -------------------------------------------------------------------------
% MAIN LOOP
% -------------------------------------------------------------------------
n_sites = height(sno_tbl);

for ii = test_site_inds

    test_site_name = string(sno_tbl.site(ii));

    fprintf('\n====================================================\n');
    fprintf('TEST SITE: %d/%d | %d (%s)\n', ii, n_sites, ii, test_site_name);
    fprintf('====================================================\n');

    % ---------------------------------------------------------------------
    % Load TEST td_site (master timeline + truth)
    % ---------------------------------------------------------------------
    test_file = find_td_site_file(dynamic_dir, ii);
    if isempty(test_file)
        fprintf('  WARNING: no td_site file found for test site -> skipping\n');
        continue
    end

    S = load(test_file, 'td_site');
    td_test = S.td_site;
    clear S

    keep_test = td_test.wy >= wys(1) & td_test.wy <= wys(end);
    td_test = td_test(keep_test,:);

    if isempty(td_test)
        fprintf('  WARNING: test td_site is empty after WY filter -> skipping\n');
        continue
    end

    % Master timeline (based on test site table)
    wy_master   = td_test.wy;
    dowy_master = td_test.dowy;

    % True SWE at test site
    swe_true_master = td_test.snotel_SWE;

    % Date vector
    date_master = water_year_dowy_to_datetime(wy_master, dowy_master);

    % Key for fast joins
    key_master = make_key(wy_master, dowy_master);
    n_master = numel(key_master);

    % ---------------------------------------------------------------------
    % Neighbor search (within radius, excluding itself)
    % ---------------------------------------------------------------------
    dx = sno_tbl.XX - sno_tbl.XX(ii);
    dy = sno_tbl.YY - sno_tbl.YY(ii);
    d_all = sqrt(dx.^2 + dy.^2);

    neighbor_inds = find(isfinite(d_all) & d_all > 0 & d_all <= radius_m);

    if numel(neighbor_inds) < min_neighbors
        fprintf('  WARNING: < %d neighbors within %d km -> skipping\n', min_neighbors, radius_km);
        continue
    end

    fprintf('  Neighbors within %d km: %d\n', radius_km, numel(neighbor_inds));

    % ---------------------------------------------------------------------
    % Preallocate neighbor predictions + aligned neighbor SWE
    % ---------------------------------------------------------------------
    n_neighbors = numel(neighbor_inds);

    pred_swe_all = NaN(n_master, n_neighbors);   % model-pred SWE at test site
    swe_n_all    = NaN(n_master, n_neighbors);   % neighbor SNOTEL SWE aligned to master
    dists        = NaN(n_neighbors, 1);

    % ---------------------------------------------------------------------
    % Cache TEST-site static predictors (target location)
    % ---------------------------------------------------------------------
    td_test_static.fveg      = get_static_value(td_test, sno_tbl, ii, 'fveg');
    td_test_static.elev      = get_static_value(td_test, sno_tbl, ii, 'elev');
    td_test_static.northness = get_static_value(td_test, sno_tbl, ii, 'northness');
    td_test_static.eastness  = get_static_value(td_test, sno_tbl, ii, 'eastness');
    td_test_static.slope     = get_static_value(td_test, sno_tbl, ii, 'slope');
    td_test_static.TPI       = get_static_value(td_test, sno_tbl, ii, 'TPI');
    td_test_static.Sx        = get_static_value(td_test, sno_tbl, ii, 'Sx');

    % Static normals (P,T) + persistence + forest fractions
    % (stored in td_site and/or sno_tbl; treat as scalars)
    td_test_static.P                 = get_static_value(td_test, sno_tbl, ii, 'P');
    td_test_static.T                 = get_static_value(td_test, sno_tbl, ii, 'T');
    td_test_static.snow_persistence  = get_static_value(td_test, sno_tbl, ii, 'snow_persistence');

    td_test_static.evergreen_frac    = get_static_value(td_test, sno_tbl, ii, 'evergreen_frac');
    td_test_static.mixed_forest_frac = get_static_value(td_test, sno_tbl, ii, 'mixed_forest_frac');
    td_test_static.deciduous_frac    = get_static_value(td_test, sno_tbl, ii, 'deciduous_frac');

    % Test-site fSCA used for the physical-zero rule (dynamic)
    fsca_test_master = get_series_value(td_test, 'fSCA_8day', n_master);

    % ---------------------------------------------------------------------
    % Loop over neighbors (model sites)
    % ---------------------------------------------------------------------
    for jj = 1:n_neighbors

        mdl_ind = neighbor_inds(jj);
        mdl_site_name = string(sno_tbl.site(mdl_ind));

        dists(jj) = d_all(mdl_ind);

        % ---- load neighbor td_site
        mdl_file = find_td_site_file(dynamic_dir, mdl_ind);
        if isempty(mdl_file)
            fprintf('  Neighbor %d/%d: %d (%s) | missing td_site -> skip\n', ...
                jj, n_neighbors, mdl_ind, mdl_site_name);
            continue
        end

        S = load(mdl_file, 'td_site');
        td_mdl = S.td_site;
        clear S

        keep_mdl = td_mdl.wy >= wys(1) & td_mdl.wy <= wys(end);
        td_mdl = td_mdl(keep_mdl,:);

        if isempty(td_mdl)
            fprintf('  Neighbor %d/%d: %d (%s) | empty after WY filter -> skip\n', ...
                jj, n_neighbors, mdl_ind, mdl_site_name);
            continue
        end

        % ---- choose model
        if isKey(model_path_map, mdl_ind)
            model_file = model_path_map(mdl_ind);
            mdl = load_model_object(model_file);
            mdl_tag = 'site_specific';
        else
            mdl = mdl_regional;
            mdl_tag = 'regional';
        end

        fprintf('  Neighbor %d/%d: %d (%s) | dist=%.1f km | model=%s\n', ...
            jj, n_neighbors, mdl_ind, mdl_site_name, dists(jj)/1000, mdl_tag);

        % -----------------------------------------------------------------
        % Align neighbor series to master timeline via (wy,dowy)
        % -----------------------------------------------------------------
        key_mdl = make_key(td_mdl.wy, td_mdl.dowy);
        [tf, loc] = ismember(key_master, key_mdl);

        swe_n             = NaN(n_master, 1);
        fsca_n            = NaN(n_master, 1);
        fsca_8day_n       = NaN(n_master, 1);
        med_swe_n         = NaN(n_master, 1);
        day_to_med_melt_n = NaN(n_master, 1);

        % Baseline neighbor SWE
        if ismember('snotel_SWE', td_mdl.Properties.VariableNames)
            swe_n(tf) = td_mdl.snotel_SWE(loc(tf));
        elseif ismember('swe', td_mdl.Properties.VariableNames)   % backward compat
            swe_n(tf) = td_mdl.swe(loc(tf));
        end

        % Neighbor dynamic predictors
        if ismember('fSCA', td_mdl.Properties.VariableNames)
            fsca_n(tf) = td_mdl.fSCA(loc(tf));
        end
        if ismember('fSCA_8day', td_mdl.Properties.VariableNames)
            fsca_8day_n(tf) = td_mdl.fSCA_8day(loc(tf));
        else
            fsca_8day_n = movmean(fsca_n, [7 0], 'omitnan');
        end
        if ismember('med_swe', td_mdl.Properties.VariableNames)
            med_swe_n(tf) = td_mdl.med_swe(loc(tf));
        end
        if ismember('day_to_med_melt', td_mdl.Properties.VariableNames)
            day_to_med_melt_n(tf) = td_mdl.day_to_med_melt(loc(tf));
        end

        % Save aligned neighbor SWE for later "raw SNOTEL IDW"
        swe_n_all(:, jj) = swe_n;

        % -----------------------------------------------------------------
        % Build X by matching mdl.PredictorNames (new model)
        % -----------------------------------------------------------------
        X_tbl = build_predictor_table( ...
            td_test_static, ...
            td_mdl, mdl_ind, ...
            dowy_master, dists(jj), ...
            swe_n, fsca_n, fsca_8day_n, med_swe_n, day_to_med_melt_n, ...
            sno_tbl);

        X = table_to_X_in_model_order(X_tbl, mdl);

        % -----------------------------------------------------------------
        % Valid mask (must cover what the model uses + baseline SWE)
        % -----------------------------------------------------------------
        valid = isfinite(swe_n) & (swe_n >= 0) & isfinite(dowy_master) & isfinite(dists(jj));
        valid = valid & isfinite(fsca_n) & isfinite(fsca_8day_n);
        valid = valid & isfinite(day_to_med_melt_n) & isfinite(med_swe_n);

        % Require static predictors (normals/fractions)
        valid = valid & isfinite(X_tbl.P) & isfinite(X_tbl.T);
        valid = valid & isfinite(X_tbl.snow_persistence);
        valid = valid & isfinite(X_tbl.evergreen) & isfinite(X_tbl.mixed_forest) & isfinite(X_tbl.deciduous);

        if ~any(valid)
            continue
        end

        % -----------------------------------------------------------------
        % Predict delta SWE + add baseline SWE
        % -----------------------------------------------------------------
        pred_swe = NaN(n_master, 1);

        temp_out = predict(mdl, X(valid,:));
        pred_tmp = temp_out + swe_n(valid);
        pred_tmp(pred_tmp < 0) = 0;

        % Enforce physical zero condition:
        fsca_test_v = fsca_test_master(valid);
        swe_n_v     = swe_n(valid);

        zero_mask = (fsca_test_v == 0);
        pred_tmp(zero_mask) = 0;

        pred_swe(valid) = pred_tmp;
        pred_swe_all(:, jj) = pred_swe;

    end % neighbor loop

    % ---------------------------------------------------------------------
    % IDW combine day-by-day
    % ---------------------------------------------------------------------
    swe_idw = NaN(n_master, 1);
    swe_idw_snotel = NaN(n_master, 1);

    contrib_site_inds   = cell(n_master, 1);
    contrib_swe_snotel  = cell(n_master, 1);
    contrib_swe_model   = cell(n_master, 1);
    contrib_w           = cell(n_master, 1);

    for t = 1:n_master

        % -----------------------------
        % A) IDW of model-predicted SWE
        % -----------------------------
        pred_t = pred_swe_all(t, :);
        good_pred = isfinite(pred_t) & isfinite(dists');

        if sum(good_pred) >= min_neighbors

            d_use = dists(good_pred);
            p_use = pred_t(good_pred);

            d_use = d_use(:);
            p_use = p_use(:);

            z = (d_use == 0);
            if any(z)
                z1 = find(z, 1, 'first');
                w_use = zeros(size(d_use));
                w_use(z1) = 1;

                swe_idw(t) = p_use(z1);
            else
                w_use = 1 ./ (d_use .^ p_idw);
                w_use = w_use ./ sum(w_use);

                swe_idw(t) = sum(w_use .* p_use);
            end

            contrib_site_inds{t}  = neighbor_inds(good_pred);
            contrib_swe_snotel{t} = swe_n_all(t, good_pred);
            contrib_swe_model{t}  = pred_t(good_pred);
            contrib_w{t}          = w_use(:).';

        else
            contrib_site_inds{t}  = [];
            contrib_swe_snotel{t} = [];
            contrib_swe_model{t}  = [];
            contrib_w{t}          = [];
        end

        % -----------------------------
        % B) IDW of neighbor SNOTEL SWE
        % -----------------------------
        swe_t = swe_n_all(t, :);
        good_swe = isfinite(swe_t) & (swe_t >= 0) & isfinite(dists');

        if sum(good_swe) >= min_neighbors

            d_use = dists(good_swe);
            s_use = swe_t(good_swe);

            d_use = d_use(:);
            s_use = s_use(:);

            z = (d_use == 0);
            if any(z)
                swe_idw_snotel(t) = s_use(find(z, 1, 'first'));
            else
                w = 1 ./ (d_use .^ p_idw);
                w = w ./ sum(w);
                swe_idw_snotel(t) = sum(w .* s_use);
            end
        end

    end

    % ---------------------------------------------------------------------
    % Output + save
    % ---------------------------------------------------------------------
    out_tbl = table();
    out_tbl.site_ind = repmat(ii, n_master, 1);
    out_tbl.site = repmat(test_site_name, n_master, 1);

    out_tbl.date = date_master;
    out_tbl.wy = wy_master;
    out_tbl.dowy = dowy_master;

    out_tbl.swe_idw = swe_idw;
    out_tbl.swe_idw_snotel = swe_idw_snotel;

    out_tbl.swe_true = swe_true_master;

    out_tbl.contrib_site_inds  = contrib_site_inds;
    out_tbl.contrib_swe_snotel = contrib_swe_snotel;
    out_tbl.contrib_swe_model  = contrib_swe_model;
    out_tbl.contrib_w          = contrib_w;

    safe_site_name = regexprep(char(test_site_name), '[^a-zA-Z0-9_]', '_');
    out_file = fullfile(out_dir, ['LOO_RADIUS50km_SWE_td_' sprintf('%03d', ii) '_' safe_site_name ...
        '_WY' num2str(wys(1)) '_' num2str(wys(end)) '.mat']);

    save(out_file, 'out_tbl', '-v7.3');

    fprintf('  Saved: %s\n', out_file);

end % test loop

fprintf('\nDONE. Outputs saved to:\n%s\n', out_dir);

% =====================================================================
% Build predictor table (canonical variable names)
%   - Uses ONLY td_test_static for static normals/fractions/persistence
%   - Uses neighbor-aligned dynamic series for time-varying predictors
% =====================================================================
function X_tbl = build_predictor_table( ...
    td_test_static, ...
    td_mdl, mdl_ind, ...
    dowy_master, dist_m, ...
    swe_n, fsca_n, fsca_8day_n, med_swe_n, day_to_med_melt_n, ...
    sno_tbl)

n = numel(dowy_master);

% ---- Static (replicated)
P_test          = repmat(td_test_static.P, n, 1);
T_test          = repmat(td_test_static.T, n, 1);
snow_persist    = repmat(td_test_static.snow_persistence, n, 1);

evergreen       = repmat(td_test_static.evergreen_frac, n, 1);
mixed_forest    = repmat(td_test_static.mixed_forest_frac, n, 1);
deciduous       = repmat(td_test_static.deciduous_frac, n, 1);

% ---- Physio (TEST) + dist
veg_col   = repmat(td_test_static.fveg, n, 1);
elev_col  = repmat(td_test_static.elev, n, 1);
north_col = repmat(td_test_static.northness, n, 1);
east_col  = repmat(td_test_static.eastness, n, 1);
slope_col = repmat(td_test_static.slope, n, 1);
TPI_col   = repmat(td_test_static.TPI, n, 1);
Sx_col    = repmat(td_test_static.Sx, n, 1);
dist_col  = repmat(dist_m, n, 1);

% ---- Relative physio (TEST - NEIGHBOR)
mdl_fveg = get_static_value(td_mdl, sno_tbl, mdl_ind, 'fveg');
mdl_elev = get_static_value(td_mdl, sno_tbl, mdl_ind, 'elev');

rel_veg  = veg_col  - repmat(mdl_fveg, n, 1);
rel_elev = elev_col - repmat(mdl_elev, n, 1);

% ---- Derived
dif_from_med_swe = swe_n - med_swe_n;

% ---- Assemble canonical predictor variables
X_tbl = table();

X_tbl.Veg = veg_col;
X_tbl.Elev = elev_col;
X_tbl.Northness = north_col;
X_tbl.Eastness  = east_col;
X_tbl.slope     = slope_col;
X_tbl.TPI       = TPI_col;
X_tbl.TPI30     = TPI_col;   % duplicate alias so either predictor name works

X_tbl.Sx        = Sx_col;

X_tbl.Dist = dist_col;

X_tbl.P = P_test;
X_tbl.T = T_test;

X_tbl.snow_persistence = snow_persist;

X_tbl.evergreen    = evergreen;
X_tbl.mixed_forest = mixed_forest;
X_tbl.deciduous    = deciduous;

X_tbl.DOWY = double(dowy_master(:));
X_tbl.days_to_med_melt = day_to_med_melt_n;
X_tbl.dif_from_med_SWE = dif_from_med_swe;
X_tbl.fSCA = fsca_n;

% stored var is fsca_8day but model label is "fSCA 7 day"
X_tbl.fSCA_8day = fsca_8day_n;

% model label "Snotel SD" is wrong; it is SWE baseline
X_tbl.Snotel_SWE = swe_n;

X_tbl.Rel_Veg  = rel_veg;
X_tbl.Rel_Elev = rel_elev;

end

% =====================================================================
% Convert predictor table into numeric matrix X in mdl.PredictorNames order
% =====================================================================
function X = table_to_X_in_model_order(X_tbl, mdl)

pred_names = mdl.PredictorNames;

norm = @(s) regexprep(lower(string(s)), '[^a-z0-9]+', '');

tbl_names = string(X_tbl.Properties.VariableNames);

tbl_map = containers.Map('KeyType','char','ValueType','char');
for k = 1:numel(tbl_names)
    tbl_map(char(norm(tbl_names(k)))) = char(tbl_names(k));
end

use_vars = strings(numel(pred_names), 1);

for k = 1:numel(pred_names)
    p = string(pred_names{k});
    p_norm = char(norm(p));

    % Map model display labels -> canonical variable names
    if strcmp(p_norm, char(norm("veg"))) || strcmp(p_norm, char(norm("veg.")))
        p_norm = char(norm("Veg"));
    elseif strcmp(p_norm, char(norm("elev"))) || strcmp(p_norm, char(norm("elev.")))
        p_norm = char(norm("Elev"));
    elseif strcmp(p_norm, char(norm("tpi30"))) || strcmp(p_norm, char(norm("tpi 30")))
        p_norm = char(norm("TPI30"));
    elseif strcmp(p_norm, char(norm("dist"))) || strcmp(p_norm, char(norm("dist.")))
        p_norm = char(norm("Dist"));
    elseif strcmp(p_norm, char(norm("snowpersistence"))) || strcmp(p_norm, char(norm("snow persistence")))
        p_norm = char(norm("snow_persistence"));
    elseif strcmp(p_norm, char(norm("days to med melt"))) || strcmp(p_norm, char(norm("days_to_med_melt")))
        p_norm = char(norm("days_to_med_melt"));
    elseif strcmp(p_norm, char(norm("dif from med swe"))) || strcmp(p_norm, char(norm("dif_from_med_swe")))
        p_norm = char(norm("dif_from_med_SWE"));
    elseif strcmp(p_norm, char(norm("fsca 7 day"))) || strcmp(p_norm, char(norm("fsca7day")))
        p_norm = char(norm("fSCA_8day"));
    elseif strcmp(p_norm, char(norm("snotel sd"))) || strcmp(p_norm, char(norm("snotelsd")))
        p_norm = char(norm("Snotel_SWE"));
    elseif strcmp(p_norm, char(norm("rel veg"))) || strcmp(p_norm, char(norm("rel. veg."))) || strcmp(p_norm, char(norm("rel. veg")))
        p_norm = char(norm("Rel_Veg"));
    elseif strcmp(p_norm, char(norm("rel elev"))) || strcmp(p_norm, char(norm("rel. elev"))) || strcmp(p_norm, char(norm("rel. elev.")))
        p_norm = char(norm("Rel_Elev"));
    elseif strcmp(p_norm, char(norm("mixed forest"))) || strcmp(p_norm, char(norm("mixedforest")))
        p_norm = char(norm("mixed_forest"));
    end

    if isKey(tbl_map, p_norm)
        use_vars(k) = string(tbl_map(p_norm));
    else
        warning('Missing predictor for model: %s (normalized: %s). Filling with NaN.', pred_names{k}, p_norm);
        X_tbl.(sprintf('missing_%02d', k)) = NaN(height(X_tbl), 1);
        use_vars(k) = string(X_tbl.Properties.VariableNames{end});
    end
end

X = table2array(X_tbl(:, use_vars));

end

% =====================================================================
% Helper: find td_site file for a given site index
% =====================================================================
function td_file = find_td_site_file(dynamic_dir, site_ind)

pat = fullfile(dynamic_dir, ['td_site_' sprintf('%03d', site_ind) '_*.mat']);
D = dir(pat);

if isempty(D)
    td_file = '';
    return
end

[~, ix] = max([D.datenum]);
td_file = fullfile(dynamic_dir, D(ix).name);

end

% =====================================================================
% Helper: build model map from filenames in models_dir
%   expects filenames containing _<index>_ and ending with RF_model_500_SWE.mat
% =====================================================================
function model_path_map = build_model_path_map(models_dir)

model_path_map = containers.Map('KeyType','double','ValueType','char');

D = dir(fullfile(models_dir, '*RF_model_500_SWE.mat'));
if isempty(D)
    warning('No SWE model files found in: %s', models_dir);
    return
end

for k = 1:numel(D)
    fname = D(k).name;

    tok = regexp(fname, '_(\d+)_', 'tokens', 'once');
    if isempty(tok)
        continue
    end

    ind = str2double(tok{1});
    if ~isfinite(ind)
        continue
    end

    model_path_map(ind) = fullfile(models_dir, fname);
end

end

% =====================================================================
% Helper: load model object (TreeBagger or any object with predict())
% =====================================================================
function mdl = load_model_object(model_file)

S = load(model_file);

if isfield(S,'mdl')
    mdl = S.mdl;
    return
end

fns = fieldnames(S);
for k = 1:numel(fns)
    candidate = S.(fns{k});
    try
        if isa(candidate,'TreeBagger') || isa(candidate,'CompactTreeBagger')
            mdl = candidate;
            return
        end
    catch
    end
    try
        if isobject(candidate) && any(strcmp(methods(candidate),'predict'))
            mdl = candidate;
            return
        end
    catch
    end
end

error('No model with predict() found in %s', model_file);

end

% =====================================================================
% Helper: convert WY + DOWY to datetime (WY starts Oct 1 previous year)
% =====================================================================
function dt = water_year_dowy_to_datetime(wy_vec, dowy_vec)

wy_vec = double(wy_vec(:));
dowy_vec = double(dowy_vec(:));

n = numel(wy_vec);
dt = NaT(n, 1);

for i = 1:n
    wy = wy_vec(i);
    d = dowy_vec(i);

    if ~isfinite(wy) || ~isfinite(d) || d < 1
        dt(i) = NaT;
        continue
    end

    start_date = datetime(wy-1, 10, 1);
    dt(i) = start_date + days(d - 1);
end

end

% =====================================================================
% Helper: integer key for joining on (wy, dowy)
% =====================================================================
function key = make_key(wy_vec, dowy_vec)

wy_vec = double(wy_vec(:));
dowy_vec = double(dowy_vec(:));

key = wy_vec .* 1000 + dowy_vec;

end

% =====================================================================
% Helper: get series column from table, else NaN(n,1)
% =====================================================================
function x = get_series_value(T, var_name, n)

x = NaN(n, 1);

if istable(T) && ismember(var_name, T.Properties.VariableNames)
    v = T.(var_name);
    if numel(v) == n
        x = v(:);
    else
        x(1:min(n,numel(v))) = v(1:min(n,numel(v)));
    end
end

end

% =====================================================================
% Helper: get static value from td_site (first row) else sno_tbl else NaN
% =====================================================================
function v = get_static_value(td_site, sno_tbl, ind, var_name)

v = NaN;

if istable(td_site) && ismember(var_name, td_site.Properties.VariableNames)
    tmp = td_site.(var_name);
    if ~isempty(tmp)
        v = tmp(1);
        return
    end
end

if istable(sno_tbl) && ismember(var_name, sno_tbl.Properties.VariableNames)
    tmp = sno_tbl.(var_name);
    if ~isempty(tmp) && ind <= numel(tmp)
        v = tmp(ind);
        return
    end
end

end
