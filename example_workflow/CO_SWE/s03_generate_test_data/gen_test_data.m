
% this final script will generate the test data based on the masks
% generated in s03 



% load snotel tables
cd /pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data
sno_tbl = readtable('rocky_mtn_snotel.xlsx');
load rocky_physio_500.mat
addpath('/projects/johe7316/Function_Database');

mask_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/masks/snotel_masks/' num2str(wy)]; 
save_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/test_data/' num2str(wy)];

if ~exist(save_path, 'dir')
    mkdir(save_path);
end


cd(mask_path)
names = get_names(pwd);

for ii = start_it:end_it%1:length(names)

    cd(mask_path)
    disp(ii)
    
    load(names{ii})
    
    dist = sqrt((sno_tbl.XX(id) - GRID.XX).^2 + (sno_tbl.YY(id) - GRID.YY).^2); 
    
    td.site = sno_tbl.site(id);

    td.dist = dist(snotel_mask);
    td.elev = GRID.elev(snotel_mask); 
    td.fveg = GRID.fveg(snotel_mask);   
    td.northness = GRID.northness(snotel_mask); 
    td.eastness = GRID.eastness(snotel_mask);
    td.slope = GRID.slope(snotel_mask); 
    td.Sx = GRID.Sx(snotel_mask);
    td.TPI = GRID.TPI(snotel_mask);
    td.XX = GRID.XX(snotel_mask);
    td.YY = GRID.YY(snotel_mask);
    td.idx = find(snotel_mask);

    td.snow_persistence = GRID.snow_persistence(snotel_mask);
    td.evergreen_frac = GRID.evergreen_frac(snotel_mask);
    td.mixed_forest_frac = GRID.mixed_forest_frac(snotel_mask);
    td.deciduous_frac = GRID.deciduous_frac(snotel_mask);
    td.P = GRID.P(snotel_mask);
    td.T = GRID.T(snotel_mask);
    
    % get lat/lon
    [td.lat,td.lon] = utm2ll(td.XX,td.YY,13); 
    
    % grab the values closest to snotel 
    [~,ind] = min(td.dist);
    
    % add snotel data 
    td.snotel_ELEV = td.elev(ind);
    td.snotel_FVEG = td.fveg(ind);
    td.snotel_northness = td.northness(ind);
    td.snotel_TPI = td.TPI(ind);
    td.snotel_eastness = td.eastness(ind);
    td.snotel_slope = td.slope(ind);
    td.snotel_Sx = td.Sx(ind);
    td.snotel_idx = td.idx(ind);
    
    td.state = sno_tbl.state{id};
    td.state_ID = sno_tbl.state_ID(id);
    td.master_ID = id;

    % SAVE 

    cd(save_path)
    save_name = string(sno_tbl.site{id});
    save_name = strrep(save_name,' ','');
    
    save(save_name + '_test_data_ID_' + num2str(id) + '_.mat','td')

    % clear temp variables from this iteration
    clear td id snotel_mask

end









