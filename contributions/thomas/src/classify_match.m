
function result = classify_match(res, index, cfg)
%CLASSIFY_MATCH Prend la decision finale de reconnaissance.
%
% res   : resultat de match_audio
% index : base indexee (metadata facultatives)
% cfg   : configuration du projet

result.song_id = 0;
result.title = "inconnu";
result.score = 0;
result.score2 = 0;
result.offset_s = NaN;
result.is_known = false;

% Aucun candidat trouve
if isempty(res.song_id)
    return;
end

% Meilleur candidat
bestSong = res.song_id(1);
bestScore = res.score(1);

result.score = bestScore;
result.score2 = res.score2;
result.offset_s = res.delta(1) * cfg.H / cfg.Fs;

% Seuil non calibre : decision encore indeterminee
threshold = cfg.decision.threshold;

if isnan(threshold)
    result.is_known = NaN;
    return;
end

% Score insuffisant : morceau inconnu
if bestScore < threshold
    return;
end

% Morceau reconnu
result.is_known = true;
result.song_id = bestSong;

% Recuperation facultative du titre
if isfield(index, 'metadata') && ...
        istable(index.metadata) && ...
        ismember('title', index.metadata.Properties.VariableNames) && ...
        bestSong >= 1 && bestSong <= height(index.metadata)

    result.title = string(index.metadata.title(bestSong));
end
end
