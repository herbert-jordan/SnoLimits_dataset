


% this script will calculate the multiplier for each snotel mask for a
% given year 

% the total sum of distances at a certain point has already been calculated
% in the previous script
addpath /projects/johe7316/Function_Database

cd /pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data
sno_tbl = readtable('rocky_mtn_snotel.xlsx');
sno_tbl2 = readtable('snotel_basin_pairs.xlsx');
load rocky_grid_mask_500m.mat

in_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/snotel_masks/' num2str(wy)];
dist_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/inverse_total_distances';
save_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/IDW_multipliers/' num2str(wy)];

if ~exist(save_path,'dir')
    mkdir(save_path)
end

% load total distances 
    cd(dist_path)
    load(['sum_dist_' num2str(wy) '.mat'])

% get mask file names 
    cd(in_path)
    names = get_names(pwd);

for ii = 1:length(names)
    
    % load the mask
        counter(ii)
        cd(in_path)
        load(names{ii})

    % remove nans from the grid and find distances
        Xsub = XX;
        Xsub(~snotel_mask) = nan;
        Ysub = YY;
        Ysub(~snotel_mask) = nan;
    
        dist = sqrt((sno_tbl.XX(id) - Xsub).^2 + (sno_tbl.YY(id) - Ysub).^2); 

        dist(dist == 0) = 0.001;

        dist_squared = dist.^2;

    % get the total distances
        total_dist = sum_dist;
        total_dist(~snotel_mask) = nan;

    % calculate the mulipliers 
        mults = 1 ./ dist_squared;
        mults = mults ./ total_dist;

    % SAVE
        cd(save_path)
        save_name = char(names{ii});
        save_name = ['mult_' save_name];
        save(save_name,'mults')

end

