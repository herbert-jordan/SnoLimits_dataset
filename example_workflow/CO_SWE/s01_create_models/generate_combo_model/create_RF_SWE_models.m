

% create an RF model for each snotel site which has lidar data. The table
% 'snotel_basin_pairs' contains each snotel site and its corresponding
% basin

% the command file will define which snotel site to run. The script will
% then open the training data for the corresponding basin. It will then
% delete all other snotel sites from the training data. 

% The script will also load the subsampled regional training data. Deleting
% all data from the snotel's basin prior to model training 


% define paths
addpath('/projects/johe7316/Function_Database')
td_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/inputs/training_data';
save_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/inputs/models/combo';
input_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data';

% load input data
cd(input_path)
tbl = readtable('snotel_basin_pairs.xlsx');
sno_tbl = readtable('rocky_mtn_snotel.xlsx');

cd(td_path)
load training_data_rocky_500m_SWE_all.mat
load training_data_rocky_500m_SWE_sub.mat

% this flag determines if a snotel station has overlapping lidar
lidar_flag = sum(it == tbl.id);

% if overlapping lidar, continue with traditional combo model 
if lidar_flag 

    % establish site and basin, then load the basin training data
    tbl_id = find(tbl.id == it);
    site         = categorical(sno_tbl.site(it));
    basin        = tbl.basin{tbl_id};
    basin_nospace = strrep(basin,' ','');
    id           = it;
    
    % parse down the training data to the basin/site in question
    ind1 = basin == training_data.basin;
    ind2 = site == training_data.site;
    ind = and(ind1,ind2);
    training_data = training_data(ind,:);
    
    % remove data from the basin from the regional data
    ind = basin == td.basin;
    td(ind,:) = [];
    
    % aggregate training data
    td = [td; training_data];
    
    %%% DEFINE ML TRAINING DATA
    [X, Y,var_names] = package_data_500_SWE(td);
    
    disp('Starting model creation')
    tic
    
    mdl = TreeBagger(100,X,Y,'Method','regression', ...
    'OOBPredictorImportance','On', ...
    'PredictorNames', var_names,...
    'MinLeafSize',5);
    
    mdl = compact(mdl);
    disp('Model creation complete')
    
    cd(save_path) 
    
    save([char(site) '_' num2str(id) '_' basin_nospace '_RF_model_500_SWE.mat'],'mdl','-v7.3')

