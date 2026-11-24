%% Etude de l'influence du seuil

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

T = readtable('results/calibration_scores.csv');

positive = T.true_song_id > 0;
negative = T.true_song_id == 0;

correct = T.predicted_song_id == T.true_song_id;

thresholds = (0:max(T.S1)+1)';

TBD_values = zeros(size(thresholds));
TFD_values = zeros(size(thresholds));

for i = 1:numel(thresholds)

    accepted = T.S1 >= thresholds(i);

    TBD_values(i) = 100 * mean( ...
        accepted(positive) & correct(positive));

    TFD_values(i) = 100 * mean(accepted(negative));

end

%% Sauvegarde des resultats

sweep = table(thresholds, TBD_values, TFD_values, ...
    'VariableNames', {'threshold', 'TBD', 'TFD'});

writetable(sweep, 'results/threshold_sweep.csv');

%% Representation graphique

figure('Color', 'w');

plot(thresholds, TBD_values, 'b', 'LineWidth', 2);
hold on;

plot(thresholds, TFD_values, 'r', 'LineWidth', 2);

xline(cfg.decision.threshold, '--k', ...
    sprintf('Seuil retenu = %d', cfg.decision.threshold));

xlabel('Seuil de decision');
ylabel('Taux (%)');

title('Influence du seuil sur les performances');

legend('TBD', 'TFD', 'Seuil retenu', ...
    'Location', 'best');

ylim([0 105]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_tfd_threshold.png', ...
    'Resolution', 300);