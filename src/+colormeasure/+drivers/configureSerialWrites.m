function configureSerialWrites(port, timeout)
%CONFIGURESERIALWRITES Bound every native write before sending any command.
% MATLAB R2026b introduced EnableWriteTimeout. Timeout alone bounds only
% reads when this property is false. Injected transports expose the same
% properties so protocol tests exercise the production configuration.
% https://www.mathworks.com/help/instrument/serialport.html
validateattributes(timeout, {'numeric'}, {'scalar','real','finite','positive'});
assert(isprop(port,'Timeout') && isprop(port,'EnableWriteTimeout'), ...
    'Measurement:WriteTimeoutUnsupported', ...
    ['Native serial connections require MATLAB R2026b or newer. ' ...
     'Injected transports must expose Timeout and EnableWriteTimeout.']);
port.Timeout = timeout;
port.EnableWriteTimeout = true;
end
