function cleanup = isolateRegistry(testCase)
%ISOLATEREGISTRY Give a test an empty session registry; restore the previous one.
% The launchers and the device catalog read the process-wide registry (root
% appdata ColorMeasureSessions), so a batch another test left registered
% would change their branch. Cleanup disposes test-owned registered or
% published sessions and restores only their workspace bindings. It also
% removes recovery variables created during the test. Existing sessions,
% unrelated workspace edits and the original appdata presence are preserved.
% The optional cleanup function supports an explicit, idempotent early reset.
key = 'ColorMeasureSessions'; present = isappdata(groot,key);
previous = getappdata(groot,key);
names = evalin('base','who'); values = cell(size(names));
for index = 1:numel(names), values{index} = evalin('base',names{index}); end
previousSessions = {};
if ~isempty(previous), previousSessions = previous.sessions; end
for index = 1:numel(values)
    if isa(values{index},'colormeasure.session.Session')
        previousSessions{end+1} = values{index}; %#ok<AGROW>
    end
end
recovered = evalin('base','who(''colorMeasureRecovered_*'')');
if present, rmappdata(groot,key); end
restored = false; cleanup = @restore;
testCase.addTeardown(cleanup);

    function restore()
        if restored, return, end
        restored = true;
        % Read raw appdata: sessionRegistry('get') prunes deleted handles.
        registry = getappdata(groot,key); sessions = {};
        if ~isempty(registry), sessions = registry.sessions; end
        currentNames = evalin('base','who'); bindings = {};
        for n = 1:numel(currentNames)
            value = evalin('base',currentNames{n});
            if ownedSession(value,previousSessions)
                sessions{end+1} = value; %#ok<AGROW>
                bindings{end+1} = currentNames{n}; %#ok<AGROW>
            end
        end
        finish = onCleanup(@() restoreState(key,present,previous,names,values,bindings,recovered));
        for n = 1:numel(sessions)
            if ownedSession(sessions{n},previousSessions)
                colormeasuretest.disposeSession(sessions{n});
            end
        end

        clear finish
    end
end

function restoreState(key,present,previous,names,values,bindings,recovered)
added = setdiff(evalin('base','who(''colorMeasureRecovered_*'')'),recovered);
if ~isempty(added), evalin('base',['clear ' strjoin(added,' ')]); end
for index = 1:numel(bindings)
    prior = find(strcmp(names,bindings{index}),1);
    if isempty(prior), evalin('base',['clear ' bindings{index}]);
    else, assignin('base',bindings{index},values{prior}); end
end
if present, setappdata(groot,key,previous);
elseif isappdata(groot,key), rmappdata(groot,key); end
end

function yes = ownedSession(value,previousSessions)
yes = isa(value,'colormeasure.session.Session') && isscalar(value) && ...
    ~any(cellfun(@(previous)any(previous(:)==value),previousSessions));
end
