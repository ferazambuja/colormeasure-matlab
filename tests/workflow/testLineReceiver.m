function tests = testLineReceiver
% The line receiver shared by the CR and CS-2000 transports: terminator and
% optional-LF rules, reassembly of fragmented replies, the 4096-byte cap, the
% family's own identifiers and messages, and deadline loops that run on the
% injected clock and never sleep past the deadline.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
colormeasuretest.setupPaths(testCase);
end

function testLineEndsAtCarriageReturnOrLineFeedAndDropsThePairedLineFeed(testCase)
[receiver, port] = fixture();
port.inject(sprintf('ab\r\ncd\nef\r'));
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'ab');
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'cd');
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'ef');
verifyEmpty(testCase, receiver.Buffer);
port.inject(sprintf('\ngh\n')); % The LF completing the last CR arrives later.
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'gh');
verifyEmpty(testCase, receiver.Buffer);
end

function testFragmentedReplyIsReassembledOnSimulatedTime(testCase)
[receiver, port, clock] = fixture();
port.inject('OK:0:RC Model:', 0);
port.inject('CR-250', 0.3);
port.inject(sprintf('\r\n'), 0.6);
verifyEqual(testCase, receiver.readLine(port, clock.now(), 2), 'OK:0:RC Model:CR-250');
verifyGreaterThanOrEqual(testCase, clock.now(), 0.6);
verifyLessThan(testCase, clock.now(), 0.61);
end

function testTimeoutUsesTheFamilyMessageAndNeverSleepsPastTheDeadline(testCase)
[receiver, port, clock] = fixture();
started = clock.now();
verifyError(testCase, @() receiver.readLine(port, started, 0.05), 'CR:Timeout');
try
    receiver.readLine(port, clock.now(), 0.05);
    verifyFail(testCase, 'The second read must time out as well.');
catch err
    verifyEqual(testCase, err.message, 'Timed out after 0.05 seconds waiting for a complete CR reply.');
end
verifyTrue(testCase, all(clock.Sleeps <= 0.005));
verifyEqual(testCase, clock.now() - started, 0.1, 'AbsTol', 1e-12);
end

function testLineArrivingDuringTheLastSleepIsReturnedAtTheDeadline(testCase)
[receiver, port, clock] = fixture();
port.inject(sprintf('late\r'), 0.0175); % inside the final 5 ms sleep before 0.02 s
verifyEqual(testCase, receiver.readLine(port, clock.now(), 0.02), 'late');
verifyEqual(testCase, clock.now(), 0.02, 'AbsTol', 1e-12);
verifyTrue(testCase, all(clock.Sleeps <= 0.005));
end

function testOverlongLinesFailWithTheFamilyFramingMessages(testCase)
[receiver, port] = fixture();
port.inject(repmat('x', 1, 4097));
try
    receiver.readLine(port, 0, 1);
    verifyFail(testCase, 'An unterminated overlong line must fail.');
catch err
    verifyEqual(testCase, err.identifier, 'CR:Framing');
    verifyEqual(testCase, err.message, 'Response line exceeds 4096 bytes. Check ECHO is off.');
end
[receiver, port] = fixture();
port.inject([repmat('y', 1, 4097) sprintf('\r')]);
try
    receiver.readLine(port, 0, 1);
    verifyFail(testCase, 'A terminated overlong line must fail.');
catch err
    verifyEqual(testCase, err.identifier, 'CR:Framing');
    verifyEqual(testCase, err.message, 'Response line exceeds 4096 bytes.');
end
[receiver, port] = fixture();
port.inject([repmat('z', 1, 4096) sprintf('\r\n')]);
verifyEqual(testCase, numel(receiver.readLine(port, 0, 1)), 4096);
end

function testExactlyFourThousandNinetySixUnterminatedBytesStillWaitForTheTerminator(testCase)
[receiver, port, clock] = fixture();
port.inject(repmat('w', 1, 4096));
verifyError(testCase, @() receiver.readLine(port, clock.now(), 0.02), 'CR:Timeout'); % waits, no framing error
verifyEqual(testCase, numel(receiver.Buffer), 4096);
port.inject('w'); % the 4097th byte without a terminator
try
    receiver.readLine(port, clock.now(), 1);
    verifyFail(testCase, 'The 4097th unterminated byte must fail.');
catch err
    verifyEqual(testCase, err.identifier, 'CR:Framing');
end
end

function testClearForgetsBufferedBytesAndThePendingLineFeed(testCase)
[receiver, port] = fixture();
port.inject(sprintf('ab\rcd'));
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'ab');
verifyEqual(testCase, receiver.Buffer, 'cd');
receiver.clear();
verifyEmpty(testCase, receiver.Buffer);
% A CR that ends the input leaves its optional LF pending; clear forgets it.
[receiver, port] = fixture();
port.inject(sprintf('ab\r'));
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'ab');
verifyEmpty(testCase, receiver.Buffer);
receiver.clear();
port.inject(sprintf('\nef\n')); % No pending CR after clear, so this LF ends an empty line.
emptyLine = receiver.readLine(port, 0, 1);
verifyEmpty(testCase, emptyLine); verifyClass(testCase, emptyLine, 'char');
verifyEqual(testCase, receiver.readLine(port, 0, 1), 'ef');
end

function testMessagesMustBeComplete(testCase)
verifyError(testCase, @() colormeasure.drivers.LineReceiver(struct('prefix', 'CR')), ...
    'Measurement:LineReceiver');
