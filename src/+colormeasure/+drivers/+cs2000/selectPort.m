function portName = selectPort(requested, listPorts)
%SELECTPORT Choose one candidate; Connect still verifies the CS-2000 identity.
% Shared selection rules and macOS alias handling live in
% colormeasure.session.choosePort; this family keeps its CS2000:* identifiers.
portName = colormeasure.session.choosePort(requested, listPorts, 'CS2000');
end
