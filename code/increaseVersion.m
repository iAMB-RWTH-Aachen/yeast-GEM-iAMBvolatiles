function increaseVersion(bumpType)
% increaseVersion
%   Upgrades the model to a new version. Run this function after merging
%   changes to the main branch for making a new release.
%
%   bumpType    One of the following 3 strings: "major", "minor" or
%               "patch", indicating the type of increase of version to be
%               performed.
%
%   NOTE: This function requires a git wrapper added to the MATLAB search
%         path: https://github.com/manur/MATLAB-git
%
%   Usage: increaseVersion(bumpType)
%

%Check if in main:
currentBranch = git('rev-parse --abbrev-ref HEAD');
if ~strcmp(currentBranch,'main')
    error('ERROR: not in main')
end

%Bump version number:
fid = fopen('../version.txt','r');
oldVersion = fgetl(fid);
fclose(fid);
oldVersion = str2double(strsplit(oldVersion,'.'));
newVersion = oldVersion;
switch bumpType
    case 'major'
        newVersion(1) = newVersion(1) + 1;
        newVersion(2) = 0;
        newVersion(3) = 0;
    case 'minor'
        newVersion(2) = newVersion(2) + 1;
        newVersion(3) = 0;
    case 'patch'
        newVersion(3) = newVersion(3) + 1;
    otherwise
        error('ERROR: invalid input. Use "major", "minor" or "patch"')
end
newVersion = num2str(newVersion,'%d.%d.%d');

%Check if history has been updated:
fid     = fopen('../history.md','r');
history = fscanf(fid,'%s');
fclose(fid);
if ~contains(history,['yeast' newVersion ':'])
    error('ERROR: update history.md first')
end

%Load model:
model = importModel('../model/yeast-GEM.xml');

%Allow .mat & .xlsx storage:
copyfile('../.gitignore','backup')
fin  = fopen('backup','r');
fout = fopen('../.gitignore','w');
still_reading = true;
while still_reading
  inline = fgets(fin);
  if ~ischar(inline)
      still_reading = false;
  elseif ~startsWith(inline,'*.mat') && ~startsWith(inline,'*.xlsx')
      fwrite(fout,inline);
  end
end
fclose('all');
delete('backup');

%Include tag and save model:
model.id = ['yeastGEM_v' newVersion];
saveYeastModel(model,true,true,true)   %only save if model can grow

%Check if any file changed (except for history.md and 1 line in yeast-GEM.xml):
diff   = git('diff --numstat');
diff   = strsplit(diff,'\n');
change = false;
for i = 1:length(diff)
    diff_i = strsplit(diff{i},'\t');
    if length(diff_i) == 3
        %.xml file: 1 line should be added & 1 line should be deleted
        if strcmp(diff_i{3},'model/yeast-GEM.xml')
            if eval([diff_i{1} ' > 1']) || eval([diff_i{2} ' > 1'])
                disp(['NOTE: File ' diff_i{3} ' is changing more than expected'])
                change = true;
            end
        %Any other file except for history.md: no changes should be detected
        elseif ~strcmp(diff_i{3},{'history.md'})
            disp(['NOTE: File ' diff_i{3} ' is changing'])
            change = true;
        end
    end
end
if change
    error(['Some files are changing from develop. To fix, first update develop, ' ...
        'then merge to main, and try again.'])
end

%Update version file:
fid = fopen('../version.txt','wt');
fprintf(fid,newVersion);
fclose(fid);
end
