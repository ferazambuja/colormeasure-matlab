function dispose(value)
%DISPOSE Delete a handle that may already be empty or deleted.
if ~isempty(value) && isvalid(value), delete(value); end
end
