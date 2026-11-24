%% Evaluation independante du systeme

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

%% Chargement du seuil calibre

C = load('results/calibration.mat', 'threshold');

cfg.decision.threshold = C.threshold;

%% Chargement des requetes d'evaluation

T = readtable('data/queries/evaluation_list.csv');

N = height(T);

predicted = zeros(N,1);
scores = zeros(N,1);
scores2 = zeros(N,1);
times = zeros(N,1);

%% Reconnaissance des requetes

for i = 1:N

    tic;

    filename = string(T.file(i));

    [x, ~] = preprocess_audio(filename, cfg);

    [S_dB, ~, ~] = compute_spectrogram(x, cfg);

    peaks = extract_peaks(S_dB, cfg);

    [keys, m_anchor] = generate_hashes(peaks, cfg);

    result = recognize_query(index, keys, m_anchor, cfg);

    times(i) = toc;

    predicted(i) = result.song_id;
    scores(i) = result.score;
    scores2(i) = result.score2;

    fprintf('Evaluation %d/%d : score = %d\n', ...
        i, N, scores(i));

end

%% Calcul des performances

positive = T.true_song_id > 0;
negative = T.true_song_id == 0;

correct = predicted == T.true_song_id;

TBD = 100 * mean(correct(positive));

TFD = 100 * mean(predicted(negative) > 0);

accuracy = 100 * mean(correct);

%% Affichage

fprintf('\n--- RESULTATS EVALUATION ---\n');

fprintf('Seuil utilise : %d\n', C.threshold);
fprintf('Nombre de requetes : %d\n', N);
fprintf('TBD : %.2f %%\n', TBD);
fprintf('TFD : %.2f %%\n', TFD);
fprintf('Accuracy : %.2f %%\n', accuracy);
fprintf('Temps moyen : %.3f s\n', mean(times));

%% Sauvegarde

T.predicted_song_id = predicted;
T.S1 = scores;
T.S2 = scores2;
T.time_s = times;
T.correct = correct;

writetable(T, 'results/evaluation_scores.csv');

save('results/evaluation.mat', ...
    'TBD', 'TFD', 'accuracy', 'times');

errors = T(~correct,:);

writetable(errors, 'results/errors.csv');