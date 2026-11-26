function exp_theory()
%EXP_THEORY Vérifications théoriques du rapport (questions 1 et 2).
%   Q1 : part de la puissance des références sous 4 kHz ; efficacité du
%        filtre anti-repliement de preprocess_audio (sans toolbox).
%   Q2 : vérification de la propriété (2) (filtrage = biais g(k)),
%        invariance au gain et propriété (1) (translation temporelle).
S = rx_setup(); cfg = S.cfg;

%% Q1-a : puissance sous 4 kHz (signal d'origine, mono)
n = numel(S.af); frac = nan(n, 1); fs0 = nan(n, 1);
for s = 1:n
    try
        [x, fs] = audioread(S.af{s});
        x = mean(x, 2); x = x - mean(x);
        X = abs(fft(x)).^2;
        f = (0:numel(x) - 1)' * fs / numel(x);
        half = f <= fs / 2;
        frac(s) = sum(X(half & f <= 4000)) / sum(X(half));
        fs0(s) = fs;
    catch ME
        warning('exp_theory:read', '%s : %s', S.af{s}, ME.message);
    end
end
writetable(table((1:n)', fs0, frac, 'VariableNames', ...
    {'song_id', 'fs_orig', 'frac_power_below_4k'}), fullfile(S.out, 'q1_power_below_4k.csv'));
fprintf('Q1 : puissance sous 4 kHz : moyenne %.3f, min %.3f, max %.3f\n', ...
    mean(frac, 'omitnan'), min(frac), max(frac));

%% Q1-b : anti-repliement (raies à 1 kHz et 5 kHz échantillonnées à 44,1 kHz)
fs = 44100; t = (0:2 * fs - 1)' / fs;
x = sin(2 * pi * 1000 * t) + sin(2 * pi * 5000 * t);
y_ok = preprocess_audio(x, cfg, fs);
t_new = (0:1 / cfg.Fs:t(end))';
y_raw = interp1(t, x, t_new, 'linear');
lv = @(y, f0) line_level(y, cfg.Fs, f0);
r_ok = lv(y_ok, 3000) - lv(y_ok, 1000);
r_raw = lv(y_raw, 3000) - lv(y_raw, 1000);
writetable(table({'avec_filtre'; 'sans_filtre'}, [r_ok; r_raw], ...
    'VariableNames', {'methode', 'niveau_3kHz_rel_1kHz_dB'}), fullfile(S.out, 'q1_antialiasing.csv'));
fprintf('Q1 : raie repliée à 3 kHz : %.1f dB avec filtre, %.1f dB sans filtre\n', r_ok, r_raw);

%% Q2 : propriété (2) sur le morceau 19 (passe-bande RIF 500-2000 Hz, ordre 64, alpha = 0.5)
[x, ~] = preprocess_audio(S.af{19}, cfg);
L = 65; nn = (0:L - 1)' - (L - 1) / 2;
f1 = 500 / cfg.Fs; f2 = 2000 / cfg.Fs;
h = 2 * f2 * rx_sinc(2 * f2 * nn) - 2 * f1 * rx_sinc(2 * f1 * nn);
h = h .* (0.54 - 0.46 * cos(2 * pi * (0:L - 1)' / (L - 1)));
alpha = 0.5;
y = alpha * filter(h, 1, x);
[Sx, f, ~] = compute_spectrogram(x, cfg);
Sy = compute_spectrogram(y, cfg);
Hk = fft(h, cfg.Nfft);
g = 20 * log10(alpha * abs(Hk(1:numel(f))) + eps);
M = size(Sx, 2);
frames = round(linspace(0.15 * M, 0.85 * M, 6));
D = Sy(:, frames) - Sx(:, frames);
writetable(array2table([f, g, D], 'VariableNames', ...
    [{'f_Hz', 'g_theorique_dB'}, arrayfun(@(m) sprintf('trame_%d', m), frames, 'UniformOutput', false)]), ...
    fullfile(S.out, 'q2_property2_curves.csv'));

pass = f >= 600 & f <= 1900;
devPass = abs(D(pass, :) - g(pass));
pk = extract_peaks(Sx, cfg);
lin = sub2ind(size(Sx), pk(:, 2), pk(:, 1));
dpk = abs(Sy(lin) - Sx(lin) - g(pk(:, 2)));
keep = g(pk(:, 2)) > -20;
pky = extract_peaks(Sy, cfg);
inPass = f(pk(:, 2)) >= 600 & f(pk(:, 2)) <= 1900;
surv_pass = mean(ismember(pk(inPass, :), pky, 'rows'));
Tm = table(median(devPass(:)), rx_quantile(devPass(:), 0.95), median(dpk(keep)), ...
    rx_quantile(dpk(keep), 0.95), sum(keep), surv_pass, ...
    'VariableNames', {'ecart_median_bande_passante_dB', 'ecart_q95_bande_passante_dB', ...
    'ecart_median_pics_dB', 'ecart_q95_pics_dB', 'n_pics', 'pics_conserves_bande_passante'});
writetable(Tm, fullfile(S.out, 'q2_property2_metrics.csv'));
disp(Tm);

%% Invariance au gain et propriété (1)
P0 = extract_peaks(Sx, cfg);
Pg = extract_peaks(compute_spectrogram(0.3 * x, cfg), cfg);
gain_ok = isequal(P0, Pg);
tests = {}; fe = []; ft = [];
tests{end + 1} = 'gain_x0.3'; fe(end + 1) = double(gain_ok); ft(end + 1) = double(gain_ok);
for m0 = [16 7]
    xs = x(m0 * cfg.H + 1:end);
    Ps = extract_peaks(compute_spectrogram(xs, cfg), cfg);
    Ps(:, 1) = Ps(:, 1) + m0;
    A = P0(P0(:, 1) > m0 + 4 & P0(:, 1) < M - 4, :);
    [pe, pt] = rx_survival(A, Ps);
    tests{end + 1} = sprintf('decalage_%d_trames', m0); fe(end + 1) = pe; ft(end + 1) = pt;
end
xs = x(cfg.H / 2 + 1:end);                 % décalage d'une demi-trame (256 échantillons)
Ps = extract_peaks(compute_spectrogram(xs, cfg), cfg);
A = P0(P0(:, 1) > 4 & P0(:, 1) < M - 4, :);
[pe, pt] = rx_survival(A, Ps);
tests{end + 1} = 'decalage_demi_trame'; fe(end + 1) = pe; ft(end + 1) = pt;
Ti = table(tests', fe', ft', 'VariableNames', {'test', 'frac_exacte', 'frac_tol1'});
writetable(Ti, fullfile(S.out, 'q2_invariances.csv'));
disp(Ti);
end

function L = line_level(y, Fs, f0)
y = y(:); n = numel(y);
w = 0.5 - 0.5 * cos(2 * pi * (0:n - 1)' / n);
Y = abs(fft(y .* w));
f = (0:n - 1)' * Fs / n;
band = abs(f - f0) <= 3 * Fs / n & f <= Fs / 2;
L = 20 * log10(max(Y(band)) + eps);
end
