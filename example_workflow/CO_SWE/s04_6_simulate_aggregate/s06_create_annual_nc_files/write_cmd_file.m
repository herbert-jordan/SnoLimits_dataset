


cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s06_create_annual_nc_files
fileID = fopen('lb_cmd_file','w');


for ii = 2001:2025

    fprintf(fileID, 'matlab -nodisplay -r ''wy = %i; write_annual_nc_tif_SWE_rocky;'' > write_annual_%i.out \n',ii,ii);

end

fclose(fileID);
