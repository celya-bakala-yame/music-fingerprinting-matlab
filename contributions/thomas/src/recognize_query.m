
function result = recognize_query(index, keys, m_query, cfg)
%RECOGNIZE_QUERY Reconnait une requete a partir de ses empreintes.
%
% Entrees :
%   index   : base d'empreintes indexees
%   keys    : cles des empreintes de la requete
%   m_query : positions temporelles correspondantes
%   cfg     : parametres du systeme
%
% Sortie :
%   result  : decision et scores de reconnaissance

% 1. Rechercher les empreintes dans la base
matches = query_index(index, keys, m_query);

% 2. Calculer les alignements temporels
res = match_audio(matches);

% 3. Prendre la decision finale
result = classify_match(res, index, cfg);
end

