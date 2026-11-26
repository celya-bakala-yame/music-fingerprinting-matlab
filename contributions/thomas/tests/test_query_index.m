
function tests = test_query_index
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
end

function testFoundFingerprint(testCase)
index.map = containers.Map('KeyType', 'double', ...
    'ValueType', 'any');

% Une empreinte presente dans deux morceaux
index.map(123) = [2, 140; 3, 280];

keys = 123;
m_query = 100;

matches = query_index(index, keys, m_query);

verifyEqual(testCase, matches, [2, 140, 100; ...
    3, 280, 100]);
end

function testMissingFingerprint(testCase)
index.map = containers.Map('KeyType', 'double', ...
    'ValueType', 'any');

index.map(123) = [2, 140];

matches = query_index(index, 999, 100);

verifyEqual(testCase, matches, zeros(0, 3));
end

function testMultipleFingerprints(testCase)
index.map = containers.Map('KeyType', 'double', ...
    'ValueType', 'any');

index.map(123) = [2, 140];
index.map(456) = [2, 150];

matches = query_index(index, [123; 456], [100; 110]);

verifyEqual(testCase, matches, [2, 140, 100; ...
    2, 150, 110]);
end
