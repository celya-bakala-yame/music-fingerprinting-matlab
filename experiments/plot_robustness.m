%% Representation des resultats de robustesse

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

R = readtable('results/robustness_results.csv');

types = string(R.type);

%% Figure 1 : Robustesse au bruit

B = R(types == "noise", :);
B = sortrows(B, 'value');

figure('Color', 'w');

plot(B.value, B.TBD, '-ob', 'LineWidth', 2);
hold on;
plot(B.value, B.TFD, '-sr', 'LineWidth', 2);

xlabel('Rapport signal sur bruit (dB)');
ylabel('Taux (%)');

title('Robustesse au bruit blanc');

legend('TBD', 'TFD', 'Location', 'best');

xticks(B.value);
ylim([0 105]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_vs_snr.png', ...
    'Resolution', 300);

%% Figure 2 : Robustesse au filtrage

F = R(types == "lowpass", :);
F = sortrows(F, 'value');

Tel = R(types == "telephone", :);
Clean = R(types == "clean", :);

labels = categorical({ ...
    'Original', '1000 Hz', '2000 Hz', ...
    '3000 Hz', 'Telephone'});

labels = reordercats(labels, { ...
    'Original', '1000 Hz', '2000 Hz', ...
    '3000 Hz', 'Telephone'});

tbd = [Clean.TBD; F.TBD; Tel.TBD];
tfd = [Clean.TFD; F.TFD; Tel.TFD];

figure('Color', 'w');

bar(labels, [tbd tfd]);

ylabel('Taux (%)');
title('Robustesse au filtrage frequentiel');

legend('TBD', 'TFD', 'Location', 'best');

ylim([0 110]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_filter.png', ...
    'Resolution', 300);

%% Figure 3 : Robustesse au volume

V = R(types == "volume", :);

V = [V; Clean];
V = sortrows(V, 'value');

figure('Color', 'w');

bar(V.value, [V.TBD V.TFD]);

xlabel('Variation du volume (dB)');
ylabel('Taux (%)');

title('Robustesse aux variations de volume');

legend('TBD', 'TFD', 'Location', 'best');

xticks(V.value);
ylim([0 110]);
grid on;

exportgraphics(gcf, ...
    'results/figures/fig_tbd_volume.png', ...
    'Resolution', 300);

fprintf('Les trois figures ont ete sauvegardees.\n');