clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

addpath('src');

rng(2026);

%% Chargement de l'index

D = load('results/fingerprint_index.mat');

index = D.index;
cfg = D.cfg;

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

Q = readtable('data/queries/evaluation_list.csv', ...
    'TextType','string');

%% Chargement du bruit reel

[noise, Fs_noise] = audioread('data/noise/babble.wav');

[noise, ~] = preprocess_audio(noise, cfg, Fs_noise);

assert(length(noise) >= 10 * cfg.Fs, ...
    'Enregistrement de bruit trop court.');

assert(mean(noise.^2) > 0, ...
    'Enregistrement de bruit silencieux.');

%% Parametres experimentaux

snr_values = [10 5 0];
durations = [3 5 10];

n = height(Q);

details = table();

%% Evaluation

for s = 1:length(snr_values)

    snr_db = snr_values(s);

    predicted = zeros(n,1);
    S1 = zeros(n,1);
    S2 = zeros(n,1);

    % Memes positions de bruit pour chaque RSB
    rng(2026);

    for i = 1:n

        filename = Q.file(i);

        if ~isfile(filename)
            [~, name, ext] = fileparts(filename);

            filename = fullfile('data','queries', ...
                'evaluation',name + ext);
        end

        [x, Fs] = audioread(filename);

        [x, ~] = preprocess_audio(x, cfg, Fs);

        % Selection aleatoire d'un extrait de bruit
        L = length(x);

        assert(length(noise) >= L);

        start = randi(length(noise)-L+1);

        b = noise(start:start+L-1);

        b = b - mean(b);

        % Calcul des puissances
        Px = mean(x.^2);
        Pb = mean(b.^2);

        assert(Px > 0 && Pb > 0);

        % Ajustement au RSB souhaite
        b = b * sqrt(Px / (Pb * 10^(snr_db/10)));

        y = x + b;

        % Reconnaissance
        result = recognize_query(y, cfg.Fs, index, cfg);

        predicted(i) = result.song_id;
        S1(i) = result.score;
        S2(i) = result.score2;

    end

    T = table( ...
        repmat(snr_db,n,1), ...
        Q.query_id, ...
        Q.duration_s, ...
        Q.true_song_id, ...
        predicted,S1,S2, ...
        'VariableNames', ...
        {'RSB_dB','query_id','duration_s', ...
        'true_song_id','predicted_song_id','S1','S2'});

    details = [details; T];

    fprintf('RSB %d dB : %d requetes terminees.\n', ...
        snr_db,n);

end

%% Calcul des performances

summary = table();

for s = 1:length(snr_values)

    for d = 1:length(durations)

        mask = details.RSB_dB == snr_values(s) & ...
            details.duration_s == durations(d);

        R = details(mask,:);

        pos = R.true_song_id > 0;
        neg = R.true_song_id == 0;

        TBD = 100 * mean( ...
            R.predicted_song_id(pos) == R.true_song_id(pos));

        TFD = 100 * mean(R.predicted_song_id(neg) > 0);

        T = table(snr_values(s),durations(d),TBD,TFD, ...
            'VariableNames', ...
            {'RSB_dB','duration_s','TBD','TFD'});

        summary = [summary; T];

    end

end

disp(summary);

writetable(details,'results/babble_details.csv');
writetable(summary,'results/babble_results.csv');

%% Figure finale

figure('Color','w');

hold on;

for d = 1:length(durations)

    R = summary(summary.duration_s == durations(d),:);

    R = sortrows(R,'RSB_dB');

    plot(R.RSB_dB,R.TBD,'-o', ...
        'LineWidth',2);

end

xlabel('Rapport signal sur bruit (dB)');
ylabel('Taux de bonne detection (%)');

title('Robustesse au bruit reel (brouhaha)');

legend('3 secondes','5 secondes','10 secondes', ...
    'Location','best');

xticks([0 5 10]);

ylim([0 105]);

grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_babble.png', ...
    'Resolution',300);

fprintf('\nExperimentation terminee.\n');