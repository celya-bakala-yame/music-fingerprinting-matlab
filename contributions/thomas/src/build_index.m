function index = build_index(meta, cfg)
%BUILD_INDEX Indexe les morceaux de référence.
%
%   index = build_index(meta, cfg)
%
% Entrées :
%   meta : table issue de readtable('data/metadata.csv') (ou chemin du CSV)
%          colonnes utilisées : song_id (sinon numéro de ligne), file
%   cfg  : configuration (config.m)
%
% Pour chaque morceau : preprocess_audio -> compute_spectrogram ->
% extract_peaks -> generate_hashes, puis insertion via assemble_index
% (toutes les occurrences conservées, jamais d'écrasement).
%
% Sortie : voir assemble_index. En plus :
%   index.stats : table par morceau (song_id, duration_s, n_peaks,
%                 n_keys, peaks_per_s, keys_per_s, time_s)

if ischar(meta) || isstring(meta)
    meta = readtable(meta, 'TextType', 'string');
end
if ~istable(meta)
    error('build_index:meta', 'meta doit être une table (metadata.csv).');
end

nSongs = height(meta);
vars = meta.Properties.VariableNames;
root = fileparts(fileparts(mfilename('fullpath')));

song_ids = zeros(nSongs, 1);
keys_c = cell(nSongs, 1);
manchor_c = cell(nSongs, 1);

duration_s = zeros(nSongs, 1);
n_peaks = zeros(nSongs, 1);
n_keys = zeros(nSongs, 1);
time_s = zeros(nSongs, 1);

for r = 1:nSongs
    t0 = tic;

    if ismember('song_id', vars)
        song_ids(r) = double(meta.song_id(r));
    else
        song_ids(r) = r;
    end

    path = resolve_audio_path(meta, r, root);

    [x, Fs] = preprocess_audio(path, cfg);
    S_dB = compute_spectrogram(x, cfg);
    peaks = extract_peaks(S_dB, cfg);
    [keys_c{r}, manchor_c{r}] = generate_hashes(peaks, cfg);

    duration_s(r) = numel(x) / Fs;
    n_peaks(r) = size(peaks, 1);
    n_keys(r) = numel(keys_c{r});
    time_s(r) = toc(t0);

    fprintf('[build_index] %d/%d  song_id=%d  %.1f s  %d pics  %d clés  (%.2f s)\n', ...
        r, nSongs, song_ids(r), duration_s(r), n_peaks(r), n_keys(r), time_s(r));
end

if numel(unique(song_ids)) ~= numel(song_ids)
    error('build_index:song_id', 'song_id en double dans metadata.csv.');
end

index = assemble_index(song_ids, keys_c, manchor_c, meta, cfg);

peaks_per_s = n_peaks ./ max(duration_s, eps);
keys_per_s = n_keys ./ max(duration_s, eps);
index.stats = table(song_ids, duration_s, n_peaks, n_keys, peaks_per_s, ...
    keys_per_s, time_s, 'VariableNames', {'song_id', 'duration_s', ...
    'n_peaks', 'n_keys', 'peaks_per_s', 'keys_per_s', 'time_s'});
end

function path = resolve_audio_path(meta, r, root)
% Cherche le fichier tel quel, puis relatif à la racine, puis dans
% data/references/ et data/negatives/.
if ~ismember('file', meta.Properties.VariableNames)
    error('build_index:file', 'Colonne "file" absente de metadata.csv.');
end
f = char(string(meta.file(r)));
candidates = {f, fullfile(root, f), ...
    fullfile(root, 'data', 'references', f), ...
    fullfile(root, 'data', 'negatives', f)};
for c = 1:numel(candidates)
    if isfile(candidates{c})
        path = candidates{c};
        return;
    end
end
error('build_index:file', 'Fichier audio introuvable : %s', f);
end
