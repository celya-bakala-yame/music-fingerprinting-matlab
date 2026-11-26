function exp_survival()
%EXP_SURVIVAL Survie des pics et des paires (questions 3, 4 et 6),
%   confrontation du score mesuré au modèle s ~ F rho Tq p^2.
%   Requêtes : les 60 positives de l'ensemble d'évaluation (3, 5, 10 s).
S = rx_setup(); cfg = S.cfg;
E = S.eval(S.eval.true_song_id > 0, :);
fprintf('Chargement de l''index...\n');
L = load(fullfile(S.root, 'results', 'fingerprint_index.mat'), 'index');
idx = L.index;

conds = {'noise', 20; 'noise', 10; 'noise', 5; 'noise', 0; 'mp3', 128; 'mp3', 64; 'mp3', 32};
rng(2026);
rows = cell(0, 13);
X = cell(height(E), 1);
for i = 1:height(E)
    x = preprocess_audio(E.path{i}, cfg);
    X{i} = x;
    Tq = E.duration_s(i); sid = E.true_song_id(i);
    Pc = rx_peaks(x, cfg);
    [kc, mc] = generate_hashes(Pc, cfg);
    [st, sw] = rx_scores(idx, kc, mc, sid);
    rows(end + 1, :) = {E.query_id(i), Tq, 'clean', 0, size(Pc, 1), numel(kc), ...
        size(Pc, 1), numel(kc), 1, 1, 1, st, sw}; %#ok<AGROW>
    for c = 1:size(conds, 1)
        if strcmp(conds{c, 1}, 'noise')
            y = apply_degradations(x, cfg.Fs, 'noise', conds{c, 2});
        else
            y = rx_mp3(x, cfg, conds{c, 2});
        end
        Pd = rx_peaks(y, cfg);
        [kd, md] = generate_hashes(Pd, cfg);
        [pe, pt] = rx_survival(Pc, Pd);
        if isempty(kc), ps = NaN; else, ps = mean(ismember([kc mc], [kd md], 'rows')); end
        [st, sw] = rx_scores(idx, kd, md, sid);
        rows(end + 1, :) = {E.query_id(i), Tq, conds{c, 1}, conds{c, 2}, size(Pc, 1), ...
            numel(kc), size(Pd, 1), numel(kd), pe, pt, ps, st, sw}; %#ok<AGROW>
    end
    fprintf('Survie : requête %d/%d\n', i, height(E));
end
T = cell2table(rows, 'VariableNames', {'query_id', 'Tq', 'condition', 'niveau', ...
    'n_pics_propre', 'n_cles_propre', 'n_pics_degrade', 'n_cles_degrade', ...
    'p_exact', 'p_tol1', 'survie_paires', 's_vrai', 's_meilleur_faux'});
writetable(T, fullfile(S.out, 'survival_by_query.csv'));

%% Q3 : taille du voisinage (20 requêtes positives de 10 s, bruit blanc 10 dB)
V = [1 2 5; 2 3 5; 3 5 5; 3 8 5; 5 8 5; 5 12 5; 3 5 3; 3 5 8];   % [dm dk pics/bande/s]
sel = find(E.duration_s == 10);
rng(7);
Y = cell(numel(sel), 1);
for j = 1:numel(sel)
    Y{j} = apply_degradations(X{sel(j)}, cfg.Fs, 'noise', 10);
end
R = zeros(size(V, 1), 6);
for v = 1:size(V, 1)
    c2 = cfg;
    c2.peaks.dm = V(v, 1); c2.peaks.dk = V(v, 2); c2.peaks.per_band_per_s = V(v, 3);
    np = 0; dur = 0; pe = zeros(numel(sel), 1); pt = pe;
    for j = 1:numel(sel)
        Pc = rx_peaks(X{sel(j)}, c2); Pd = rx_peaks(Y{j}, c2);
        np = np + size(Pc, 1); dur = dur + numel(X{sel(j)}) / cfg.Fs;
        [pe(j), pt(j)] = rx_survival(Pc, Pd);
    end
    rho = np / dur;
    R(v, :) = [V(v, :), rho, mean(pe), mean(pt)];
end
Tn = array2table(R, 'VariableNames', {'dm', 'dk', 'pics_bande_s', 'rho', 'p_exact', 'p_tol1'});
Tn.rho_p2_exact = Tn.rho .* Tn.p_exact .^ 2;
Tn.rho_p2_tol1 = Tn.rho .* Tn.p_tol1 .^ 2;
writetable(Tn, fullfile(S.out, 'neighborhood.csv'));
disp(Tn);
end
