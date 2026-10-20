classdef testCS2000Deadlines < matlab.unittest.TestCase
    % Deadline boundary checks against a simulated clock. The in-memory peer
    % and the driver share one colormeasuretest.FakeClock, so the 35-second
    % pre-measurement policy and a 10.2-second first reply are exercised
    % exactly, without wall-clock waits.
    methods (TestClassSetup)
        function prepare(testCase)
            colormeasuretest.setupPaths(testCase);
        end
    end
    methods (Test)
        function firstReplyAfterTenSecondsStillCommits(testCase)
            clock = colormeasuretest.FakeClock();
            peer = colormeasuretest.cs2000.Port(clock); state = peer.State;
            meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',peer, ...
                'ResponseTimeout',0.05,'Clock',clock);
            testCase.addTeardown(@()delete(meter));
            meter.Connect();
            % One delayed chunk contains both complete frames. Ordinary
            % ResponseTimeout cannot account for this 10.2-second interval.
            text = sprintf('OK00,002\r\nOK00\r\n');
            peer.queue('MEAS,1',text,numel(text),10.2);
            started = clock.now(); wall = tic; meter.Measure(); elapsed = clock.now() - started;
            testCase.verifyGreaterThanOrEqual(elapsed,10.2);
            testCase.verifyLessThan(elapsed,35);
            testCase.verifyLessThan(toc(wall),5); % Simulated time, not waited.
            testCase.verifyEqual(numel(meter.metadata),1);
            testCase.verifyTrue(meter.isConnected());
            testCase.verifyEqual(sum(strcmp(state('commands'),'MEAS,1')),1);
        end

        function missingFirstReplyTimesOutAtThirtyFiveSeconds(testCase)
            clock = colormeasuretest.FakeClock();
            peer = colormeasuretest.cs2000.Port(clock); state = peer.State;
            meter = colormeasure.drivers.cs2000.CS2000('SIM','Transport',peer, ...
                'ResponseTimeout',0.05,'Clock',clock);
            testCase.addTeardown(@()delete(meter));
            meter.Connect(); peer.queue('MEAS,1','');
            started = clock.now(); wall = tic;
            testCase.verifyError(@()meter.Measure(),'CS2000:Timeout');
            elapsed = clock.now() - started;
            testCase.verifyGreaterThanOrEqual(elapsed,35);
            testCase.verifyLessThan(elapsed,35.01); % The loop never sleeps past the deadline.
            testCase.verifyLessThan(toc(wall),5);
            testCase.verifyEmpty(meter.metadata);
            testCase.verifyTrue(state('deleted'));
            commands = state('commands');
            testCase.verifyEqual(commands{end},'MEAS,1');
            testCase.verifyEqual(sum(strcmp(commands,'MEAS,1')),1);
            testCase.verifyFalse(meter.cleanupStatus.remoteReleased);
        end
    end
end
