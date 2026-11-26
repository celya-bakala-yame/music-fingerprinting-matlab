function exp_peak_density()
rng(2026);
cfg0 = config();
f = dir('data/references/*.mp3');
voisinages = [2 3; 3 5; 5 8];          % [dm dk] = (trames, canaux)
rsb = [30 20 10 5 0 -5];
D = 20 * cfg0.Fs;                       % 20 s par morceau pour aller vite
mkdir('results/tables');

% charger les 3 morceaux (20 s chacun, depuis 30 s)
X = cell(3,1);
for i = 1:3
    x = preprocess_audio(fullfile(f(i).folder, f(i).name), cfg0);
    X{i} = x(30*cfg0.Fs+1 : 30*cfg0.Fs+D);
end

% --- 1. densité selon le voisinage ---
R = zeros(3, 3);
for v = 1:3
    cfg = cfg0; cfg.peaks.dm = voisinages(v,1); cfg.peaks.dk = voisinages(v,2);
    for i = 1:3
        S = compute_spectrogram(X{i}, cfg);
        p = extract_peaks(S, cfg);
        R(i,v) = size(p,1)/(D/cfg.Fs);
    end
end
T1 = array2table(R, 'VariableNames', {'dm2_dk3','dm3_dk5','dm5_dk8'});
T1.song_id = (1:3)';
writetable(T1, 'results/tables/peak_density.csv');
disp(T1)

% --- 2. survie des pics sous bruit ---
Surv = zeros(numel(rsb), 3);
for v = 1:3
    cfg = cfg0; cfg.peaks.dm = voisinages(v,1); cfg.peaks.dk = voisinages(v,2);
    for r = 1:numel(rsb)
        taux = zeros(3,1);
        for i = 1:3
            x = X{i};
            y = x + sqrt(mean(x.^2)/10^(rsb(r)/10)) * randn(size(x));
            p0 = extract_peaks(compute_spectrogram(x, cfg), cfg);
            p1 = extract_peaks(compute_spectrogram(y, cfg), cfg);
            surv = 0;
            for n = 1:size(p0,1)
                if any(abs(p1(:,1)-p0(n,1))<=1 & abs(p1(:,2)-p0(n,2))<=1)
                    surv = surv + 1;
                end
            end
            taux(i) = surv/size(p0,1);
        end
        Surv(r,v) = mean(taux);
    end
end
T2 = array2table(Surv, 'VariableNames', {'dm2_dk3','dm3_dk5','dm5_dk8'});
T2.RSB_dB = rsb(:);
writetable(T2, 'results/tables/peak_survival.csv');
disp(T2)
end