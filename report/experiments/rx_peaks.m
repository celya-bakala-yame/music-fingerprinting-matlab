function P = rx_peaks(x, cfg)
%RX_PEAKS Pics [m k] d'un signal déjà prétraité (fonctions de src/).
S_dB = compute_spectrogram(x, cfg);
P = extract_peaks(S_dB, cfg);
end
