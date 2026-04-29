
% this script completes the IDW interpolation of the 50m data into the
% complete rocky grid. 

% Each snotel site has snow depth data, indices of each pt location in the
% rocky grid, and a multiplier.

% For each day, each SD point needs to be placed into the rocky grid and
% multiplied by its pre-calculated IDW multiplier. When aggregating the
% data, we simply need to add each multiplied snow depth to every other
% value at the same location to get the final snow depth value.

cd /pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/input_data
load rocky_grid_mask_500m.mat

addpath /projects/johe7316/Function_Database
data_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/unaggregated_daily_outputs/' num2str(wy)]; 
cd(data_path)
save_path = ['/pl/active/smyth_da/Herbert_ML/SnoLimits/rocky_domain/500m_SWE/data/daily_outputs/' num2str(wy)];
if ~exist(save_path,'dir')
    mkdir(save_path)
end


names = get_names(pwd);

for dowy = begins:ends
    
    cd(data_path)
    out_mat = single(zeros(size(XX)));

    for ii = 1:length(names)
    
        counter(ii)

        ncfile = names{ii};
        
        % read data, multiplier, and indices
        swe_out = ncread(ncfile,'swe',[1 dowy],[inf 1]);
        mult = ncread(ncfile,'mult');
        swe_out = swe_out .* mult;
        idx = ncread(ncfile,'idx');

        out_mat(idx) = single(swe_out + out_mat(idx));
        toc
    
    end

    out_500m = single(out_mat);
    out_500m(~mask) = nan;

    cd(save_path)
    save(['output_500m_' num2str(wy) '_' num2str(dowy) '.mat'],'out_500m','-v7.3')

end

