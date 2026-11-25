function tests = test_hashes
%TEST_HASHES Tests des empreintes et de l'index (Thomas).
%   runtests('tests/test_hashes.m')  -> 5 tests
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
addpath(fullfile(root, 'src'));

cfg = config();
if isnan(cfg.hash.gamma_f)
    cfg.hash.gamma_f = 1;   % valeur de test tant que config.m n'est pas fixé
end
testCase.TestData.cfg = cfg;

% Pics synthétiques (bande 200-4000 Hz : k = 27..513)
rng(1);
peaks = sortrows([randi(300, 400, 1), randi([27 513], 400, 1)]);
peaks = unique(peaks, 'rows');
testCase.TestData.peaks = peaks;
testCase.TestData.peaks_shift = peaks + [17 0];
end

% (1) Déterminisme : même entrée -> mêmes clés
function testDeterminism(testCase)
cfg = testCase.TestData.cfg;
p = testCase.TestData.peaks;
[k1, m1] = generate_hashes(p, cfg);
[k2, m2] = generate_hashes(p(end:-1:1, :), cfg);  % ordre d'entrée indifférent
verifyClass(testCase, k1, 'uint32');
verifyClass(testCase, m1, 'uint32');
verifyNotEmpty(testCase, k1);
verifyEqual(testCase, k1, k2);
verifyEqual(testCase, m1, m2);
verifySize(testCase, k1, size(m1));
end

% (2) Translation temporelle : mêmes clés, m_anchor décalé de 17
function testTranslation(testCase)
cfg = testCase.TestData.cfg;
[k1, m1] = generate_hashes(testCase.TestData.peaks, cfg);
[k2, m2] = generate_hashes(testCase.TestData.peaks_shift, cfg);
verifyEqual(testCase, k2, k1);
verifyEqual(testCase, double(m2) - double(m1), 17 * ones(size(m1)));
end

% (3) Une clé insérée pour 2 morceaux renvoie 2 occurrences
function testSharedKeyTwoOccurrences(testCase)
cfg = testCase.TestData.cfg;
cfg.index.version = 'both';
shared = uint32(12345);
keys_c = {[shared; uint32(1)], [uint32(2); shared; shared]};
m_c = {uint32([10; 11]), uint32([20; 21; 40])};
index = assemble_index([1; 2], keys_c, m_c, [], cfg);

occ = index.map(shared);
verifyEqual(testCase, occ, uint32([1 10; 2 21; 2 40]));
verifyEqual(testCase, numel(unique(occ(:, 1))), 2);
verifyEqual(testCase, index.n_occurrences, 5);

% Aucune occurrence perdue : n_index == n_attendu
vals = values(index.map);
n_index = sum(cellfun(@(v) size(v, 1), vals));
verifyEqual(testCase, n_index, 5);

% v1 et v2 renvoient les mêmes correspondances
q = [shared; uint32(2); uint32(999)];
mq = [100; 101; 102];
verifyEqual(testCase, sortrows(query_index(index, q, mq)), ...
    sortrows(query_index_v2(index, q, mq)));
end

% (4) Les clés d'un morceau indexé renvoient son song_id (chaîne complète)
function testIndexedSongFound(testCase)
cfg = testCase.TestData.cfg;
d = tempname;
mkdir(d);
cleanup = onCleanup(@() rmdir(d, 's')); %#ok<NASGU>

Fs = cfg.Fs;
t = (0:1/Fs:8-1/Fs)';
rng(7);
% Deux "morceaux" synthétiques différents : suites de notes aléatoires
files = {'synth_a.wav', 'synth_b.wav'};
for s = 1:2
    x = zeros(size(t));
    nNotes = 32;
    L = floor(numel(t) / nNotes);
    for n = 1:nNotes
        f = 250 + 3000 * rand(1, 3);
        idx = (n-1)*L + (1:L);
        x(idx) = sum(sin(2*pi*t(idx)*f), 2);
    end
    x = x + 0.05 * randn(size(x));
    x = 0.9 * x / max(abs(x));
    audiowrite(fullfile(d, files{s}), x, Fs);
end

meta = table([1; 2], ["A"; "B"], string(fullfile(d, files(:))), ...
    'VariableNames', {'song_id', 'title', 'file'});
index = build_index(meta, cfg);

x = preprocess_audio(fullfile(d, files{2}), cfg);
peaks = extract_peaks(compute_spectrogram(x, cfg), cfg);
[keys, ma] = generate_hashes(peaks, cfg);

verifyGreaterThan(testCase, numel(keys), 0);
for i = 1:numel(keys)
    occ = index.map(keys(i));
    verifyTrue(testCase, any(occ(:, 1) == 2 & occ(:, 2) == ma(i)));
end

% Le morceau 2 doit dominer les correspondances
matches = query_index(index, keys, ma);
verifyGreaterThan(testCase, mean(matches(:, 1) == 2), 0.5);
verifyEqual(testCase, index.n_occurrences, sum(index.stats.n_keys));
end

% (5) Clés valides : dm dans 2..31, décodage réversible
function testKeyRangeAndDecoding(testCase)
cfg = testCase.TestData.cfg;
p = testCase.TestData.peaks;
keys = generate_hashes(p, cfg);
[kq1, kq2, dm] = decode_key(keys);

dm_min = ceil(cfg.hash.dt_min * cfg.Fs / cfg.H);
dm_max = floor(cfg.hash.dt_max * cfg.Fs / cfg.H);
verifyEqual(testCase, [dm_min dm_max], [2 31]);
verifyTrue(testCase, all(dm >= 2 & dm <= 31));
verifyTrue(testCase, all(kq1 <= 512 & kq2 <= 512));

% Ré-encodage identique
re = uint32(double(kq1) * 2^15 + double(kq2) * 2^5 + double(dm));
verifyEqual(testCase, re, keys);

% Cas connu à la main
cfg.hash.gamma_f = 1;
k = generate_hashes([1 100; 5 130], cfg);    % kq1 = 99, kq2 = 129, dm = 4
verifyEqual(testCase, k, uint32(99*2^15 + 129*2^5 + 4));
end
