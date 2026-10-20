function queries = metadataQueries()
%METADATAQUERIES Last-capture settings from CR Remote Communication v1.36.
% Sections 4.3.1.3-20, .34, .41; no current-setup RS or modifying SC commands.
% https://www.colorimetryresearch.com/downloads
% Keep docs/drivers/cr/metadata.md and metadata fixtures current when changing this list.
rows = {
    'deviceTime',          'RM Time',            'text',       '',     'always';
    'accessory',           'RM Accessory',       'text',       '',     'always';
    'filters',             'RM Filter',          'text',       '',     'always';
    'aperture',            'RM Aperture',        'text',       '',     'always';
    'instrumentMode',      'RM Mode',            'text',       '',     'always';
    'exposureMode',        'RM ExposureMode',    'text',       '',     'always';
    'exposureMs',          'RM Exposure',        'milliseconds','ms',   'always';
    'maxAutoExposureMs',   'RM MaxAutoExposure', 'milliseconds','ms',   'always';
    'rangeMode',           'RM RangeMode',       'text',       '',     'always';
    'range',               'RM Range',           'text',       '',     'always';
    'syncMode',            'RM SyncMode',        'syncMode',       '',     'always';
    'syncFrequencyHz',     'RM SyncFreq',        'hertz',      'Hz',   'sync';
    'exposureMultiplier',  'RM ExposureX',       'positiveInteger','',   'always';
    'userCalibrationMode', 'RM UserCalibMode',   'calibrationMode',       '',     'always';
    'legacyMatrixMode',    'RM MatrixMode',      'legacyMatrixMode',       '',     'legacy';
    'matrixId',            'RM Matrix',          'text',       '',     'matrix';
    'matchId',             'RM Match',           'text',       '',     'match';
    'speed',               'RM Speed',           'text',       '',     'spectral';
    'warnings',            'RM Warnings',        'text',       '',     'always';
    'cmfIndex',            'RM CMF',             'integer',    '',     'spectral'};
queries = cell2struct(rows,{'field','command','kind','unit','condition'},2);
end
