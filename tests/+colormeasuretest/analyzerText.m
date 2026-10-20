function text = analyzerText(messages)
%ANALYZERTEXT Render the retained diagnostics without running checkcode again.
% Keep complete line/column arrays, identifiers and messages in the text
% report; the same checkcode structs supply its JSON and MAT counterparts.
rows = cell(1,numel(messages));
for index = 1:numel(messages)
    item = messages(index);
    rows{index} = sprintf('L%s (C%s): %s: %s\n', ...
        mat2str(item.line),mat2str(item.column),item.id,item.message);
end
text = [rows{:}];
if isempty(text), text = ''; end
end
