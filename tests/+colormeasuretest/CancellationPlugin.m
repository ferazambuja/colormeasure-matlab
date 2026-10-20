classdef CancellationPlugin < matlab.unittest.plugins.TestRunnerPlugin
    %CANCELLATIONPLUGIN Stop at a completed-test boundary and retain results.
    properties (SetAccess=private)
        Results = matlab.unittest.TestResult.empty
    end
    properties (Access=private)
        CancellationFile
    end
    methods
        function plugin = CancellationPlugin(cancellationFile)
            plugin.CancellationFile = cancellationFile;
        end
    end
    methods (Access=protected)
        function runTestSuite(plugin,data)
            try
                runTestSuite@matlab.unittest.plugins.TestRunnerPlugin(plugin,data);
            catch exception
                % The framework's public results include completed and allocated
                % incomplete cases while this suite is still unwinding.
                plugin.Results = data.TestResult;
                rethrow(exception);
            end
            plugin.Results = data.TestResult;
        end
        function runTest(plugin,data)
            if isfile(plugin.CancellationFile)
                error('measurement:TestCancelled','Checks were cancelled before the next test.');
            end
            runTest@matlab.unittest.plugins.TestRunnerPlugin(plugin,data);
            if isfile(plugin.CancellationFile)
                error('measurement:TestCancelled','Checks were cancelled after the current test.');
            end
        end
    end
end
