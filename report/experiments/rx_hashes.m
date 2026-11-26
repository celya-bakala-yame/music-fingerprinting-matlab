function [keys, m_anchor] = rx_hashes(peaks, cfg, gamma_f)
%RX_HASHES Paires ancre-cible identiques à src/generate_hashes.m, avec en
%   plus la quantification fréquentielle Qf(k) = floor((k-1)/gamma_f) (6).
%   Pour gamma_f = 1, les clés sont strictement identiques à generate_hashes.
keys = zeros(0, 1); m_anchor = zeros(0, 1);
if isempty(peaks), return; end
peaks = sortrows(peaks, 1);
dt_min = ceil(cfg.hash.dt_min * cfg.Fs / cfg.H);
dt_max = floor(cfg.hash.dt_max * cfg.Fs / cfg.H);
fanout = cfg.hash.fanout;
dk_max = cfg.hash.dk_max;
base_f = floor(cfg.Nfft / 2) + 1;
Nf = ceil(base_f / gamma_f);
base_dt = dt_max + 1;
P = size(peaks, 1);
keys = zeros(P * fanout, 1);
m_anchor = zeros(P * fanout, 1);
n = 0;
for i = 1:P
    m1 = peaks(i, 1); k1 = peaks(i, 2); count = 0;
    q1 = floor((k1 - 1) / gamma_f);
    for j = i + 1:P
        dt = peaks(j, 1) - m1;
        if dt > dt_max, break; end
        k2 = peaks(j, 2);
        if dt < dt_min || abs(k2 - k1) > dk_max, continue; end
        q2 = floor((k2 - 1) / gamma_f);
        n = n + 1;
        keys(n) = (q1 * Nf + q2) * base_dt + dt;
        m_anchor(n) = m1;
        count = count + 1;
        if count >= fanout, break; end
    end
end
keys = keys(1:n); m_anchor = m_anchor(1:n);
end
