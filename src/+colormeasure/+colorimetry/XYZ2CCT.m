function [CCT, Duv] = XYZ2CCT(XYZ)
% XYZ2CCT CCT in kelvin and signed Duv for rows of CIE 1931 2-degree XYZ.
%   [CCT, Duv] = colormeasure.colorimetry.XYZ2CCT(XYZ) accepts an N x 3 numeric matrix and
%   returns N x 1 double columns. A 3 x 3 input means three XYZ rows.
%   Duv uses CIE 1960 (u,v), equivalently (u', 2*v'/3).
%   Invalid or unbracketed estimates return a NaN pair without changing XYZ.
%
%   This version preserves the MCSL table and triangular/parabolic method,
%   with the CR v2 applicability policy. It is a compatibility calculation,
%   not an accuracy guarantee. See docs/colorimetry/cct.md for conventions and limits.
%
%   Adapted from RIT-MCSL/MCSL-Tools Convert/XYZ2CCT.m at ce4e63f19ad54617478ff84791483deec920532d.
%   Copyright 2021 Luke Hellwig, Tucker Downs, Minyao Li, Michael Murdoch,
%   and Yongmin Park. MIT license; see THIRD_PARTY_NOTICES.md.
%   Fernando Voltolini de Azambuja, 2026: standalone data loading, guarded
%   batch input, and squared-distance search with three local square roots.
%   Ohno (2014), https://doi.org/10.1080/15502724.2014.839020.
narginchk(1,1);
if ~isnumeric(XYZ) || ~ismatrix(XYZ) || size(XYZ,2) ~= 3
    error('colormeasure:Colorimetry:InvalidXYZ', 'XYZ must be an N x 3 numeric matrix of XYZ rows.');
end
XYZ = double(XYZ);
CCT = NaN(size(XYZ,1),1);
Duv = NaN(size(XYZ,1),1);

persistent temperatures locus
if isempty(temperatures)
    root = colormeasure.root();
    data = load(fullfile(root,'resources','colorimetry','PlanckLocus.mat'), 'cct', 'uvY1960');
    if ~isfield(data,'cct') || ~isfield(data,'uvY1960') || ...
            ~isnumeric(data.cct) || ~isvector(data.cct) || ...
            ~isnumeric(data.uvY1960) || size(data.uvY1960,2) < 2
        error('colormeasure:Colorimetry:PlanckData', 'The bundled Planckian locus table is invalid.');
    end
    candidateT = data.cct(:);
    candidateLocus = data.uvY1960(:,1:2);
    if numel(candidateT) < 3 || size(candidateLocus,1) ~= numel(candidateT) || ...
            ~isreal(candidateT) || ~isreal(candidateLocus) || ...
            any(~isfinite(candidateT)) || any(~isfinite(candidateLocus),'all') || ...
            any(diff(candidateT) <= 0) || candidateT(1) ~= 1000 || candidateT(end) ~= 25000
        error('colormeasure:Colorimetry:PlanckData', 'The bundled Planckian locus table is invalid.');
    end
    temperatures = candidateT;
    locus = candidateLocus;
end

for j = 1:size(XYZ,1)
    value = XYZ(j,:);
    if ~isreal(value) || any(~isfinite(value)) || any(value < 0) || value(2) <= 0
        continue
    end
    % CCT is scale invariant. Normalize only the calculation to avoid overflow.
    value = value ./ max(value);
    denominator = value(1) + 15*value(2) + 3*value(3);
    uv = [4*value(1) 6*value(2)] ./ denominator;

    % The minimizing index is unchanged by squaring nonnegative distances.
    % Keep the first minimum to make an exact tie deterministic.
    squaredDistances = sum((locus - uv).^2,2);
    [~, m] = min(squaredDistances);
    if m == 1 || m == numel(temperatures)
        continue % No pair of surrounding temperatures brackets this estimate.
    end
    distance = sqrt(squaredDistances(m-1:m+1));
    t = temperatures(m-1:m+1);
    l = sqrt(sum((locus(m-1,:) - locus(m+1,:)).^2));
    x = (distance(1)^2 - distance(3)^2 + l^2) / (2*l);
    estimate = t(1) + (t(3)-t(1))*(x/l);
    vTx = locus(m-1,2) + (locus(m+1,2)-locus(m-1,2))*(x/l);
    radialSquared = distance(1)^2 - x^2;
    % The squared perpendicular distance is nonnegative geometrically. At a
    % chord midpoint subtraction can lose a few ulps; clamp only that roundoff.
    if radialSquared < 0
        tolerance = 8*eps(max(distance(1)^2, x^2));
        if radialSquared < -tolerance, continue; end
        radialSquared = 0;
    end
    signedDistance = sqrt(radialSquared)*sign(uv(2)-vTx);

    if abs(signedDistance) > 0.002
        product = (t(3)-t(2))*(t(1)-t(3))*(t(2)-t(1));
        a = (t(1)*(distance(3)-distance(2)) + ...
            t(2)*(distance(1)-distance(3)) + ...
            t(3)*(distance(2)-distance(1))) * product^-1;
        b = -(t(1)^2*(distance(3)-distance(2)) + ...
            t(2)^2*(distance(1)-distance(3)) + ...
            t(3)^2*(distance(2)-distance(1))) * product^-1;
        c = -(distance(1)*(t(3)-t(2))*t(2)*t(3) + ...
            distance(2)*(t(1)-t(3))*t(1)*t(3) + ...
            distance(3)*(t(2)-t(1))*t(1)*t(2)) * product^-1;
        estimate = -(b/(2*a));
        signedDistance = sign(uv(2)-vTx)*(a*estimate^2+b*estimate+c);
    end

    % Preserve the legacy positive-boundary rejection as well as CR's
    % two-sided applicability check. CCT and Duv are always available together.
    if ~isreal(estimate) || ~isreal(signedDistance) || ...
            ~isfinite(estimate) || ~isfinite(signedDistance) || ...
            estimate <= temperatures(1) || estimate >= temperatures(end) || ...
            signedDistance >= 0.05 || abs(signedDistance) > 0.05
        continue
    end
    CCT(j) = estimate;
    Duv(j) = signedDistance;
end
end
