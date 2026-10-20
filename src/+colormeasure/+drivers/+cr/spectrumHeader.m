function wl = spectrumHeader(payload)
%SPECTRUMHEADER Remote Communication v1.36 section 4.3.1.37 (p.35).
% https://www.colorimetryresearch.com/downloads
% Optical bandwidth is not output spacing; all models use the returned grid.
h = colormeasure.drivers.cr.numbers(payload, 4);
first = h(1); last = h(2); step = h(3); count = h(4);
if first <= 0 || last <= first || step <= 0 || count < 2 || ...
        count ~= fix(count) || count > 10000 || ...
        abs(first + (count-1)*step - last) > 1e-8*max(1,last)
    error('CR:SpectrumHeader', 'Inconsistent spectrum start, end, spacing or count.');
end
wl = first + (0:count-1)*step;
end
