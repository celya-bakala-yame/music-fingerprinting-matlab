%% TEST_AUDIOID  Tests automatisés de l'interface AudioID
%
% Scénarios d'origine (numérotation du cahier des charges) :
%   1. Chargement correct de l'index
%   2. Reconnaissance d'un fichier audio connu (+ décalage temporel)
%   3. Rejet d'un fichier audio inconnu
%   5. Affichage du spectrogramme et des pics
%   6. Affichage de l'histogramme d'alignement
%   7. Gestion de l'absence de l'index
%   9. Gestion d'un fichier audio invalide (et d'un extrait trop court)
%  10. Répétition de plusieurs reconnaissances sans recharger l'index
%
% Scénarios ajoutés (métadonnées et non-régression) :
%  11. Chargement et vérification de data/metadata.csv (100/100)
%  12. Correspondance song_id / fma_id / fichier et affichage (morceau n°19)
%  13. Métadonnées absentes ou incompatibles (fichiers temporaires)
%  14. Scores de reconnaissance inchangés (avec / sans métadonnées, et
%      comparaison à results/evaluation_scores.csv)
%
% Scénarios manuels (voir gui/README.md) : microphone, annulation de la
% sélection, redimensionnement, lisibilité des onglets.
%
% Lancement depuis la racine du projet :
%   run('gui/test_AudioID.m')
%
% Aucun fichier du dépôt n'est modifié : les fichiers de test temporaires
% sont écrits dans tempdir puis supprimés.

clear; clc;

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'gui'));
addpath(fullfile(root, 'src'));

report = cell(0, 3);   % {scénario, statut, détail}
tol_offset = 0.1;      % tolérance sur le décalage (s), comme tests/test_end_to_end.m
expected_threshold = 22;

