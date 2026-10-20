classdef (Abstract) Spectroradiometer < colormeasure.drivers.cs2000.COMClass
    %SPECTRORADIOMETER Aligned CS-2000 history and value-only persistence.
    % Column-oriented spectra, XYZ and metadata are saved in one value snapshot.
    % Fernando Voltolini de Azambuja, 2026.
    methods (Abstract)
        Connect(h)
        Disconnect(h)
        Measure(h)
    end
    properties
        saveOnDelete (1,1) logical = false
    end
    properties (SetAccess = protected)
        spectralData = zeros(401,0)
        XYZData = zeros(3,0)
        metadata = struct([])
        identity = struct()
        segmentId = ''
        measurementConditions = struct()
        isSaved = false
    end
    properties (Access = protected)
        conditionsSnapshotIndependent = false
    end
    properties (Constant)
        wavelengths = (380:780)'
    end
    methods
        function h = Spectroradiometer(portNumber, baudRate, parity, dataBits, stopBits, dtr, rts, varargin)
            h@colormeasure.drivers.cs2000.COMClass(portNumber, baudRate, parity, dataBits, stopBits, dtr, rts, varargin{:});
            h.segmentId = char(java.util.UUID.randomUUID());
        end

        function measurements = snapshot(h)
            %SNAPSHOT Complete value-only history; does not open a port or save.
            measurements = struct('schemaVersion',2,'segmentId',h.segmentId,'spectralData',h.spectralData, ...
                'XYZData',h.XYZData,'wavelengths',h.wavelengths, ...
                'metadata',h.metadata,'identity',h.identity, ...
                'measurementConditions',h.measurementConditions, ...
                'measurementConditionsIndependent',h.conditionsSnapshotIndependent);
        end

        function Save(h, fileName)
            % Stage the current value snapshot before replacing this chosen path.
            h.saveSnapshot(fileName,true);
        end

        function Erase(h)
            if isempty(h.XYZData), return; end
            h.spectralData(:,end) = []; h.XYZData(:,end) = [];
            h.metadata(end,:) = [];
            if ~h.conditionsSnapshotIndependent
                if isempty(h.metadata)
                    h.measurementConditions = struct();
                else
                    h.measurementConditions = h.metadata(end).conditions;
                end
            end
            h.isSaved = false;
        end

        function EraseAll(h)
            h.spectralData = zeros(401,0); h.XYZData = zeros(3,0);
            h.metadata = struct([]); h.measurementConditions = struct();
            h.conditionsSnapshotIndependent = false;
            h.isSaved = false;
        end

        function Load(h, fileName)
            % Append a current native snapshot only after complete validation.
            % Per-reading identity is retained; the live connection is unchanged.
            saved = load(fileName);
            if ~isfield(saved,'measurements')
                error('CS2000:FileFormat', 'File needs a current measurements snapshot.');
            end
            values = saved.measurements;
            required = {'schemaVersion','segmentId','spectralData','XYZData','wavelengths', ...
                'metadata','identity','measurementConditions','measurementConditionsIndependent'};
            if ~isstruct(values) || ~isscalar(values) || ...
                    ~all(isfield(values,required)) || ~isequal(values.schemaVersion,2) || ...
                    ~isequal(values.wavelengths,h.wavelengths)
                error('CS2000:FileFormat', 'Unsupported or incomplete measurement snapshot.');
            end
            if ~ischar(values.segmentId) || ~isrow(values.segmentId) || ...
                    isempty(regexp(values.segmentId,'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$','once'))
                error('CS2000:FileFormat','The snapshot needs its original UUID segmentId.');
            end
            spectrum = values.spectralData; xyz = values.XYZData;
            latestConditions = values.measurementConditions;
            if ~isstruct(latestConditions) || ~isscalar(latestConditions) || ...
                    ~isstruct(values.identity) || ~isscalar(values.identity)
                error('CS2000:FileFormat', 'Latest conditions and identity must be scalar structs.');
            end
            entries = values.metadata;
            if ~isstruct(entries) || numel(entries) ~= size(xyz,2) || ...
                    (~isempty(entries) && (~all(isfield(entries,{'conditions','identity','acquisition','readingId'})) || ...
                    numel(fieldnames(entries)) ~= 4))
                error('CS2000:FileFormat', 'Metadata must align with the measurement columns.');
            end
            if ~isempty(entries)
                if ~all(arrayfun(@(x) isstruct(x.conditions) && isscalar(x.conditions) && ...
                        isstruct(x.identity) && isscalar(x.identity) && ...
                        isstruct(x.acquisition) && isscalar(x.acquisition), entries))
                    error('CS2000:FileFormat', 'Each metadata entry must contain scalar value structs.');
                end
                entries = orderfields(entries(:),{'conditions','identity','acquisition','readingId'});
            end
            independent = values.measurementConditionsIndependent;
            if ~islogical(independent) || ~isscalar(independent)
                error('CS2000:FileFormat', 'Latest-conditions provenance flag must be a scalar logical.');
            end
            h.validateReadings(spectrum,xyz);
            if ~isempty(entries)
                ids = {entries.readingId};
                if ~all(cellfun(@(id) ischar(id) && isrow(id) && ...
                        ~isempty(regexp(id,'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$','once')),ids))
                    error('CS2000:FileFormat','Each acquired row needs its original UUID readingId.');
                end
                if numel(unique(ids)) ~= numel(ids) || ...
                        (~isempty(h.metadata) && any(ismember(ids,{h.metadata.readingId})))
                    % The same acquisition is not a second sample. Refuse both
                    % exact duplicates and conflicting rows before appending.
                    error('CS2000:DuplicateReading','An imported readingId is already retained or repeated in this snapshot.');
                end
            end
            nextSpectrum = [h.spectralData, spectrum];
            nextXYZ = [h.XYZData, xyz];
            nextMetadata = [h.metadata; entries];
            h.spectralData = nextSpectrum; h.XYZData = nextXYZ;
            h.metadata = nextMetadata;
            h.measurementConditions = latestConditions;
            h.conditionsSnapshotIndependent = independent;
            h.isSaved = false;
        end

        function delete(h)
            if h.saveOnDelete && ~h.isSaved && ~isempty(h.XYZData)
                fileName = [tempname '.mat'];
                try
                    h.Save(fileName);
                    fprintf('Measurements saved to %s\n',fileName);
                catch err
                    warning('CS2000:AutoSave', 'Automatic save failed: %s',err.message);
                end
            end
        end
    end
    methods (Access = protected)
        function saveSnapshot(h,fileName,replaceExisting)
            % Write complete data before publishing. Automatic paths cannot replace.
            if ~(ischar(fileName) && isrow(fileName) && ~isempty(fileName)) && ...
                    ~(isstring(fileName) && isscalar(fileName) && ~ismissing(fileName) && strlength(fileName)>0)
                error('CS2000:SavePath','Specify one nonempty MAT filename.');
            end
            fileName=char(fileName);
            [parent,stem,extension]=fileparts(fileName);
            if isempty(extension),extension='.mat';end
            if isempty(parent),parent=pwd;end
            [found,folder]=fileattrib(parent);
            if isempty(stem) || ~found || ~isscalar(folder) || ~folder.directory
                error('CS2000:SavePath','Choose a MAT file in an existing folder.');
            end
            % fileattrib resolves relative folders against MATLAB's cwd.
            % Java's cwd can differ after MATLAB cd; publish absolute paths.
            fileName=fullfile(folder.Name,[stem extension]);
            if isfolder(fileName)
                error('CS2000:SavePath','The MAT destination is a directory: %s',fileName);
            end
            measurements=h.snapshot();
            try
                colormeasure.session.saveMatFile(fileName, ...
                    struct('measurements',measurements),replaceExisting);
            catch problem
                wrapped=MException('CS2000:SaveFailed','Measurement save failed: %s',problem.message);
                throw(addCause(wrapped,problem));
            end
            h.isSaved=true;
        end

        function commitReading(h, spectrum, xyz, conditions, acquisition)
            h.validateReadings(spectrum,xyz);
            if size(xyz,2) ~= 1 || ~isstruct(conditions) || ~isscalar(conditions) || ...
                    ~isstruct(acquisition) || ~isscalar(acquisition)
                error('CS2000:Reading', 'A complete reading and scalar metadata are required.');
            end
            % Stable acquisition identity survives erase, save and import.
            % It is assigned once, after complete acquisition validation.
            entry = struct('conditions',conditions,'identity',h.identity,'acquisition',acquisition, ...
                'readingId',char(java.util.UUID.randomUUID()));
            nextSpectrum = [h.spectralData, spectrum];
            nextXYZ = [h.XYZData, xyz];
            nextMetadata = [h.metadata; entry];
            h.spectralData = nextSpectrum; h.XYZData = nextXYZ;
            h.metadata = nextMetadata; h.measurementConditions = conditions;
            h.conditionsSnapshotIndependent = false;
            h.isSaved = false;
        end
    end
    methods (Access = private)
        function validateReadings(~, spectrum, xyz)
            if ~isnumeric(spectrum) || ~isreal(spectrum) || ~ismatrix(spectrum) || ...
                    size(spectrum,1) ~= 401 || any(~isfinite(spectrum(:))) || ...
                    ~isnumeric(xyz) || ~isreal(xyz) || ~ismatrix(xyz) || ...
                    size(xyz,1) ~= 3 || any(~isfinite(xyz(:))) || ...
                    size(spectrum,2) ~= size(xyz,2)
                error('CS2000:Reading', 'Expected finite real 401-by-N spectra and aligned 3-by-N XYZ.');
            end
            if any(spectrum(:) == -9.9999e9) || any(xyz(:) == -9.9999e9)
                error('CS2000:Unavailable', 'Instrument calculation-error sentinel is not a measurement.');
            end
        end
    end
end
