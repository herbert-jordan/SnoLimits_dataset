

% this cmd file is written based on the defined water year and the number
% of snotels run in the given water year.

wipe

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/input_data
load("valid_snotel_by_year.mat")

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s04_generate_time_series
fileID = fopen('lb_cmd_file','w');

for wy = 2025

    ind = find(wy == valid_snotel.wy);
    num_snotel = sum(valid_snotel.flag(ind,:));
    
    for ii = 1:num_snotel
    
        fprintf(fileID, 'matlab -nodisplay -r ''wy = %i; it = %i; generate_time_series;'' > snotel_%i_%i.out \n',wy,ii,wy,ii);
    
    end

end

fclose(fileID);