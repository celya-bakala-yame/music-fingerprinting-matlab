function index = build_index(audio_files, cfg)
% Construction de la base d'empreintes audio.

index.map = containers.Map('KeyType', 'double', ...
    'ValueType', 'any');

for song_id = 1:numel(audio_files)

    filename = audio_files{song_id};

    % Pretraitement audio
    [x, ~] = preprocess_audio(filename, cfg);

    % Calcul du spectrogramme
    [S_dB, ~, ~] = compute_spectrogram(x, cfg);

    % Extraction des pics spectraux
    peaks = extract_peaks(S_dB, cfg);

    % Generation des empreintes
    [keys, m_anchor] = generate_hashes(peaks, cfg);

    % Enregistrement dans l'index
    for i = 1:numel(keys)

        key = keys(i);
        occurrence = [song_id, m_anchor(i)];

        if isKey(index.map, key)
            index.map(key) = [index.map(key); occurrence];
        else
            index.map(key) = occurrence;
        end

    end

    fprintf('Morceau %d : %d empreintes\n', ...
        song_id, numel(keys));

end

fprintf('Index construit : %d signatures distinctes\n', ...
    index.map.Count);
end