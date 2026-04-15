%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%               ProcessGnssMeasScript.m,         %%%%%%%%%%%%%%%%
%%%%%%%%%%% script to read GnssLogger output, compute and plot: %%%%%%%%%%%
%%%%%%%% pseudoranges, C/No, and weighted least squares PVT solution  %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Author: Frank van Diggelen
% Open Source code for processing Android GNSS Measurements
% Modified by Alex Minetto (NavSAS Research Group) 
% Last update: Alex Minetto & Simone Zocca 12-Oct-2021
% Last update: Andrea Nardin 19-Oct-2023
% Spoofing enhancement: Andrea Nardin 10-Mar-2024

% NOTE: Compatible with GNSSLogger App v2.0.0.1
% WARNING: CodeType breaks the code for logs retrieved by GNSSLogger App
% v3.0.0.1



% you can run the data in pseudoranges log files collected through your device by: 
% 1) changing 'dirName = ...' to match the local directory you are using:
% 3) running ProcessGnssMeasScript.m script file (this script) 
clc, close all, clear all
% include library functions (utilities and functions)
addpath('library')


% ***** SETTINGS *********************************************************
%% input data (GNSS logger)
% To add your own data:
% save data from GnssLogger App, and edit dirName and prFileName appropriately
prFileName    = 'gnss_log_2026_03_19_13_27_58.txt';
dirName       = 'demoFiles/dataset_20260319_outdoor_I';

%% true position
param.llaTrueDegDegM = [];
%enter true WGS84 lla, if you know it:
% param.llaTrueDegDegM = [37.422578, -122.081678, -28]; %Charleston Park Test Site

%% Spoofing settings
spoof.active = 0; % [1: spoofing active, 0: spoofing disabled]
spoof.delay = 0; % [s] additional delay introduced by the spoofer [s]
spoof.t_start = 15; % [s] start spoofing time
spoof.position = [45.0639728, 7.6585169, 314.17]; % spoofed position

%% Plots
plotAccDeltaRange = 0;
plotPseudorangeRate = 1;

%********************* END SETTINGS ***************************************
%rng('default');
%% Set the data filter and Read log file
dataFilter = SetDataFilter;
dataFilter{end+1, 1} = 'Svid';
dataFilter{end, 2} =  'Svid ~= 10';
dataFilter{end+1, 1} = 'Svid';
dataFilter{end, 2} =  'Svid ~= 31';
dataFilter{end+1, 1} = 'Svid';
dataFilter{end, 2} = 'Svid ~= 29';
dataFilter{end+1, 1} = 'Svid';
dataFilter{end, 2} = 'Svid ~= 8';
dataFilter{end+1,1} = 'Cn0DbHz';
dataFilter{end,2} = 'Cn0DbHz>20';
[gnssRaw,gnssAnalysis] = ReadGnssLogger(dirName,prFileName,dataFilter);
if isempty(gnssRaw), return, end



%% Get online ephemeris from Nasa CCDIS service, first compute UTC Time from gnssRaw:
fctSeconds = 1e-3*double(gnssRaw.allRxMillis(end));
utcTime = Gps2Utc([],fctSeconds);
allGpsEph = GetNasaHourlyEphemeris(utcTime,dirName);
if isempty(allGpsEph), return, end

%% process raw measurements, compute pseudoranges:
% Compute synthetic spoofer-sat ranges
if spoof.active
    [gnssMeas_tmp] = ProcessGnssMeas(gnssRaw);
    gpsPvt_tmp = GpsWlsPvt(gnssMeas_tmp,allGpsEph,spoof);
    [spoof] = compute_spoofSatRanges(gnssMeas_tmp,gpsPvt_tmp,spoof);
    % Now consistently spoof the measurements
    [gnssMeas] = ProcessGnssMeas(gnssRaw,spoof);
else
    [gnssMeas] = ProcessGnssMeas(gnssRaw);
end

%% plot pseudoranges and pseudorange rates
h1 = figure;
[colors] = PlotPseudoranges(gnssMeas,prFileName);
if plotPseudorangeRate
    h2 = figure;
    PlotPseudorangeRates(gnssMeas,prFileName,colors);
end
h3 = figure;
PlotCno(gnssMeas,prFileName,colors);

%% compute WLS position and velocity
gpsPvt = GpsWlsPvt(gnssMeas,allGpsEph,spoof);

% compute median position
iFi = isfinite(gpsPvt.allLlaDegDegM(:,1));%index into finite results
llaMed = median(gpsPvt.allLlaDegDegM(iFi,:));

%% plot PVT results
h4 = figure;
ts = 'Raw Pseudoranges, Weighted Least Squares solution';
PlotPvt(gpsPvt,prFileName,param.llaTrueDegDegM,ts); drawnow;
h5 = figure;
PlotPvtStates(gpsPvt,prFileName);

