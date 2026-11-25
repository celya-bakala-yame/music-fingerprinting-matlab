clear;
clc;

project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

E = readtable('results/evaluation_scores.csv', ...
    'TextType','string');

M = readtable('data/metadata.csv', ...
    'TextType','string');

% Conserver les requetes positives
E = E(E.true_song_id > 0,:);

% Associer chaque requete au genre du morceau
E = innerjoin(E, M(:, {'song_id','title','artist','genre'}), ...
    'LeftKeys','true_song_id', ...
    'RightKeys','song_id');

assert(height(E) == 60);

E.correct = E.predicted_song_id == E.true_song_id;

genres = unique(E.genre);

n = numel(genres);

total = zeros(n,1);
success = zeros(n,1);
failures = zeros(n,1);
TBD = zeros(n,1);

for i = 1:n

    mask = E.genre == genres(i);

    total(i) = nnz(mask);
    success(i) = sum(E.correct(mask));
    failures(i) = total(i) - success(i);

    TBD(i) = 100 * success(i) / total(i);

end

T = table(genres,total,success,failures,TBD, ...
    'VariableNames', ...
    {'genre','queries','success','failures','TBD'});

disp(T);

fprintf('\n=== DETAILS DES ECHECS ===\n');

disp(E(~E.correct, ...
    {'query_id','true_song_id','title', ...
    'artist','genre','S1','S2'}));

writetable(T,'results/evaluation_by_genre.csv');

writetable(E(~E.correct,:), ...
    'results/errors_with_metadata.csv');

% Figure
figure('Color','w');

b = bar(categorical(genres,genres),TBD);

ylabel('Taux de bonne detection (%)');
xlabel('Genre musical');

title('Performances de reconnaissance par genre');

ylim([0 115]);

grid on;
xtickangle(30);

% Afficher le nombre de requetes
for i = 1:n

    text(b.XEndPoints(i),TBD(i)+3, ...
        sprintf('n=%d',total(i)), ...
        'HorizontalAlignment','center');

end

exportgraphics(gcf, ...
    'results/figures/fig_tbd_by_genre.png', ...
    'Resolution',300);