
function [bestSong, bestOffset, bestVotes] = match_audio(matches)
%MATCH_AUDIO Identifie le morceau par vote temporel.
%
% Entree :
%   matches : matrice K x 3
%             [song_id, m_ref, m_query]
%
% Sorties :
%   bestSong   : identifiant du morceau reconnu
%   bestOffset : decalage temporel en trames
%   bestVotes  : nombre de votes du meilleur groupe

    % Cas sans correspondance
    if isempty(matches)
        bestSong = NaN;
        bestOffset = NaN;
        bestVotes = 0;
        return;
    end

    % Calculer les decalages temporels
    offsets = matches(:, 2) - matches(:, 3);

    % Regrouper les correspondances par morceau et decalage
    [groups, songIds, detectedOffsets] = findgroups( ...
        matches(:, 1), offsets);

    % Compter les votes de chaque groupe
    votes = splitapply(@numel, offsets, groups);

    % Identifier le groupe ayant le plus de votes
    [bestVotes, bestGroup] = max(votes);

    bestSong = songIds(bestGroup);
    bestOffset = detectedOffsets(bestGroup);
end