%% Plot Accumulated Delta Range 
if (any(isfinite(gnssMeas.AdrM) & gnssMeas.AdrM~=0)) 
    [gnssMeas]= ProcessAdr(gnssMeas);
    if plotAccDeltaRange
    h6 = figure;
    PlotAdr(gnssMeas,prFileName,colors);
    [adrResid]= GpsAdrResiduals(gnssMeas,allGpsEph,param.llaTrueDegDegM);drawnow
    end
end

if exist('adrRedis','var') && ~isempty(adrResid)
    h7 = figure;
    PlotAdrResids(adrResid,gnssMeas,prFileName,colors);
end

%% plot PVT on geoplot
h8 = figure('Name','[Optional] Plot Positioning Solution on Map');
geoplot(gpsPvt.allLlaDegDegM(:,1),gpsPvt.allLlaDegDegM(:,2)), hold on

% animated geoplot
for epochIdx = 1:size(gpsPvt.allLlaDegDegM,1)
figure(h8)
geoplot(gpsPvt.allLlaDegDegM(epochIdx,1),gpsPvt.allLlaDegDegM(epochIdx,2),'ro','MarkerSize',4,'MarkerFaceColor','r') 
drawnow
pause(0.01)
end

%% ADDITIONAL RELEVANT DATAs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% filter out invalid data (NaNs)
valid_idx = isfinite(gpsPvt.allLlaDegDegM(:,1));
latitudes = gpsPvt.allLlaDegDegM(valid_idx, 1);
longitudes = gpsPvt.allLlaDegDegM(valid_idx, 2);
altitudes = gpsPvt.allLlaDegDegM(valid_idx, 3);

% altitude statistics
fprintf('Altitude Standard Deviation (m) = %.2f\n', std(altitudes));
fprintf('Altitude Variance (m^2) = %.2f\n', var(altitudes));
fprintf('Altitude Maximum (m) = %.2f\n', max(altitudes));
fprintf('Altitude Minimum (m) = %.2f\n', min(altitudes));
fprintf('Altitude Range (m) = %.2f\n', max(altitudes) - min(altitudes));

% horizontal statistics 
% approximate coordinate conversion to meters
lat_med = median(latitudes);
lon_med = median(longitudes);
dy = (latitudes - lat_med) * 111320;
dx = (longitudes - lon_med) * 111320 * cosd(lat_med);
horiz_errors = sqrt(dx.^2 + dy.^2);

% true 2D horizontal standard deviation (DRMS)
drms = sqrt(var(dx) + var(dy));

fprintf('50%% Circular Error Probable (CEP) (m) = %.2f\n', median(horiz_errors));
fprintf('Horizontal Standard Deviation (DRMS) (m) = %.2f\n', drms);
fprintf('Horizontal Radial Variance (m^2) = %.2f\n', var(horiz_errors));
fprintf('East Variance (m^2) = %.2f\n', var(dx));
fprintf('North Variance (m^2) = %.2f\n', var(dy));
fprintf('Maximum Horizontal Error (m) = %.2f\n', max(horiz_errors));

% HDOP
if isfield(gpsPvt, 'allHdop')
    hdop_vals = gpsPvt.allHdop(:,1);
elseif isfield(gpsPvt, 'allDop')
    hdop_vals = gpsPvt.allDop(:, 3); 
else
    hdop_vals = NaN;
end

if ~isnan(hdop_vals)
    hdop_vals = hdop_vals(isfinite(hdop_vals));
    fprintf('Mean HDOP = %.2f\n', mean(hdop_vals));
    fprintf('Maximum HDOP = %.2f\n', max(hdop_vals));
    fprintf('Minimum HDOP = %.2f\n', min(hdop_vals));
else
    fprintf('HDOP field not found in gpsPvt.\n');
end

% C/N0 
cn0_vals = gnssMeas.Cn0DbHz(gnssMeas.Cn0DbHz > 0);
fprintf('Mean C/N0 (dB-Hz) = %.2f\n', mean(cn0_vals));

% velocity and clock errors (optional but useful) 
if isfield(gpsPvt, 'allVelMps')
    valid_vel = gpsPvt.allVelMps(isfinite(gpsPvt.allVelMps));
    fprintf('RMS Velocity Error (m/s) = %.2f\n', rms(valid_vel));
end

if isfield(gpsPvt, 'allBcMeters')
    valid_bc = gpsPvt.allBcMeters(isfinite(gpsPvt.allBcMeters));
    clock_drift_rate = mean(diff(valid_bc)); % assuming 1 Hz sampling
    fprintf('Mean Clock Bias Drift Rate (m/s) = %.2f\n', clock_drift_rate);
end
%% end of ProcessGnssMeasScript
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright 2016 Google Inc.
% 
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
%     http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
