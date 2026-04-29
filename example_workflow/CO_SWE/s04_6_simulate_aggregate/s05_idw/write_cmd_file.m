

% this cmd file is written based on the defined water year and the number
% of snotels run in the given water year.

wipe


chunks = 50;

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s0456
fileID = fopen('lb_cmd_file5','w');

for wy = [2005 2020]%[2001:2025]

    num_days = days_in_year(wy);
    [begins,ends] = split_loop_indices(num_days,chunks);

    for ii = 1:chunks
    
        fprintf(fileID, 'matlab -nodisplay -r ''wy = %i; begins = %i; ends = %i; agg_500m_data;'' > agg_%i_%i.out \n',wy,begins(ii),ends(ii),wy,ii);
    
    end

end

fclose(fileID);


