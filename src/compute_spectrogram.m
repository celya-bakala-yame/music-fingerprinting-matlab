function [S_dB, f, t] = compute_spectrogram(x, cfg)
[s, f, t] = spectrogram(x, cfg.win, cfg.N - cfg.H, cfg.Nfft, cfg.Fs);
S_dB = 10*log10(abs(s).^2 + 1e-12);
end