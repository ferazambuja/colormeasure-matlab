function tests = testMeasurementLogView
% Log interaction tests use original event identities, not wrapped line numbers.
tests = functiontests(localfunctions);
end

function setupOnce(t)
colormeasuretest.setupPaths(t);
end


function testFollowingStartsOnAndMovesAfterAppendAndHeightResize(t)
% ListboxTop settles only when the hidden listbox is rendered; a capture
% forces that where drawnow does not (measured 2026-09-23), so this test
% keeps getframe. The other tests here only read properties.
[view, fig, entries] = makeView(t, 1000);
log = colormeasuretest.field(fig, 'SessionLog');
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 1);
verifyNumElements(t, get(log, 'String'), 1000);
getframe(fig); before = get(log, 'ListboxTop');
view.update(entries, [16 16 388 154]); getframe(fig);
verifyGreaterThan(t, get(log, 'ListboxTop'), before);
entries(end+1) = event(1001);
view.update(entries, [16 16 388 154]); getframe(fig);
verifyGreaterThan(t, get(log, 'ListboxTop'), 990);
verifyEqual(t, get(log, 'UserData'), 1:1001);
view.update(entries, [16 16 568 300]); getframe(fig);
verifyGreaterThan(t, get(log, 'ListboxTop'), 980);
end

function testSelectingPausesAndRetainsFullMessageAcrossUpdates(t)
[view, fig, entries] = makeView(t, 1000);
entries(350).message = sprintf('First paragraph\n\n%s\nLAST_DETAIL', repmat('long/path/',1,50));
% Build a fresh view, because session events are immutable once appended.
delete(view); view = colormeasure.ui.LogView(fig); t.addTeardown(@() delete(view));
view.update(entries, [16 16 568 440]);
set(logHandle(fig), 'Value', 350, 'ListboxTop', 340); colormeasuretest.click(logHandle(fig));
log = logHandle(fig); drawnow; top = get(log, 'ListboxTop');
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 0);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 350');
expected = sprintf('%s [%s]\n%s', entries(350).timeUTC, upper(entries(350).level), entries(350).message);
verifyEqual(t, get(colormeasuretest.field(fig, 'CopyLogMessage'), 'UserData'), expected);
verifyNumElements(t, get(log, 'String'), 1000);
detail = colormeasuretest.field(fig, 'LogDetails'); scroll(detail,'bottom'); drawnow;
detailValue=detail.Value;
entries(end+1) = event(1001); view.update(entries, [16 16 568 440]); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(log, 'Value'), 350);
verifyEqual(t,detail.Value,detailValue);
view.update(entries, [16 16 388 250]); drawnow;
verifyEqual(t, get(log, 'Value'), 350);
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(colormeasuretest.field(fig, 'CopyLogMessage'), 'UserData'), expected);
verifyTrue(t, any(contains(get(detail, 'Value'), 'LAST_DETAIL')));
verifyEqual(t,detail.Value,detailValue);
verifyEqual(t,char(detail.Editable),'off');
verifyEqual(t,strjoin(detail.Value,newline),expected);
end

function testJumpResumesFollowingWithoutChangingFilter(t)
[view, fig, entries] = makeView(t, 1000);
filter = colormeasuretest.field(fig, 'LogFilter'); set(filter, 'Value', 2); colormeasuretest.click(filter);
log = colormeasuretest.field(fig, 'SessionLog'); indices = get(log, 'UserData');
set(log, 'Value', 2, 'ListboxTop', 1); colormeasuretest.click(log);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), sprintf('Message %d',indices(2)));
colormeasuretest.click(colormeasuretest.field(fig, 'JumpToLatest')); drawnow;
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 1);
verifyEqual(t, get(filter, 'Value'), 2);
verifyGreaterThan(t, get(log, 'ListboxTop'), numel(indices)-30);
verifyEqual(t, char(get(colormeasuretest.field(fig, 'LogDetails'), 'Visible')), 'off');
entries(end+1) = event(1001); view.update(entries, [16 16 568 440]);
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 1);
end

