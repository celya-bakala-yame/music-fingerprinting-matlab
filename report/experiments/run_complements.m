%% RUN_COMPLEMENTS  Mesures complémentaires (relecture du rapport)
% Écrit uniquement dans report/results/ ; journal : log_run_complements.txt
here = fileparts(mfilename('fullpath'));
addpath(here);
outdir = fullfile(fileparts(here), 'results');
if ~isfolder(outdir), mkdir(outdir); end
diary(fullfile(outdir, 'log_run_complements.txt')); diary on
fprintf('Début : %s\n', char(datetime('now')));
t_all = tic;
try
    exp_complements();
    fprintf('OK exp_complements\n');
catch ME_s
    fprintf('ECHEC : %s\n', getReport(ME_s, 'extended', 'hyperlinks', 'off'));
end
fprintf('\nTerminé en %.1f min\n', toc(t_all) / 60);
diary off
