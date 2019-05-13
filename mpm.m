%% mpm (MATLAB PACKAGE MANAGER)
%{

CXRO Matlab package manager, 04.01.2019, R. Miyakawa and C. Anderson

Package manager that uses a git backend to install and update Matlab
dependencies.  Install mpm by downloading cloning this git repo: 

    https://github.com/ryanmiyakawa/mpm.git

or by running the script MPMSetup.m.  MPM requires git to be installed on
the command line to work properly.  

%}


function mpm(varargin)

    % Load package information from package.json
    cFile = fullfile(pwd, 'packages.json');     
    [cePackageNames, stPackages] = getPackageListFromJson(cFile);


    if isempty(varargin)
        direct = 'help';
    else
        direct = varargin{1};
    end


    if direct(1) == '-'
        direct = direct(2:end);
    end
    
    
    % PRIMARY ROUTER
    switch direct
        case {'install', 'i'}
            
            requireGitOrDie(); % Warn and return if git is not installed
            
            % On install if packages.json exists but not mpm-packages, the
            % just make the dir:
            if checkpackagsjsonexists() && ~checkmpmpackagesexists()
                mkdir('mpm-packages');
            end

            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            dDepth = 0;

            ceUpdatedPackages = {};
            ceInstalledPackages = {};
            
            if length(varargin) == 1
                % install/update all from packages.json
                
                for k = 1:length(cePackageNames)
                    [stPackages, exitFlag] = mpmInstallPackage(cePackageNames{k}, stPackages, dDepth);
                    if exitFlag == 1
                        ceInstalledPackages{end+1} = cePackageNames{k};
                    end
                    if exitFlag == 2
                        ceUpdatedPackages{end+1} = cePackageNames{k};
                    end
                end
                

            else
                % Just install specific packages
                cPackageName = regexprep(varargin{2}, '-', '_');
                [stPackages, exitFlag] = mpmInstallPackage(cPackageName, stPackages, dDepth);
                
                if exitFlag == 1
                    ceInstalledPackages{end+1} = cePackageNames{k};
                end
                if exitFlag == 2
                    ceUpdatedPackages{end+1} = cePackageNames{k};
                end
            end
            
            % now write packages.json back to file:
            fid         = fopen('packages.json', 'w');
            fwrite(fid, jsonPretty(stPackages));
            fclose(fid);
            
            % Echo updates:
            if ~isempty(ceInstalledPackages)
                fprintf('\nMPM successfully installed the following packages: \n');
                for k = 1:length(ceInstalledPackages)
                    if k == length(ceInstalledPackages)
                         fprintf('%s\n\n', ceInstalledPackages{k});
                    else
                         fprintf('%s, ', ceInstalledPackages{k});
                    end
                end
            end
            if ~isempty(ceUpdatedPackages)
                fprintf('\nMPM successfully installed the following packages: \n');
                for k = 1:length(ceUpdatedPackages)
                    if k == length(ceUpdatedPackages)
                         fprintf('%s\n\n', ceUpdatedPackages{k});
                    else
                         fprintf('%s, ', ceUpdatedPackages{k});
                    end
                end
            end
            
            if isempty(ceInstalledPackages) && isempty(ceUpdatedPackages)
                fprintf('\nAll packages are up to date!\n\n');
            end
            
            listInstalledPackages();

            
        case {'uninstall', 'u'}
            requireGitOrDie(); % Warn and return if git is not installed
            
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            if length(varargin) ~= 2
                error('Must specify package name to uninstall, type "mpm help" for details');
            end
            
            cPackageName = regexprep(varargin{2}, '-', '_');
            stPackages = unmpmInstallPackage(cPackageName, stPackages);
            
            % now write packages.json back to file:
            fid         = fopen('packages.json', 'w');
            fwrite(fid, jsonPretty(stPackages));
            fclose(fid);
            
        case {'help', 'h'}
            printHelp();
        case {'list', 'l'}
            listPackages();
            
        case 'push'
            requireGitOrDie(); % Warn and return if git is not installed
            
            if length(varargin) < 2
                warning('(COMMIT MEASSAGE REQUIRED) \NPlease add commit message before pushing\n');
                return
            end
            
            cCommitMessage = '';
            for k = 2:length(varargin)
                cCommitMessage = [cCommitMessage ' ' varargin{k}]; %#ok<AGROW>
            end
            
            if ~isempty(cCommitMessage) && (cCommitMessage(2) == '''' || cCommitMessage(2) == '"')
                cCommitMessage = cCommitMessage(3:end);
            end
            if ~isempty(cCommitMessage) && (cCommitMessage(end) == '''' || cCommitMessage(end) == '"')
                cCommitMessage = cCommitMessage(1:end-1);
            end
            
            cResponse = gitAddAndPush(cCommitMessage);
            
            if contains(cResponse, 'git pull')
                warning('(MPM UPDATE REQUIRED)\nMPM has unmerged updates, please update and reconcile merge\n');
            else
                fprintf('MPM succesfully pushed!\n\n');
            end
           
            
        case 'init'
           requireGitOrDie(); % Warn and return if git is not installed
           
           mpminit();
            
        case {'update'}
            requireGitOrDie(); % Warn and return if git is not installed
            
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            
            cResponse = owngitstatus();
            
            if contains(cResponse, 'Changes not staged for commit')
                fprintf('%s\n', cResponse);
                warning('MPM working tree dirty, if this is intentional, please push changes by using "mpm push" before updating');
                return
            end
            
            
            printVersion();
            cResponse = mpmupdate();
            
            fprintf('%s\n\n', cResponse);

        case 'status'
            requireGitOrDie(); % Warn and return if git is not installed
            
            if ~checkmpmexists()
                error('Warning: MPM is not initialized in this directory, run "mpm init" to initialize');
            end
            
            printVersion();
            listInstalledPackages();
            
            if length(varargin) > 1 && any(strcmp(varargin{2}, {'all', 'full', 'al', 'a', 'f'}))
                printGitStatus(true);
            else
                printGitStatus(false);
            end
            
        case 'ownstatus'
            requireGitOrDie(); % Warn and return if git is not installed
            
            cResponse = owngitstatus();
            
            if contains(cResponse, 'Changes not staged for commit')
                fprintf('%s\n', cResponse);
                warning('Working tree dirty, if this is intentional, please push changes by using "mpm push"');
            else
                fprintf('MPM working tree clean \n\n', cResponse);
            end
            
 
        case {'register', 'r'}
            requireGitOrDie(); % Warn and return if git is not installed
            
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
            cRepoName = regexprep(cRepoName, '\\', '/');
            mpmregister(cPackageName, cPackageNameSanitized, cRepoName);
        case {'addpath', 'a'}           
            
            % adds path of mpm-packages to general path
            if length(varargin) == 2
                cMpmDir = varargin{2};
                cPathVar = fullfile(cMpmDir, 'mpm-packages');
                mpmAddPath(cPathVar, cMpmDir);
            else
                cPathVar = 'mpm-packages';
                mpmAddPath(cPathVar);
            end
            
        case {'clearpath', 'clear', 'c'}           
            
            % Reset path to pathdef:
            path(pathdef);
            
            
        case {'cd', 'cdmpm'}
            [d, ~] = fileparts(mfilename('fullpath'));
            cd(d);
            fprintf('Changed directory to mpm root\n\n');
           
            
        case {'ver', 'version', 'v'}
            
            fid         = fopen('changelog', 'r');
            cChangelog    = fread(fid, inf, 'uint8=>char')';
            fclose(fid);
            
            printVersion();
            
            if length(varargin) == 1 || ~strcmp(varargin{2}, 'nochangelog')
                fprintf('Version history:\n----------------\n%s\n\n', cChangelog);
            end
            
            if ~checkGitWorks()
                warning('MPM requires git to be installed on the command line')
                return
            end
                
        case {'newversion', 'new-version', 'n'}
            if ~checkGitWorks()
                warning('MPM requires git to be installed on the command line')
                return
            end
            
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
                if cAddText(2) == '"' || cAddText(2) == ''''
                    cAddText = [' ', cAddText(3:end)];
                end
                if cAddText(end) == '"' || cAddText(end) == ''''
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


function requireGitOrDie()
    if ~checkGitWorks()
        error(sprintf('MPM requires git to be installed on the command line.\nInstall git for command line and run "mpm help" to get started'))   
    end
end

function lVal = checkGitWorks()
    [st, cm] = system('git help -g');
    lVal = strfind(cm, 'The common Git guides are:');
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

function mpmAddPath(cPackagesDir, cMpmDir)

    cCurDir = cd;
    
    if nargin == 2 % mpm-packages is remote, so change to project root first
        cd(cMpmDir);
        cePackages = getInstalledPackages();
        cd(cCurDir);
    else
        cePackages = getInstalledPackages();
    end
    cd (cPackagesDir);


    for k = 1:length(cePackages)
        % For each package, check if package.json has a path, otherwise add src
        % folder
        if ~isempty(dir(fullfile(cePackages{k}, 'src')))
            cPathVar = fullfile(cePackages{k}, 'src');
            addpath(genpath(cPathVar));
        else
            cPathVar = cePackages{k};
            addpath(genpath(cPathVar));
        end
        fprintf('mpm: Adding %s to MATLAB path\n', cPathVar);

    end


    cd (cCurDir);
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
    
    cRegisteredPacakgesPath = fullfile(fileparts(mfilename('fullpath')), 'registered-packages.json');
    
    stRegisteredPackages = getRegisteredPackages();
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    cResponse = 'y';
    if any(strcmp(ceFieldNames, cPackageNameSanitized))
        
        cResponse = input(sprintf('WARNING: Package "%s" already registered with mpm, OVERWRITE? (y/n)\n',cPackageName) ,'s');
    end
    
    if cResponse == 'y' || cResponse == 'Y'
        fprintf('\nRegistering package "%s" with mpm with url: %s\n\n', cPackageName, cRepoURL);
        stRegisteredPackages.(cPackageNameSanitized).repo_url = cRepoURL;

        [~,cPackageName,~] = fileparts(cRepoURL);
        stRegisteredPackages.(cPackageNameSanitized).repo_name = cPackageName;

        fid         = fopen(cRegisteredPacakgesPath, 'w');
        fwrite(fid, jsonPretty(stRegisteredPackages));
        fclose(fid);
    end
    
    cd(cCurDir);

end

% Retrieves a "proper" package name from sanitized name.  Required because
% MATLAB structs can't contain hyphens in field names like json props
function cPackageName = getRepoName(cPackageNameSanitized)
    stRegisteredPackages = getRegisteredPackages();
    cPackageName = stRegisteredPackages.(cPackageNameSanitized).repo_name;
end


function [cePackageNames, stPackages] = getPackageListFromJson(cJsonName)
 % Load package information from package.json
 
    
    if exist(cJsonName, 'file') ~= 2
        
        cePackageNames = {};
        stPackages = struct;
        stPackages.dependencies = {};
        
        return;
    end
    
    
    fid         = fopen(cJsonName, 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    

    if isempty(cText)
        % No package json file yet:
        cePackageNames = {};
        stPackages = struct;
        stPackages.dependencies = {};
    else
        stPackages  = jsondecode(cText');
        cePackageNames = stPackages.dependencies;
    end
end

function [stPackages, exitFlag] = mpmInstallPackage(cPackageName, stPackages, dDepth)
    
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
        fprintf('Installing package %s\n', cPackageName);
        cResponse = gitclone(cPackageName);
        
        if ~contains(cResponse, 'fatal') % then failed
            fprintf('Package "%s" successfully installed!!\n\n', cRepoName);
            exitFlag = 1; % Installed
        else 
            error('Fatal error: package "%s" cannot be found', cPackageName);
        end
    else
        % package already exists:
        fprintf('Checking for updates for package "%s"\n', cPackageName);
        cResponse = gitpull(cRepoName);
        if contains(cResponse, 'Already up to date')
            % fprintf('Package "%s" is already up to date\n\n', cRepoName);
            exitFlag = 3; % Already up to date
        elseif contains(cResponse, 'CONFLICT') % then failed
            exitFlag = 4; % Merge conflicts
            warning('UPDATE FAILED (MERGE CONFLICTS): package "%s" has merge conflicts, please reconcile\nGit message: %s\n', cPackageName, cResponse);       
        else
            
%             fprintf('Package "%s" successfully updated!\n\n', cRepoName);
            exitFlag = 2; % Updated
        end
            
    end

    % Next check whether this needs to be registered in json:
    if ~lPackageInJson
         stPackages.dependencies{end + 1} = cPackageName;
    end
    
    % Check if the installed package has dependencies, and if so,
    % recursively install
    if ~lPackageInModules && ~isempty(dir(fullfile('mpm-packages', cRepoName, 'packages.json')))
        
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
                stPackages = mpmInstallPackage(cePackageNames{k}, stPackages, dDepth + 1);
            end
        end
    end

end

function stPackages = unmpmInstallPackage(cPackageName, stPackages)
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


function cResponse = gitpull(cPackageName)
    cCurDir = cd;
    cd(fullfile('mpm-packages', cPackageName));
    [~, cResponse] = system('git pull origin master');
    cd(cCurDir);
end

function cResponse = gitclone(cRepoName)
    % Lookup package in registered packages:

    cPackageURL = getRegisteredPackageURL(cRepoName);
    cCurDir = cd;
    cd('mpm-packages');
    [~, cResponse] = system(sprintf('git clone %s', cPackageURL));
    cd(cCurDir);
end

function cResponse = gitstatus(cRepoName)
    cCurDir = cd;
    cd(fullfile('mpm-packages', cRepoName));
    [~, cResponse] = system('git status');
    cd(cCurDir);
end

function cResponse = owngitstatus()
    cCurDir = cd;
    [d, ~] = fileparts(mfilename('fullpath'));
    cd(d);
 
    [~, cResponse] = system('git status');
    
    cd (cCurDir);
end

function cResponse = gitAddAndPush(cCommitMessage)
    cCurDir = cd;
    [d, ~] = fileparts(mfilename('fullpath'));
    cd(d);
    
    system('git add .');
    [~, ~] = system(sprintf('git commit -m "%s"', cCommitMessage));
    [~, cResponse] = system('git push origin master');
    cd (cCurDir);
end


function st = getRegisteredPackages()
 % Returns a structure of registered packages
    cRegisteredPacakgesPath = fullfile(fileparts(mfilename('fullpath')), 'registered-packages.json');
    fid         = fopen(cRegisteredPacakgesPath, 'r');
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    st = jsondecode(cText');

end

function cUrl = getRegisteredPackageURL(cPackageName)
 % Lookup package in registered packages:
 
    
    stRegisteredPackages = getRegisteredPackages(); 
    
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    if ~any(strcmp(ceFieldNames, cPackageName))
        % Then this package was not registered:
        error('Package %s is not found among packages registered with mpm');
    else
        cUrl = stRegisteredPackages.(cPackageName).repo_url;
    end
end


function cResponse = mpmupdate()
    cCurDir = cd;
    [d, ~] = fileparts(mfilename('fullpath'));
    cd(d);
    [~, cResponse] = system('git pull origin master');
    cd(cCurDir);
end

function printGitStatus(lShowFull)

    ceRepoNames = getInstalledPackages();
    dNumEditedPackages = 0;
    
    if isempty(ceRepoNames)
        return
    end
    
    % Loop through packages and run a status on each
    for k = 1:length(ceRepoNames)
        cRepoName = ceRepoNames{k};
        
        cGitResponse = gitstatus(cRepoName);
        if ~(contains(cGitResponse, 'nothing to commit, working tree clean'))
            dNumEditedPackages = dNumEditedPackages + 1;
            cPathToPackage = fullfile(cd, 'mpm-packages', cRepoName);
            fprintf('** Edits have been made to package "%s" in:\n   %s\n\n', cRepoName, cPathToPackage);
        elseif nargin == 1 && lShowFull
            fprintf('Package "%s": Working tree clean\n\n', cRepoName);
        end
    end
    
    if dNumEditedPackages == 0
        fprintf('All mpm packages have clean working trees\n\n');
    end

end

function listPackages()
    stRegisteredPackages = getRegisteredPackages();
    
    ceFieldNames = fieldnames(stRegisteredPackages);
    
    fprintf('Registered mpm packages:\n---------------------------------\n');
    
    for k = 1:length(ceFieldNames)
         fprintf('%d) %s\n%s\n\n', k, stRegisteredPackages.(ceFieldNames{k}).repo_name, ...
             stRegisteredPackages.(ceFieldNames{k}).repo_url);
        
    end
    fprintf('\n');

end

function listInstalledPackages()
    ceInstalledPackages = getInstalledPackages();
    
    if isempty(ceInstalledPackages)
        fprintf('No installed mpm packages\n\n');
        return
    end
    fprintf('Installed mpm packages:\n---------------------------------\n');

    dPackages = 0;
    for k = 1:length(ceInstalledPackages)
        cRepoName = ceInstalledPackages{k};
        if ~isempty(dir(sprintf('mpm-packages/%s', cRepoName)))
            dPackages = dPackages + 1;
            fprintf('  %d) %s\n', dPackages, cRepoName);
        end
    end
    fprintf('\n');
end

function ceInstalledPackages = getInstalledPackages()
    fid         = fopen('packages.json', 'r');
    if fid == -1
        fprintf('Warning: MPM not found in this directory\n');
        return
    end
    cText       = fread(fid, inf, 'uint8=>char');
    fclose(fid);

    stPackages = jsondecode(cText');

    ceFieldNames = stPackages.dependencies;
    ceInstalledPackages = {};
    
    dPackages = 0;
    for k = 1:length(ceFieldNames)
        cRepoName = getRepoName(ceFieldNames{k});
        if ~isempty(dir(sprintf('mpm-packages/%s', cRepoName)))
            dPackages = dPackages + 1;
            ceInstalledPackages{dPackages} = cRepoName; %#ok<AGROW>
        end
    end

end

function printVersion()
    fid         = fopen('version', 'r');
    cVersion       = fread(fid, inf, 'uint8=>char');
    fclose(fid);
    fprintf(['----------------------------------\nMPM MATLAB package manager %s\n', ...
        'Center for X-ray Optics\n' ...
        '----------------------------------\n\n'], cVersion);
end

function printHelp()
 
    printVersion();
    fprintf('USAGE:\n');
    fprintf('mpm init \t\tInits mpm to current directory\n');
    fprintf('mpm list \t\tLists registered and available mpm packages\n');
    fprintf('mpm addpath [<optional> path to mpm-packages dir]\n\t\t\tAdds mpm-packages to path\n');
    fprintf('mpm clearpath \t\tResets path to MATLAB pathdef\n');
    fprintf('mpm install \t\tInstalls/updates packages specified in package.json\n');
    fprintf('mpm install [package name]\n\t\t\tInstalls/updates a specific named package from mpm registered packages\n');
    fprintf('mpm uninstall [package name]\n\t\t\tRemoves named package from project\n');
    fprintf('mpm status\t\tEchoes installed packages and git status of all mpm package git repos\n');
    
    fprintf('mpm version\t\tEchoes mpm version and changelog\n');
    fprintf('mpm update\t\tPulls latest version of mpm\n');
    
    fprintf('\n=========================================================================\n');
    fprintf('=== Advanced use: Probably don''t do this unless you are Chris or Ryan ===\n');
    fprintf('mpm register [package name] [repo-url or github url]\n\t\t\tRegisters a package to mpm\n');
    fprintf('mpm ownstatus \t\tDisplays git status of mpm repo\n');
    fprintf('mpm push [commit message]\n\t\t\tCommits and pushes changes to the MPM repo\n');
    fprintf('mpm newversion [version notes]\n\t\t\tIncrements version number and adds version notes to changelog\n');
    fprintf('=========================================================================\n');
end

% A simple pretty print json algorithm
function strOut = jsonPretty(str)
    str = jsonencode(str);
    ct = 1;
    strOut = '';
    lftCt = 0;
    while ct <= length(str)
        ch = str(ct);
        switch ch
            case ','
                strOut = sprintf('%s,\n%s',strOut, makeTabs(lftCt));
                
            case '{'
                lftCt = lftCt + 1;
                strOut = sprintf('%s{\n%s',strOut, makeTabs(lftCt));
                
            case '}'
                lftCt = lftCt - 1;
                strOut = sprintf('%s\n%s}',strOut, makeTabs(lftCt));
            case '['
                lftCt = lftCt + 1;
                strOut = sprintf('%s[\n%s',strOut, makeTabs(lftCt));
                
            case ']'
                lftCt = lftCt - 1;
                strOut = sprintf('%s\n%s]',strOut, makeTabs(lftCt));
                
            otherwise
                strOut(end+1) = ch;
        end
        ct = ct + 1;
    end
end

function cTabs = makeTabs(ct)
    cTabs = '';
    for k = 1:ct
        cTabs = sprintf('%s\t', cTabs);
    end
end

