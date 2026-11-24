%% Test de bout en bout du systeme

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

%% Test 1 : morceau connu

[x, Fs] = audioread(audio_files{2});

start_s = 10;
duration_s = 5;

debut = start_s * Fs + 1;

query = x(debut:debut+duration_s*Fs-1, :);

[result, ~] = recognize_query(query, Fs, index, cfg);

assert(result.is_known == 1, ...
    'Le morceau connu a ete rejete.');

assert(result.song_id == 2, ...
    'Le morceau identifie est incorrect.');

assert(abs(result.offset_s - start_s) <= 0.1, ...
    'Erreur de localisation temporelle.');

fprintf('TEST 1 OK : reconnaissance du morceau connu\n');
fprintf('TEST 2 OK : estimation du decalage temporel\n');

%% Test 3 : morceau inconnu

filename = fullfile(files(221).folder, files(221).name);

[x, Fs] = audioread(filename);

query = x(1:5*Fs, :);

[result, ~] = recognize_query(query, Fs, index, cfg);

assert(result.is_known == 0, ...
    'Le morceau inconnu a ete accepte.');

fprintf('TEST 3 OK : rejet du morceau inconnu\n');

fprintf('\nTous les tests de bout en bout sont valides.\n');