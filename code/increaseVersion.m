function increaseVersion(bumpType)
% increaseVersion
%   Upgrades the model to a new version. Run this function after merging
%   changes to the main branch for making a new release.
%
%   bumpType    One of the following 3 strings: "major", "minor" or
%               "patch", indicating the type of increase of version to be
%               performed.
%
%   Usage: increaseVersion(bumpType)
%

%Check if in main:
[~,currentBranch] = system('git rev-parse --abbrev-ref HEAD');
if ~strcmp(strtrim(currentBranch),'main')
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
disp('Loading model file')
model = importModel('../model/yeast-GEM.xml');

%Run tests
cd modelTests
disp('Running gene essentiality analysis')
[new.accuracy,new.tp,new.tn,new.fn,new.fp] = essentialGenes(newModel);
disp('Run growth analysis')
new.R2=growth(newModel);
saveas(gcf,'../../growth.png');

copyfile('../README.md','backup.md')
fin  = fopen('backup.md','r');
fout = fopen('../README.md','w');
searchStats1 = '^(- Accuracy\: )0\.\d+';
searchStats2 = '^(- True positive genes\: )\d+';
searchStats3 = '^(- True negative genes\: )\d+';
searchStats4 = '^(- False positive genes\: )\d+';
searchStats5 = '^(- False negative genes\: )\d+';
newStats1 = ['$1' num2str(new.accuracy)];
newStats2 = ['$1' num2str(numel(new.tp))];
newStats3 = ['$1' num2str(numel(new.tn))];
newStats4 = ['$1' num2str(numel(new.fp))];
newStats5 = ['$1' num2str(numel(new.fn))];

searchStats6 = '^(- R<sup>2<\/sup>\: )0\.\d+';
newStats6 = ['$1' num2str(new.R2)];

while ~feof(fin)
    str = fgets(fin);
    inline = regexprep(str,searchStats1,newStats1);
    inline = regexprep(inline,searchStats2,newStats2);
    inline = regexprep(inline,searchStats3,newStats3);
    inline = regexprep(inline,searchStats4,newStats4);
    inline = regexprep(inline,searchStats5,newStats5);
    inline = regexprep(inline,searchStats6,newStats6);
    inline = unicode2native(inline,'UTF-8');
    fwrite(fout,inline);
end
fclose('all');
delete('backup.md');

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
[~,diff]   = system('git diff --numstat');
diff   = strsplit(diff,'\n');
change = false;
for i = 1:length(diff)
    diff_i = strsplit(diff{i},'\t');
    if length(diff_i) == 3
        switch diff_i{3}
            case 'model/yeast-GEM.xml'
                %.xml file: 2 lines should be added & 2 lines should be deleted
                if eval([diff_i{1} ' > 2']) || eval([diff_i{2} ' > 2'])
                    disp(['NOTE: File ' diff_i{3} ' is changing more than expected'])
                    change = true;
                end
            case 'model/yeast-GEM.yml'
                %.yml file: 2 lines should be added & 2 lines should be deleted
                if eval([diff_i{1} ' > 2']) || eval([diff_i{2} ' > 2'])
                    disp(['NOTE: File ' diff_i{3} ' is changing more than expected'])
                    change = true;
                end                
            case 'history.md'
            otherwise
                disp(['NOTE: File ' diff_i{3} ' is changing'])
                change = true;                
        end
    end
end
if change == true
    error(['Some files are changing from develop. To fix, first update develop, ' ...
        'then merge to main, and try again.'])
end

%Update version file:
fid = fopen('../version.txt','wt');
fprintf(fid,newVersion);
fclose(fid);
end
