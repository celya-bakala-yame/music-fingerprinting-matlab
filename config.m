function cfg = config()
%CONFIG Paramètres communs du système de reconnaissance musicale.

% Audio
cfg.Fs = 8000;

% Spectrogramme
cfg.N = 1024;
cfg.H = 512;
cfg.Nfft = 1024;
cfg.win = hann(cfg.N, 'periodic');

% Détection des pics
cfg.peaks.dm = 3;
cfg.peaks.dk = 5;
cfg.peaks.fmin = 200;
cfg.peaks.fmax = 4000;
cfg.peaks.nbands = 6;
cfg.peaks.per_band_per_s = 5;

% Génération des empreintes
cfg.hash.dt_min = 0.1;
cfg.hash.dt_max = 2;
cfg.hash.dk_max = 60;
cfg.hash.fanout = 10;

% Paramètre à définir avec l'équipe
cfg.hash.gamma_f = NaN;

% Décision de reconnaissance
cfg.decision.threshold = NaN;

end
