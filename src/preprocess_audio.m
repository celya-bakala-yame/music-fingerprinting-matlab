function [x, Fs] = preprocess_audio(src, cfg, fs_in)

if ischar(src) || isstring(src)
    if ~isfile(src)
        error('preprocess_audio:input', ...
            'Fichier introuvable : %s', src);
    end
    [x, fs_in] = audioread(src);
else
    x = src;
    if nargin < 3 || isempty(fs_in)
        error('preprocess_audio:input', ...
            'fs_in obligatoire pour un vecteur');
    end
end

if isempty(x)
    error('preprocess_audio:input', 'Signal vide');
end

x = mean(x, 2);
x = x(:);
x = x - mean(x);

% Reechantillonnage sans Signal Processing Toolbox
if fs_in ~= cfg.Fs

    % Filtrage anti-repliement avant sous-echantillonnage
    if fs_in > cfg.Fs
        fc = 0.45 * cfg.Fs / fs_in;
        n = (-100:100)';

        h = zeros(size(n));
        nz = n ~= 0;

        h(nz) = sin(2*pi*fc*n(nz)) ./ (pi*n(nz));
        h(~nz) = 2*fc;

        w = 0.54 + 0.46*cos(pi*n/100);
        h = h .* w;
        h = h / sum(h);

        x = conv(x, h, 'same');
    end

    t_old = (0:length(x)-1)' / fs_in;
    t_new = (0:1/cfg.Fs:t_old(end))';

    x = interp1(t_old, x, t_new, 'linear');
end

x = x / max(abs(x) + eps);
Fs = cfg.Fs;

end