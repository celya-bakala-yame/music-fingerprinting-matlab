function [S_dB, f, t] = compute_spectrogram(x, cfg)
% Calcule le spectrogramme sans Signal Processing Toolbox.

x = x(:);

N = cfg.N;
H = cfg.H;
Nfft = cfg.Nfft;
Fs = cfg.Fs;

if length(x) < N
    error('Le signal audio est trop court.');
end

% Nombre de trames completes
M = floor((length(x) - N) / H) + 1;

% Matrice : frequences x trames
S = zeros(floor(Nfft/2) + 1, M);

for m = 1:M
    debut = (m-1)*H + 1;

    segment = x(debut:debut+N-1);
    segment = segment .* cfg.win(:);

    X = fft(segment, Nfft);

    S(:,m) = abs(X(1:size(S,1)));
end

% Conversion en decibels
S_dB = 20*log10(S + eps);

% Axes du spectrogramme
f = (0:size(S,1)-1)' * Fs / Nfft;
t = ((0:M-1)*H + N/2) / Fs;
end