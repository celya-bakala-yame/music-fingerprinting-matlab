% INDEX_3SONGS  Indexation des 3 premiers morceaux + vérifications (Thomas, 7-9/11)
%
% Lancer depuis la racine du projet : run('experiments/index_3songs.m')
% Sortie : results/indexes/index_3songs.mat (hors Git, copie sur le Drive)

clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root); addpath(fullfile(root, 'src'));
cfg = config();

meta = readtable(fullfile(root, 'data', 'metadata.csv'), 'TextType', 'string');
meta = meta(1:min(3, height(meta)), :);

% 1. Indexation + temps
t0 = tic;
index = build_index(meta, cfg);
t_index = toc(t0);

out = fullfile(root, 'results', 'indexes', 'index_3songs.mat');
save(out, 'index', '-v7.3');
info = dir(out);

fprintf('\nTemps d''indexation : %.2f s\n', t_index);
fprintf('Taille du fichier   : %.2f Mo\n', info.bytes / 2^20);
disp(index.stats);   % pics/s et clés/s par morceau (≈ densité x fan-out)

% 2. Aucune occurrence perdue : n_index == n_attendu
n_attendu = sum(index.stats.n_keys);
vals = values(index.map);
n_index = sum(cellfun(@(v) size(v, 1), vals));
fprintf('n_attendu = %d   n_index = %d   -> %s\n', n_attendu, n_index, ...
    string(n_attendu == n_index));
assert(n_attendu == n_index, 'Des occurrences ont été perdues.');

% 3. Une clé présente dans au moins 2 morceaux
ks = keys(index.map);
nSongsPerKey = cellfun(@(v) numel(unique(v(:, 1))), vals);
iShared = find(nSongsPerKey >= 2, 1);
if isempty(iShared)
    warning('Aucune clé partagée entre 2 morceaux (possible avec gamma_f = 1).');
else
    occ = index.map(ks{iShared});
    fprintf('Clé partagée %u -> song_id %s\n', ks{iShared}, ...
        mat2str(unique(occ(:, 1))'));
end
fprintf('Clés distinctes : %d | partagées par >= 2 morceaux : %d (%.1f %%)\n', ...
    numel(ks), sum(nSongsPerKey >= 2), 100 * mean(nSongsPerKey >= 2));

% 4. Interroger l'index avec les clés de song02 entier
if height(meta) >= 2
    f2 = char(meta.file(2));
    if ~isfile(f2), f2 = fullfile(root, 'data', 'references', f2); end
    x = preprocess_audio(f2, cfg);
    [k2, m2] = generate_hashes(extract_peaks(compute_spectrogram(x, cfg), cfg), cfg);
    matches = query_index(index, k2, m2);
    share2 = mean(matches(:, 1) == meta.song_id(2));
    fprintf('Requête song02 entier : %.1f %% des correspondances -> song_id %d\n', ...
        100 * share2, meta.song_id(2));
    res = match_audio(matches);
    fprintf('Meilleur : song_id %d, score %d (2e : %d), delta = %d trames\n', ...
        res.song_id(1), res.score(1), res.score2, res.delta(1));
    assert(res.delta(1) == 0, 'Le morceau entier doit s''aligner avec delta = 0.');
end
