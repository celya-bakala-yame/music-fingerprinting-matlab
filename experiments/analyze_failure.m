%% Analyse des cas d'echec

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath('src');

query_ids = [16 41];

T = readtable('data/queries/evaluation_list.csv');

figure('Color', 'w');
tiledlayout(2,1);

for i = 1:numel(query_ids)

    row = T(T.query_id == query_ids(i), :);

    [x, ~] = preprocess_audio(string(row.file), cfg);

    [S_dB, f, t] = compute_spectrogram(x, cfg);

    peaks = extract_peaks(S_dB, cfg);

    [keys, ~] = generate_hashes(peaks, cfg);

    nexttile;

    imagesc(t, f, S_dB);
    axis xy;
    hold on;

    if ~isempty(peaks)
        scatter(t(peaks(:,1)), f(peaks(:,2)), ...
            12, 'r', 'filled');
    end

    xlabel('Temps (s)');
    ylabel('Frequence (Hz)');

    title(sprintf('Requete %d - %d secondes', ...
        query_ids(i), row.duration_s));

    colorbar;

    fprintf('Requete %d : %d pics, %d empreintes\n', ...
        query_ids(i), size(peaks,1), numel(keys));

end

sgtitle('Analyse des requetes non reconnues');

exportgraphics(gcf, ...
    'results/figures/failure_analysis.png', ...
    'Resolution', 300);