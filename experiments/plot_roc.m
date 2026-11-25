clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

R = readtable('results/threshold_sweep.csv');

C = load('results/calibration.mat', 'threshold');

figure('Color','w');

plot(R.TFD, R.TBD, '-o', ...
    'LineWidth', 1.8, ...
    'MarkerSize', 3);

hold on;

% Point de fonctionnement retenu
[~, k] = min(abs(R.threshold - C.threshold));

scatter(R.TFD(k), R.TBD(k), ...
    100, 'filled');

xlabel('Taux de fausse detection (%)');
ylabel('Taux de bonne detection (%)');

title('Courbe ROC du systeme de reconnaissance');

legend('Balayage du seuil', ...
    sprintf('Seuil retenu = %d', C.threshold), ...
    'Location','best');

xlim([-1 101]);
ylim([-1 105]);

grid on;

exportgraphics(gcf, ...
    'results/figures/fig_roc.png', ...
    'Resolution',300);

fprintf('Seuil retenu : %d\n', C.threshold);
fprintf('TBD : %.2f %%\n', R.TBD(k));
fprintf('TFD : %.2f %%\n', R.TFD(k));