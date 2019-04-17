function mpm(varargin)


%     curDir = cd;

    % Load package information from package.json
    [cePackageNames, stPackages] = getPackageListFromJson('packages.json');


    if isempty(varargin)
        direct = 'help';
    else
        direct = varargin{1};
    end

%     try

    if direct(1) == '-'
        direct = direct(2:end);
    end

    switch direct
        case {'install', 'i'}
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            dDepth = 0;

            if length(varargin) == 1
                % install/update all from packages.json
                
                for k = 1:length(cePackageNames)
                    stPackages = installPackage(cePackageNames{k}, stPackages, dDepth);
                end

            else
                % Just install specific packages
                cPackageName = regexprep(varargin{2}, '-', '_');
                stPackages = installPackage(cPackageName, stPackages, dDepth);
            end
            
            % now write packages.json back to file:
            fid         = fopen('packages.json', 'w');
            fwrite(fid, jsonencode(stPackages));
            fclose(fid);
        case {'uninstall', 'u'}
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            if length(varargin) ~= 2
                error('Must specify package name to uninstall, type "mpm help" for details');
            end
            
            cPackageName = regexprep(varargin{2}, '-', '_');
            stPackages = uninstallPackage(cPackageName, stPackages);
            
            % now write packages.json back to file:
            fid         = fopen('packages.json', 'w');
            fwrite(fid, jsonencode(stPackages));
            fclose(fid);
            
        case {'help', 'h'}
            printHelp();
        case {'list', 'l'}
            listPackages();
            
        case 'push'
            
            if length(varargin) < 2
                fprintf('Please add commit message before pushing\n\n');
                return
            end
            cCurDir = cd;
            [d, ~] = fileparts(mfilename('fullpath'));
            cd(d);
            
            
            cAddText = '';
            for k = 2:length(varargin)
                cAddText = [cAddText ' ' varargin{k}]; %#ok<AGROW>
            end
            
            system('git add .');
            system(sprintf('git commit -m "%s"', cAddText));
            system('git push origin master');
            
            cd (cCurDir);
            
        case 'init'
            mpminit();
            
        case {'update'}
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
             printVersion();
            mpmupdate();

        case 'status'
            
            
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            
            printVersion();
            listInstalledPackages()
            
            
            % Loop through packages and run a status on each
            for k = 1:length(cePackageNames)
                fprintf('\n---------------------------------------\nStatus of package: %s\n---------------------------------------\n', getRepoName(cePackageNames{k}));
                gitstatus(getRepoName(cePackageNames{k}));
            end

        case {'register', 'r'}
            if length(varargin) ~= 3
                error('Required format: mpm register [package name] [package git repo url or github url]');
            end
            cPackageName = varargin{2};
            cPackageNameSanitized = regexprep(varargin{2}, '-', '_');
            [p, d, e] = fileparts(varargin{3});
            if isempty(e)
                e = '.git';
            end
            cRepoName = fullfile(p,[d,e]);
            mpmregister(cPackageName, cPackageNameSanitized, cRepoName);
        case {'addpath', 'a'}
            if ~checkmpmexists()
                fprintf('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            % adds path of mpm-packages to general path
            if length(varargin) == 2
                cPathVar = fullfile(varargin{2}, 'mpm-packages');
            else
                cPathVar = 'mpm-packages';
            end
            
            fprintf('Adding %s to MATLAB path\n', cPathVar);
            addpath(genpath(cPathVar));
            
        case {'ver', 'version', 'v'}
            
            fid         = fopen('changelog', 'r');
            cChangelog    = fread(fid, inf, 'uint8=>char')';
            fclose(fid);
            
            printVersion();
            
            if length(varargin) == 1 || ~strcmp(varargin{2}, 'nochangelog')
                fprintf('Version history:\n----------------\n%s\n\n', cChangelog);
            end
                
        case {'newversion', 'new-version', 'n'}
            cCurDir = cd;
            [d, ~] = fileparts(mfilename('fullpath'));
            cd(d);
 
    
            fid         = fopen('version', 'r');
            cVersion    = fread(fid, inf, 'uint8=>char')';
            fclose(fid);
            
            [~, d2, ~] = regexp(cVersion, 'v(\d+)\.(\d+)\.(\d+)', 'match', 'tokens');
            
            dVs = d2{1};
            
            cVersion = sprintf('v%d.%d.%d',...
                    str2double(dVs{1}), str2double(dVs{2}), str2double(dVs{3}) + 1);
            
            fid         = fopen('version', 'w');
            fwrite(fid, cVersion);
            fclose(fid);
            
            
            if length(varargin) >= 2
                
                fid         = fopen('changelog', 'r');
                cText    = fread(fid, inf, 'uint8=>char')';
                fclose(fid);
                
                cAddText = '';
                for k = 2:length(varargin)
                    cAddText = [cAddText ' ' varargin{k}]; %#ok<AGROW>
                end
                if cAddText(1) == '"'
                    cAddText = cAddText(2:end);
                end
                if cAddText(end) == '"'
                    cAddText = cAddText(1:end-1);
                end
                
                fid         = fopen('changelog', 'w');
                cNewChangelogText = sprintf('%s -%s\n%s', cVersion, cAddText, cText);
                fwrite(fid, cNewChangelogText);
                fclose(fid);
                
                fprintf('Added new version %s\n\n CHANGELOG: \n%s\n\n', cVersion, cNewChangelogText);
            end
               cd(cCurDir);
            
            
            
        otherwise
            
            
            error('Unknown directive "%s", run "mpm help" to see valid usage', direct);
            

            
    end
    
%     catch
%         error (lasterr);
%     end

end

function lVal = checkmpmexists()
    lVal =  checkpackagsjsonexists() && checkmpmpackagesexists();
end

function lVal = checkpackagsjsonexists()
    lVal =  ~isempty(dir('packages.json'));
end

function lVal = checkmpmpackagesexists()
    lVal =   ~isempty(dir('mpm-packages'));
end


function mpminit()
printVersion();
% check if init has happened already:
    if checkmpmexists()
        fprintf('MPM already initialized to directory %s \n', cd);
    end
    
    
    if isempty(dir('mpm-packages'))
        mkdir('mpm-packages');
    end

    if isempty(dir('packages.json'))
        fid = fopen('packages.json', 'w');
        fclose(fid);
    end
    fprintf('MPM initialized in directory %s \n', cd);
    
    % Check if .gitignore exists, and if it does, cat mpm-packages to it:
    if ~isempty(dir('.gitignore'))
        fid         = fopen('.gitignore', 'r');
        cText       = (fread(fid, inf, 'uint8=>char'))';
        fclose(fid);
        
        if ~contains(cText, 'mpm-packages')
            fprintf('Adding "mpm-packages" to .gitignore\n\n');
            cText = sprintf('%s\n%s', cText, 'mpm-packages');
            fid         = fopen('.gitignore', 'w');
            fwrite(fid, cText);
            fclose(fid);
        end
    end
    
    fprintf('MPM is initialized!\n');
end


% Registers a package with mpm
function mpmregister(cPackageName, cPackageNameSanitized, cRepoURL)

    cCurDir = cd;   
    [d, ~] = fileparts(mfilename('fullpath'));
    cd(d);    
    
    fid         = fopen('registered-packages.json', 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    
    stRegisteredPackages = jsondecode(cText);
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    if any(strcmp(ceFieldNames, cPackageNameSanitized))
        fprintf('Package %s already registered with mpm\n', cPackageName);
    else
        fprintf('Registering package %s with mpm with url: %s\n\n', cRepoURL);
        stRegisteredPackages.(cPackageNameSanitized).repo_url = cRepoURL;
        
        [~,cPackageName,~] = fileparts(cRepoURL);
        stRegisteredPackages.(cPackageNameSanitized).repo_name = cPackageName;
        
        fid         = fopen('registered-packages.json', 'w');
        fwrite(fid, jsonencode(stRegisteredPackages));
        fclose(fid);
    end
    cd(cCurDir);

end

% Retrieves a "proper" package name from sanitized name.  Required because
% MATLAB structs can't contain hyphens in field names like json props
function cPackageName = getRepoName(cPackageNameSanitized)
    fid         = fopen('registered-packages.json', 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    
    stRegisteredPackages = jsondecode(cText);
    cPackageName = stRegisteredPackages.(cPackageNameSanitized).repo_name;
end


function [cePackageNames, stPackages] = getPackageListFromJson(cJsonName)
 % Load package information from package.json
    fid         = fopen(cJsonName, 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    

    if isempty(cText)
        % No package json file yet:
        cePackageNames = {};
        stPackages = struct;
        stPackages.dependencies = {};
    else
        stPackages  = jsondecode(cText);
        cePackageNames = stPackages.dependencies;
    end
end

function stPackages = installPackage(cPackageName, stPackages, dDepth)
    if ~isfield(stPackages, 'dependencies')
        stPackages.dependencies = {};
    end
    ceDependencies = stPackages.dependencies;
    
    cRepoName = getRepoName(cPackageName);


    % Booleans reflecting existence of package
    lPackageInJson = any(strcmp(ceDependencies, cPackageName));
    lPackageInModules = ~isempty(dir(fullfile('mpm-packages', cRepoName)));

    if ~lPackageInModules
        % then this needs to be cloned:
        % package does not exist yet
        fprintf('Installing package %s\n', cPackageName);
        gitclone(cPackageName);
    else
        % package already exists:
        fprintf('Updating package %s\n', cPackageName);
        gitpull(cRepoName);
    end

    % Next check whether this needs to be registered in json:
    if ~lPackageInJson
         stPackages.dependencies{end + 1} = cPackageName;
    end
    
    % Check if the installed package has dependencies, and if so,
    % recursively install
    if ~isempty(dir(fullfile('mpm-packages', cRepoName, 'packages.json')))
        
        % Found dependencies in this package:
        fprintf('Found dependencies in package %s\n', cRepoName)
        cePackageNames = getPackageListFromJson(fullfile('mpm-packages',cRepoName, 'packages.json'));
        for k = 1:length(cePackageNames)
            
            if (dDepth > 15)
                error('Infinite recursion detected... terminating');
            end
            
            % Install only if this package does not exist in level-one
            % packages:
            if ~any(strcmp(ceDependencies, cePackageNames{k}))
                stPackages = installPackage(cePackageNames{k}, stPackages, dDepth + 1);
            end
        end
    end

end

function stPackages = uninstallPackage(cPackageName, stPackages)
    if ~isfield(stPackages, 'dependencies')
        stPackages.dependencies = {};
    end
    ceDependencies = stPackages.dependencies;
    cRepoName = getRepoName(cPackageName);
    
    lPackageInJson = any(strcmp(ceDependencies, cPackageName));
    lPackageInModules = ~isempty(dir(fullfile('mpm-packages', cRepoName)));
    
    if ~lPackageInJson && ~lPackageInModules
        fprintf('Package %s not found!\n\n', cRepoName);
        return
    end
    
    % Removing from mpm-pacakges
    if lPackageInModules
        fprintf('Removing mpm-package %s\n', cRepoName);
        cDir = cd;
        cd('mpm-packages')
        rmdir( cRepoName, 's');
        cd(cDir);
    end
    
    % Remove from package.json
    if lPackageInJson
        stPackages.dependencies(strcmp( stPackages.dependencies, cPackageName)) = [];
    end
    
    fprintf('Package %s successfully uninstalled!\n\n', cRepoName);
end


function gitpull(cPackageName)
    cCurDir = cd;
    cd(fullfile('mpm-packages', cPackageName));
    system('git pull origin master');
    cd(cCurDir);
    
    fprintf('Package %s successfully updated!\n', cPackageName);
    
end

function gitclone(cRepoName)
    % Lookup package in registered packages:

    cPackageURL = getRegisteredPackageURL(cRepoName);
    cCurDir = cd;
    cd('mpm-packages');
    system(sprintf('git clone %s', cPackageURL));
    cd(cCurDir);
    
    fprintf('Package %s successfully downloaded!\n', cRepoName);

end

function gitstatus(cRepoName)
    cCurDir = cd;
    cd(fullfile('mpm-packages', cRepoName));
    [st, cm] = system('git status');
    if (contains(cm, 'nothing to commit, working tree clean'))
        fprintf('Working tree clean\n');
    else
        fprintf('>> Edits have been made to package "%s", git response:\n\n%s', cRepoName, cm);
    end
    cd(cCurDir);
end

function cUrl = getRegisteredPackageURL(cPackageName)
 % Lookup package in registered packages:
    fid         = fopen('registered-packages.json', 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    stRegisteredPackages = jsondecode(cText);
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    if ~any(strcmp(ceFieldNames, cPackageName))
        % Then this package was not registered:
        error('Package %s is not found among packages registered with mpm');
    else
        cUrl = stRegisteredPackages.(cPackageName).repo_url;
    end
end


function mpmupdate()
    cCurDir = cd;
    [d, ~] = fileparts(mfilename('fullpath'));
    cd(d);
    system('git pull origin master');
    cd(cCurDir);
end

function listPackages()
    fid         = fopen('registered-packages.json', 'r');
    
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    
    stRegisteredPackages = jsondecode(cText);
    
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    fprintf('Registered mpm packages:\n---------------------------------\n');
    
    for k = 1:length(ceFieldNames)
         fprintf('%d) %s\n%s\n\n', k, stRegisteredPackages.(ceFieldNames{k}).repo_name, ...
             stRegisteredPackages.(ceFieldNames{k}).repo_url);
        
    end
    fprintf('\n');

end

function listInstalledPackages()
    fid         = fopen('packages.json', 'r');
    if fid == -1
        fprintf('Warning: MPM not found in this directory\n');
        return
    end
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);

    stPackages = jsondecode(cText);

    ceFieldNames = stPackages.dependencies;

    if isempty(ceFieldNames)
        fprintf('No installed mpm packages\n');
        return
    end
    fprintf('Installed mpm packages:\n---------------------------------\n');

    dPackages = 0;
    for k = 1:length(ceFieldNames)
        cRepoName = getRepoName(ceFieldNames{k});
        if ~isempty(dir(sprintf('mpm-packages/%s', cRepoName)))
            dPackages = dPackages + 1;
            fprintf('  %d) %s\n', dPackages, cRepoName);
        end
    end
    fprintf('\n');
end

function printVersion()
    fid         = fopen('version', 'r');
    cVersion       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    fprintf('----------------------------------\nMPM MATLAB package manager %s\n----------------------------------\n\n', cVersion);
end

function printHelp()
 
    printVersion();
    fprintf('USAGE:\n');
    fprintf('> mpm init\n\tInits mpm to current directory\n\n');
    fprintf('> mpm list \n\tLists registered and available mpm packages\n\n');
    fprintf('> mpm install \n\tInstalls/updates packages specified in package.json\n\n');
    fprintf('> mpm install [package name]\n\tInstalls/updates a specific named package from mpm registered packages\n\n');
    fprintf('> mpm uninstall [package name]\n\tRemoves named package from project\n\n');
    fprintf('> mpm status\n\tEchoes installed packages and git status of all mpm package git repos\n\n');
    fprintf('> mpm register [package name] [repo-url or github url]\n\tRegisters a package to mpm\n\n');
    fprintf('> mpm version\n\tEchoes mpm version and changelog\n\n');
    fprintf('> mpm update\n\tPulls latest version of mpm\n\n');
    fprintf('> mpm addpath [<optional> path to mpm-packages dir]\n\tAdds mpm-packages to path\n\n');
end
