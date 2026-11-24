%% Influence de la duree des extraits

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

T = readtable('results/evaluation_scores.csv');

durations = [3 5 10];

TBD_duration = zeros(1,3);
TFD_duration = zeros(1,3);

for i = 1:3

    positive = T.duration_s == durations(i) ...
        & T.true_song_id > 0;

    negative = T.duration_s == durations(i) ...
        & T.true_song_id == 0;

    TBD_duration(i) = 100 * mean(T.correct(positive));

    TFD_duration(i) = 100 * mean( ...
        T.predicted_song_id(negative) > 0);

end

figure('Color', 'w');

bar(durations, [TBD_duration; TFD_duration]');

xlabel('Duree de la requete (s)');
ylabel('Taux (%)');

title('Influence de la duree sur la reconnaissance');

legend('TBD', 'TFD', 'Location', 'best');

xticks(durations);
ylim([0 110]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_vs_duration.png', ...
    'Resolution', 300);

disp(table(durations', TBD_duration', TFD_duration', ...
    'VariableNames', {'Duree_s', 'TBD', 'TFD'}));