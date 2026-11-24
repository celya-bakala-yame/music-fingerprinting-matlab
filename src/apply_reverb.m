function y = apply_reverb(x, Fs, RT60)
% Simulation d'une reverberation acoustique

x = x(:);

t = (0:round(RT60*Fs))' / Fs;

% Enveloppe exponentielle decroissante
envelope = exp(-log(1000)*t/RT60);

% Reponse impulsionnelle synthetique
h = randn(size(t)) .* envelope;

h = 0.5 * h / sqrt(sum(h.^2));

% Ajout du son direct
h(1) = h(1) + 1;

% Convolution avec la reponse impulsionnelle
y = conv(x, h);

% Conservation de la duree initiale
y = y(1:length(x));

% Normalisation
y = y / (max(abs(y)) + eps);

end