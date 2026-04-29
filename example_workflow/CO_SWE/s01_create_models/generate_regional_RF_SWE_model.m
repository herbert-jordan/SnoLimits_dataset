

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/DATA/training_data/training_data_500m/SWE
load training_data_rocky_500m_SWE_all.mat

% package the training data
[X, Y,var_names] = package_data_500_SWE_nodowy(training_data);

tic
mdl = TreeBagger(100,X,Y,'Method','regression', ...
'OOBPredictorImportance','On', ...
'PredictorNames', var_names,...
'MinLeafSize',5);
toc

mdl_full = mdl;

mdl = compact(mdl);

figure;
bar(mdl_full.OOBPermutedPredictorDeltaError)
xticks(1:numel(var_names))          % set tick positions
xticklabels(var_names)              % label bars with strings in var
xtickangle(45)                % optional: tilt labels for readability
ylabel('OOB Predictor Importance')
title('Predictor Importance')
grid on

cd /Users/jordanherbert/Library/CloudStorage/OneDrive-UCB-O365/Boulder_Research/MASTER_Herbert/Projects/ML/rocky_domain/workflow_500m_SWE/s01_create_models
save('reg_model_rocky_SWE_500_nodowy.mat',"mdl")