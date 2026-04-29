
wipe

path = pwd;


cd(path)
fileID = fopen('lb_cmd_file','w');


for it = 1:155

    fprintf(fileID, 'matlab -nodisplay -r ''it = %i; create_RF_SWE_models;'' > combo_model_%i.out \n',it,it);

end

fclose(fileID);
