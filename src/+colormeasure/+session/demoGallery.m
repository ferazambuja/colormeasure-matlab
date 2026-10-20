function demoGallery(session, profiles, annotate)
%DEMOGALLERY Populate a live session with one synthetic reading per profile.
%   demoGallery(session, profiles, annotate) measures each profile under a
%   numbered name and a SYNTHETIC GALLERY note; the optional annotate
%   function (index, name, notes) returns the name and notes to use and lets
%   a family vary particular entries. Population stops at the first refused
%   reading. Shared by the family demo sessions.
%   Fernando Voltolini de Azambuja, 2026.
if nargin < 3, annotate = @(~, name, notes) deal(name, notes); end
for index = 1:numel(profiles)
    name = sprintf('Sample %03d - %s', index, profiles(index).name);
    notes = sprintf('SYNTHETIC GALLERY: %s Not a measured or calibrated reference.', ...
        profiles(index).description);
    [name, notes] = annotate(index, name, notes);
    if ~session.measure(name, notes), break, end
end
end
