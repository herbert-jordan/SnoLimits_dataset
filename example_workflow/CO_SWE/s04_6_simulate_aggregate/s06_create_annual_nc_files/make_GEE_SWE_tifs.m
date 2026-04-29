
% this script will be used to make .tifs that are ingestable into the GEE
% framework

% the .tifs should be organized by water year with one band per day. 

%-----------------------------------------------------------------------%

blanca = 1;

for wy = 2001:2025

    % define paths etc.
    if blanca == 1
        data_path = ['/pl/active/smyth_da/Herbert_ML/rocky_domain_data/500m_SWE_workflow/daily_outputs/' num2str(wy)];
        save_path = '/pl/active/smyth_da/Herbert_ML/rocky_domain_data/500m_SWE_workflow/annual_tifs';
        input_path = '/pl/active/smyth_da/Herbert_ML/rocky_domain_data/input_data';
        addpath('/projects/johe7316/Function_Database')
    else
        data_path = ['/Volumes/PortableSSD/rocky_domain/data/SWE/swe_500/' num2str(wy)];
        save_path = '/Volumes/PortableSSD/rocky_domain/data/SWE/annual_tifs_to_compress';
        input_path = '/Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/input_data';
    end
    
    num_days = days_in_year(wy);
    
    % load coordinates and georef object
        cd(input_path)
        load geo_reference_R_500m.mat
        load rocky_grid_500m.mat
    
    % define the output tif name
        tif_name = ['Rocky_SWE_500m_' num2str(wy) '.tif'];
    
    % initialize data matrix
        out = nan(size(GRID.XX,1),size(GRID.XX,2),num_days);
    
    % loop through and aggregate data
        cd(data_path)
        for ii = 1:num_days
            
            counter(ii)
            load(['output_500m_' num2str(wy) '_' num2str(ii) '.mat'])
        
            out_500 = single(out_500m);
        
            out(:,:,ii) = out_500;
        
        end
    
    % Write multiband GeoTIFF (bands = days)
        cd(save_path)
        geotiffwrite(tif_name, out, R, ...
            'CoordRefSysCode', 32613);  % EPSG:32613 (UTM Zone 13N)

    
        clearvars -except wy blanca
end