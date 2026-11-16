function peaks = extract_peaks(S_dB, cfg)
p  = cfg.peaks;
df = cfg.Fs / cfg.Nfft;                      % 7.8125 Hz

% 1. maxima locaux (±dk canaux, ±dm trames)
Smax = movmax(movmax(S_dB, [p.dk p.dk], 1), [p.dm p.dm], 2);
mask = (S_dB == Smax);

% 2. restriction 200-4000 Hz (k = 27..513)
kmin = ceil(p.fmin/df) + 1;
kmax = floor(p.fmax/df) + 1;
mask(1:kmin-1, :) = false;
mask(kmax+1:end, :) = false;
[k, m] = find(mask);
vals = S_dB(mask);

% 3. bandes géométriques + blocs d'1 s (≈16 trames)
edges = p.fmin * (p.fmax/p.fmin).^((0:p.nbands)/p.nbands);
band  = discretize((k-1)*df, edges);
blocklen = round(cfg.Fs / cfg.H);
block = ceil(m / blocklen);
g = (block-1)*p.nbands + band;

keep = false(numel(k), 1);
for gg = unique(g)'
    idx = find(g == gg);
    [~, o] = sort(vals(idx), 'descend');
    keep(idx(o(1:min(end, p.per_band_per_s)))) = true;
end

peaks = sortrows([m(keep) k(keep)]);
end