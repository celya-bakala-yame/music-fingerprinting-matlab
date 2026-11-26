%% RUN_ALL  Expériences complémentaires du rapport
% Lance les quatre expériences et enregistre un journal dans report/results/.
% Aucun fichier existant du dépôt n'est modifié.
here = fileparts(mfilename('fullpath'));
addpath(here);
outdir = fullfile(fileparts(here), 'results');
if ~isfolder(outdir), mkdir(outdir); end
diary(fullfile(outdir, 'log_run_all.txt')); diary on
fprintf('Début : %s\n', char(datetime('now')));
t_all = tic;
steps = {'exp_theory', 'exp_survival', 'exp_gamma', 'exp_index_cost'};
for s_i = 1:numel(steps)
    fprintf('\n===== %s =====\n', steps{s_i});
    t_s = tic;
    try
        feval(steps{s_i});
        fprintf('OK %s (%.1f s)\n', steps{s_i}, toc(t_s));
    catch ME_s
        fprintf('ECHEC %s : %s\n', steps{s_i}, getReport(ME_s, 'extended', 'hyperlinks', 'off'));
    end
end
fprintf('\nTerminé en %.1f min\n', toc(t_all) / 60);
diary off
