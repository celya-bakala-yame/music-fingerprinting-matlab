function tests = test_preprocessing
tests = functiontests(localfunctions);
end

function setupOnce(tc)
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
tc.TestData.cfg.Fs = 8000;
end

function testStereo(tc)
x = randn(44100*2, 2);
y = preprocess_audio(x, tc.TestData.cfg, 44100);
verifyTrue(tc, iscolumn(y));
verifyEqual(tc, numel(y), 16000, 'AbsTol', 1);
end

function testSinus(tc)
fs = 44100; t = (0:2*fs-1)'/fs;
[y, Fs] = preprocess_audio(sin(2*pi*1000*t), tc.TestData.cfg, fs);
Y = abs(fft(y)); f = (0:numel(y)-1)'*Fs/numel(y);
[~, i] = max(Y(1:floor(end/2)));
verifyEqual(tc, f(i), 1000, 'AbsTol', 8);
end

function testAmplitude(tc)
y = preprocess_audio(randn(8000,1)*0.1, tc.TestData.cfg, 8000);
verifyEqual(tc, max(abs(y)), 1, 'AbsTol', 1e-6);
end

function testInexistant(tc)
verifyError(tc, @() preprocess_audio('nexiste_pas.wav', tc.TestData.cfg), 'preprocess_audio:input');
end