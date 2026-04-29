
% this script will be used to IDW interpolate the 50 m grid

% I will loop through the snotel masks and calculate the distance from each
% valid point in the mask to the snotel site it represents.

% the loop will add all distances to each other, creating a total distance
% to snotel for each 50 m point. This value represents the normalizations
% coefficient for each 50 m point. 

% Back into context: 
% When simulating snow depth at a single point I will divide the point by
% its distance to snotel and then divide it by the total distance to
% snotel.

% then, we can add up all partial snow depth values at a given point to
% yield the final snow depth

addpath /projects/johe7316/Function_Database

cd /pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data
sno_tbl = readtable('rocky_mtn_snotel.xlsx');
sno_tbl2 = readtable('snotel_basin_pairs.xlsx');
load rocky_grid_mask_500m.mat

in_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/snotel_masks/' num2str(wy)];
save_path = '/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/inverse_total_distances';
if ~exist(save_path,'dir')
    mkdir(save_path)
end


cd(in_path)

names = get_names(pwd);

sum_dist = zeros(size(XX));
sum_dist(~mask) = nan;
sum_dist = single(sum_dist);

for ii = 1:length(names)
    
    counter(ii)
    cd(in_path)

    load(names{ii})

    
    Xsub = XX;
    Xsub(~snotel_mask) = nan;
    Ysub = YY;
    Ysub(~snotel_mask) = nan;

    dist = sqrt((sno_tbl.XX(id) - Xsub).^2 + (sno_tbl.YY(id) - Ysub).^2);

    dist(dist == 0) = 0.001;

    dist = dist.^2;
    dist = 1./dist;

    sum_dist(snotel_mask) = dist(snotel_mask) + sum_dist(snotel_mask);
 
    
end

cd(save_path)
save(['sum_dist_' num2str(wy) '.mat'],'sum_dist')