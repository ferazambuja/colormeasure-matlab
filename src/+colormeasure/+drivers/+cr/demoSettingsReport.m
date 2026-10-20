function report = demoSettingsReport(model,values)
%DEMOSETTINGSREPORT Explicit virtual capabilities, never device detection.
% Choice IDs and limits below belong only to this synthetic teaching example.
% Fernando Voltolini de Azambuja, 2026.
[key,label]=colormeasure.drivers.cr.modelInfo(model);
if nargin<2
    values=struct('exposureMode',0,'exposureMs',10,'exposureMultiplier',1, ...
        'syncMode',0,'syncFrequencyHz',60,'accessory',0, ...
        'filter1',0,'filter2',0,'filter3',0,'userCalibrationMode',0, ...
        'matchId',0,'aperture','Synthetic aperture');
    if strcmp(key,'CR100')
        values.rangeMode=0; values.range=3; values.matrixId=0; values.mode=0;
    else
        values.speed=1;
    end
end
controls=colormeasure.drivers.cr.settingsControls(key);
for k=1:numel(controls)
    id=controls(k).id;
    controls(k).available=true;
    switch id
        case {'exposureMode','rangeMode'}
            controls(k).choices=choices(0:1,{'Auto','Fixed'});
        case 'range'
            controls(k).choices=choices(0:3,{'A','B','C','D'});
        case 'syncMode'
            controls(k).choices=choices(0:2,{'None','Auto','Manual'});
        case 'speed'
            controls(k).choices=choices(0:3,{'Slow','Normal','Fast','2xFast'});
        case 'accessory'
            controls(k).choices=choices(0:1,{'Standard','Synthetic alternate accessory'});
        case {'filter1','filter2','filter3'}
            controls(k).choices=choices(0:1,{'None','Synthetic ND filter'});
        case 'userCalibrationMode'
            if strcmp(key,'CR100')
                controls(k).choices=choices(0:2,{'None','Matrix','Match'});
            else
                controls(k).choices=choices([0 2],{'None','Match'});
            end
        case {'matrixId','matchId'}
            controls(k).choices=choices(0,{'Synthetic stored correction'});
        case 'mode'
            controls(k).choices=choices(0:2,{'Colorimeter','Flicker','Response Time'});
            controls(k).available=false;
        case 'aperture'
            controls(k).available=false;
        case 'exposureMultiplier'
            controls(k).minimum=1; controls(k).maximum=100;
        case 'syncFrequencyHz'
            controls(k).minimum=1; controls(k).maximum=1000;
        otherwise
            controls(k).minimum=1; controls(k).maximum=10000;
    end
end
stamp=colormeasure.session.utcText(datetime('now','TimeZone','UTC'));
report=struct('values',values,'controls',controls, ...
    'identity',struct('model',label,'synthetic',true), ...
    'readAtUTC',stamp,'responses',struct(),'synthetic',true);
end

function value=choices(ids,labels)
value=struct('value',num2cell(ids),'label',labels);
end
