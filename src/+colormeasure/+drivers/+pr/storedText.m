function text = storedText()
%STOREDTEXT Exact stored PR text shared by acquisition and presentation.
%   Readings store these strings and viewData recognizes them with strcmp;
%   changing either changes saved data and the comparisons that recognize it.
text = struct('xyzMethod','colormeasure.colorimetry.spectra2XYZ; CIE 1931 2-degree observer; MCSL-compatible v1', ...
    'spectralUnits','Instrument units; raw M5 unitsCode retained');
end
