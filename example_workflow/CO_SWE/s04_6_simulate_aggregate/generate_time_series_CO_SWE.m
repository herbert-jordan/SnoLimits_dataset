

% J Herbert 
% 12.26.24

% This script will generate an annual time-series of 50 m snow depth data
% surrounding a snotel site in the rocky mountain region. Currently, the
% domain is set to all points that are within a 100 km radius of the snotel
% site as well as within the rocky mountain domain. 

% This script is set up to run on the CURC supercomputers. The command file
% will have to specify: 
% 1. The snotel site
% 2. The water year 

% the physiographic data (test data) is stored in individual .mat files in the peta
% library. To run the script we need to isolate the dynamic variables for
% each time step. The steps for this are: 
% 1. open fSCA data and do a nearest neighbor interpolation to the 50 m
%    data
% 2. Gather daily snotel data 
% 3. Gather daily median SWE snotel data 
% 4. Melt out data 

% The MODEL is crucial. We need to load an already trained model which will
% be used to make the daily predictions of snow depth. 


%%% THE COMMAND FILE NEEDS TO DEFINE THE WATER YEAR AND 'it' %%%


tic

%% define paths and load data
    addpath('/projects/johe7316/Function_Database')
    physio_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/test_data/' num2str(wy)];
    snotel_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data/snotel_annual';   
    combo_model_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/inputs/models/combo';
    reg_model_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/inputs/models/reg_model_rocky_SWE_500.mat';
    fsca_path = '/projects/johe7316/MODIS/rocky_domain/WY_data_final';
    med_snotel_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data';
    idw_weight_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/IDW_multipliers/' num2str(wy)];
    save_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/unaggregated_daily_outputs/' num2str(wy)]; 
    if ~exist(save_path,'dir')
        mkdir(save_path)
    end

% loop through the sites defined in the cmd file 
for it = it_start:it_end
        
    %% load a physio data file
        cd(physio_path)
        names_physio = get_names(pwd); 
        
        load(names_physio{it});
        disp(['Physio file: ' names_physio{it}])
        
        % grab site name for saving
        site_name = char(names_physio{it});
        uscore = strfind(site_name,'_');
        site_name = site_name(1:uscore(1)-1);
    
    %% load the correct RF model
        cd(combo_model_path)
        
        % get the snotel IDs of the model
        names = get_names(pwd);
        for zz = 1:length(names)
        
            uscore = strfind(names{zz},'_');
            temp = char(names{zz});
            temp = temp(uscore(1)+1:uscore(2)-1);
            model_IDs(zz) = str2double(temp);
        
        end
        
        % either load the specific snotel model or the regional model
        if sum(td.master_ID == model_IDs)
            ind = find(td.master_ID == model_IDs);
            load(names{ind})
        else
            cd
            load(reg_model_path)
        end
    
    %% load snotel data for the site / year (and med. snotel)
        cd(med_snotel_path)
        med_swe_table = readtable('med_swe_dowy_rocky_domain.xlsx');
        load rocky_med_melt_dowy.mat
        melt_dowy = melt_dowy(td.master_ID);

        cd(snotel_path)
        load(['rocky_snotel_' num2str(wy) '.mat'])
        snotel_swe = SNOTEL.SWE(:,td.master_ID);
        time = SNOTEL.TIME;
    
    %% calculate snotel melt out
        % [snow_periods, ~,~,~] = snow_metrics(time, SNOTEL.SWE(:,td.master_ID), 0, wy);
        % melt_dowy = serial_2_dowy(snow_periods.sdate_07_melt100);

    
    %% load fSCA
        cd(fsca_path)
        load([ 'WY' num2str(wy) '_rocky_fSCA.mat' ])
    
    %% make the snotel vals arrays
        td.snotel_ELEV = ones(height(td.elev),1) * td.snotel_ELEV;
        td.snotel_FVEG = ones(height(td.elev),1) * td.snotel_FVEG;

    
    %% Load the IDW multipliers 
        cd(idw_weight_path)
        
        % get the index of the correct file and load it
            mult_files = get_names(pwd);
            % get multiplier IDs
            for zz = 1:length(mult_files)
                
                id = char(mult_files{zz});
        
                us = strfind(id,'_');
                pi = strfind(id,'.');
        
                id = id(us(3)+1:pi(1)-1);
                mult_ids(zz) = str2double(id);
        
            end
    
            mult_file_ind = find(td.master_ID == mult_ids);
            load(mult_files{mult_file_ind})
        
        % extract the multiplier values 
            multiplier = mults(td.idx);
    
    %%% generate the .nc file 
        cd(save_path)
        nc_file = [site_name '_ID_' num2str(td.master_ID) '_' num2str(wy) '.nc'];
    
        if exist(nc_file,'file')
            delete(nc_file)
        end
    
        nccreate(nc_file,'swe',...
             'Dimensions',{'pts',length(td.idx),'time',length(SNOTEL.TIME)}, ...
             'Datatype','single')
    
        nccreate(nc_file,'idx',...
             'Dimensions',{'pts',length(td.idx)}, ...
             'Datatype','double')
    
        nccreate(nc_file,'mult',...
             'Dimensions',{'pts',length(td.idx)}, ...
             'Datatype','double')
    
        ncwrite(nc_file,'idx',td.idx)
        ncwrite(nc_file,'mult',multiplier)
    
    
    disp('all data loaded - starting DOWY loop')
    
    toc
    %% loop through each day    
    for ii = 1:height(SNOTEL.TIME)
    
        disp(['Starting dowy loop ' num2str(ii) ' --- it = ' num2str(it)])
        toc
    
        %% add the dynamic variables
            % snotel sd
            td.snotel_SWE = ones(height(td.elev),1) * snotel_swe(ii);
            
            % dowy 
            td.dowy = ones(height(td.elev),1) * ii;

            % fSCA (daily)
            fsca_daily = fSCA(:,:,ii);
            td.fSCA = fsca_daily(td.idx);
            
            % fSCA (8-day trailing mean: ii, ii-1, ..., ii-7)
            td.fSCA_8day = get_fsca_8day_trailing_mean(fSCA, ii, td.idx);

            % days to melt
            day_to_melt = ii - melt_dowy; 
            td.day_to_med_melt = ones(height(td.elev),1) * day_to_melt;
            
            % difference from med swe
            med_swe = med_swe_table{ii,td.master_ID};
            td.med_swe = ones(height(td.elev),1) * med_swe;
                     
        %% package data and make the prediction
    
            % initialize as zeros
            swe_500 = zeros(length(td.XX),1);
            % flag points that have fSCA not equal to zero
            run_flag = td.fSCA_8day ~= 0;
        
            X = package_test_data_500_SWE(td);
            X = X(run_flag,:);
            temp_out = predict(mdl,X);
            temp_out = temp_out + td.snotel_SWE(run_flag);
    
            swe_500(run_flag) = temp_out;
            swe_500(swe_500 < 0) = 0;
            swe_500 = single(swe_500);
           
        %% WRITE NC
            ncwrite(nc_file,'swe',swe_500,[1 ii])

    
    end

    clear model_IDs mult_ids names mult_files fsca td

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
