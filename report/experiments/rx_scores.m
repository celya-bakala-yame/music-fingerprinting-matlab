function [s_true, s_wrong, n_matches, n_spurious] = rx_scores(index, keys, m_query, true_id, fast)
%RX_SCORES Score du vrai morceau et meilleur score d'un autre morceau
%   (query_index + match_audio de src/).
s_true = 0; s_wrong = 0; n_matches = 0; n_spurious = 0;
if isempty(keys), return; end
if nargin >= 5 && fast
    matches = rx_query(index, keys, m_query);
else
    matches = query_index(index, keys, m_query);
end
n_matches = size(matches, 1);
n_spurious = sum(matches(:, 1) ~= true_id);
res = match_audio(matches);
if isempty(res.song_id), return; end
t = res.song_id == true_id;
if any(t), s_true = res.score(t); end
if any(~t), s_wrong = max(res.score(~t)); end
end
