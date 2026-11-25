clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

addpath('src');

rng(2026);

D = load('results/fingerprint_index.mat');

index = D.index;
cfg = D.cfg;

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

Q = readtable('data/queries/evaluation_list.csv', ...
    'TextType', 'string');

n = height(Q);

predicted = zeros(n,1);
S1 = zeros(n,1);
S2 = zeros(n,1);
time_s = zeros(n,1);

for i = 1:n

    filename = Q.file(i);

    if ~isfile(filename)
        [~, name, ext] = fileparts(filename);
        filename = fullfile('data', 'queries', ...
            'evaluation', name + ext);
    end

    [x, Fs] = audioread(filename);

    x = mean(x, 2);

    % Bruit blanc à 15 dB
    y = apply_degradations(x, Fs, 'noise', 15);

    timer = tic;

    result = recognize_query(y, Fs, index, cfg);

    time_s(i) = toc(timer);

    predicted(i) = result.song_id;
    S1(i) = result.score;
    S2(i) = result.score2;

    fprintf('Requete %d/%d : vrai=%d, predit=%d\n', ...
        i, n, Q.true_song_id(i), predicted(i));

end

positive = Q.true_song_id > 0;
negative = Q.true_song_id == 0;

TBD = 100 * mean( ...
    predicted(positive) == Q.true_song_id(positive));

TFD = 100 * mean(predicted(negative) > 0);

details = table( ...
    repmat("noise",n,1), ...
    repmat(15,n,1), ...
    Q.query_id, ...
    Q.true_song_id, ...
    predicted, S1, S2, time_s, ...
    'VariableNames', { ...
    'type','value','query_id','true_song_id', ...
    'predicted_song_id','S1','S2','time_s'});

summary = table("noise", 15, TBD, TFD, mean(time_s), ...
    'VariableNames', {'type','value','TBD','TFD','time_s'});

writetable(details, 'results/noise_15db_details.csv');

writetable(summary, 'results/noise_15db_results.csv');

fprintf('\n=== BRUIT BLANC A 15 dB ===\n');
fprintf('TBD : %.2f %%\n', TBD);
fprintf('TFD : %.2f %%\n', TFD);

disp(summary);