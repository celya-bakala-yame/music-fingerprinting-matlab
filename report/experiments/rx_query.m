function matches = rx_query(index, keys, m_query)
%RX_QUERY Même sortie que src/query_index.m ([song_id, m_ref, m_query]),
%   mais concaténation unique : utilisée pour gamma_f > 1, où le nombre
%   d'appariements rend la concaténation incrémentale trop lente.
keys = keys(:); m_query = m_query(:);
C = cell(numel(keys), 1);
for i = 1:numel(keys)
    if isKey(index.map, keys(i))
        occ = double(index.map(keys(i)));
        C{i} = [occ, repmat(m_query(i), size(occ, 1), 1)];
    end
end
matches = vertcat(C{:});
if isempty(matches), matches = zeros(0, 3); end
end
