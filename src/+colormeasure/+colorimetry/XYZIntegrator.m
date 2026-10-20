classdef XYZIntegrator
    % XYZINTEGRATOR Prepare repeated spectral-to-XYZ calculations on one grid.
    %   p = colormeasure.colorimetry.XYZIntegrator(wavelength_nm); XYZ = p.convert(spectra);
    %   Wavelengths must be double precision; spectra may be single or double.
    %   Spectra are N-wavelength x M-reading or its transpose. Square arrays
    %   contain spectra in columns. Output is always M x 3 double.
    %
    %   Compatibility convention: CIE 1931 2-degree, spline-interpolated CMFs,
    %   zero outside 360-830 nm, uniform inclusive rectangle sum, inherited
    %   MCSL photometric factor. This is not a calibration or new integration
    %   standard. Signed bins are retained. See docs/colorimetry/science.md.
    %   Fernando Voltolini de Azambuja, 2026.
    properties (SetAccess = immutable)
        Wavelength
        Step
        Scale
    end
    properties (GetAccess = private, SetAccess = immutable)
        MatchingFunctions
    end
    methods
        function obj = XYZIntegrator(wavelength)
            [wavelength, step] = uniformGrid(wavelength);
            [cmf, native] = colormeasure.colorimetry.observer();
            % Exact native samples need no interpolation. Off-grid samples
            % retain the school's spline convention for numerical continuity.
            if all(wavelength==fix(wavelength))
                matching = zeros(numel(wavelength),3);
                inside = wavelength>=native(1) & wavelength<=native(end);
                matching(inside,:) = cmf(wavelength(inside)-native(1)+1,:);
            else
                matching = interp1(native,cmf,wavelength,'spline',0);
            end
            peakNm = (299792458 / 540e12) / 1e-9;
            obj.Wavelength = wavelength;
            obj.Step = step;
            obj.Scale = 683*obj.Step / interp1(native,cmf(:,2),peakNm);
            if ~isfinite(obj.Scale)
                error('colormeasure:Colorimetry:NumericRange','Wavelength step exceeds the calculation range.');
            end
            obj.MatchingFunctions = matching;
        end
        function XYZ = convert(obj,spectra)
            spectra=spectralColumns(spectra,numel(obj.Wavelength),'Spectra');
            % Keep scale outside the product, matching the legacy operation
            % order. Do not resample, clip or independently normalize readings.
            XYZ = obj.Scale .* (obj.MatchingFunctions.' * spectra).';
            if any(~isfinite(XYZ),'all')
                error('colormeasure:Colorimetry:NumericRange','XYZ exceeds the finite calculation range.');
            end
        end
    end
end
