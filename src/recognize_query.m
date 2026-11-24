function [result, diag] = recognize_query(a, b, c, cfg)
% Reconnaissance musicale par empreintes audio
%
% Interface complete :
% [result, diag] = recognize_query(x, Fs, index, cfg)
%
% Ancienne interface :
% result = recognize_query(index, keys, m_query, cfg)

diag = struct();

if isstruct(a)

    % Compatibilite avec les anciens scripts
    index = a;
    keys = b;
    m_query = c;

else

    % Pipeline complet
    x = a;
    Fs = b;
    index = c;

    [x, ~] = preprocess_audio(x, cfg, Fs);

    [S_dB, f, t] = compute_spectrogram(x, cfg);

    peaks = extract_peaks(S_dB, cfg);

    [keys, m_query] = generate_hashes(peaks, cfg);

    diag.S_dB = S_dB;
    diag.f = f;
    diag.t = t;
    diag.peaks = peaks;

end

% Recherche dans l'index
matches = query_index(index, keys, m_query);

% Alignement temporel
res = match_audio(matches);

% Decision finale
result = classify_match(res, index, cfg);

% Informations de diagnostic
diag.keys = keys;
diag.m_query = m_query;
diag.matches = matches;
diag.res = res;

end