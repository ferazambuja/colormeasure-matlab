function values = settingsValues(numericFields, textSetup)
% SETTINGSVALUES Normalize documented setup fields; unknown is never zero.
%   D601 supplies selection IDs; D602 supplies descriptive current settings.
%   Neither report is an atomic record of an earlier exposure.
%   Fernando Voltolini de Azambuja, 2026. See docs/drivers/pr/settings.md.
values=struct('exposureMilliseconds',NaN,'cycles',NaN,'syncMode','', ...
    'syncFrequencyHz',NaN,'primaryAccessoryId',NaN,'addon1Id',NaN, ...
    'addon2Id',NaN,'addon3Id',NaN,'apertureId',NaN,'sensitivityMode','', ...
    'smartDark',NaN,'photometricUnits','','instrumentObserver',NaN,'shutterMode','');
if nargin<1,numericFields={};end
if nargin<2,textSetup=struct();end
if ~isempty(numericFields)
    if numel(numericFields)~=16
        error('PR655:InvalidResponse','D601 must contain status and 15 setup fields.');
    end
    numbers=str2double(numericFields(2:end));
    if ~isreal(numbers)||any(~isfinite(numbers))||any(numbers(1:14)~=fix(numbers(1:14)))
        error('PR655:InvalidResponse','D601 returned invalid numeric setup fields.');
    end
    values.primaryAccessoryId=numbers(1); values.addon1Id=numbers(2);
    values.addon2Id=numbers(3); values.addon3Id=numbers(4); values.apertureId=numbers(5);
    values.photometricUnits=label(numbers(6),[0 1],{'english','metric'});
    if numbers(8)>=0,values.exposureMilliseconds=numbers(8);end
    if numbers(10)>=1&&numbers(10)<=99,values.cycles=numbers(10);end
    if ismember(numbers(11),[2 10]),values.instrumentObserver=numbers(11);end
    if ismember(numbers(12),[0 1]),values.smartDark=numbers(12);end
    values.syncMode=label(numbers(13),[0 1 3],{'none','auto','user'});
    % D601 calls the last field SyncPeriod; use D602's explicit Hertz label
    % below instead of silently assigning units to the bare numeric field.
end
if isfield(textSetup,'captureMode')
    text=lower(strtrim(textSetup.captureMode));
    if strcmp(text,'standard sensitivity'),values.sensitivityMode='standard';end
    if strcmp(text,'extended sensitivity'),values.sensitivityMode='extended';end
end
if isfield(textSetup,'syncFrequency')
    token=regexp(textSetup.syncFrequency,'^([0-9]+(?:\.[0-9]+)?)\s+Hertz$','tokens','once');
    if ~isempty(token)
        frequency=str2double(token{1});
        if isfinite(frequency),values.syncFrequencyHz=frequency;end
    end
end
% The D602 DarkMode field is Smart Dark, not SZ shutter control. Its value
% cannot populate shutterMode; that setting remains acknowledgement-only.
end
function text=label(value,codes,labels)
text=''; index=find(codes==value,1);
if ~isempty(index),text=labels{index};end
end
