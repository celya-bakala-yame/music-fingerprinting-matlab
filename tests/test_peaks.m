function tests = test_peaks
tests = functiontests(localfunctions);
end

function setupOnce(tc)
racine = fullfile(fileparts(mfilename('fullpath')),'..');
addpath(racine, fullfile(racine,'src'));
tc.TestData.cfg = config();
end

function testSinus(tc)
cfg = tc.TestData.cfg;
x = sin(2*pi*1000*(0:5*cfg.Fs-1)'/cfg.Fs);
S = compute_spectrogram(x, cfg);
peaks = extract_peaks(S, cfg);
[~, kmode] = max(histcounts(peaks(:,2), 1:size(S,1)+1));
verifyEqual(tc, kmode, 129, 'AbsTol', 1);
end

function testTaille(tc)
cfg = tc.TestData.cfg;
x = randn(3*cfg.Fs, 1);
[S, ~, t] = compute_spectrogram(x, cfg);
verifyEqual(tc, size(S,1), 513);
verifyEqual(tc, size(S,2), numel(t));
end

function testBande(tc)
cfg = tc.TestData.cfg;
rng(1); x = randn(10*cfg.Fs, 1);
S = compute_spectrogram(x, cfg);
peaks = extract_peaks(S, cfg);
verifyGreaterThanOrEqual(tc, min(peaks(:,2)), 27);
verifyLessThanOrEqual(tc, max(peaks(:,2)), 513);
end

function testDensite(tc)
cfg = tc.TestData.cfg;
rng(1); x = randn(20*cfg.Fs, 1);
S = compute_spectrogram(x, cfg);
peaks = extract_peaks(S, cfg);
d = size(peaks,1) / 20;
verifyGreaterThanOrEqual(tc, d, 25);
verifyLessThanOrEqual(tc, d, 35);
end

function testBandesRepresentees(tc)
cfg = tc.TestData.cfg;
rng(1); x = randn(20*cfg.Fs, 1);
S = compute_spectrogram(x, cfg);
peaks = extract_peaks(S, cfg);
df = cfg.Fs/cfg.Nfft; p = cfg.peaks;
edges = p.fmin*(p.fmax/p.fmin).^((0:p.nbands)/p.nbands);
n = histcounts((peaks(:,2)-1)*df, edges);
verifyTrue(tc, all(n > 0));
end