function specs = settingsSpecs(model)
%SETTINGSSPECS Native command mapping, Remote Communications 1.36 sections 4.2/4.3.
% Choice values are device IDs; reported names are resolved against RC lists.
% https://www.colorimetryresearch.com/downloads
[~,model] = colormeasure.drivers.cr.modelInfo(model);
rows = {
    'mode','Mode','choice',1.16;
    'exposureMode','ExposureMode','choice',1.04;
    'exposureMs','Exposure','milliseconds',1.04;
    'rangeMode','RangeMode','choice',1.04;
    'range','Range','choice',1.04;
    'exposureMultiplier','ExposureX','positiveInteger',1.04;
    'syncMode','SyncMode','choice',1.04;
    'syncFrequencyHz','SyncFreq','hertz',1.04;
    'speed','Speed','choice',1.17;
    'accessory','Accessory','choice',1.04;
    'filter1','Filter1','filter',1.04;
    'filter2','Filter2','filter',1.04;
    'filter3','Filter3','filter',1.04;
    'userCalibrationMode','UserCalibMode','choice',1.16;
    'matrixId','Matrix','index',1.04;
    'matchId','Match','index',1.16;
    'maxAutoExposureMs','MaxAutoExposure','milliseconds',1.26};
specs = cell2struct(rows,{'id','token','kind','since'},2);
if strcmp(model,'CR-100')
    specs(strcmp({specs.id},'speed')) = [];
else
    specs(ismember({specs.id},{'mode','rangeMode','range','matrixId'})) = [];
end
end
