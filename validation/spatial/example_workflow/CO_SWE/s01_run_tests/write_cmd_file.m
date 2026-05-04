

% this cmd file is written based on the defined water year and the number
% of snotels run in the given water year.

wipe




cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/500m_testing/CO/SWE/regional/s01_run_tests
fileID = fopen('lb_cmd_file','w');


for ii = 1:15

    fprintf(fileID, 'matlab -nodisplay -r ''it = %i; RF_rocky_regional_SWE_500m;'' > reg_500_%i.out \n',ii,ii);

end



fclose(fileID);


