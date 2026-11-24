%% Initialisation de la base de reference

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

cfg = config();

%% Selection du dataset FMA

fma_path = uigetdir(fullfile(getenv('HOME'), 'Downloads'), ...
    'Selectionner le dossier fma_small');

if isequal(fma_path, 0)
    error('Aucun dossier selectionne.');
end

files = dir(fullfile(fma_path, '**', '*.mp3'));

assert(numel(files) >= 221, ...
    'Le dataset doit contenir au moins 221 fichiers MP3.');

% Ordre reproductible des fichiers
[~, order] = sort({files.name});
files = files(order);

%% Selection des 100 morceaux de reference

audio_files = arrayfun( ...
    @(f) fullfile(f.folder, f.name), ...
    files(1:100), ...
    'UniformOutput', false);

%% Construction de l'index

tic;
index = build_index(audio_files, cfg);
build_time = toc;

fprintf('Temps de construction : %.3f s\n', build_time);

%% Sauvegarde

if ~isfolder('results')
    mkdir('results');
end

save('results/fingerprint_index.mat', ...
    'index', 'cfg', 'audio_files', '-v7.3');

fprintf('Base de reference sauvegardee.\n');