
function tests = test_alignment
% Tests unitaires de l'alignement temporel
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'src'));
addpath(projectRoot);
end

function testBestSong(testCase)
matches = createSyntheticMatches();
res = match_audio(matches);

verifyEqual(testCase, res.song_id(1), 2);
end

function testBestOffset(testCase)
matches = createSyntheticMatches();
res = match_audio(matches);

verifyEqual(testCase, res.delta(1), 40);
end

function testScore(testCase)
matches = createSyntheticMatches();
res = match_audio(matches);

verifyGreaterThanOrEqual(testCase, res.score(1), 200);
end

function testUnknownSong(testCase)
matches = createSyntheticMatches();
res = match_audio(matches);

cfg = config();
cfg.decision.threshold = res.score(1) + 1;

index = struct();
result = classify_match(res, index, cfg);

verifyFalse(testCase, result.is_known);
verifyEqual(testCase, result.song_id, 0);
verifyEqual(testCase, result.title, "inconnu");
end

function testNoiseOnly(testCase)
rng(2026);

% Correspondances aleatoires dispersees
n = 300;
song = randi(3, n, 1);
mRef = randi(10000, n, 1);
mQuery = randi(10000, n, 1);

matches = [song, mRef, mQuery];
res = match_audio(matches);

% Les votes doivent rester disperses.
verifyLessThan(testCase, res.score(1), 10);
end

function matches = createSyntheticMatches()
rng(1);

% 200 correspondances correctes du morceau 2
mQuery = (1:200)';
mRef = mQuery + 40;

correctMatches = [ ...
    2 * ones(200,1), mRef, mQuery];

% 600 correspondances parasites
n = 600;
noiseSong = randi(3, n, 1);
noiseRef = randi(10000, n, 1);
noiseQuery = randi(10000, n, 1);

noiseMatches = [noiseSong, noiseRef, noiseQuery];

matches = [correctMatches; noiseMatches];
end
