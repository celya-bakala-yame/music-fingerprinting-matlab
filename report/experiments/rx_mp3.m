function y = rx_mp3(x, cfg, kbps)
%RX_MP3 Codage / décodage MP3 réel (FFmpeg, libmp3lame), même commande
%   que experiments/evaluate_mp3.m, puis compensation du retard du codeur.
wav = [tempname '.wav'];
mp3 = [tempname '.mp3'];
audiowrite(wav, 0.99 * x / (max(abs(x)) + eps), cfg.Fs);
cmd = sprintf(['ffmpeg -y -loglevel error -i "%s" -ar 44100 ' ...
    '-codec:a libmp3lame -b:a %dk "%s"'], wav, kbps, mp3);
[st, out] = system(cmd);
delete(wav);
if st ~= 0
    error('rx_mp3:ffmpeg', 'FFmpeg : %s', out);
end
[y, ~] = preprocess_audio(mp3, cfg);
delete(mp3);
y = rx_align(x, y);
end

function y2 = rx_align(x, y)
% Retard estimé par intercorrélation (FFT) dans ±800 échantillons (±0,1 s).
x = x(:); y = y(:);
n = max(numel(x), numel(y));
nf = 2^nextpow2(2 * n);
c = real(ifft(fft(y, nf) .* conj(fft(x, nf))));
maxlag = 800;
lags = [0:maxlag, -maxlag:-1];
cc = [c(1:maxlag + 1); c(end - maxlag + 1:end)];
[~, i] = max(cc);
lag = lags(i);                 % y(n) ~ x(n - lag)
if lag >= 0
    y2 = y(lag + 1:end);
else
    y2 = [zeros(-lag, 1); y];
end
if numel(y2) >= numel(x)
    y2 = y2(1:numel(x));
else
    y2 = [y2; zeros(numel(x) - numel(y2), 1)];
end
end
