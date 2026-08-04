% Author     :   H. Francalanci
%                Biomechanics and Translational Research in Surgery Group
%                University of Geneva
%                https://www.unige.ch/medecine/chiru/en/research-groups/nicolas-holzer-et-florent-moissenet
% License    :   Creative Commons Attribution-NonCommercial 4.0 International License
%                https://creativecommons.org/licenses/by-nc/4.0/legalcode
% Source code:   To be defined
% Reference  :   To be defined
% Date       :   July 2026
% -------------------------------------------------------------------------
% Description:   Parse a 3D Slicer Markups Fiducial file (.fcsv) into a
%                point matrix and label list.
%                Format (v5.x) : "# columns = id,x,y,z,ow,ox,oy,oz,vis,sel,lock,label,desc,associatedNodeID"
%                Coordinates are in the file's native CoordinateSystem
%                (commented header line, typically LPS for Slicer) and in
%                the CT's native unit (mm) — no conversion is applied here.
% -------------------------------------------------------------------------
% Inputs  : filePath (char) path to a .fcsv file
% Outputs : points (Nx3 double) x,y,z per fiducial, native units/frame
%           labels (Nx1 cell)   fiducial label (column 'label')
% -------------------------------------------------------------------------
% Dependencies : None
% -------------------------------------------------------------------------
% This work is licensed under the Creative Commons Attribution -
% NonCommercial 4.0 International License. To view a copy of this license,
% visit http://creativecommons.org/licenses/by-nc/4.0/ or send a letter to
% Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
% -------------------------------------------------------------------------

function [points, labels] = ReadFcsvPoints(filePath)

fid = fopen(filePath, 'r');
if fid == -1
    error('ReadFcsvPoints:fileNotFound', 'Cannot open %s', filePath);
end
raw = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = raw{1};

points = zeros(0, 3);
labels = {};
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line) || line(1) == '#'
        continue;
    end
    c = strsplit(line, ',');
    points(end+1, :) = [str2double(c{2}), str2double(c{3}), str2double(c{4})]; %#ok<AGROW>
    labels{end+1}    = c{12}; %#ok<AGROW>
end

end
