
function matches = query_index(index, keys, m_query)
%QUERY_INDEX Recherche les empreintes dans l'index.
%
% Entrees :
%   index.map : containers.Map
%       cle -> matrice Nx2 [song_id, m_ref]
%   keys      : empreintes de la requete
%   m_query   : positions temporelles des empreintes
%
% Sortie :
%   matches   : matrice Kx3 [song_id, m_ref, m_query]

matches = zeros(0, 3);

% Les deux vecteurs doivent avoir la meme longueur.
if numel(keys) ~= numel(m_query)
    error('keys et m_query doivent avoir la meme taille.');
end

keys = keys(:);
m_query = m_query(:);

for i = 1:numel(keys)

    key = keys(i);

    % Une empreinte absente ne produit aucun match.
    if ~isKey(index.map, key)
        continue;
    end

    % Occurrences de cette empreinte dans la base.
    % Conversion en double : l'index stocke du uint32, et
    % m_ref - m_query en uint32 saturerait a 0 si negatif.
    occurrences = double(index.map(key));

    % Nombre d'occurrences retrouvees.
    n = size(occurrences, 1);

    % Ajouter la position de la requete.
    query_times = repmat(m_query(i), n, 1);

    % Format impose : [song_id, m_ref, m_query].
    new_matches = [occurrences, query_times];

    matches = [matches; new_matches];

end
end
