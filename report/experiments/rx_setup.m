function S = rx_setup()
%RX_SETUP Initialisation commune des expériences complémentaires du rapport.
%   Ne modifie aucun fichier existant : lecture de results/fingerprint_index.mat
%   (cfg, audio_files) et de data/queries/evaluation_list.csv ; écriture
%   uniquement dans report/results/.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
cd(root);
addpath(fullfile(root, 'src'));
setenv('PATH', ['/opt/homebrew/bin:/usr/local/bin:' getenv('PATH')]);
L = load(fullfile(root, 'results', 'fingerprint_index.mat'), 'cfg', 'audio_files');
S.root = root;
S.cfg = L.cfg;
S.af = L.audio_files;
S.out = fullfile(root, 'report', 'results');
if ~isfolder(S.out), mkdir(S.out); end
S.eval = readtable(fullfile(root, 'data', 'queries', 'evaluation_list.csv'), 'TextType', 'char');
S.eval.path = fullfile(root, S.eval.file);
end
