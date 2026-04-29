

% for each point find the closest snotel site

cd /pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data
load rocky_grid_500m.mat
sno_tbl = readtable("rocky_mtn_snotel.xlsx");
sno_tbl2 = readtable('snotel_basin_pairs.xlsx');
load valid_snotel_by_year.mat
save_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/snotel_masks/' num2str(wy)];
if ~exist(save_path,'dir')
    mkdir(save_path)
end

ind = find(wy == valid_snotel.wy);

sno_flag = valid_snotel.flag_SWE(ind,:);
sno_flag = find(sno_flag);
n_snotel = length(sno_flag);

% Loop through each SNOTEL site
for ii = 1:n_snotel

    fprintf("Processing SNOTEL site %d / %d\n", ii, n_snotel);

    id = sno_flag(ii);
    
    % Compute distance from current SNOTEL site to all points
    dist = sqrt((sno_tbl.XX(sno_flag(ii)) - GRID.XX).^2 + (sno_tbl.YY(sno_flag(ii)) - GRID.YY).^2);
    ind = dist < 125000;
    snotel_mask = ind;

    % % see if snotel contains lidar 
    % islidar = sum(sno_tbl2.id == id);
    % 
    % % in the case there is lidar data, add it to the max
    % if islidar 
    % 
    %     % get the index of the lidar basin in the outline mask
    %     s2_ind = find(sno_tbl2.id == id);
    %     lid_idx = find(categorical(sno_tbl2.basin(s2_ind)) == bsns);
    %     % add mask 
    %     snotel_mask = or(snotel_mask,lid_mask_ind(:,:,lid_idx));
    % 
    %     % now remove points from areas in other lidar basins 
    %     lid_mask_temp = lid_mask_ind;
    %     lid_mask_temp(:,:,lid_idx) = [];
    %     lid_mask_temp = logical(sum(lid_mask_temp,3));
    % 
    %     % find overlap between other sites
    %     hm = and(snotel_mask,lid_mask_temp);
    %     snotel_mask(hm) = 0;
    % 
    % end
    % 
    % if ~islidar % remove lidar basins from non-lidar snotel
    %     % find overlap and make zero
    %     hm = and(snotel_mask,lid_mask_all);
    %     snotel_mask(hm) = 0;
    % end



    % now remove all points that are outside of rocky domain
    hm = and(snotel_mask,~GRID.flag);
    snotel_mask(hm) = 0;

    cd(save_path)
    site_save = strrep(char(sno_tbl.site(id)),' ','');
    save(['mask_' site_save '_' num2str(id) '.mat'],'snotel_mask','id')


end


