
wipe

path = pwd;


cd(path)
fileID = fopen('lb_cmd_file','w');


for ii = 2001:2025

    fprintf(fileID, 'matlab -nodisplay -r ''wy = %i; gen_snotel_masks;'' > closest_snotel_%i.out \n',ii,ii);

end

fclose(fileID);
