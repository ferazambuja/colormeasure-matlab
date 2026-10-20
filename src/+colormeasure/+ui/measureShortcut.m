function [label,modifiers,hint]=measureShortcut()
%MEASURESHORTCUT One chord for the idle Measure action on every platform.
% Control delivers key release on the macOS desktop; Command chords can leave
% the held-key guard latched. Keep one policy for buttons and callback guards.
label='Ctrl+Shift+M';modifiers={'control';'shift'};hint=label;
end
