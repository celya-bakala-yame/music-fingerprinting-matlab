%% Projet - Reconnaissance musicale par empreintes audio

clear;
clc;
close all;

project_root = fileparts(mfilename('fullpath'));
cd(project_root);
addpath('src');

%% Chargement de la base d'empreintes

index_file = 'results/fingerprint_index.mat';

assert(isfile(index_file), ...
    'Index absent. Construire la base avant de lancer main.m.');

database = load(index_file);

index = database.index;
cfg = database.cfg;

fprintf('Base d empreintes chargee.\n');
fprintf('Seuil de reconnaissance : %d\n', ...
    cfg.decision.threshold);

%% Selection du fichier audio

[file, folder] = uigetfile( ...
    {'*.wav;*.mp3;*.m4a;*.flac', 'Fichiers audio'}, ...
    'Selectionner un extrait musical');

if isequal(file, 0)
    disp('Selection annulee.');
    return;
end

filename = fullfile(folder, file);

[x, Fs] = audioread(filename);

%% Reconnaissance

tic;

[result, diag] = recognize_query(x, Fs, index, cfg);

elapsed = toc;

%% Affichage du resultat

fprintf('\n--- RESULTAT DE LA RECONNAISSANCE ---\n');

if result.is_known

    fprintf('Morceau reconnu : %d\n', result.song_id);
    fprintf('Titre : %s\n', string(result.title));
    fprintf('Position temporelle : %.3f s\n', ...
        result.offset_s);

else

    fprintf('Morceau inconnu.\n');

end

fprintf('Score S1 : %d\n', result.score);
fprintf('Score S2 : %d\n', result.score2);
fprintf('Temps de traitement : %.3f s\n', elapsed);

%% Visualisation du spectrogramme

figure('Color', 'w');

imagesc(diag.t, diag.f, diag.S_dB);

axis xy;
hold on;

if ~isempty(diag.peaks)

    scatter(diag.t(diag.peaks(:,1)), ...
        diag.f(diag.peaks(:,2)), ...
        12, 'r', 'filled');

end

xlabel('Temps (s)');
ylabel('Frequence (Hz)');

title('Spectrogramme et constellation de pics');

colorbar;

%% Export de la figure

if ~isfolder('results/figures')
    mkdir('results/figures');
end

exportgraphics(gcf, ...
    'results/figures/main_recognition_example.png', ...
    'Resolution', 300);