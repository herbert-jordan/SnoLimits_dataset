
wipe



fileID = fopen('lb_cmd_file','w');


for wy = 2001:2025


    fprintf(fileID, 'matlab -nodisplay -r ''wy = %i; s02_calc_total_distances;'' > mask_%i.out \n',wy,wy);

end

fclose(fileID);