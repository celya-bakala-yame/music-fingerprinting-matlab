function exp_complements()
%EXP_COMPLEMENTS Mesures complémentaires demandées en relecture du rapport.
%   (a) tests unitaires de la seconde implémentation des empreintes
%       (copie de la branche thomas/hashes-index dans thomas_branch/) ;
%   (b) non-régression : mêmes paires et mêmes scores S1/S2 que la version
%       évaluée (src/generate_hashes.m) pour gamma_f = 1 ;
%   (c) index en tableaux triés (v2) : mémoire et temps de requête face au
%       containers.Map, mêmes correspondances ;
%   (d) influence du nombre de cibles par ancre F ;
%   (e) distribution du nombre d'occurrences par clé (collisions).
%   Aucun fichier de src/ ni de results/ n'est modifié.
S = rx_setup(); cfg = S.cfg; af = S.af; root = S.root; out = S.out;
tdir = fullfile(root, 'report', 'experiments', 'thomas_branch');
Nref = numel(af);
thr = cfg.decision.threshold;

%% Pics des références et des requêtes d'évaluation (chaîne évaluée)
P = cell(Nref, 1);
for s = 1:Nref
    x = preprocess_audio(af{s}, cfg);
    P{s} = rx_peaks(x, cfg);
end
E = S.eval; nQ = height(E); pos = E.true_song_id > 0; neg = ~pos;
Q = cell(nQ, 1); Qn = cell(nQ, 1);
rng(2026);
for i = 1:nQ
    x = preprocess_audio(E.path{i}, cfg);
    Q{i} = rx_peaks(x, cfg);
    Qn{i} = rx_peaks(apply_degradations(x, cfg.Fs, 'noise', 10), cfg);
end
fprintf('Pics calculés.\n');

%% Version évaluée : clés et scores sur l'index du projet
Ks = cell(Nref, 1); Ms = Ks;
for s = 1:Nref
    [Ks{s}, Ms{s}] = generate_hashes(P{s}, cfg);
end
L = load(fullfile(root, 'results', 'fingerprint_index.mat'), 'index');
idxA = L.index; clear L
SA = zeros(2 * nQ, 3);                 % [S1 S2 song_id] propre puis bruit 10 dB
for c = 1:2
    for i = 1:nQ
        if c == 1, pk = Q{i}; else, pk = Qn{i}; end
        [k, m] = generate_hashes(pk, cfg);
        res = match_audio(query_index(idxA, k, m));
        SA((c - 1) * nQ + i, :) = rx_top(res);
    end
end
clear idxA
fprintf('Scores de la version évaluée calculés.\n');

%% Seconde implémentation (uint32, gamma_f, tableaux triés)
oldpath = path;
addpath(fullfile(tdir, 'src'), '-begin');
clear generate_hashes query_index build_index assemble_index query_index_v2 decode_key
cleanupPath = onCleanup(@() restore_path(oldpath)); %#ok<NASGU>

