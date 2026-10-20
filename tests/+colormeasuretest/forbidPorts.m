function ports = forbidPorts(varargin) %#ok<STOUT>
%FORBIDPORTS Port-list seam that fails: the action under test must not
% enumerate ports.
error('colormeasuretest:PortsForbidden','This check must not enumerate ports.');
end