%% Sélection des requêtes de test (ensemble d'évaluation)
evalList = fullfile(root, 'data', 'queries', 'evaluation_list.csv');
qPos = [];
qNeg = [];
q19 = [];
if isfile(evalList)
    E = readtable(evalList, 'TextType', 'char');
    E.path = fullfile(root, E.file);
    E = E(cellfun(@isfile, E.path), :);
    % Requêtes de 10 s : les deux échecs connus (requêtes 16 et 41) sont des 3 s / 5 s
    pos = E(E.true_song_id > 0 & E.duration_s == 10, :);
    neg = E(E.true_song_id == 0 & E.duration_s == 10, :);
    if height(pos) > 0, qPos = pos(1, :); end
    if height(neg) > 0, qNeg = neg(1, :); end
    e19 = sortrows(E(E.true_song_id == 19, :), 'duration_s', 'descend');
    if height(e19) > 0, q19 = e19(1, :); end
end

%% 1. Chargement de l'index
app = [];
try
    t0 = tic;
    app = AudioID('Visible', 'off');
    tOpen = toc(t0);
    assert(app.IsLoaded, 'IsLoaded = false');
    assert(app.LoadCount == 1, 'LoadCount = %d', app.LoadCount);
    assert(app.Index.map.Count > 0, 'Index vide');
    assert(app.Cfg.decision.threshold == expected_threshold, ...
        'Seuil = %g au lieu de %g', app.Cfg.decision.threshold, expected_threshold);
    report(end+1, :) = {'1. Chargement de l''index', 'OK', sprintf( ...
        '%d signatures, %d références, seuil = %g, ouverture %.1f s', ...
        double(app.Index.map.Count), numel(app.AudioFiles), ...
        app.Cfg.decision.threshold, tOpen)};
catch ME
    report(end+1, :) = {'1. Chargement de l''index', 'ÉCHEC', ME.message};
end

loaded = ~isempty(app) && isvalid(app) && app.IsLoaded;
metaFile = fullfile(root, 'data', 'metadata.csv');

%% 11. Métadonnées chargées et vérifiées
if ~loaded
    report(end+1, :) = {'11. Métadonnées chargées', 'NON EXÉCUTÉ', 'index indisponible'};
else
    try
        mi = app.MetaInfo;
        N = numel(app.AudioFiles);
        assert(strcmp(mi.status, 'ok'), 'Statut "%s" : %s', mi.status, strjoin(mi.issues, ' | '));
        assert(mi.nValid == N && N == 100, '%d/%d lignes validées', mi.nValid, N);
        assert(isfield(app.Index, 'metadata') && istable(app.Index.metadata), ...
            'index.metadata absent en mémoire');
        M = app.Index.metadata;
        assert(height(M) == N && isequal(M.song_id, (1:N)'), 'Table non alignée sur song_id');
        assert(all(M.valid), 'Lignes non validées');
        % Correspondance fma_id <-> fichier audio indexé pour toutes les lignes
        fmaAudio = cellfun(@(p) str2double(regexprep(p, '^.*[\\/]|\.[^.]*$', '')), app.AudioFiles(:));
        assert(isequal(M.fma_id, fmaAudio), 'fma_id différent des fichiers audio_files');
        assert(~isfile(fullfile(root, 'results', 'fingerprint_index_gui.mat')), ...
            'Un fichier MAT inattendu a été créé');
        report(end+1, :) = {'11. Métadonnées chargées', 'OK', sprintf( ...
            '%d/%d lignes vérifiées (%s), en mémoire uniquement', mi.nValid, N, mi.checks)};
    catch ME
        report(end+1, :) = {'11. Métadonnées chargées', 'ÉCHEC', ME.message};
    end
end

%% 2. Fichier connu
if ~loaded || isempty(qPos)
    report(end+1, :) = {'2. Fichier connu', 'NON EXÉCUTÉ', 'index ou requête positive indisponible'};
else
    try
        [r, dg, el] = app.recognizeFile(qPos.path{1});
        assert(isequal(r.is_known, true), 'Requête rejetée (S1 = %d)', r.score);
        assert(r.song_id == qPos.true_song_id, 'ID %d au lieu de %d', r.song_id, qPos.true_song_id);
        err = abs(r.offset_s - qPos.start_s);
        assert(err <= tol_offset, 'Erreur de décalage %.3f s', err);
        report(end+1, :) = {'2. Fichier connu', 'OK', sprintf( ...
            '%s -> #%d « %s », S1 = %d, S2 = %d, offset %.2f s (vrai %.2f s), %.0f ms', ...
            qPos.file{1}, r.song_id, r.title, r.score, r.score2, r.offset_s, qPos.start_s, 1000*el)};
    catch ME
        report(end+1, :) = {'2. Fichier connu', 'ÉCHEC', ME.message};
    end
end

%% 5. Spectrogramme et pics (sur la reconnaissance précédente)
if ~loaded || isempty(app.LastDiag)
    report(end+1, :) = {'5. Spectrogramme et pics', 'NON EXÉCUTÉ', 'aucune reconnaissance préalable'};
else
    try
        dg = app.LastDiag;
        assert(isequal(size(dg.S_dB), [numel(dg.f), numel(dg.t)]), 'Dimensions S_dB incohérentes');
        assert(~isempty(dg.peaks), 'Aucun pic');
        im = findobj(app.AxSpec, 'Type', 'image');
        sc = findobj(app.AxSpec, 'Type', 'scatter');
        assert(numel(im) == 1, 'Image du spectrogramme absente');
        assert(isequal(size(im.CData), size(dg.S_dB)), 'Image différente de diag.S_dB');
        assert(numel(sc) == 1 && numel(sc.XData) == size(dg.peaks, 1), 'Pics superposés incorrects');
        sc2 = findobj(app.AxConst, 'Type', 'scatter');
        assert(numel(sc2) == 1 && numel(sc2.XData) == size(dg.peaks, 1), 'Constellation incorrecte');
        report(end+1, :) = {'5. Spectrogramme et pics', 'OK', sprintf( ...
            '%d x %d, %d pics tracés', size(dg.S_dB, 1), size(dg.S_dB, 2), size(dg.peaks, 1))};
    catch ME
        report(end+1, :) = {'5. Spectrogramme et pics', 'ÉCHEC', ME.message};
    end
end

%% 6. Histogramme d'alignement
if ~loaded || isempty(app.LastDiag)
    report(end+1, :) = {'6. Histogramme d''alignement', 'NON EXÉCUTÉ', 'aucune reconnaissance préalable'};
else
    try
        b = findobj(app.AxHist, 'Type', 'bar');
        assert(~isempty(b), 'Aucune barre tracée');
        assert(max(b(1).YData) == app.LastResult.score, ...
            'Pic de l''histogramme (%d) différent de S1 (%d)', max(b(1).YData), app.LastResult.score);
        bc = findobj(app.AxCand, 'Type', 'bar');
        assert(~isempty(bc) && bc(1).YData(1) == app.LastResult.score, 'Graphique des candidats incorrect');
        assert(app.AxHist.YLim(2) > app.LastResult.score, 'Pic masqué par la limite de l''axe');
        report(end+1, :) = {'6. Histogramme d''alignement', 'OK', sprintf( ...
            'pic = S1 = %d votes', app.LastResult.score)};
    catch ME
        report(end+1, :) = {'6. Histogramme d''alignement', 'ÉCHEC', ME.message};
    end
end

%% 12. Morceau n°19 : correspondance et affichage
if ~loaded || isempty(q19)
    report(end+1, :) = {'12. Affichage métadonnées (#19)', 'NON EXÉCUTÉ', 'requête du morceau 19 indisponible'};
else
    try
        M = app.Index.metadata;
        [~, n19, e19x] = fileparts(app.AudioFiles{19});
        assert(strcmp([n19 e19x], '000213.mp3'), 'audio_files{19} = %s', [n19 e19x]);
        assert(M.title(19) == "Boute" && M.artist(19) == "Au" && M.genre(19) == "Pop" ...
            && M.fma_id(19) == 213, 'Ligne 19 inattendue : %s / %s / %s / %g', ...
            M.title(19), M.artist(19), M.genre(19), M.fma_id(19));

        [r, ~, ~] = app.recognizeFile(q19.path{1});
        assert(isequal(r.is_known, true) && r.song_id == 19, ...
            'Requête %s : song_id %d, is_known %d', q19.file{1}, r.song_id, r.is_known);
        assert(strcmp(r.title, "Boute"), 'result.title = "%s"', r.title);
        s = app.getDisplayedResult();
        assert(strcmp(s.title, 'Boute'), 'Titre affiché "%s"', s.title);
        assert(contains(s.subtitle, 'Au') && contains(s.subtitle, 'Pop'), ...
            'Artiste/genre affichés "%s"', s.subtitle);
        assert(strcmp(s.identifiant, '#19 · FMA 213'), 'Identifiant affiché "%s"', s.identifiant);
        assert(strcmp(s.reference, '000213.mp3'), 'Fichier affiché "%s"', s.reference);
        assert(startsWith(s.source, 'SOURCE  FICHIER'), 'Source affichée "%s"', s.source);
        report(end+1, :) = {'12. Affichage métadonnées (#19)', 'OK', sprintf( ...
            '%s -> « %s » · %s · %s', q19.file{1}, s.title, s.subtitle, s.identifiant)};
    catch ME
        report(end+1, :) = {'12. Affichage métadonnées (#19)', 'ÉCHEC', ME.message};
    end
end

%% 3. Fichier inconnu
if ~loaded || isempty(qNeg)
    report(end+1, :) = {'3. Fichier inconnu', 'NON EXÉCUTÉ', 'index ou requête négative indisponible'};
else
    try
        [r, ~, el] = app.recognizeFile(qNeg.path{1});
        assert(isequal(r.is_known, false), 'Requête négative acceptée (S1 = %d)', r.score);
        assert(r.song_id == 0, 'song_id non nul pour un rejet');
        s = app.getDisplayedResult();
        assert(strcmp(s.identifiant, '—') && strcmp(s.position, 'Non applicable'), ...
            'Un identifiant ou une position est affiché pour un rejet');
        report(end+1, :) = {'3. Fichier inconnu', 'OK', sprintf( ...
            '%s rejeté, S1 = %d < seuil %g, %.0f ms, aucun titre affiché', qNeg.file{1}, r.score, ...
            app.Cfg.decision.threshold, 1000*el)};
    catch ME
        report(end+1, :) = {'3. Fichier inconnu', 'ÉCHEC', ME.message};
    end
end

%% 9. Fichier invalide et extrait trop court
if ~loaded
    report(end+1, :) = {'9. Fichier invalide', 'NON EXÉCUTÉ', 'index indisponible'};
else
    fBad = [tempname '.wav'];
    fShort = [tempname '.wav'];
    try
        fid = fopen(fBad, 'w');
        fwrite(fid, uint8('ceci n''est pas un fichier audio'));
        fclose(fid);
        audiowrite(fShort, 0.1 * randn(round(0.3 * 8000), 1), 8000);

        id1 = '';
        try
            app.recognizeFile(fBad);
        catch ME1
            id1 = ME1.identifier;
        end
        id2 = '';
        try
            app.recognizeFile(fShort);
        catch ME2
            id2 = ME2.identifier;
        end
        assert(strcmp(id1, 'AudioID:invalidFile'), 'Fichier corrompu : identifiant "%s"', id1);
        assert(strcmp(id2, 'AudioID:tooShort'), 'Extrait court : identifiant "%s"', id2);
        report(end+1, :) = {'9. Fichier invalide', 'OK', ...
            'fichier corrompu -> AudioID:invalidFile ; 0,3 s -> AudioID:tooShort'};
    catch ME
        report(end+1, :) = {'9. Fichier invalide', 'ÉCHEC', ME.message};
    end
    if isfile(fBad), delete(fBad); end
    if isfile(fShort), delete(fShort); end
end

%% 10. Reconnaissances répétées sans rechargement
if ~loaded || isempty(qPos) || isempty(qNeg)
    report(end+1, :) = {'10. Reconnaissances répétées', 'NON EXÉCUTÉ', 'requêtes indisponibles'};
else
    try
        n0 = numel(app.History);
        times = zeros(1, 6);
        for k = 1:6
            if mod(k, 2)
                f = qPos.path{1};
            else
                f = qNeg.path{1};
            end
            [~, ~, times(k)] = app.recognizeFile(f);
        end
        assert(app.LoadCount == 1, 'Index rechargé (LoadCount = %d)', app.LoadCount);
        assert(numel(app.History) == n0 + 6, 'Historique incomplet');
        report(end+1, :) = {'10. Reconnaissances répétées', 'OK', sprintf( ...
            '6 reconnaissances, LoadCount = 1, temps moyen %.0f ms', 1000*mean(times))};
    catch ME
        report(end+1, :) = {'10. Reconnaissances répétées', 'ÉCHEC', ME.message};
    end
end

%% 14. Scores inchangés
if ~loaded || isempty(qPos) || isempty(qNeg)
    report(end+1, :) = {'14. Scores inchangés', 'NON EXÉCUTÉ', 'requêtes indisponibles'};
else
    try
        % (a) Avec / sans métadonnées, et interface / appel direct du pipeline
        idxNoMeta = rmfield(app.Index, 'metadata');
        qs = {qPos.path{1}, qNeg.path{1}};
        if ~isempty(q19), qs{end+1} = q19.path{1}; end
        for k = 1:numel(qs)
            [x, Fs] = audioread(qs{k});
            rGui = app.recognizeFile(qs{k});
            rRef = recognize_query(x, Fs, idxNoMeta, app.Cfg);
            assert(isequal([rGui.score rGui.score2 rGui.song_id rGui.is_known], ...
                [rRef.score rRef.score2 rRef.song_id rRef.is_known]) && ...
                isequaln(rGui.offset_s, rRef.offset_s), ...
                'Écart avec / sans métadonnées sur %s', qs{k});
        end
        detail = sprintf('%d requêtes identiques avec / sans métadonnées', numel(qs));

        % (b) Ensemble d'évaluation complet comparé aux scores enregistrés
        scoreFile = fullfile(root, 'results', 'evaluation_scores.csv');
        if isfile(scoreFile)
            R = readtable(scoreFile, 'TextType', 'char');
            assert(all(ismember({'file', 'S1', 'S2', 'predicted_song_id'}, ...
                R.Properties.VariableNames)), 'Colonnes inattendues dans evaluation_scores.csv');
            nDiff = 0;
            nRun = 0;
            firstDiff = '';
            for k = 1:height(R)
                fq = fullfile(root, R.file{k});
                if ~isfile(fq), continue; end
                [x, Fs] = audioread(fq);
                rr = recognize_query(x, Fs, app.Index, app.Cfg);
                nRun = nRun + 1;
                if rr.score ~= R.S1(k) || rr.score2 ~= R.S2(k) || rr.song_id ~= R.predicted_song_id(k)
                    nDiff = nDiff + 1;
                    if isempty(firstDiff)
                        firstDiff = sprintf('%s : S1 %d/%d, S2 %d/%d, ID %d/%d', R.file{k}, ...
                            rr.score, R.S1(k), rr.score2, R.S2(k), rr.song_id, R.predicted_song_id(k));
                    end
                end
            end
            assert(nRun > 0, 'Aucune requête d''évaluation disponible localement');
            assert(nDiff == 0, '%d/%d requêtes différentes (ex. %s)', nDiff, nRun, firstDiff);
            detail = sprintf('%s ; %d/%d requêtes identiques à results/evaluation_scores.csv (S1, S2, ID)', ...
                detail, nRun, height(R));
        else
            detail = [detail ' ; evaluation_scores.csv absent (comparaison non faite)'];
        end
        report(end+1, :) = {'14. Scores inchangés', 'OK', detail};
    catch ME
        report(end+1, :) = {'14. Scores inchangés', 'ÉCHEC', ME.message};
    end
end

%% 13. Métadonnées absentes ou incompatibles (sans recharger l'index)
if ~loaded || ~isfile(metaFile)
    report(end+1, :) = {'13. Métadonnées incompatibles', 'NON EXÉCUTÉ', 'index ou metadata.csv indisponible'};
else
    tmpSwap = [tempname '.csv'];
    tmpNoId = [tempname '.csv'];
    tmpAbsent = [tempname '.csv'];
    try
        L = splitlines(string(fileread(metaFile)));
        L = strip(L(strlength(strip(L)) > 0));
        hdr = split(L(1), ',');
        iF = find(hdr == "fma_id");
        assert(~isempty(iF), 'colonne fma_id introuvable');

        % (a) fma_id de deux lignes échangés -> ces deux morceaux sont rejetés
        A = L;
        p2 = split(A(2), ',');
        p3 = split(A(3), ',');
        assert(numel(p2) == numel(hdr) && numel(p3) == numel(hdr), ...
            'Lignes 1-2 non découpables simplement (virgules dans les champs)');
        tmp = p2(iF); p2(iF) = p3(iF); p3(iF) = tmp;
        A(2) = join(p2, ',');
        A(3) = join(p3, ',');
        writeLinesCompat(A, tmpSwap);
        info = app.reloadMetadata(tmpSwap);
        assert(strcmp(info.status, 'partial') && info.nValid == 98, ...
            'Échange fma_id : statut %s, %d validées', info.status, info.nValid);
        assert(~app.Index.metadata.valid(1) && ~app.Index.metadata.valid(2) && ...
            strlength(app.Index.metadata.title(1)) == 0, 'Lignes incohérentes non rejetées');

        % (b) colonne song_id absente -> métadonnées rejetées, interface utilisable
        B = L;
        B(1) = replace(B(1), 'song_id', 'identifiant');
        writeLinesCompat(B, tmpNoId);
        info = app.reloadMetadata(tmpNoId);
        assert(strcmp(info.status, 'error') && ~isfield(app.Index, 'metadata'), ...
            'Fichier sans song_id : statut %s', info.status);
        if ~isempty(qPos)
            r = app.recognizeFile(qPos.path{1});
            s = app.getDisplayedResult();
            assert(isequal(r.is_known, true) && strcmp(s.title, 'Titre non disponible'), ...
                'Sans métadonnées : titre affiché "%s"', s.title);
        end

        % (c) fichier absent
        info = app.reloadMetadata(tmpAbsent);
        assert(strcmp(info.status, 'absent') && ~isfield(app.Index, 'metadata'), ...
            'Fichier absent : statut %s', info.status);

        % Restauration du fichier réel, sans rechargement de l'index
        info = app.reloadMetadata(metaFile);
        assert(strcmp(info.status, 'ok') && info.nValid == 100, 'Restauration impossible');
        assert(app.LoadCount == 1, 'Index rechargé (LoadCount = %d)', app.LoadCount);
        report(end+1, :) = {'13. Métadonnées incompatibles', 'OK', ...
            'fma_id échangés -> 98/100 ; sans song_id -> rejet ; absent -> titres masqués ; restauré'};
    catch ME
        report(end+1, :) = {'13. Métadonnées incompatibles', 'ÉCHEC', ME.message};
        try
            app.reloadMetadata(metaFile);
        catch
        end
    end
    if isfile(tmpSwap), delete(tmpSwap); end
    if isfile(tmpNoId), delete(tmpNoId); end
end

if ~isempty(app) && isvalid(app)
    delete(app);
end

%% 7. Index absent
try
    absent = fullfile(tempdir, 'audioid_index_absent.mat');
    if isfile(absent), delete(absent); end
    app2 = AudioID('IndexFile', absent, 'Visible', 'off');
    assert(~app2.IsLoaded, 'IsLoaded = true sans index');
    idErr = '';
    try
        app2.recognizeSignal(randn(8000 * 3, 1), 8000, 'test');
    catch ME3
        idErr = ME3.identifier;
    end
    assert(strcmp(idErr, 'AudioID:notLoaded'), 'Identifiant "%s"', idErr);
    delete(app2);
    report(end+1, :) = {'7. Index absent', 'OK', ...
        'message de reconstruction affiché, reconnaissance bloquée (AudioID:notLoaded)'};
catch ME
    report(end+1, :) = {'7. Index absent', 'ÉCHEC', ME.message};
end

%% Bilan
fprintf('\n=================== BILAN DES TESTS AudioID ===================\n');
for i = 1:size(report, 1)
    fprintf('%-34s %-12s %s\n', report{i, 1}, report{i, 2}, report{i, 3});
end
nOK = sum(strcmp(report(:, 2), 'OK'));
fprintf('---------------------------------------------------------------\n');
fprintf('%d / %d scénarios automatiques réussis.\n', nOK, size(report, 1));
fprintf('Tests manuels (microphone, annulation, affichage) : voir gui/README.md, section 4.2.\n');

%% Fonction locale
function writeLinesCompat(lines, filename)
%WRITELINESCOMPAT Écrit un tableau de chaînes, une par ligne (UTF-8).
fid = fopen(filename, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', lines);
fclose(fid);
end
