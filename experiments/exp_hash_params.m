% EXP_HASH_PARAMS  gamma_f, fan-out, collisions, temps (Thomas, 13-16/11)
%
% Lancer depuis la racine : run('experiments/exp_hash_params.m')
% Utilise data/queries/calibration_list.csv (Célya) si présent ;
% sinon tire des extraits au hasard (rng(2026)) dans les références
% et dans data/negatives/.
% Sorties : results/tables/hash_params.csv, timing.csv
%           results/figures/fig_gamma_tradeoff.png, fig_fanout_tradeoff.png,
%           fig_collisions_hist.png, fig_timing.png
% Ne JAMAIS utiliser evaluation_list.csv ici.

clear; clc;
N_REFS = 20;            % sous-ensemble de références
N_POS = 30; N_NEG = 30; % si pas de liste de calibration
QUERY_S = 5;
SNR_DB = 10;
GAMMAS = [1 2 4];
FANOUTS = [4 8 10 12];

root = fileparts(fileparts(mfilename('fullpath')));
addpath(root); addpath(fullfile(root, 'src'));
cfg0 = config();
if isnan(cfg0.hash.gamma_f), cfg0.hash.gamma_f = 1; end
figdir = fullfile(root, 'results', 'figures');
tabdir = fullfile(root, 'results', 'tables');

meta = readtable(fullfile(root, 'data', 'metadata.csv'), 'TextType', 'string');
ref = meta(meta.set == "reference", :);
ref = ref(1:min(N_REFS, height(ref)), :);

