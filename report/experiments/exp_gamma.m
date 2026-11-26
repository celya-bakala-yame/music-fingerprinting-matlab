function exp_gamma()
%EXP_GAMMA Influence de la quantification gamma_f (question 4) :
%   nombre de clés possibles M, appariements parasites attendus nq*Nu/M et
%   mesurés, scores, taux d'identification. Bruit blanc 10 dB et MP3 64 kbit/s,
%   ensemble d'évaluation (60 positives, 60 négatives).
S = rx_setup(); cfg = S.cfg; af = S.af; Nref = numel(af);
dt_min = ceil(cfg.hash.dt_min * cfg.Fs / cfg.H);
dt_max = floor(cfg.hash.dt_max * cfg.Fs / cfg.H);
Nt = dt_max - dt_min + 1;
K = floor(cfg.Nfft / 2) + 1;

P = cell(Nref, 1);
for s = 1:Nref
    [x, ~] = preprocess_audio(af{s}, cfg);
    P{s} = rx_peaks(x, cfg);
end
% Contrôle : gamma_f = 1 reproduit exactement generate_hashes
[k1, m1] = rx_hashes(P{1}, cfg, 1); [k0, m0] = generate_hashes(P{1}, cfg);
assert(isequal(k1, k0) && isequal(m1, m0), 'rx_hashes(gamma=1) differe de generate_hashes');

E = S.eval; nQ = height(E);
rng(2026);
Qn = cell(nQ, 1); Qm = cell(nQ, 1);
for i = 1:nQ
    x = preprocess_audio(E.path{i}, cfg);
    Qn{i} = rx_peaks(apply_degradations(x, cfg.Fs, 'noise', 10), cfg);
    Qm{i} = rx_peaks(rx_mp3(x, cfg, 64), cfg);
end
pos = E.true_song_id > 0; neg = ~pos;
thr = cfg.decision.threshold;

gammas = [1 2 4 8];
rows = cell(0, 16);
for g = gammas
    allk = cell(Nref, 1); allv = cell(Nref, 1);
    for s = 1:Nref
        [k, m] = rx_hashes(P{s}, cfg, g);
        allk{s} = k; allv{s} = [repmat(s, numel(k), 1), m];
    end
    allk = vertcat(allk{:}); allv = vertcat(allv{:});
    Nu = numel(allk);
    [allk, o] = sort(allk); allv = allv(o, :);
    first = find([true; diff(allk) ~= 0]);
    cnt = diff([first; Nu + 1]);
    idx.map = containers.Map('KeyType', 'double', 'ValueType', 'any');
    for u = 1:numel(first)
        idx.map(allk(first(u))) = allv(first(u):first(u) + cnt(u) - 1, :);
    end
    Nf = ceil(K / g); M = Nf^2 * Nt;
    if g == 1
        % Contrôle : rx_query donne les mêmes appariements que query_index
        [kq, mq] = rx_hashes(Qn{1}, cfg, 1);
        a1 = sortrows(rx_query(idx, kq, mq)); a2 = sortrows(query_index(idx, kq, mq));
        assert(isequal(a1, a2), 'rx_query differe de query_index');
    end
    for cnd = {'bruit_10dB', 'mp3_64'}
        Q = Qn; if strcmp(cnd{1}, 'mp3_64'), Q = Qm; end
        nq = zeros(nQ, 1); spur = nq; st = nq; sw = nq; top = nq;
        for i = 1:nQ
            [kq, mq] = rx_hashes(Q{i}, cfg, g);
            nq(i) = numel(kq);
            [st(i), sw(i), ~, spur(i)] = rx_scores(idx, kq, mq, E.true_song_id(i), true);
            top(i) = pos(i) && st(i) > sw(i);
        end
        s1neg = sw(neg);
        accepted_pos = top & st >= thr;
        rows(end + 1, :) = {g, cnd{1}, M, Nu, idx.map.Count, mean(nq(pos)), ...
            mean(nq(pos)) * Nu / M, mean(spur(pos)), mean(st(pos)), mean(sw(pos)), ...
            mean(s1neg), max(s1neg), 100 * mean(top(pos)), 100 * mean(accepted_pos(pos)), ...
            100 * mean(s1neg >= thr), thr}; %#ok<AGROW>
        fprintf('gamma=%d %s : identification %.1f %%, parasites mesurés %.0f\n', ...
            g, cnd{1}, 100 * mean(top(pos)), mean(spur(pos)));
    end
    clear idx
end
T = cell2table(rows, 'VariableNames', {'gamma_f', 'condition', 'M', 'Nu', 'cles_distinctes', ...
    'nq_moyen', 'parasites_attendus', 'parasites_mesures', 's_vrai_moyen', ...
    's_meilleur_faux_positives', 's1_moyen_negatives', 's1_max_negatives', ...
    'identification_rang1_pct', 'TBD_seuil_pct', 'TFD_seuil_pct', 'seuil'});
writetable(T, fullfile(S.out, 'gamma_f.csv'));
disp(T);
end
