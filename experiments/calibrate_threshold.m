%% Calibration du seuil de reconnaissance

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

cal = readtable('data/queries/calibration_list.csv');

N = height(cal);

scores = zeros(N,1);
scores2 = zeros(N,1);
predicted = zeros(N,1);

cfg_cal = cfg;
cfg_cal.decision.threshold = 0;

%% Calcul des scores

for i = 1:N

    filename = string(cal.file(i));

    [x, ~] = preprocess_audio(filename, cfg);

    [S_dB, ~, ~] = compute_spectrogram(x, cfg);

    peaks = extract_peaks(S_dB, cfg);

    [keys, m_anchor] = generate_hashes(peaks, cfg);

    result = recognize_query(index, keys, m_anchor, cfg_cal);

    scores(i) = result.score;
    scores2(i) = result.score2;
    predicted(i) = result.song_id;

    fprintf('Requete %d/%d : score = %d\n', ...
        i, N, scores(i));

end

%% Separation des requetes

positive = cal.true_song_id > 0;
negative = cal.true_song_id == 0;

scores_pos = scores(positive);
scores_neg = scores(negative);

correct = predicted == cal.true_song_id;

%% Selection du seuil

max_neg = max(scores_neg);

threshold = max_neg + max(1, ceil(0.2*max_neg));

cfg.decision.threshold = threshold;

TBD = 100 * mean(correct(positive) & ...
                 scores(positive) >= threshold);

TFD = 100 * mean(scores(negative) >= threshold);

%% Affichage des resultats

fprintf('\n--- RESULTATS CALIBRATION ---\n');

fprintf('Score positif moyen : %.2f\n', mean(scores_pos));
fprintf('Score positif minimal : %d\n', min(scores_pos));
fprintf('Score negatif moyen : %.2f\n', mean(scores_neg));
fprintf('Score negatif maximal : %d\n', max_neg);

fprintf('Seuil retenu : %d\n', threshold);
fprintf('TBD calibration : %.2f %%\n', TBD);
fprintf('TFD calibration : %.2f %%\n', TFD);

%% Sauvegarde des resultats

if ~exist('results/figures', 'dir')
    mkdir('results/figures');
end

cal.predicted_song_id = predicted;
cal.S1 = scores;
cal.S2 = scores2;
cal.ratio = scores ./ max(scores2, 1);

writetable(cal, 'results/calibration_scores.csv');

save('results/calibration.mat', ...
    'scores_pos', 'scores_neg', ...
    'threshold', 'TBD', 'TFD');

%% Distribution des scores

figure('Color', 'w');

tiledlayout(1,2);

nexttile;
histogram(scores_neg, 'BinMethod', 'integers', ...
    'FaceColor', [0.85 0.33 0.10]);
hold on;
xline(threshold, '--k', sprintf('Seuil = %d', threshold));
xlabel('Score de reconnaissance');
ylabel('Nombre de requetes');
title('Requetes negatives');
grid on;

nexttile;
histogram(scores_pos, 'NumBins', 15, ...
    'FaceColor', [0 0.45 0.74]);
hold on;
xline(threshold, '--k', sprintf('Seuil = %d', threshold));
xlabel('Score de reconnaissance');
ylabel('Nombre de requetes');
title('Requetes positives');
grid on;

sgtitle('Calibration du seuil de reconnaissance');

exportgraphics(gcf, ...
    'results/figures/calibration_score_hist.png', ...
    'Resolution', 300);