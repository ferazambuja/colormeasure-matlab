function [html, plain] = helpHtml(title, paragraphs, headings, style, details)
%HELPHTML Format plain operating help as static, selectable HTML.
% Text is always escaped. A nested cell/string array is a bulleted list;
% missing headings leave the corresponding paragraph intact.
% Optional technical details use a native HTML disclosure; all text remains
% escaped and is also included in the plain-text output. DETAILS is a list of
% lines under "Technical details", or struct('summary',label,'lines',list).
% Fernando Voltolini de Azambuja, 2026.
if nargin < 3, headings = {}; end
if nargin < 4, style = 'light'; end
if nargin < 5, details = {}; end
if ~iscell(paragraphs), paragraphs = cellstr(string(paragraphs(:))); end
headings = cellstr(string(headings(:)));
if strcmp(style,'dark')
    style = 'dark';
    background = '#242424'; foreground = '#eeeeee'; border = '#666666';
else
    style = 'light';
    background = '#ffffff'; foreground = '#202020'; border = '#b8b8b8';
end
plain = {char(title)};
body = ['<h1>' escape(title) '</h1>'];
for k = 1:numel(paragraphs)
    if k <= numel(headings) && ~isempty(headings{k})
        body = [body '<h2>' escape(headings{k}) '</h2>']; %#ok<AGROW>
        plain = [plain; {''; headings{k}}]; %#ok<AGROW>
    end
    paragraph = paragraphs{k};
    if iscell(paragraph) || (isstring(paragraph) && ~isscalar(paragraph))
        items = cellstr(string(paragraph(:)));
        body = [body '<ul>']; %#ok<AGROW>
        for item = 1:numel(items)
            body = [body '<li>' escape(items{item}) '</li>']; %#ok<AGROW>
            plain{end+1,1} = ['- ' items{item}]; %#ok<AGROW>
        end
        body = [body '</ul>']; %#ok<AGROW>
    else
        body = [body '<p>' escape(paragraph) '</p>']; %#ok<AGROW>
        plain = [plain; {''; char(paragraph)}]; %#ok<AGROW>
    end
end
summary = 'Technical details';
if isstruct(details), summary = details.summary; details = details.lines; end
if ~isempty(details)
    % Static disclosure, with browser keyboard behavior and no MATLAB callback.
    % https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element
    body = [body '<details><summary>' escape(summary) '</summary>'];
    plain = [plain; {''; summary}];
    details = cellstr(string(details(:)));
    for k = 1:numel(details)
        body = [body '<p>' escape(details{k}) '</p>']; %#ok<AGROW>
        plain = [plain; {''; details{k}}]; %#ok<AGROW>
    end
    body = [body '</details>'];
end
html = ['<!doctype html><html lang="en"><head><meta charset="utf-8">' ...
    '<meta name="viewport" content="width=device-width,initial-scale=1">' ...
    '<style>html{color-scheme:' char(style) ';background:' background ';color:' foreground '}' ...
    'body{margin:0;padding:12px 14px;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;' ...
    'overflow-wrap:anywhere;user-select:text;-webkit-user-select:text;cursor:text}' ...
    'main:focus-visible,summary:focus-visible{outline:2px solid ' border ';outline-offset:2px}' ...
    'summary{cursor:pointer;margin:0 0 12px}details{margin-top:12px}' ...
    'h1{font-size:17px;line-height:1.3;margin:0 0 12px}' ...
    'h2{font-size:14px;line-height:1.35;margin:18px 0 5px;font-weight:650}' ...
    'p{margin:0 0 12px;white-space:pre-wrap}ul{padding-left:22px;margin:5px 0 12px}' ...
    'li{padding-left:2px;margin:4px 0;white-space:pre-wrap}' ...
    '</style></head><body><main tabindex="0" aria-label="' escape(title) '">' ...
    body '</main></body></html>'];
end

function text = escape(value)
text = char(string(value));
text = strrep(text,'&','&amp;');
text = strrep(text,'<','&lt;');
text = strrep(text,'>','&gt;');
text = strrep(text,'"','&quot;');
text = strrep(text,'''','&#39;');
end
