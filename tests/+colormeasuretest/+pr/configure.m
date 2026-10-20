function configure(varargin)
%CONFIGURE Set the simulated PR state shared with the fake serial connection.
% Defaults describe a PR-655 on one virtual port replying with a flat unit
% spectrum; options override the model (PR-670 steps 2 nm), ports, the
% macOS flag, the units code of the frame header, the metadata replies
% (D110, D114, D13), the flicker frequency text and the whole frame.
p = inputParser;
p.addParameter('Model','PR-655');
p.addParameter('Ports',"VIRTUAL");
p.addParameter('OnMac',false);
p.addParameter('UnitsCode',0);
p.addParameter('D110','00000,655 SESSION-1');
p.addParameter('D114','00000,2.22D');
p.addParameter('D13','00000,Normal,25 msec');
p.addParameter('Hertz','60.00 Hertz');
p.addParameter('Frame',[]);
p.parse(varargin{:});
o = p.Results;
step = 4; if strcmp(o.Model,'PR-670'), step = 2; end
frame = o.Frame;
if isempty(frame)
    frame = [sprintf('00000,%d,0.000e+000,1.827e-01,5.147e+01\r\n',o.UnitsCode) ...
        sprintf('%d,1.000e+00\r\n',380:step:780)];
end
colormeasuretest.pr.state(struct('ports',o.Ports,'listModes',{{}},'onMac',o.OnMac, ...
    'openedPort','','closed',false,'commands',{{}},'identityReply',['00000,' o.Model], ...
    'remoteReply',sprintf('REMOTE MODE\r\n'), ...
    'metadataReplies',struct('D110',o.D110,'D114',o.D114, ...
        'D602',['00000,MS-75,None,None,None,1 deg,English,Adaptive,0 msec,Normal,' ...
        '1 cycles,2 deg,No Smart Dark,No Sync,Standard Sensitivity,' o.Hertz], ...
        'D13',o.D13),'metadataUnterminated',{{}}, ...
    'flickerReply',['00000,Auto Sync,' o.Hertz],'echo',false,'failRestore',false, ...
    'chunks',{{frame}},'delays',0));
end
