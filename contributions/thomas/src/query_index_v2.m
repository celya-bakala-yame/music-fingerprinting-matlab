function matches = query_index_v2(index, keys, m_query)
%QUERY_INDEX_V2 Recherche dans l'index v2 (tableaux triés).
%
%   matches = query_index_v2(index, keys, m_query)
%
% Même contrat de sortie que query_index :
%   matches : K x 3 double [song_id, m_ref, m_query]
% Nécessite un index construit avec cfg.index.version = 2 ou 'both'.
% (Proposition à relire avec Célya avant fusion dans query_index.)

if numel(keys) ~= numel(m_query)
    error('keys et m_query doivent avoir la meme taille.');
end
keys = uint32(keys(:));
m_query = double(m_query(:));

[found, loc] = ismember(keys, index.ukeys);
qi = find(found);
if isempty(qi)
    matches = zeros(0, 3);
    return;
end

first = double(index.first(loc(qi)));
cnt = double(index.count(loc(qi)));
K = sum(cnt);

% Construction vectorisée des plages first:first+cnt-1
rowsIdx = zeros(K, 1);
qOf = zeros(K, 1);
p = 0;
for a = 1:numel(qi)
    r = p + (1:cnt(a));
    rowsIdx(r) = first(a):(first(a) + cnt(a) - 1);
    qOf(r) = qi(a);
    p = p + cnt(a);
end

matches = [double(index.vals(rowsIdx, :)), m_query(qOf)];
end
