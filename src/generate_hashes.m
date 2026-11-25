function [keys, m_anchor] = generate_hashes(peaks, cfg)
%GENERATE_HASHES Paires ancre-cible -> clés d'empreinte uint32.
%
%   [keys, m_anchor] = generate_hashes(peaks, cfg)
%
% Entrée :
%   peaks : matrice P x 2 double [m, k] (sortie de extract_peaks)
%           m = indice de trame (1..M), k = indice de canal (1..513)
%   cfg   : configuration (config.m), champs utilisés :
%           cfg.Fs, cfg.H, cfg.hash.dt_min, cfg.hash.dt_max,
%           cfg.hash.dk_max, cfg.hash.fanout, cfg.hash.gamma_f
%
% Sorties (vecteurs colonnes uint32 de même longueur) :
%   keys     : key = kq1*2^15 + kq2*2^5 + dm
%              kq = floor((k-1)/gamma_f)  (10 bits, <= 512)
%              dm = m2 - m1               (5 bits, 2..31)
%   m_anchor : m1, trame de l'ancre (t = (m1-1)*H/Fs secondes)
%
% Zone cible de l'ancre i : dm_min <= m_j - m_i <= dm_max et
% |k_j - k_i| <= dk_max ; on garde les cfg.hash.fanout premières
% cibles dans l'ordre temporel (tri par m puis k).
%
% Décodage : voir decode_key.m

gamma_f = cfg.hash.gamma_f;
if isnan(gamma_f) || gamma_f < 1 || gamma_f ~= round(gamma_f)
    error('generate_hashes:gamma_f', ...
        ['cfg.hash.gamma_f doit être un entier >= 1 (valeur actuelle : %g). ' ...
         'Le fixer dans config.m.'], gamma_f);
end

dm_min = ceil(cfg.hash.dt_min * cfg.Fs / cfg.H);   % = 2
dm_max = floor(cfg.hash.dt_max * cfg.Fs / cfg.H);  % = 31
if dm_min < 1 || dm_max > 31 || dm_min > dm_max
    error('generate_hashes:dm', ...
        'Zone cible [%d, %d] trames incompatible avec 5 bits (1..31).', ...
        dm_min, dm_max);
end
dk_max = cfg.hash.dk_max;
fanout = cfg.hash.fanout;

keys = zeros(0, 1, 'uint32');
m_anchor = zeros(0, 1, 'uint32');

if isempty(peaks)
    return;
end
if size(peaks, 2) ~= 2
    error('generate_hashes:format', 'peaks doit être une matrice P x 2 [m, k].');
end

peaks = sortrows(double(peaks), [1 2]);
m = peaks(:, 1);
k = peaks(:, 2);
P = numel(m);

if any(k < 1) || any(m < 1)
    error('generate_hashes:format', 'Indices m et k attendus à partir de 1.');
end

% Pré-allocation (au plus fanout paires par ancre)
k1 = zeros(P * fanout, 1);
k2 = zeros(P * fanout, 1);
dm = zeros(P * fanout, 1);
m1 = zeros(P * fanout, 1);
n = 0;

jstart = 1;
for i = 1:P
    % Première cible possible : m_j >= m_i + dm_min (m trié => monotone)
    while jstart <= P && m(jstart) < m(i) + dm_min
        jstart = jstart + 1;
    end

    cnt = 0;
    j = jstart;
    while j <= P && m(j) <= m(i) + dm_max && cnt < fanout
        if abs(k(j) - k(i)) <= dk_max
            cnt = cnt + 1;
            n = n + 1;
            k1(n) = k(i);
            k2(n) = k(j);
            dm(n) = m(j) - m(i);
            m1(n) = m(i);
        end
        j = j + 1;
    end
end

k1 = k1(1:n); k2 = k2(1:n); dm = dm(1:n); m1 = m1(1:n);

% Quantification fréquentielle (dm reste exact)
kq1 = floor((k1 - 1) / gamma_f);
kq2 = floor((k2 - 1) / gamma_f);

if any(kq1 > 1023) || any(kq2 > 1023)
    error('generate_hashes:kq', 'kq dépasse 10 bits.');
end

% Encodage (calcul exact en double puis conversion)
keys = uint32(kq1 * 2^15 + kq2 * 2^5 + dm);
m_anchor = uint32(m1);
end
