wipe

go ri
load valid_snotel_by_year.mat

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s03_generate_test_data
fileID = fopen('lb_cmd_file','w');

chunk_size = 25; % adjust as needed

for ii = 2001:2025

    ind = find(ii == valid_snotel.wy);

    num_valid = sum(valid_snotel.flag_SWE,2);
    num_snotel = num_valid(ind);

    % figure out number of chunks
    num_chunks = ceil(num_snotel / chunk_size);

    for ch = 1:num_chunks
        start_it = (ch-1)*chunk_size + 1;
        end_it   = min(ch*chunk_size, num_snotel);

        fprintf(fileID, ...
            'matlab -nodisplay -r ''wy = %i; start_it = %i; end_it = %i; gen_test_data;'' > test_data_gen_%i_chunk_%i.out \n', ...
            ii, start_it, end_it, ii, ch);
    end
end

fclose(fileID);
