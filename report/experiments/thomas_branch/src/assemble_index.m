function index = assemble_index(song_ids, keys_c, manchor_c, meta, cfg)
%ASSEMBLE_INDEX Construit l'index inversé à partir de clés déjà calculées.
%
%   index = assemble_index(song_ids, keys_c, manchor_c, meta, cfg)
%
% Utilisé par build_index (clés issues de l'audio) et par les tests
% (clés synthétiques), pour que la logique d'insertion soit la même.
%
% Entrées :
%   song_ids  : vecteur des song_id (un par morceau)
%   keys_c    : cellule, keys_c{s} = clés uint32 du morceau s
%   manchor_c : cellule, manchor_c{s} = m_anchor uint32 du morceau s
%   meta      : table des morceaux (peut être vide [])
%   cfg       : configuration ; cfg.index.version facultatif :
%               1 (défaut) -> index.map (containers.Map)
%               2          -> tableaux triés uniquement
%               'both'     -> les deux (tests de non-régression)
%
% Sortie : structure index
%   index.songs, index.metadata (alias pour classify_match), index.cfg
%   v1 : index.map  : uint32 -> matrice n x 2 uint32 [song_id, m_ref]
%   v2 : index.keys (uint32, trié), index.vals (n x 2 uint32),
%        index.ukeys, index.first, index.count
%   index.n_occurrences : nombre total d'occurrences insérées

version = 1;
if isfield(cfg, 'index') && isfield(cfg.index, 'version')
    version = cfg.index.version;
end
is_both = (ischar(version) || isstring(version)) && strcmpi(version, 'both');
want_map = isequal(version, 1) || is_both;
want_arr = isequal(version, 2) || is_both;

index.songs = meta;
index.metadata = meta;
index.cfg = cfg;

% Concaténation de toutes les occurrences [key, song_id, m_ref]
nTot = 0;
for s = 1:numel(keys_c)
    nTot = nTot + numel(keys_c{s});
end
allk = zeros(nTot, 1, 'uint32');
allv = zeros(nTot, 2, 'uint32');
pos = 0;
for s = 1:numel(keys_c)
    ks = uint32(keys_c{s}(:));
    ms = uint32(manchor_c{s}(:));
    if numel(ks) ~= numel(ms)
        error('assemble_index:size', ...
            'keys et m_anchor de tailles différentes (morceau %d).', song_ids(s));
    end
    r = pos + (1:numel(ks));
    allk(r) = ks;
    allv(r, 1) = uint32(song_ids(s));
    allv(r, 2) = ms;
    pos = pos + numel(ks);
end

% Tri stable par clé : chaque clé regroupe TOUTES ses occurrences
[allk, ord] = sort(allk);
allv = allv(ord, :);

if isempty(allk)
    ukeys = zeros(0, 1, 'uint32');
    first = zeros(0, 1);
else
    isNew = [true; allk(2:end) ~= allk(1:end-1)];
    first = find(isNew);
    ukeys = allk(first);
end
count = diff([first; numel(allk) + 1]);

index.n_occurrences = numel(allk);

if want_map
    index.map = containers.Map('KeyType', 'uint32', 'ValueType', 'any');
    for u = 1:numel(ukeys)
        rows = first(u):(first(u) + count(u) - 1);
        % Clés uniques : aucune écrasée ; si la clé existait déjà
        % (index enrichi plus tard), on concatène.
        if isKey(index.map, ukeys(u))
            index.map(ukeys(u)) = [index.map(ukeys(u)); allv(rows, :)];
        else
            index.map(ukeys(u)) = allv(rows, :);
        end
    end
end

if want_arr
    index.keys = allk;
    index.vals = allv;
    index.ukeys = ukeys;
    index.first = uint32(first);
    index.count = uint32(count);
end
end
