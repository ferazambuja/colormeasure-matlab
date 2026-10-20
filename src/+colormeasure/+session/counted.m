function text = counted(count, one, many)
%COUNTED Count text that agrees in number: "1 reading", "2 readings".
%   Fernando Voltolini de Azambuja, 2026.
noun = many;
if count == 1, noun = one; end
text = sprintf('%d %s', count, noun);
end
