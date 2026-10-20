function [session,state]=continuationBatch(folder,io,opticalMode)
%CONTINUATIONBATCH Known virtual CR-250 identity and capture facts for software checks.
% These explicit fixture facts are simulated, not inferred physical metadata.
state=containers.Map('KeyType','char','ValueType','any');
state('reads')=0;state('saves')=0;state('failSave')=false;
state('serial')='VIRTUAL-CR250-001';state('loseScale')=false;
state('duringRead')=@()[];state('duringSave')=@()[];state('failRelease')=false;
state('connects')=0;state('releases')=0;
adapter=colormeasure.drivers.cr.demoAdapter('CR250','interactive');
if nargin>=3,adapter.configuration.opticalMode=opticalMode;end
acquire=adapter.read;apply=adapter.settings.apply;read=adapter.settings.read;connect=adapter.connect;release=adapter.release;
adapter.connect=@connection;adapter.release=@releaseInstrument;
adapter.read=@reading;adapter.settings.read=@settings;adapter.settings.apply=@applySettings;
if nargin<2,io=colormeasure.session.services();end
io.saveMat=@save;
session=colormeasure.session.Session(adapter,folder,io);
    function value=reading(instrument)
        callback=state('duringRead');callback();
        state('reads')=state('reads')+1;value=acquire(instrument);
        value.xyzScale='fixture synthetic common scale';
        if state('loseScale'),value.xyzScale='unknown';end
        value.instrumentMetadata=struct('identity',identity());
    end
    function value=identity()
        value=struct('model','CR-250','serialNumber',state('serial'),'synthetic',true);
    end
    function value=settings(instrument)
        value=read(instrument);value.identity=identity();
        value.values.maxAutoExposureMs=10000;
    end
    function value=applySettings(instrument,overrides)
        value=apply(instrument,overrides);
        value.before.identity=identity();value.after.identity=identity();
        value.before.values.maxAutoExposureMs=10000;value.after.values.maxAutoExposureMs=10000;
    end
    function save(measurements,destination,info)
        state('saves')=state('saves')+1;
        callback=state('duringSave');callback();
        if state('failSave'),error('Fixture:Save','Synthetic disk failure.');end
        colormeasure.session.saveMat(measurements,destination,info);
    end
    function instrument=connection(port)
        state('connects')=state('connects')+1;instrument=connect(port);
    end
    function releaseInstrument(instrument)
        state('releases')=state('releases')+1;
        release(instrument);
        if state('failRelease'),error('Fixture:Release','Synthetic unconfirmed release.');end
    end
end
