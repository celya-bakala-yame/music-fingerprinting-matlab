%% Evaluation de la robustesse a la reverberation

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

rng(2026);

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

T = readtable('data/queries/evaluation_list.csv');

RT60_values = [0 0.3 0.6 1];

rows = zeros(numel(RT60_values), 3);

for r = 1:numel(RT60_values)

    RT60 = RT60_values(r);

    predicted = zeros(height(T),1);

    for i = 1:height(T)

        [x, Fs] = audioread(string(T.file(i)));

        if RT60 == 0
            y = x;
        else
            y = apply_reverb(x, Fs, RT60);
        end

        [y, ~] = preprocess_audio(y, cfg, Fs);

        [S_dB, ~, ~] = compute_spectrogram(y, cfg);

        peaks = extract_peaks(S_dB, cfg);

        [keys, m_anchor] = generate_hashes(peaks, cfg);

        result = recognize_query( ...
            index, keys, m_anchor, cfg);

        predicted(i) = result.song_id;

    end

    positive = T.true_song_id > 0;
    negative = T.true_song_id == 0;

    correct = predicted == T.true_song_id;

    TBD = 100 * mean(correct(positive));
    TFD = 100 * mean(predicted(negative) > 0);

    rows(r,:) = [RT60, TBD, TFD];

    fprintf('RT60 = %.1f s : TBD = %.2f %% | TFD = %.2f %%\n', ...
        RT60, TBD, TFD);

end

%% Sauvegarde

R = array2table(rows, 'VariableNames', ...
    {'RT60_s', 'TBD', 'TFD'});

writetable(R, 'results/reverb_results.csv');

disp(R);

%% Representation graphique

figure('Color', 'w');

plot(R.RT60_s, R.TBD, '-ob', 'LineWidth', 2);
hold on;

plot(R.RT60_s, R.TFD, '-sr', 'LineWidth', 2);

xlabel('Temps de reverberation RT60 (s)');
ylabel('Taux (%)');

title('Robustesse a la reverberation acoustique');

legend('TBD', 'TFD', 'Location', 'best');

xticks(RT60_values);
ylim([0 105]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_reverb.png', ...
    'Resolution', 300);