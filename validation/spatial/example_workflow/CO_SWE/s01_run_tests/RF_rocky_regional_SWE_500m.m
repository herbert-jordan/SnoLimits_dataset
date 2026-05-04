

% define paths and load data 
    addpath /projects/johe7316/Function_Database
    in_path = '/projects/johe7316/ML/training_data_500m/SWE';
    cd(in_path)
    load training_data_rocky_500m_SWE.mat

    save_path = '/scratch/alpine/johe7316/ML/500m_testing/CO/SWE/regional/save';

% get indices of the basin to run 
    basins = unique(training_data.basin);
    bsn = basins(it);
    ind = training_data.basin == bsn;

% remove this basin from the regional subset
    test_data = training_data(ind,:);
    training_data(ind,:) = [];


    [X,Y] = package_data_500_SWE(training_data);
    [test_X,~] = package_data_500_SWE(test_data);

% train the model and make the prediction 
    mdl = TreeBagger(100,X,Y,'Method','regression', ...
    'OOBPredictorImportance','On', ...
    'MinLeafSize',5);
    
    disp('Model creation complete')
    
    predicted_SWE = predict(mdl,test_X);
    predicted_SWE = predicted_SWE + test_data.snotel_SWE;
    predicted_SWE(predicted_SWE < 0) = 0;
    f_ind = test_data.fSCA_8day == 0;
    predicted_SWE(f_ind) = 0;
    disp('Prediction complete'); 

    test_data.pred_SWE = predicted_SWE;
    rf_out = test_data;

    disp('prediction complete')

    OOB = mdl.OOBPermutedPredictorDeltaError;
    mdl = compact(mdl);

% save the outputs 
    cd(save_path)

    bsn = char(bsn);
    bsn = strrep(bsn,' ','');

    save(['rf_out_reg_SWE_500m_' bsn '.mat'],'rf_out','OOB')