end

function testRealClockCountsWallSecondsAndSleeps(testCase)
clock = colormeasure.drivers.RealClock();
first = clock.now(); clock.sleep(0.02);
verifyGreaterThanOrEqual(testCase, clock.now() - first, 0.015);
receiver = colormeasure.drivers.LineReceiver(messages());
earlier = receiver.now(); pause(0.02); later = receiver.now();
verifyGreaterThanOrEqual(testCase, later - earlier, 0.015, 'the default clock is the wall clock');
end

function [receiver, port, clock] = fixture()
clock = colormeasuretest.FakeClock();
receiver = colormeasure.drivers.LineReceiver(messages(), clock);
port = colormeasuretest.cr.Port('CR-250', clock);
end

function value = messages()
value = struct('prefix', 'CR', ...
    'timeout', 'Timed out after %.3g seconds waiting for a complete CR reply.', ...
    'overflow', 'Response line exceeds 4096 bytes.', ...
    'overflowUnterminated', 'Response line exceeds 4096 bytes. Check ECHO is off.');
end

function testDrainKeepsBufferedAndFragmentedBytesAndObservesTheQuietInterval(t)
[receiver,port,clock]=fixture();
port.inject('buffered');receiver.collect(port);
port.inject('later',0.03);
status=receiver.drain(port,0.04,0.2,65536,'quiet interval missing');
verifyEqual(t,status.discardedBytes,uint8('bufferedlater'));
verifyTrue(t,status.attempted);verifyTrue(t,status.quietObserved);
verifyGreaterThanOrEqual(t,clock.now(),0.07);
verifyEmpty(t,receiver.Buffer);
verifyEqual(t,status,receiver.RecoveryStatus);
end

function testDrainQuietByTheDeadlineIsObservedNotTimedOut(t)
% The quiet interval completes exactly at the deadline; the final check sees it.
[receiver,port,clock]=fixture();
port.inject('late');receiver.collect(port);
status=receiver.drain(port,0.003,0.003,65536,'quiet interval missing');
verifyTrue(t,status.quietObserved);
verifyEqual(t,status.discardedBytes,uint8('late'));
verifyEqual(t,clock.now(),0.003);
end

function testDrainQuietAfterLaterBytesCanEndExactlyAtTheDeadline(t)
% Callers require timeout greater than quietPeriod. Later bytes can still
% move the beginning of quiet so its final check coincides with the deadline.
[receiver,port,clock]=fixture();
port.inject('initial');receiver.collect(port);port.inject('last',0.003);
status=receiver.drain(port,0.005,0.01,65536,'quiet interval missing');
verifyTrue(t,status.quietObserved);
verifyEqual(t,status.discardedBytes,uint8('initiallast'));
verifyEqual(t,clock.now(),0.01,'AbsTol',1e-12);
end

function testDrainRefusesQuietFirstObservedAfterASchedulerJump(t)
% A delayed sleep may overrun the real deadline. It must not authorize the
% next identity command merely because the port is empty after that jump.
clock=colormeasuretest.FakeClock();
oversleeping=struct('now',@()clock.now(),'sleep',@oversleep);
receiver=colormeasure.drivers.LineReceiver(messages(),oversleeping);
port=colormeasuretest.cr.Port('CR-250',clock);
port.inject('kept');receiver.collect(port);
verifyError(t,@()receiver.drain(port,0.005,0.01,65536,'quiet interval missing'),'CR:DrainTimeout');
verifyFalse(t,receiver.RecoveryStatus.quietObserved);
verifyEqual(t,receiver.RecoveryStatus.discardedBytes,uint8('kept'));
verifyEqual(t,clock.now(),0.025,'AbsTol',1e-12);
verifyEmpty(t,port.State('commands'));
    function oversleep(duration)
        clock.sleep(duration);clock.advance(0.02);
    end
end

function testDrainFailuresRetainDiagnosticsAndDoNotExceedTheDeadline(t)
[receiver,port,~]=fixture();
port.inject('kept');receiver.collect(port);port.inject('oversize');
verifyError(t,@()receiver.drain(port,0.04,0.2,8,'quiet interval missing'),'CR:DrainLimit');
verifyEqual(t,receiver.RecoveryStatus.discardedBytes,uint8('kept'));
verifyFalse(t,receiver.RecoveryStatus.quietObserved);
[receiver,port,clock]=fixture();
for at=0:0.01:0.1,port.inject('busy',at);end
verifyError(t,@()receiver.drain(port,0.04,0.05,Inf,'quiet interval missing'),'CR:DrainTimeout');
verifyEqual(t,clock.now(),0.05,'AbsTol',1e-12);
verifyNotEmpty(t,receiver.RecoveryStatus.discardedBytes);
verifyFalse(t,receiver.RecoveryStatus.quietObserved);
end

function testDrainRefusesAnOversizedInitialBufferEvenWithoutNewPortBytes(t)
[receiver,port]=fixture();port.inject(repmat('b',1,9));receiver.collect(port);
verifyEqual(t,port.NumBytesAvailable,0);
verifyError(t,@()receiver.drain(port,0.04,0.2,8,'quiet interval missing'),'CR:DrainLimit');
verifyEqual(t,receiver.RecoveryStatus.discardedBytes,uint8(repmat('b',1,9)));
verifyFalse(t,receiver.RecoveryStatus.quietObserved);
verifyEqual(t,receiver.Buffer,repmat('b',1,9));
end
