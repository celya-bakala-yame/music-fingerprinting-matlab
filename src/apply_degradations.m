function y = apply_degradations(x, Fs, type, value)
% Application de degradations a un signal audio

x = x(:);

switch lower(type)

    case 'noise'
        % Ajout de bruit blanc avec un RSB impose
        noise = randn(size(x));

        P_signal = mean(x.^2);
        P_noise = mean(noise.^2);

        noise = noise * sqrt( ...
            P_signal / (P_noise * 10^(value/10)));

        y = x + noise;

    case 'lowpass'
        % Filtrage passe-bas FIR sans toolbox
        y = lowpass_fir(x, Fs, value);

    case 'telephone'
        % Bande telephonique : 300-3400 Hz
        y = lowpass_fir(x, Fs, 3400) ...
            - lowpass_fir(x, Fs, 300);

    case 'volume'
        % Modification du volume en dB
        y = x * 10^(value/20);

        % Simulation de la saturation
        y = max(-1, min(1, y));

    case 'clean'
        y = x;

    otherwise
        error('Degradation inconnue : %s', type);

end

end


function y = lowpass_fir(x, Fs, fc)

n = (-100:100)';
f = fc/Fs;

h = zeros(size(n));

nz = n ~= 0;

h(nz) = sin(2*pi*f*n(nz)) ./ (pi*n(nz));
h(~nz) = 2*f;

w = 0.54 + 0.46*cos(pi*n/100);

h = h .* w;
h = h / sum(h);

y = conv(x, h, 'same');

end