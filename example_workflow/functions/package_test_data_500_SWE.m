


% this function takes an input table and packages the output to use for
% training data in an ML framework

function [X, var_names] = package_test_data_500_SWE(td)
    
    % Create subsets for the X variable
    physio_subset = [td.fveg, td.elev, td.northness, td.eastness, td.slope, td.TPI, td.Sx, td.dist, td.P, ...
        td.T, td.snow_persistence, td.evergreen_frac, td.mixed_forest_frac, td.deciduous_frac];

    time_subset = [td.day_to_med_melt, td.snotel_SWE - td.med_swe, td.fSCA, td.fSCA_8day];
    
    snotel = [td.snotel_SWE, td.fveg - td.snotel_FVEG, td.elev - td.snotel_ELEV];
    
    % Aggregate the subsets into the X variable
    X = [physio_subset, time_subset, snotel];

    var_names = {'Veg.','Elev.','Northness','Eastness', 'slope','TPI 30','Sx','Dist.','P','T',...
        'snow persistence','evergreen','mixed forest','deciduous',...
        'Days to med. melt','Dif from med. SWE','fSCA','fSCA 8 day',...
        'Snotel SWE','Rel. Veg.','Rel. Elev'};

end