function testFilterRetainsHiddenSelectionAndRestoresFullDetails(t)
[~, fig, entries] = makeView(t, 100);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'Value', 3); colormeasuretest.click(log); % INFO
original = get(colormeasuretest.field(fig, 'CopyLogMessage'), 'UserData');
filter = colormeasuretest.field(fig, 'LogFilter'); set(filter, 'Value', 2); colormeasuretest.click(filter);
verifyEmpty(t, get(log, 'Value'));
verifyEqual(t, char(get(colormeasuretest.field(fig, 'CopyLogMessage'), 'Enable')), 'off');
verifyTrue(t, contains(strjoin(get(colormeasuretest.field(fig, 'LogDetails'), 'Value')), 'hidden by the filter'));
indices = get(log, 'UserData');
verifyTrue(t, all(ismember({entries(indices).level}, {'warning','error'})));
set(filter, 'Value', 1); colormeasuretest.click(filter);
verifyEqual(t, get(log, 'UserData'), 1:100);
verifyEqual(t, get(log, 'Value'), 3);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 3');
verifyEqual(t, get(colormeasuretest.field(fig, 'CopyLogMessage'), 'UserData'), original);
verifyEqual(t, char(get(colormeasuretest.field(fig, 'LogDetails'), 'Visible')), 'on');
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 0);
end

function testEmptyFilterIsSafeAndCanFollowFirstMatchingMessage(t)
[view, fig, ~] = makeView(t, 0);
entries = repmat(event(3),1,10); view.update(entries, [16 16 568 440]);
filter = colormeasuretest.field(fig, 'LogFilter'); set(filter, 'Value', 2); colormeasuretest.click(filter);
log = colormeasuretest.field(fig, 'SessionLog');
verifyEmpty(t, get(log, 'UserData')); verifyEmpty(t, get(log, 'Value'));
set(log, 'Value', 1); colormeasuretest.click(log); % The empty-state placeholder is not an event.
verifyEqual(t, char(get(colormeasuretest.field(fig, 'LogDetails'), 'Visible')), 'off');
entries(end+1) = event(1); view.update(entries, [16 16 568 440]);
verifyEqual(t, get(log, 'UserData'), 11);
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 1);
end

function testDuplicateMessagesUseEventIdentity(t)
[view, fig, ~] = makeView(t, 0);
entries = repmat(event(1),1,30); view.update(entries, [16 16 388 250]);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'Value', 19); colormeasuretest.click(log);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 19');
view.update(entries, [16 16 568 440]);
verifyEqual(t, get(log, 'Value'), 19);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 19');
end

function testModifierSelectionInspectsNewEndpoint(t)
[~, fig, ~] = makeView(t, 30);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'Value', 20); colormeasuretest.click(log);
set(log, 'Value', [10 20]); colormeasuretest.click(log); % Ctrl/Command-click an earlier event.
verifyEqual(t, get(log, 'Value'), 10);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 10');
set(log, 'Value', 10:15); colormeasuretest.click(log); % Shift-select a later endpoint.
verifyEqual(t, get(log, 'Value'), 15);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 15');
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 0);
drawnow;
verifyLessThanOrEqual(t, get(log, 'ListboxTop'), 15);
end

function testVisibleSelectionDoesNotMoveSurroundingHistory(t)
[~, fig, ~] = makeView(t, 1000);
log = colormeasuretest.field(fig, 'SessionLog');
set(log, 'Value', 500, 'ListboxTop', 495); colormeasuretest.click(log);
set(log, 'ListboxTop', 500); drawnow;
top = get(log, 'ListboxTop');
set(log, 'Value', 508); colormeasuretest.click(log); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(log, 'Value'), 508);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 508');
end

function testUnchangedUpdateDoesNotMoveViewportOrOverwriteNativeSelection(t)
[view, fig, entries] = makeView(t, 1000);
log = colormeasuretest.field(fig, 'SessionLog');
% A native selection can arrive before its callback is dispatched. An
% unrelated session notification must leave that input and the viewport alone.
set(log, 'Value', 109, 'ListboxTop', 100); drawnow;
top = get(log, 'ListboxTop');
view.update(entries, [16 16 568 440]); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(log, 'Value'), 109);
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 1);
colormeasuretest.click(log);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 109');
end

function testRepeatedSelectionDoesNotLeaveADeferredScrollRequest(t)
[view, fig, entries] = makeView(t, 1000);
log = colormeasuretest.field(fig, 'SessionLog');
set(log, 'Value', 500); colormeasuretest.click(log); colormeasuretest.click(log);
% After clicking the same event twice, scrolling elsewhere remains paused
% across new messages; the old click must not become a deferred reveal.
set(log, 'ListboxTop', 100); drawnow; top=get(log,'ListboxTop');
entries(end+1) = event(1001);
view.update(entries, [16 16 568 440]); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(log, 'Value'), 500);
end

