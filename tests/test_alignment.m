
function tests = test_alignment
%TEST_ALIGNMENT Tests avec des correspondances synthetiques.
tests = functiontests(localfunctions);
end

function testKnownOffset(testCase)
    % Reproductibilite
    rng(1);

    % Parametres du scenario
    targetSong = 2;
    trueOffset = 40;
    nTrue = 200;
    nNoise = 600;

    % 200 correspondances correctes pour le morceau 2
    mQuery = randi([1, 500], nTrue, 1);
    mRef = mQuery + trueOffset;

    trueMatches = [ ...
        repmat(targetSong, nTrue, 1), mRef, mQuery];

    % 600 correspondances aleatoires parasites
    noiseSongs = randi([1, 3], nNoise, 1);
    noiseRef = randi([1, 1000], nNoise, 1);
    noiseQuery = randi([1, 500], nNoise, 1);

    noiseMatches = [noiseSongs, noiseRef, noiseQuery];

    % Ensemble des correspondances : [song_id, m_ref, m_query]
    matches = [trueMatches; noiseMatches];

    % Calcul du decalage temporel de chaque correspondance
    offsets = matches(:, 2) - matches(:, 3);

    % Comptage des votes par morceau et decalage
    [groups, songIds, detectedOffsets] = findgroups( ...
        matches(:, 1), offsets);

    votes = splitapply(@numel, offsets, groups);

    % Selection du groupe ayant le plus de votes
    [~, bestGroup] = max(votes);

    detectedSong = songIds(bestGroup);
    detectedOffset = detectedOffsets(bestGroup);

    % Verifications automatiques
    verifyEqual(testCase, detectedSong, targetSong);
    verifyEqual(testCase, detectedOffset, trueOffset);
    verifyGreaterThanOrEqual(testCase, votes(bestGroup), nTrue);
end
