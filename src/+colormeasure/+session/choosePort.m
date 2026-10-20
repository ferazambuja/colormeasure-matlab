function portName = choosePort(requested, listPorts, prefix, onMac)
%CHOOSEPORT Choose one serial candidate without probing; the driver verifies identity.
%   Shared by driver families. PREFIX selects the family's error identifiers,
%   for example 'CR' raises CR:Port, CR:PortList, CR:NoPort and CR:AmbiguousPort.
%   serialportlist reports port names, not models. Never probe multiple devices.
%   https://www.mathworks.com/help/matlab/ref/serialportlist.html
%   Fernando Voltolini de Azambuja, 2026.
if nargin<4, onMac=ismac; end
if ~(ischar(requested) && (isrow(requested) || isempty(requested))) && ...
        ~(isstring(requested) && isscalar(requested) && ~ismissing(requested))
    error([prefix ':Port'], 'Port must be a character vector or scalar string; use "" for automatic selection.');
end
portName = strtrim(char(requested));
if ~isempty(portName), return; end
ports = string(listPorts());
if ~isvector(ports) && ~isempty(ports)
    error([prefix ':PortList'], 'Available ports must be a vector of names.');
end
if any(ismissing(ports)) || any(strlength(strtrim(ports)) == 0)
    error([prefix ':PortList'], 'Available port names must not be empty or missing.');
end
ports = unique(strtrim(ports(:)), 'stable');
ports = colormeasure.session.availablePorts(ports,ports,onMac);
if isempty(ports)
    error([prefix ':NoPort'], ['No available serial port was found. Check the driver and other port owners, ' ...
        'or pass an explicit port name.']);
elseif numel(ports) ~= 1
    error([prefix ':AmbiguousPort'], ['Multiple available ports: %s. Pass an explicit port name. ' ...
        'No candidate was opened.'], strjoin(ports,', '));
end
portName = char(ports(1));
end
