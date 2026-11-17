
function res = match_audio(matches)
%MATCH_AUDIO Classe les morceaux par alignement temporel.
% matches : Kx3 [song_id, m_ref, m_query]

% Initialisation du resultat
res.song_id = [];
res.score = [];
res.delta = [];
res.score2 = 0;
res.delta_all = [];
res.song_all = [];

if isempty(matches)
    return;
end

% 1. Calcul des decalages temporels
delta = matches(:,2) - matches(:,3);
song = matches(:,1);

res.delta_all = delta;
res.song_all = song;

% 2. Regroupement par morceau et decalage
[groups, ~, ic] = unique([song, delta], 'rows');

% 3. Nombre de votes pour chaque couple
votes = accumarray(ic, 1);

% 4. Recherche du meilleur decalage par morceau
songIds = unique(song);
nSongs = numel(songIds);

scores = zeros(nSongs, 1);
bestDeltas = zeros(nSongs, 1);

for i = 1:nSongs
    mask = groups(:,1) == songIds(i);

    songVotes = votes(mask);
    songDeltas = groups(mask,2);

    [scores(i), pos] = max(songVotes);
    bestDeltas(i) = songDeltas(pos);
end

% 5. Classement des morceaux par score decroissant
[scores, order] = sort(scores, 'descend');

res.song_id = songIds(order);
res.score = scores;
res.delta = bestDeltas(order);

% 6. Score du deuxieme candidat
if nSongs >= 2
    res.score2 = scores(2);
end
end
