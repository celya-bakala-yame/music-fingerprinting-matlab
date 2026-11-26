% INDEX_PERF  Index 50 puis >= 100 morceaux, temps et mémoire (Thomas, 10-12/11)
%
% Lancer depuis la racine : run('experiments/index_perf.m')
% Sorties : results/indexes/index_100.mat (hors Git, Drive)
%           results/tables/index_perf.csv
%
% Mettre DO_V2 = true pour comparer la version 2 (tableaux triés).

clear; clc;
DO_V2 = true;
N_QUERIES = 20;
QUERY_S = 5;

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root); addpath(fullfile(root, 'src'));
cfg = config();

meta = readtable(fullfile(root, 'data', 'metadata.csv'), 'TextType', 'string');
ref = meta(meta.set == "reference", :);
sizes = unique([3, min(50, height(ref)), height(ref)]);

rows = {};
for nb = sizes
    sub = ref(1:nb, :);

    % --- Version 1 : containers.Map
    cfg1 = cfg; cfg1.index.version = 1;
    t0 = tic; index = build_index(sub, cfg1); t_build = toc(t0);
    s = whos('index');
    vals = values(index.map);
    n_occ = sum(cellfun(@(v) size(v, 1), vals));
    assert(n_occ == sum(index.stats.n_keys), 'n_index ~= n_attendu');

    [t_query, queries] = time_queries(index, sub, cfg, N_QUERIES, QUERY_S, @query_index);

    tmp = [tempname '.mat'];
    save(tmp, 'index', '-v7.3'); d = dir(tmp); delete(tmp);

    rows(end+1, :) = {nb, 1, t_build, t_build / nb, s.bytes / 2^20, ...
        d.bytes / 2^20, n_occ, numel(vals), n_occ / numel(vals), ...
        sum(index.stats.duration_s) / 60, median(t_query)}; %#ok<SAGROW>

    if nb == sizes(end)
        save(fullfile(root, 'results', 'indexes', 'index_100.mat'), 'index', '-v7.3');
        index_v1 = index;
    end

    % --- Version 2 : tableaux triés
    if DO_V2
        cfg2 = cfg; cfg2.index.version = 2;
        t0 = tic; index = build_index(sub, cfg2); t_build = toc(t0);
        s = whos('index');
        t_query = time_queries(index, sub, cfg, N_QUERIES, QUERY_S, @query_index_v2, queries);
        tmp = [tempname '.mat'];
        save(tmp, 'index', '-v7.3'); d = dir(tmp); delete(tmp);
        rows(end+1, :) = {nb, 2, t_build, t_build / nb, s.bytes / 2^20, ...
            d.bytes / 2^20, numel(index.keys), numel(index.ukeys), ...
            numel(index.keys) / numel(index.ukeys), ...
            sum(index.stats.duration_s) / 60, median(t_query)}; %#ok<SAGROW>

        % Non-régression v1 / v2 sur les mêmes requêtes
        if nb == sizes(end)
            for q = 1:numel(queries)
                a = sortrows(query_index(index_v1, queries(q).keys, queries(q).m));
                b = sortrows(query_index_v2(index, queries(q).keys, queries(q).m));
                assert(isequal(a, b), 'v1 et v2 diffèrent sur la requête %d', q);
            end
            fprintf('Non-régression v1/v2 : %d requêtes identiques\n', numel(queries));
        end
    end
end

T = cell2table(rows, 'VariableNames', {'nb_morceaux', 'version', ...
    'temps_index_s', 'temps_par_morceau_s', 'ram_Mo', 'disque_Mo', ...
    'nb_cles', 'nb_cles_distinctes', 'occ_moy_par_cle', 'audio_min', ...
    'temps_requete_median_s'});
disp(T);
writetable(T, fullfile(root, 'results', 'tables', 'index_perf.csv'));

% -------------------------------------------------------------------------
function [t, queries] = time_queries(index, sub, cfg, nQ, dur, qfun, queries)
% Temps médian query + match_audio sur nQ extraits de dur secondes.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 7
    rng(2026);
    queries = struct('keys', {}, 'm', {}, 'song_id', {});
    for q = 1:nQ
        r = randi(height(sub));
        f = char(sub.file(r));
        if ~isfile(f), f = fullfile(root, 'data', 'references', f); end
        x = preprocess_audio(f, cfg);
        L = dur * cfg.Fs;
        st = randi(max(1, numel(x) - L));
        xq = x(st:min(end, st + L - 1));
        [k, m] = generate_hashes(extract_peaks(compute_spectrogram(xq, cfg), cfg), cfg);
        queries(q) = struct('keys', k, 'm', m, 'song_id', sub.song_id(r));
    end
end
t = zeros(numel(queries), 1);
for q = 1:numel(queries)
    t0 = tic;
    res = match_audio(qfun(index, queries(q).keys, queries(q).m)); %#ok<NASGU>
    t(q) = toc(t0);
end
end
