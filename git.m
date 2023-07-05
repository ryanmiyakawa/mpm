
function git(varargin)
celAsVar = varargin;
for i = 1:numel(celAsVar)
    % Check if the element contains multiple words (space-separated)
    if contains(celAsVar{i}, ' ')
        % Add double quotes to the element
        celAsVar{i} = ['"', celAsVar{i}, '"'];
    end
end
cmd = strjoin(celAsVar, ' ');

system(['git ', cmd]);
