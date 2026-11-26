% Test du spectrogramme et detection des pics spectraux
clear;
clc;

cfg = config();

[x, Fs] = audioread('data/references/song_001.wav');

N = cfg.N;
H = cfg.H;
Nfft = cfg.Nfft;

% Calcul du spectrogramme sans toolbox
M = floor((length(x) - N) / H) + 1;
S = zeros(Nfft/2 + 1, M);

for m = 1:M
    debut = (m-1)*H + 1;
    segment = x(debut:debut+N-1);
    segment = segment .* cfg.win;

    X = fft(segment, Nfft);
    S(:,m) = abs(X(1:Nfft/2+1));
end

% Detection du pic dominant
[~, k_max] = max(S, [], 1);
peaks = [(1:M)', k_max'];

% Visualisation
figure;
imagesc((0:M-1)*H/Fs, ...
    (0:Nfft/2)*Fs/Nfft, ...
    20*log10(S + eps));

axis xy;
hold on;

plot((peaks(:,1)-1)*H/Fs, ...
    (peaks(:,2)-1)*Fs/Nfft, ...
    'r.', 'MarkerSize', 6);

xlabel('Temps (s)');
ylabel('Frequence (Hz)');
title('Detection des pics spectraux - Song 001');
colorbar;
