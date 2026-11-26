function exp_index_cost()
%EXP_INDEX_COST Taille de l'index et temps de requête en fonction du nombre
%   de morceaux indexés (figure demandée par le sujet). Index reconstruit en
%   mémoire avec src/build_index.m, jamais sauvegardé sur disque.
S = rx_setup(); cfg = S.cfg; af = S.af;
E = S.eval(S.eval.true_song_id > 0 & S.eval.duration_s == 5, :);
nq = height(E);
Kq = cell(nq, 1); Mq = cell(nq, 1); text = zeros(nq, 1);
for i = 1:nq
    t0 = tic;
    x = preprocess_audio(E.path{i}, cfg);
    [Kq{i}, Mq{i}] = generate_hashes(rx_peaks(x, cfg), cfg);
    text(i) = toc(t0);
end
Ns = [10 25 50 100];
rows = zeros(numel(Ns), 9);
for a = 1:numel(Ns)
    N = Ns(a);
    t0 = tic;
    evalc('index = build_index(af(1:N), cfg);');
    tb = toc(t0);
    vals = values(index.map);
    Nu = sum(cellfun(@(v) size(v, 1), vals));
    nk = double(index.map.Count);
    try
        mb = numel(getByteStreamFromArray(index)) / 2^20;
    catch
        mb = NaN;
    end
    tq = zeros(nq, 3);
    for r = 1:3
        for i = 1:nq
            t0 = tic;
            matches = query_index(index, Kq{i}, Mq{i});
            res = match_audio(matches);
            classify_match(res, index, cfg);
            tq(i, r) = toc(t0);
        end
    end
    tq = median(tq, 2);
    rows(a, :) = [N, tb, Nu, nk, mb, 1000 * mean(tq), 1000 * median(tq), ...
        1000 * mean(text), 1000 * (mean(tq) + mean(text))];
    fprintf('N=%d : %d entrées, %.1f Mo, recherche %.2f ms\n', N, Nu, mb, 1000 * mean(tq));
    clear index vals
end
T = array2table(rows, 'VariableNames', {'n_morceaux', 'temps_construction_s', 'Nu_entrees', ...
    'cles_distinctes', 'taille_serialisee_Mo', 'recherche_moy_ms', 'recherche_med_ms', ...
    'extraction_moy_ms', 'total_moy_ms'});
writetable(T, fullfile(S.out, 'index_cost.csv'));
disp(T);
end
