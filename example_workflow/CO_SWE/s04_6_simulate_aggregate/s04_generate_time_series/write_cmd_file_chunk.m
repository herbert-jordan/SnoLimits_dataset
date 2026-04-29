% this cmd file is written based on the defined water year and the number
% of snotels run in the given water year. It now supports chunking.

wipe

go ri 
load("valid_snotel_by_year.mat")

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s0456
fileID = fopen('lb_cmd_file4','w');

% user inputs
n_chunks = 50;   % number of chunks to split into

for wy = [2005 2020]%2001:2025

    ind = find(wy == valid_snotel.wy);
    num_snotel = sum(valid_snotel.flag_SWE(ind,:));
    
    % figure out chunk boundaries
    chunk_edges = round(linspace(1, num_snotel+1, n_chunks+1));
    
    for cc = 1:n_chunks
        it_start = chunk_edges(cc);
        it_end   = chunk_edges(cc+1) - 1;
    
        fprintf(fileID, ...
            'matlab -nodisplay -r ''wy = %i; it_start = %i; it_end = %i; generate_time_series_CO_SWE;'' > snotel_%i_chunk%i.out \n', ...
            wy, it_start, it_end, wy, cc);
    
    end

end

fclose(fileID);
