function [x, Fs] = preprocess_audio(src, cfg, fs_in)
    if ischar(src) || isstring(src)
        if ~isfile(src)
            error('preprocess_audio:input', 'Fichier introuvable : %s', src);
        end
        [x, fs_in] = audioread(src);
    else
        x = src;
        if nargin < 3 || isempty(fs_in)
            error('preprocess_audio:input', 'fs_in obligatoire pour un vecteur');
        end
    end
    if isempty(x)
        error('preprocess_audio:input', 'Signal vide');
    end
    x = mean(x, 2);          % mono
    x = x(:);                % colonne
    x = x - mean(x);         % retrait composante continue
    if fs_in ~= cfg.Fs
        x = resample(x, cfg.Fs, fs_in);
    end
    x = x / max(abs(x) + eps);
    Fs = cfg.Fs;
end