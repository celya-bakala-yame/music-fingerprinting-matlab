clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

R = readtable('results/robustness_details.csv', ...
    'TextType', 'string');

R15 = readtable('results/noise_15db_details.csv', ...
    'TextType', 'string');

Q = readtable('data/queries/evaluation_list.csv', ...
    'TextType', 'string');

% Rassembler les resultats du bruit blanc
B = R(string(R.type) == "noise", :);

% Eviter les doublons eventuels
B(B.value == 15,:) = [];

B = [B; R15];

% Recuperer la duree de chaque requete
B = innerjoin(B, Q(:, {'query_id','duration_s'}), ...
    'Keys', 'query_id');

% Requetes positives uniquement
B = B(B.true_song_id > 0,:);

snr_values = [0 5 10 15 20];

durations = [3 5 10];

TBD = nan(length(snr_values), length(durations));

for j = 1:length(durations)

    for i = 1:length(snr_values)

        mask = B.value == snr_values(i) & ...
            B.duration_s == durations(j);

        assert(nnz(mask) == 20, ...
            'Nombre de requetes inattendu.');

        TBD(i,j) = 100 * mean( ...
            B.predicted_song_id(mask) == ...
            B.true_song_id(mask));

    end

end

figure('Color','w');

plot(snr_values, TBD(:,1), '-o', 'LineWidth', 2);
hold on;

plot(snr_values, TBD(:,2), '-s', 'LineWidth', 2);
plot(snr_values, TBD(:,3), '-^', 'LineWidth', 2);

xlabel('Rapport signal sur bruit (dB)');
ylabel('Taux de bonne detection (%)');

title('Robustesse au bruit blanc selon la duree');

legend('3 secondes','5 secondes','10 secondes', ...
    'Location','best');

xticks(snr_values);
ylim([0 105]);

grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_snr_by_duration.png', ...
    'Resolution',300);

T = array2table([snr_values(:), TBD], ...
    'VariableNames', {'RSB_dB','TBD_3s','TBD_5s','TBD_10s'});

disp(T);

writetable(T, 'results/snr_by_duration.csv');