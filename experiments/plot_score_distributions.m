clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

R = readtable('results/calibration_scores.csv');

C = load('results/calibration.mat', 'threshold');

positive = R.true_song_id > 0;
negative = R.true_song_id == 0;

scores_pos = R.S1(positive);
scores_neg = R.S1(negative);

% Transformation permettant de conserver les scores nuls
% tout en utilisant une echelle logarithmique
P = scores_pos + 1;
N = scores_neg + 1;

max_score = max([P; N]);

edges = logspace(0, log10(max_score + 1), 25);

figure('Color','w');

histogram(P, edges, ...
    'FaceColor',[0.1 0.45 0.8], ...
    'FaceAlpha',0.65);

hold on;

histogram(N, edges, ...
    'FaceColor',[0.9 0.3 0.15], ...
    'FaceAlpha',0.65);

xline(C.threshold + 1, '--k', ...
    'LineWidth',2);

set(gca,'XScale','log');

xlabel('Score S1 + 1 (echelle logarithmique)');
ylabel('Nombre de requetes');

title('Distribution des scores de reconnaissance');

legend('Requetes positives', ...
    'Requetes negatives', ...
    sprintf('Seuil S1 = %d', C.threshold), ...
    'Location','best');

grid on;

exportgraphics(gcf, ...
    'results/figures/fig_score_distributions_log.png', ...
    'Resolution',300);

fprintf('Score positif minimum : %d\n', min(scores_pos));
fprintf('Score negatif maximum : %d\n', max(scores_neg));
fprintf('Score positif moyen : %.2f\n', mean(scores_pos));
fprintf('Score negatif moyen : %.2f\n', mean(scores_neg));
fprintf('Seuil retenu : %d\n', C.threshold);