% ---------------- Requêtes (signaux, pas encore d'empreintes) ------------
Q = load_queries(root, ref, meta, cfg0, N_POS, N_NEG, QUERY_S);
rng(2026);
for q = 1:numel(Q)
    x = Q(q).x;
    Q(q).x_noisy = x + sqrt(mean(x.^2) / 10^(SNR_DB/10)) * randn(size(x));
end
fprintf('%d requêtes (%d positives, %d négatives)\n', numel(Q), ...
    sum([Q.true_id] > 0), sum([Q.true_id] == 0));

% ---------------- Balayage ----------------------------------------------
grid = [ [GAMMAS(:), repmat(cfg0.hash.fanout, numel(GAMMAS), 1), ones(numel(GAMMAS),1)];
         [repmat(cfg0.hash.gamma_f, numel(FANOUTS), 1), FANOUTS(:), 2*ones(numel(FANOUTS),1)] ];
rows = {};
counts_ref = [];
for g = 1:size(grid, 1)
    cfg = cfg0;
    cfg.hash.gamma_f = grid(g, 1);
    cfg.hash.fanout = grid(g, 2);

    t0 = tic; index = build_index(ref, cfg); t_build = toc(t0);
    s = whos('index');
    vals = values(index.map);
    cnt = cellfun(@(v) size(v, 1), vals);
    if cfg.hash.gamma_f == cfg0.hash.gamma_f && cfg.hash.fanout == cfg0.hash.fanout
        counts_ref = cnt;
    end

    for cond = ["propre", "bruit10dB"]
        R = run_queries(index, Q, cfg, cond);
        rows(end+1, :) = {grid(g,3), cfg.hash.gamma_f, cfg.hash.fanout, ...
            char(cond), R.top1_pos, R.tbd, R.tfd, R.mean_true_score, ...
            R.mean_best_wrong_pos, R.mean_best_neg, numel(vals), ...
            sum(cnt) / sum(index.stats.duration_s), s.bytes / 2^20, ...
            t_build / (sum(index.stats.duration_s) / 60), median(R.t)}; %#ok<SAGROW>
    end
end

T = cell2table(rows, 'VariableNames', {'balayage', 'gamma_f', 'fanout', ...
    'condition', 'top1_positives', 'TBD', 'TFD', 'score_moyen_vrai', ...
    'votes_meilleur_faux_pos', 'votes_max_negatives', 'cles_distinctes', ...
    'cles_par_s', 'ram_Mo', 'temps_index_par_min_audio_s', ...
    'temps_requete_median_s'});
disp(T);
writetable(T, fullfile(tabdir, 'hash_params.csv'));

% ---------------- Figures compromis --------------------------------------
for b = 1:2
    sub = T(T.balayage == b, :);
    if b == 1, xv = 'gamma_f'; fn = 'fig_gamma_tradeoff.png';
    else,      xv = 'fanout';  fn = 'fig_fanout_tradeoff.png'; end
    fig = figure('Visible', 'off');
    yyaxis left; hold on;
    for cond = ["propre", "bruit10dB"]
        s2 = sub(sub.condition == cond, :);
        plot(s2.(xv), s2.top1_positives, '-o', 'DisplayName', "top-1 " + cond);
    end
    ylabel('Taux top-1 sur positives'); ylim([0 1]);
    yyaxis right;
    s2 = sub(sub.condition == "propre", :);
    plot(s2.(xv), s2.ram_Mo, '--s', 'DisplayName', 'RAM index (Mo)');
    ylabel('RAM index (Mo)');
    xlabel(strrep(xv, '_', '\_')); legend('Location', 'best'); grid on;
    title(sprintf('Compromis %s', strrep(xv, '_', '\_')));
    exportgraphics(fig, fullfile(figdir, fn)); close(fig);
end

% ---------------- Collisions ---------------------------------------------
if ~isempty(counts_ref)
    fig = figure('Visible', 'off');
    histogram(counts_ref, 'BinMethod', 'integers');
    set(gca, 'YScale', 'log'); grid on;
    xlabel('Occurrences par clé'); ylabel('Nombre de clés (log)');
    title(sprintf('Collisions (gamma\\_f=%d, fan-out=%d, %d morceaux)', ...
        cfg0.hash.gamma_f, cfg0.hash.fanout, height(ref)));
    exportgraphics(fig, fullfile(figdir, 'fig_collisions_hist.png')); close(fig);
end

% ---------------- Temps, configuration finale -----------------------------
index = build_index(ref, cfg0);
R = run_queries(index, Q, cfg0, "propre");
timing = table(numel(R.t), median(R.t), prctile(R.t, 90), ...
    sum(index.stats.time_s) / (sum(index.stats.duration_s) / 60), ...
    'VariableNames', {'nb_requetes', 'reco_median_s', 'reco_p90_s', ...
    'index_s_par_min_audio'});
disp(timing);
writetable(timing, fullfile(tabdir, 'timing.csv'));
fig = figure('Visible', 'off');
histogram(R.t * 1000); xlabel('Temps de reconnaissance (ms)'); ylabel('Requêtes');
xline(median(R.t) * 1000, '-', 'médiane'); xline(prctile(R.t, 90) * 1000, '--', 'p90');
grid on; exportgraphics(fig, fullfile(figdir, 'fig_timing.png')); close(fig);

% =========================================================================
function R = run_queries(index, Q, cfg, cond)
n = numel(Q);
pred = zeros(n, 1); S1 = zeros(n, 1); t = zeros(n, 1);
true_score = nan(n, 1); best_wrong = nan(n, 1);
for q = 1:n
    if cond == "propre", x = Q(q).x; else, x = Q(q).x_noisy; end
    t0 = tic;
    [k, m] = generate_hashes(extract_peaks(compute_spectrogram(x, cfg), cfg), cfg);
    res = match_audio(query_index(index, k, m));
    t(q) = toc(t0);
    if isempty(res.song_id), continue; end
    pred(q) = res.song_id(1); S1(q) = res.score(1);
    tid = Q(q).true_id;
    if tid > 0
        hit = res.song_id == tid;
        if any(hit), true_score(q) = res.score(hit); else, true_score(q) = 0; end
        wrong = res.score(~hit);
        if isempty(wrong), best_wrong(q) = 0; else, best_wrong(q) = max(wrong); end
    end
end
pos = [Q.true_id]' > 0; neg = ~pos;
truth = [Q.true_id]';
R.top1_pos = mean(pred(pos) == truth(pos));
thr = cfg.decision.threshold;
if isnan(thr)           % seuil pas encore calibré
    R.tbd = NaN; R.tfd = NaN;
else
    R.tbd = mean(pred(pos) == truth(pos) & S1(pos) >= thr);
    R.tfd = mean(S1(neg) >= thr);
end
R.mean_true_score = mean(true_score(pos), 'omitnan');
R.mean_best_wrong_pos = mean(best_wrong(pos), 'omitnan');
R.mean_best_neg = mean(S1(neg));
R.t = t;
end

function Q = load_queries(root, ref, meta, cfg, nPos, nNeg, dur)
Q = struct('x', {}, 'x_noisy', {}, 'true_id', {});
list = fullfile(root, 'data', 'queries', 'calibration_list.csv');
if isfile(list)
    L = readtable(list, 'TextType', 'string');
    for i = 1:height(L)
        f = char(L.file(i));
        if ~isfile(f), f = fullfile(root, 'data', 'queries', 'calibration', f); end
        tid = L.true_song_id(i);
        if tid > 0 && ~ismember(tid, ref.song_id), continue; end % hors sous-ensemble
        Q(end+1).x = preprocess_audio(f, cfg); %#ok<AGROW>
        Q(end).true_id = tid;
    end
    return;
end
warning('calibration_list.csv absent : extraits tirés au hasard.');
rng(2026);
L = dur * cfg.Fs;
for i = 1:nPos
    r = randi(height(ref));
    f = char(ref.file(r));
    if ~isfile(f), f = fullfile(root, 'data', 'references', f); end
    x = preprocess_audio(f, cfg);
    st = randi(max(1, numel(x) - L));
    Q(end+1).x = x(st:min(end, st + L - 1)); %#ok<AGROW>
    Q(end).true_id = ref.song_id(r);
end
negs = meta(meta.set == "negative", :);
for i = 1:min(nNeg, 10 * height(negs))
    r = randi(height(negs));
    f = char(negs.file(r));
    if ~isfile(f), f = fullfile(root, 'data', 'negatives', f); end
    x = preprocess_audio(f, cfg);
    st = randi(max(1, numel(x) - L));
    Q(end+1).x = x(st:min(end, st + L - 1)); %#ok<AGROW>
    Q(end).true_id = 0;
end
end