else
% NEW OPTION FOR REGIONAL MODEL

    fsca_path = '/projects/johe7316/MODIS/rocky_domain/WY_data_final';
    med_snotel_path = '/projects/johe7316/snotel/';
    cd(med_snotel_path)
    med_swe_table = readtable('med_swe_dowy_rocky_domain.xlsx');
    load rocky_med_melt_dowy.mat

    % load all lidar data and the physiographic info 
    cd(input_path)
    load rocky_lidar_500m.mat
    load rocky_physio_500.mat

    % define grid id 
    grid_id = sno_tbl.grid_ID_500m(it);

    % calculate distance from snotel to each point 
    dist = sqrt((lidar_500.XX - sno_tbl.XX(it)).^2 + (lidar_500.YY - sno_tbl.YY(it)).^2);
    dist_mask = dist <= 25000;
    
    % determine the dates (if any) where there is lidar data within 25 km 
    % of the snotel site in question
    lidar_masked = nan(size(lidar_500.SWE));
    for ii = 1:length(lidar_500.file)
        temp = lidar_500.SWE(:,:,ii);
        temp(~dist_mask) = nan;
        lidar_masked(:,:,ii) = temp;

        valid_lidar(ii,:) = sum(~isnan(temp),'all') > 0;
    end

    % FOUND LIDAR DATA IN RANGE
    if sum(valid_lidar) > 0

        snotel_swe = lidar_500.snotel_SWE(:,it);
        valid_snotel = ~isnan(snotel_swe);

        valid_sno_and_lid = and(valid_snotel,valid_lidar);

        lidar_subset = lidar_500.SWE(:,:,valid_sno_and_lid);
        snotel_subset = snotel_swe(valid_sno_and_lid);
        idxs = find(valid_sno_and_lid);

        for zz = 1:length(snotel_subset)
            
            % define dowy
            dowy = serial_2_dowy(lidar_500.TIME(idxs(zz),7));

            % get the lidar data for this day
            swe_day = lidar_subset(:,:,zz);
            
            % create mask of valid 
            mask = ~isnan(swe_day);
            
            % build temp table
            temp = table();
            
            % target variable
            temp.lidar_SWE = single(swe_day(mask));
        
            % coordinates
            temp.XX = single(lidar_500.XX(mask));
            temp.YY = single(lidar_500.YY(mask));
            
            % physiographic variables
            temp.elev              = single(GRID.elev(mask));
            temp.fveg              = single(GRID.fveg(mask));
            temp.northness         = single(GRID.northness(mask));
            temp.eastness          = single(GRID.eastness(mask));
            temp.slope             = single(GRID.slope(mask));
            temp.TPI               = single(GRID.TPI(mask));
            temp.Sx                = single(GRID.Sx(mask));
            temp.P                 = single(GRID.P(mask));
            temp.T                 = single(GRID.T(mask));
            temp.mixed_forest_frac = single(GRID.mixed_forest_frac(mask));
            temp.evergreen_frac    = single(GRID.evergreen_frac(mask));
            temp.deciduous_frac    = single(GRID.deciduous_frac(mask));
            temp.snow_persistence  = single(GRID.snow_persistence(mask));
            
            %% fSCA
                % load
                cd(fsca_path)
                load([ 'WY' num2str(lidar_500.TIME(idxs(zz),1)) '_rocky_fSCA.mat' ])
                
                % daily fsca
                fsca_daily = fSCA(:,:,dowy);
                temp.fSCA = single(fsca_daily(mask));

                % fsca 8 day
                temp.fSCA_8day = get_fsca_8day_trailing_mean(fSCA, dowy, find(mask));
            
            %% Snotel vars
                % distance to snotel
                temp.dist = single(dist(mask));
            
                % snotel variables - scalar broadcast to all pixels
                n = sum(mask(:));
                temp.snotel_SWE      = single(repmat(snotel_subset(zz),       n, 1));
                temp.snotel_ELEV     = single(repmat(GRID.elev(grid_id),      n, 1));
                temp.snotel_FVEG     = single(repmat(GRID.fveg(grid_id),      n, 1));
            
                % day to med melt
                day_to_melt = dowy - melt_dowy(it); 
                temp.day_to_med_melt = single(repmat(day_to_melt,      n, 1));

                % med swe
                med_swe = med_swe_table{dowy,it};
                temp.med_swe = single(repmat(med_swe,      n, 1));

            % time variables
            TIME_day = lidar_500.TIME(idxs(zz),:);
            temp.date = single(repmat(TIME_day(7), n, 1));
            temp.dowy = single(repmat(dowy, n, 1));   % adjust index to match your TIME format
            
            % file and site labels
            temp.file  = repmat(categorical(cellstr(lidar_500.file(idxs(zz)))), n, 1);
            temp.site  = repmat(categorical(cellstr(sno_tbl.site(it))),   n, 1);
            
            % aggregate
            if ~exist('td_new','var')
                td_new = temp;
            else
                td_new = [td_new; temp];
            end
            
        end

      

        %%% DEFINE ML TRAINING DATA

        [X, Y,var_names] = package_data_500_SWE(td_new);
        [X_sub,Y_sub] = package_data_500_SWE(td);

        X = [X; X_sub];
        Y = [Y; Y_sub];
        
        disp('Starting model creation')

        mdl = TreeBagger(100,X,Y,'Method','regression', ...
        'OOBPredictorImportance','On', ...
        'PredictorNames', var_names,...
        'MinLeafSize',5);

        mdl = compact(mdl);

        cd(save_path) 
        site = sno_tbl.site{it};
        save([char(site) '_' num2str(it) '_nearbylidar_RF_model_500_SWE.mat'],'mdl','-v7.3')
        
        clear td_new
    else
        % % no nearby data, use all lidar data in training
        % % package the training data
        % [X, Y,var_names] = package_data_500_SWE(training_data);
        % 
        % tic
        % mdl = TreeBagger(100,X,Y,'Method','regression', ...
        % 'OOBPredictorImportance','On', ...
        % 'PredictorNames', var_names,...
        % 'MinLeafSize',5);        
        % 
        % mdl = compact(mdl);
        % 
        % cd(save_path) 
        % site = sno_tbl.site{it};
        % save([char(site) '_' num2str(it) '_nolidar_RF_model_500_SWE.mat'],'mdl','-v7.3')


    end



end



function fsca_8day = get_fsca_8day_trailing_mean(fSCA, ii, idx)
% ============================================================
% GET_FSCA_8DAY_TRAILING_MEAN
%
% Returns an 8-day trailing mean fSCA vector at points "idx":
% mean of days [ii-7 : ii], clipped to [1 : ii] at start of WY.
%
% Inputs:
%   fSCA - 3D array [rows x cols x n_days]
%   ii   - current day index (1-based DOWY)
%   idx  - linear indices into fSCA(:,:,1) domain
%
% Output:
%   fsca_8day - [n_pts x 1] vector (double)
% ============================================================

    i0 = max(1, ii-7);
    inds = i0:ii;

    % accumulate only at idx points to keep memory light
    fsca_sum = zeros(length(idx), 1);
    for kk = 1:length(inds)
        tmp = fSCA(:,:,inds(kk));
        fsca_sum = fsca_sum + double(tmp(idx));
    end

    fsca_8day = fsca_sum ./ length(inds);
end