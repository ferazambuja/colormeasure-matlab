function ports = availablePorts(allPorts, available, onMac)
% AVAILABLEPORTS Keep available ports and prefer macOS callout aliases in pairs.
%   Do not remove tty-only ports or assume every serial adapter is a USB modem.
%   Fernando Voltolini de Azambuja, 2026.
ports = string(allPorts(:));
ports = unique(ports(ismember(ports, string(available(:)))), 'stable');
if onMac
    paired = startsWith(ports, '/dev/tty.') & ...
        ismember(strrep(ports, '/dev/tty.', '/dev/cu.'), ports);
    ports(paired) = [];
end
end
