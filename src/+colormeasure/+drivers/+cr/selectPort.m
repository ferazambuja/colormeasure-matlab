function portName = selectPort(requested, listPorts)
%SELECTPORT Choose one candidate; Instrument still verifies the CR identity.
% Shared selection rules and macOS alias handling live in
% colormeasure.session.choosePort; this family keeps its CR:* identifiers.
portName = colormeasure.session.choosePort(requested, listPorts, 'CR');
end
