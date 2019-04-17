% Sets up MPM

% check if we have commandline git:
[st, cm] = system('git help -g');
if ~strfind(cm, 'The common Git guides are:')
    error('Git command line interface must be installed before MPM can be set up');
end

% clone mpm git repo
cPackageURL = 'https://github.com/ryanmiyakawa/mpm.git';
system(sprintf('git clone %s', cPackageURL));

cCurDir = cd;
cd(mpm);
savepath
cd(cCurDir);

mpm -v nochangelog
fprintf('MPM succesfully installed!!\n\nType "mpm help" to get started\n\n');