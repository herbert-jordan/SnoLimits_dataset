





% this function calculates the ML performance stats
function [RMSE, R2, RMAD, Rbias] = calc_ml_stats(x,y) 

    round_num = 3;

    % calculate stats 
    RMSE = round(rmse(x,y),round_num);
    linmdl = fitlm(x,y);
    R2 = round(linmdl.Rsquared.Ordinary,round_num);
    RMAD = round(mean(abs(x - y),'omitnan')/mean(x,'omitnan'),round_num);
    % Rbias = round(mean(y - x,'omitnan')/mean(x,'omitnan'),round_num) * 100;
    Rbias = round(mean(y,'omitnan')-mean(x,'omitnan'),round_num); 

end