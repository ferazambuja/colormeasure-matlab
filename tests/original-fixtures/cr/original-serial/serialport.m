function port = serialport(varargin)
%SERIALPORT Test-only original constructor seam. Never delegates to hardware.
port = colormeasuretest.cr.originalTransport('get',varargin{:});
end
