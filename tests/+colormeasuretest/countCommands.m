function count = countCommands(state, command)
%COUNTCOMMANDS Count exact wire commands in the recording transport state.
count=sum(strcmp(state('commands'),command));
end
