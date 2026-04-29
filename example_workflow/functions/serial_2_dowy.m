% converts serial date to day of water year
% 
% RELEASE NOTES
%   Written by Mark Raleigh (raleigh@ucar.edu), July 2014
% 
% SYNTAX
%   DOWY=serial_2_dowy(sdate)
% 
% INPUTS
%   sdate = matlab serial date(s)
% 
% OUTPUTS
%   DOWY = day(s) of water year
% 

function DOWY=serial_2_dowy(sdate)

%% code


% first convert from serial date to julian date
jd = serial_2_jd(sdate);

% next, get the years from the sdates
[yrs, ~, ~, ~, ~, ~] = datevec(sdate);

% finally, convert from yr,jdate to day of water year
DOWY=jul2doWY(yrs,jd);