% (a) tests unitaires
try
    tr = runtests(fullfile(tdir, 'tests', 'test_hashes.m'));
    T = table({tr.Name}', [tr.Passed]', [tr.Failed]', 'VariableNames', {'test', 'reussi', 'echec'});
catch ME
    T = table({ME.message}, false, true, 'VariableNames', {'test', 'reussi', 'echec'});
end
writetable(T, fullfile(out, 'thomas_tests.csv'));
disp(T);

% (b) paires identiques ?
cfgT = cfg; cfgT.hash.gamma_f = 1; cfgT.index.version = 'both';
KT = cell(Nref, 1); MT = KT; samePairs = true(Nref, 1);
for s = 1:Nref
    [KT{s}, MT{s}] = generate_hashes(P{s}, cfgT);
    [a1, a2, adm] = decode_key(KT{s});
    A = sortrows([double(a1) + 1, double(a2) + 1, double(adm), double(MT{s})]);
    kc = Ks{s};
    dm = mod(kc, 32); r = floor(kc / 32);
    B = sortrows([floor(r / 513) + 1, mod(r, 513) + 1, dm, Ms{s}]);
    samePairs(s) = isequal(A, B);
end
t0 = tic;
idxT = assemble_index((1:Nref)', KT, MT, [], cfgT);
tBuild = toc(t0);

% (c) mémoire et temps de requête, v1 (Map) et v2 (tableaux triés)
v2 = rmfield(idxT, intersect(fieldnames(idxT), {'map', 'songs', 'metadata', 'cfg'}));
w = whos('v2'); bytesV2 = w.bytes;
try
    bytesMap = numel(getByteStreamFromArray(struct('map', idxT.map)));
catch
    bytesMap = NaN;
end
SB = zeros(2 * nQ, 3); sameMatches = true(2 * nQ, 1);
t1 = zeros(2 * nQ, 1); t2 = t1;
for c = 1:2
    for i = 1:nQ
        if c == 1, pk = Q{i}; else, pk = Qn{i}; end
        [k, m] = generate_hashes(pk, cfgT);
        a = tic; m1 = query_index(idxT, k, m); t1((c - 1) * nQ + i) = toc(a);
        a = tic; m2 = query_index_v2(idxT, k, m); t2((c - 1) * nQ + i) = toc(a);
        sameMatches((c - 1) * nQ + i) = isequal(sortrows(m1), sortrows(m2));
        SB((c - 1) * nQ + i, :) = rx_top(match_audio(m2));
    end
end
restore_path(oldpath);
clear generate_hashes query_index assemble_index query_index_v2 decode_key

sameScores = all(SA == SB, 2);
R = table(sum(samePairs), Nref, sum(sameScores), 2 * nQ, sum(sameMatches), 2 * nQ, ...
    double(idxT.n_occurrences), numel(idxT.ukeys), tBuild, bytesMap / 2^20, bytesV2 / 2^20, ...
    1000 * mean(t1), 1000 * mean(t2), 'VariableNames', {'morceaux_paires_identiques', 'n_morceaux', ...
    'requetes_scores_identiques', 'n_requetes', 'requetes_appariements_v1_v2_identiques', 'n_req', ...
    'Nu', 'cles_distinctes', 'assemblage_s', 'map_serialise_Mo', 'tableaux_tries_Mo', ...
    'recherche_map_ms', 'recherche_v2_ms'});
writetable(R, fullfile(out, 'nonreg_v2.csv'));
disp(R);

%% (d) Nombre de cibles par ancre F (gamma_f = 1)
Fs_ = [4 8 10 12 16];
rows = zeros(numel(Fs_), 9);
for a = 1:numel(Fs_)
    cF = cfg; cF.hash.fanout = Fs_(a);
    idx = rx_index(P, cF);
    nq = zeros(nQ, 1); st = nq; sw = nq; top = nq;
    for i = 1:nQ
        [kq, mq] = rx_hashes(Qn{i}, cF, 1);
        nq(i) = numel(kq);
        [st(i), sw(i)] = rx_scores(idx, kq, mq, E.true_song_id(i), true);
        top(i) = pos(i) && st(i) > sw(i);
    end
    nu = sum(cellfun(@(v) size(v, 1), values(idx.map)));
    rows(a, :) = [Fs_(a), nu, mean(nq(pos)), mean(st(pos)), mean(sw(pos)), max(sw(neg)), ...
        100 * mean(top(pos)), 100 * mean(top(pos) & st(pos) >= thr), 100 * mean(sw(neg) >= thr)];
    fprintf('F = %d : Nu = %d, TBD = %.1f %%\n', Fs_(a), nu, rows(a, 8));
    clear idx
end
TF = array2table(rows, 'VariableNames', {'F', 'Nu', 'nq_moyen', 's_vrai_moyen', ...
    's_meilleur_faux_pos', 's1_max_negatives', 'identification_pct', 'TBD_seuil_pct', 'TFD_seuil_pct'});
writetable(TF, fullfile(out, 'fanout.csv'));
disp(TF);

%% (e) Collisions : nombre d'occurrences par clé (version évaluée)
allk = vertcat(Ks{:});
[~, ~, ic] = unique(allk);
cnt = accumarray(ic, 1);
[u, ~, j] = unique(cnt);
writetable(table(u, accumarray(j, 1), 'VariableNames', {'occurrences', 'n_cles'}), ...
    fullfile(out, 'collisions.csv'));
cs = sort(cnt, 'descend');
top1 = sum(cs(1:ceil(0.01 * numel(cs)))) / sum(cs);
writetable(table(numel(cnt), sum(cnt), mean(cnt), max(cnt), mean(cnt == 1), top1, ...
    'VariableNames', {'cles_distinctes', 'Nu', 'occ_moyenne', 'occ_max', 'frac_cles_uniques', ...
    'part_entrees_top1pct'}), fullfile(out, 'collisions_summary.csv'));
fprintf('Collisions : 1 %% des clés portent %.1f %% des entrées\n', 100 * top1);
end

function t = rx_top(res)
if isempty(res.song_id)
    t = [0 0 0];
else
    t = [res.score(1), res.score2, res.song_id(1)];
end
end

function idx = rx_index(P, cfg)
allk = cell(numel(P), 1); allv = allk;
for s = 1:numel(P)
    [k, m] = rx_hashes(P{s}, cfg, 1);
    allk{s} = k; allv{s} = [repmat(s, numel(k), 1), m];
end
allk = vertcat(allk{:}); allv = vertcat(allv{:});
[allk, o] = sort(allk); allv = allv(o, :);
first = find([true; diff(allk) ~= 0]);
cnt = diff([first; numel(allk) + 1]);
idx.map = containers.Map('KeyType', 'double', 'ValueType', 'any');
for u = 1:numel(first)
    idx.map(allk(first(u))) = allv(first(u):first(u) + cnt(u) - 1, :);
end
end

function restore_path(p)
path(p);
clear generate_hashes query_index build_index assemble_index query_index_v2 decode_key
end
