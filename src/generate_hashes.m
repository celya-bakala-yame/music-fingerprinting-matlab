function [keys, m_anchor] = generate_hashes(peaks, cfg)
% Generation des empreintes audio a partir des pics spectraux.

keys = zeros(0, 1);
m_anchor = zeros(0, 1);

if isempty(peaks)
    return;
end

peaks = sortrows(peaks, 1);

dt_min = ceil(cfg.hash.dt_min * cfg.Fs / cfg.H);
dt_max = floor(cfg.hash.dt_max * cfg.Fs / cfg.H);

fanout = cfg.hash.fanout;
dk_max = cfg.hash.dk_max;

base_f = floor(cfg.Nfft / 2) + 1;
base_dt = dt_max + 1;

for i = 1:size(peaks, 1)

    m1 = peaks(i, 1);
    k1 = peaks(i, 2);
    count = 0;

    for j = i+1:size(peaks, 1)

        m2 = peaks(j, 1);
        k2 = peaks(j, 2);
        dt = m2 - m1;

        if dt > dt_max
            break;
        end

        if dt < dt_min || abs(k2-k1) > dk_max
            continue;
        end

        key = ((k1-1)*base_f + (k2-1))*base_dt + dt;

        keys(end+1, 1) = key;
        m_anchor(end+1, 1) = m1;

        count = count + 1;

        if count >= fanout
            break;
        end

    end
end
end