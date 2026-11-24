%% Evaluation de la robustesse

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

rng(2026);

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

T = readtable('data/queries/evaluation_list.csv');

conditions = {
    'clean', 0;
    'noise', 30;
    'noise', 20;
    'noise', 10;
    'noise', 5;
    'noise', 0;
    'noise', -5;
    'lowpass', 3000;
    'lowpass', 2000;
    'lowpass', 1000;
    'telephone', 0;
    'volume', -20;
    'volume', -6;
    'volume', 6
};

N_conditions = size(conditions,1);

rows = cell(N_conditions,5);

details = cell(N_conditions * height(T),8);
k = 0;

for c = 1:N_conditions

    type = conditions{c,1};
    value = conditions{c,2};

    predicted = zeros(height(T),1);
    times = zeros(height(T),1);

    for i = 1:height(T)

        [x, Fs] = audioread(string(T.file(i)));

        y = apply_degradations(x, Fs, type, value);

        tic;

        [y, ~] = preprocess_audio(y, cfg, Fs);

        [S_dB, ~, ~] = compute_spectrogram(y, cfg);

        peaks = extract_peaks(S_dB, cfg);

        [keys, m_anchor] = generate_hashes(peaks, cfg);

        result = recognize_query( ...
            index, keys, m_anchor, cfg);

        times(i) = toc;

        predicted(i) = result.song_id;

        k = k + 1;

        details(k,:) = {type, value, T.query_id(i), ...
            T.true_song_id(i), predicted(i), ...
            result.score, result.score2, times(i)};

    end

    positive = T.true_song_id > 0;
    negative = T.true_song_id == 0;

    correct = predicted == T.true_song_id;

    TBD = 100 * mean(correct(positive));
    TFD = 100 * mean(predicted(negative) > 0);

    rows(c,:) = {type, value, TBD, TFD, mean(times)};

    fprintf('%s %g : TBD = %.2f %% | TFD = %.2f %%\n', ...
        type, value, TBD, TFD);

end

R = cell2table(rows, 'VariableNames', ...
    {'type', 'value', 'TBD', 'TFD', 'time_s'});

D = cell2table(details, 'VariableNames', ...
    {'type', 'value', 'query_id', 'true_song_id', ...
    'predicted_song_id', 'S1', 'S2', 'time_s'});

writetable(R, 'results/robustness_results.csv');
writetable(D, 'results/robustness_details.csv');

disp(R);