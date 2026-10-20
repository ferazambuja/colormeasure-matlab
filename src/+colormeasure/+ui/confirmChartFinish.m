function accepted=confirmChartFinish(session,purpose,selection,message)
% CONFIRMCHARTFINISH One batch-boundary decision, including chart progress.
% A custom desktop service sees the same retained Session as the native dialog.
arguments
    session
    purpose (1,:) char = 'finish'
    selection (1,1) struct = struct()
    message (1,:) char = ''
end
state=session.chart;
incomplete=~isempty(state)&&state.passes(state.activePass).coverage<state.total;
if strcmp(purpose,'finish')&&~incomplete,accepted=true;return;end
if strcmp(purpose,'change-context')&&isfield(session.services,'confirmContextChange')
    accepted=isequal(session.services.confirmContextChange(session,selection),true);return
end
if strcmp(purpose,'finish')&&isfield(session.services,'confirmChartFinish')
    accepted=isequal(session.services.confirmChartFinish(session),true);return
end
if strcmp(purpose,'change-context')&&~isempty(state)
    retained='The chart setup stays saved in this batch.';
    if numel(state.passes)>1
        retained='The chart setup and earlier passes stay saved in this batch.';
    end
    message=sprintf('%s\n\n%s The new batch does not inherit the chart.',message,retained);
end
if incomplete
    summary=sprintf('Active pass %d: %d of %s measured.',state.activePass, ...
        state.passes(state.activePass).coverage,colormeasure.session.counted(state.total,'patch','patches'));
    message=sprintf('%s\n\n%s',message,summary);
end
if strcmp(purpose,'change-context')
    answer=questdlg(strtrim(message),'Change acquisition context', ...
        'Finish and start new batch','Stay','Stay');
    accepted=strcmp(answer,'Finish and start new batch');
else
    % Finishing keeps this chart inspectable; no new batch is implied.
    message=summary;
    if numel(state.passes)>1
        message=sprintf('%s\nEarlier passes remain saved for inspection.',message);
    end
    message=sprintf('%s\nFinish and save the active incomplete pass, or keep measuring?',message);
    answer=questdlg(message,'Finish chart','Finish incomplete','Keep measuring','Keep measuring');
    accepted=strcmp(answer,'Finish incomplete');
end
end
