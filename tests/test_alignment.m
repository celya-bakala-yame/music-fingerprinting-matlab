
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

    
    % Appeler notre fonction de reconnaissance
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

    [detectedSong, detectedOffset, bestVotes] = match_audio(matches);

    % Verifier que le bon morceau est reconnu
    verifyEqual(testCase, detectedSong, targetSong);

    % Verifier que le decalage temporel est correct
    verifyEqual(testCase, detectedOffset, trueOffset);

    % Verifier que les 200 correspondances sont retrouvees
    verifyGreaterThanOrEqual(testCase, bestVotes, nTrue);
end
