%% RUN_THOMAS_TESTS  Tests unitaires de la branche thomas/hashes-index
% (copie dans report/experiments/thomas_branch). Écrit report/results/thomas_tests.csv.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
tdir = fullfile(here, 'thomas_branch');
old = path;
cd(root);
addpath(root);                                  % config.m
addpath(fullfile(tdir, 'src'), '-begin');
clear generate_hashes query_index build_index assemble_index query_index_v2 decode_key config
try
    tr = runtests(fullfile(tdir, 'tests', 'test_hashes.m'));
    T = table({tr.Name}', [tr.Passed]', [tr.Failed]', 'VariableNames', {'test', 'reussi', 'echec'});
catch ME
    T = table({ME.message}, false, true, 'VariableNames', {'test', 'reussi', 'echec'});
end
path(old);
clear generate_hashes query_index build_index assemble_index query_index_v2 decode_key
writetable(T, fullfile(root, 'report', 'results', 'thomas_tests.csv'));
disp(T);