function testAppendPreservesPendingNativeSelectionBeforeItsCallback(t)
[view, fig, entries] = makeView(t, 1000);
log = colormeasuretest.field(fig, 'SessionLog');
set(log, 'Value', 109, 'ListboxTop', 100); drawnow;
entries(end+1) = event(1001);
% The completed measurement can publish a log update before MATLAB dispatches
% the native selection callback. Its event identity must survive that redraw.
view.update(entries, [16 16 568 440]); colormeasuretest.click(log); drawnow;
verifyEqual(t, get(log, 'Value'), 109);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 109');
verifyEqual(t, get(colormeasuretest.field(fig, 'FollowLatest'), 'Value'), 0);
verifyLessThanOrEqual(t, get(log, 'ListboxTop'), 109);
set(log, 'Value', [105 109]); % An earlier modifier-click also retains its endpoint.
entries(end+1) = event(1002);
view.update(entries, [16 16 568 440]); colormeasuretest.click(log);
verifyEqual(t, get(log, 'Value'), 105);
verifyEqual(t, get(colormeasuretest.field(fig, 'LogDetailLabel'), 'String'), 'Message 105');
end

function testFilteredOutAppendDoesNotRedrawOrScrollHistory(t)
[view, fig, entries] = makeView(t, 1000);
filter = colormeasuretest.field(fig, 'LogFilter'); set(filter, 'Value', 2); colormeasuretest.click(filter);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'ListboxTop', 100); drawnow;
top = get(log, 'ListboxTop'); strings = get(log, 'String');
entries(end+1) = event(3); % INFO, excluded by the current filter.
view.update(entries, [16 16 568 440]); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
verifyEqual(t, get(log, 'String'), strings);
entries(end+1) = event(1); % WARNING resumes following a visible new event.
view.update(entries, [16 16 568 440]); drawnow;
verifyGreaterThan(t, get(log, 'ListboxTop'), top);
end

function testCompactAndWideDetailsRetainReadableHistory(t)
[view, fig, entries] = makeView(t, 100);
set(fig, 'Position', [30 30 1024 600]);
view.update(entries, [16 16 300 250]);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'Value', 50); colormeasuretest.click(log);
detail = colormeasuretest.field(fig, 'LogDetails');
ruler = uicontrol(fig, 'Style', 'text', 'Visible', 'off', ...
    'FontName', get(detail,'FontName'), 'FontUnits','pixels', ...
    'FontSize', get(detail,'FontSize'), 'String', 'M');
extent = get(ruler, 'Extent'); delete(ruler);
detailPosition = get(detail, 'Position'); history = get(log, 'Position');
verifyGreaterThanOrEqual(t, detailPosition(4)-8, 3*extent(4));
verifyGreaterThanOrEqual(t, history(4)-8, 2*extent(4));
verifyLessThan(t, detailPosition(2)+detailPosition(4), history(2));
view.update(entries, [16 16 928 180]); drawnow;
detailPosition = get(detail, 'Position'); history = get(log, 'Position');
verifyGreaterThan(t, detailPosition(1), history(1)+history(3));
verifyGreaterThanOrEqual(t, detailPosition(4)-8, 3*extent(4));
verifyGreaterThanOrEqual(t, history(4)-8, 6*extent(4));
verifyEqual(t, get(log, 'Value'), 50);
end

function testUncheckingFollowPreservesScrolledViewport(t)
[view, fig, entries] = makeView(t, 1000);
follow = colormeasuretest.field(fig, 'FollowLatest'); set(follow, 'Value', 0); colormeasuretest.click(follow);
log = colormeasuretest.field(fig, 'SessionLog'); set(log, 'ListboxTop', 300); drawnow;
top = get(log, 'ListboxTop');
entries(end+1) = event(1001); view.update(entries, [16 16 568 440]); drawnow;
verifyEqual(t, get(log, 'ListboxTop'), top);
set(follow, 'Value', 1); colormeasuretest.click(follow); drawnow;
verifyGreaterThan(t, get(log, 'ListboxTop'), 970);
end

function [view, fig, entries] = makeView(t, count)
fig = figure('Visible','off','MenuBar','none','ToolBar','none','Position',[30 30 600 480]);
t.addTeardown(@() delete(fig));
view = colormeasure.ui.LogView(fig); t.addTeardown(@() colormeasuretest.dispose(view));
entries = repmat(event(1),1,count);
for index=1:count, entries(index)=event(index); end
view.update(entries,[16 16 568 440]);
end
function entry = event(index)
levels = {'info','warning','error'};
entry = struct('timeUTC','2026-09-16T12:34:56.789Z', ...
    'level',levels{1+mod(index,3)}, ...
    'message',sprintf('SYNTHETIC EVENT %04d: %s',index,repmat('long/path/',1,20)));
end
function handle = logHandle(fig)
handle = colormeasuretest.field(fig,'SessionLog');
end
