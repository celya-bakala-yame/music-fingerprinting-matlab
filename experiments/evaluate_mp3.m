%% Evaluation de la robustesse a la compression MP3

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

% Acces a FFmpeg sur macOS
setenv('PATH', ['/opt/homebrew/bin:' getenv('PATH')]);

[status, ~] = system('ffmpeg -version');

assert(status == 0, 'FFmpeg est inaccessible.');

C = load('results/calibration.mat', 'threshold');
cfg.decision.threshold = C.threshold;

T = readtable('data/queries/evaluation_list.csv');

bitrates = [128 64 32];

rows = zeros(numel(bitrates), 3);

for b = 1:numel(bitrates)

    bitrate = bitrates(b);

    predicted = zeros(height(T),1);

    for i = 1:height(T)

        filename = char(string(T.file(i)));

        temp_mp3 = [tempname '.mp3'];

        % Compression MP3
        cmd = sprintf(['ffmpeg -y -loglevel error ' ...
            '-i "%s" -ar 44100 -codec:a libmp3lame ' ...
            '-b:a %dk "%s"'], ...
            filename, bitrate, temp_mp3);

        [status, output] = system(cmd);

        if status ~= 0
            error('Erreur FFmpeg : %s', output);
        end

        % Reconnaissance du signal compresse
        [x, ~] = preprocess_audio(temp_mp3, cfg);

        delete(temp_mp3);

        [S_dB, ~, ~] = compute_spectrogram(x, cfg);

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

    rows(b,:) = [bitrate, TBD, TFD];

    fprintf('MP3 %d kbps : TBD = %.2f %% | TFD = %.2f %%\n', ...
        bitrate, TBD, TFD);

end

%% Sauvegarde

R = array2table(rows, 'VariableNames', ...
    {'bitrate_kbps', 'TBD', 'TFD'});

writetable(R, 'results/mp3_results.csv');

disp(R);

%% Representation graphique

R = sortrows(R, 'bitrate_kbps');

figure('Color', 'w');

bar(categorical(string(R.bitrate_kbps), ...
    string(R.bitrate_kbps)), [R.TBD R.TFD]);

xlabel('Debit MP3 (kbit/s)');
ylabel('Taux (%)');

title('Robustesse a la compression MP3');

legend('TBD', 'TFD', 'Location', 'best');

ylim([0 110]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_mp3.png', ...
    'Resolution', 300);