classdef AudioID < handle
    %AUDIOID Interface graphique de reconnaissance musicale par empreintes audio.
    %
    %   AudioID — Acoustic Fingerprinting & Music Recognition
    %   Projet de traitement du signal, ESIEE Paris (E4, 2026-2027).
    %
    %   L'interface réutilise strictement le pipeline existant du dossier src/ :
    %
    %       [result, diag] = recognize_query(x, Fs, index, cfg);
    %
    %   Aucun algorithme de reconnaissance n'est réimplémenté ici.
    %
    %   Au démarrage :
    %     1. results/fingerprint_index.mat (index, cfg, audio_files) est
    %        chargé UNE SEULE FOIS ; le seuil reste cfg.decision.threshold ;
    %     2. data/metadata.csv est lu, vérifié (song_id, fma_id, fichier
    %        audio) puis attaché EN MÉMOIRE à index.metadata. Aucun fichier
    %        MAT n'est écrit et l'index n'est pas reconstruit.
    %
    %   Lancement (depuis la racine du projet) :
    %       addpath('gui');
    %       app = AudioID;
    %
    %   Options :
    %       app = AudioID('IndexFile', chemin)     % autre fichier d'index
    %       app = AudioID('MetadataFile', chemin)  % autre fichier CSV
    %       app = AudioID('Visible', 'off')        % fenêtre masquée (tests)
    %
    %   API publique (utilisée par gui/test_AudioID.m) :
    %       [result, diag, t] = app.recognizeFile(chemin)
    %       [result, diag, t] = app.recognizeSignal(x, Fs, source)
    %       info = app.reloadMetadata(chemin)       % sans recharger l'index
    %       s    = app.getDisplayedResult()         % contenu de la carte résultat
    %       delete(app)                             % ferme l'interface
    %
    %   Voir aussi : gui/README.md, gui/test_AudioID.m, recognize_query.

    % =====================================================================
    properties (Constant, Access = private)
        MinDuration   = 1.0     % durée minimale acceptée (s)
        ShortDuration = 3.0     % en dessous : avertissement (cf. expériences 3/5/10 s)
        MicFs         = 44100   % fréquence d'acquisition du microphone (Hz)
        MaxHistory    = 50      % nombre maximal d'entrées d'historique
        DynRange      = 80      % dynamique affichée du spectrogramme (dB)
        FileCardH     = 144     % hauteurs des cartes de la colonne gauche (px)
        MicCardH      = 170
        MinResultH    = 410
    end

    % État lisible depuis l'extérieur (tests), modifiable uniquement par la classe
    properties (SetAccess = private)
        UIFigure                % fenêtre principale (uifigure)
        IndexFile = ''          % chemin du fichier d'index chargé
        MetadataFile = ''       % chemin du fichier de métadonnées
        Index = []              % structure index (map + metadata en mémoire)
        Cfg = []                % configuration sauvegardée avec l'index
        AudioFiles = {}         % chemins des morceaux de référence (si sauvegardés)
        MetaInfo = []           % bilan de la vérification des métadonnées
        IsLoaded = false        % bibliothèque chargée et valide
        LoadCount = 0           % nombre de chargements de l'index (doit rester à 1)
        LoadTime = NaN          % durée du chargement de l'index (s)
        LastResult = []         % dernière structure result
        LastDiag = []           % dernière structure diag
        LastSignal = []         % dernier signal analysé (x, Fs, kind, label)
        History = struct('time', {}, 'kind', {}, 'source', {}, 'outcome', {}, ...
            'song_id', {}, 'title', {}, 'score', {}, 'score2', {}, 'elapsed_ms', {})

        % Axes scientifiques (lecture publique pour les tests)
        AxSignal
        AxSpec
        AxConst
        AxHist
        AxCand
    end

    properties (Access = private)
        Root = ''               % racine du projet
        T                       % thème graphique
        CurrentFile = ''        % fichier sélectionné
        CurrentX = []           % signal du fichier sélectionné
        CurrentFs = []
        CurrentInfo = ''
        Recorder = []           % audiorecorder actif (libéré après chaque acquisition)
        RecDuration = 5         % durée d'enregistrement (s)
        RecCancelled = false
        RecHandled = false
        RecStart = []
        Busy = false

        % Grilles redimensionnées dynamiquement
        HeaderGrid
        BodyGrid
        LeftGrid

        % En-tête
        StatusDot
        StatusText
        IndexPathLabel
        LoadOtherButton
        ExportButton

        % Carte fichier
        FileNameLabel
        FileInfoLabel
        BrowseButton
        IdentifyButton

        % Carte microphone
        DurButtons
        RecordButton
        RecBarGrid
        RecLabel

        % Carte résultat
        CardStripe
        CardSource
        CardStatus
        CardTitle
        CardSubtitle
        CardDetail
        FieldValues

        % Zone d'analyse
        NavButtons
        Pages
        PageCaptions
        PeaksCheck
        SpecInfoLabel
        HistNote
        InfoValues
        InfoNotes
        HistoryTable
    end

    % =====================================================================
    methods
        function app = AudioID(varargin)
            %AUDIOID Construit l'interface puis charge la bibliothèque.
            guiDir = fileparts(mfilename('fullpath'));
            root = fileparts(guiDir);

            p = inputParser;
            p.FunctionName = 'AudioID';
            p.addParameter('IndexFile', ...
                fullfile(root, 'results', 'fingerprint_index.mat'), ...
                @(s) ischar(s) || isstring(s));
            p.addParameter('MetadataFile', ...
                fullfile(root, 'data', 'metadata.csv'), ...
                @(s) ischar(s) || isstring(s));
            p.addParameter('Visible', 'on', ...
                @(s) any(strcmpi(char(s), {'on', 'off'})));
            p.parse(varargin{:});

            app.Root = root;
            app.IndexFile = char(p.Results.IndexFile);
            app.MetadataFile = char(p.Results.MetadataFile);
            app.T = AudioID.theme();

            % Accès au pipeline existant (src/), sans le modifier
            srcDir = fullfile(root, 'src');
            if isfolder(srcDir)
                addpath(srcDir);
            end
            if exist('recognize_query', 'file') ~= 2
                error('AudioID:pipeline', ...
                    'recognize_query.m introuvable : vérifier le dossier %s.', srcDir);
            end

            app.buildUI(lower(char(p.Results.Visible)));
            app.loadLibrary();
        end

        function delete(app)
            %DELETE Libère le microphone et ferme la fenêtre.
            app.RecCancelled = true;
            app.releaseRecorder();
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        function [result, dg, elapsed] = recognizeFile(app, filename)
            %RECOGNIZEFILE Lit un fichier audio puis lance la reconnaissance.
            filename = char(filename);
            [x, Fs] = app.readAudio(filename);
            [~, name, ext] = fileparts(filename);
            [result, dg, elapsed] = app.recognize(x, Fs, 'file', [name ext]);
        end

        function [result, dg, elapsed] = recognizeSignal(app, x, Fs, source)
            %RECOGNIZESIGNAL Reconnaissance d'un signal déjà en mémoire.
            if nargin < 4 || isempty(source)
                source = 'Signal';
            end
            [result, dg, elapsed] = app.recognize(x, Fs, 'signal', char(source));
        end

        function info = reloadMetadata(app, filename)
            %RELOADMETADATA Relit et vérifie un fichier de métadonnées.
            %   L'index (index.map) n'est pas rechargé : seule la table
            %   index.metadata en mémoire est remplacée.
            if nargin >= 2 && ~isempty(filename)
                app.MetadataFile = char(filename);
            end
            if ~app.IsLoaded
                error('AudioID:notLoaded', ...
                    'La bibliothèque d''empreintes n''est pas chargée.');
            end
            info = app.loadMetadata();
            app.updateSystemInfo();
        end

        function s = getDisplayedResult(app)
            %GETDISPLAYEDRESULT Textes affichés dans la carte résultat.
            s.source = char(app.CardSource.Text);
            s.status = char(app.CardStatus.Text);
            s.title = char(app.CardTitle.Text);
            s.subtitle = char(app.CardSubtitle.Text);
            s.detail = char(app.CardDetail.Text);
            names = {'identifiant', 'reference', 'score_s1', 'score_s2', ...
                'seuil', 'position', 'temps'};
            for i = 1:numel(names)
                s.(names{i}) = char(app.FieldValues(i).Text);
            end
        end
    end

    % =====================================================================
    %  Reconnaissance
    % =====================================================================
    methods (Access = private)
        function [result, dg, elapsed] = recognize(app, x, Fs, kind, label)
            %RECOGNIZE Appel unique au pipeline + mise à jour de l'interface.
            %   kind : 'file' | 'mic' | 'signal' ; label : nom affiché.
            %   Le temps mesuré correspond au seul appel de recognize_query.
            if ~app.IsLoaded
                error('AudioID:notLoaded', ...
                    'La bibliothèque d''empreintes n''est pas chargée.');
            end
            if isrow(x)
                x = x(:);       % preprocess_audio moyenne les colonnes
            end
            app.validateSignal(x, Fs);

            t0 = tic;
            [result, dg] = recognize_query(x, Fs, app.Index, app.Cfg);
            elapsed = toc(t0);

            app.LastResult = result;
            app.LastDiag = dg;
            app.LastSignal = struct('x', x, 'Fs', Fs, 'kind', kind, 'label', label);

            app.addHistory(kind, label, result, elapsed);
            app.showResult(result, elapsed);
            app.plotAll();
            drawnow limitrate;
        end
    end

    % =====================================================================
    %  Chargement de la bibliothèque et des métadonnées
    % =====================================================================
    methods (Access = private)
        function ok = loadLibrary(app)
            %LOADLIBRARY Charge index, cfg et audio_files depuis le fichier MAT.
            ok = false;
            app.IsLoaded = false;
            app.MetaInfo = [];
            app.setLibraryStatus('loading');
            drawnow;

            if ~isfile(app.IndexFile)
                app.setLibraryStatus('missing');
                app.resetResultCard('Bibliothèque indisponible', ...
                    'Index introuvable. Voir l''onglet Système pour le reconstruire.', app.T.danger);
                app.updateSystemInfo();
                app.refreshControls();
                app.showPage(5);
                app.alert(app.rebuildHelp(), 'Index introuvable');
                return;
            end

            dlg = [];
            if app.isShown()
                dlg = uiprogressdlg(app.UIFigure, 'Title', 'AudioID', ...
                    'Message', sprintf('Chargement de la bibliothèque d''empreintes…\n%s', ...
                    app.relPath(app.IndexFile)), 'Indeterminate', 'on');
            end

            try
                t0 = tic;
                vars = who('-file', app.IndexFile);
                missing = setdiff({'index', 'cfg'}, vars);
                if ~isempty(missing)
                    error('AudioID:badIndex', ...
                        'Variable(s) absente(s) du fichier : %s.', strjoin(missing, ', '));
                end
                toLoad = intersect({'index', 'cfg', 'audio_files'}, vars, 'stable');
                S = load(app.IndexFile, toLoad{:});

                if ~isstruct(S.index) || ~isfield(S.index, 'map') || ...
                        ~isa(S.index.map, 'containers.Map')
                    error('AudioID:badIndex', ...
                        'La variable index ne contient pas de table index.map (containers.Map).');
                end
                req = {'Fs', 'N', 'H', 'Nfft', 'win', 'peaks', 'hash', 'decision'};
                miss = req(~isfield(S.cfg, req));
                if isempty(miss) && ~isfield(S.cfg.decision, 'threshold')
                    miss = {'decision.threshold'};
                end
                if ~isempty(miss)
                    error('AudioID:badIndex', ...
                        'Configuration sauvegardée incomplète (champs manquants : %s).', ...
                        strjoin(miss, ', '));
                end

                app.Index = S.index;
                app.Cfg = S.cfg;
                if isfield(S, 'audio_files') && iscell(S.audio_files)
                    app.AudioFiles = S.audio_files;
                else
                    app.AudioFiles = {};
                end
                app.LoadTime = toc(t0);
                app.LoadCount = app.LoadCount + 1;
                app.IsLoaded = true;
            catch ME
                app.closeDialog(dlg);
                app.setLibraryStatus('error');
                app.resetResultCard('Bibliothèque indisponible', ...
                    'Le fichier d''index n''a pas pu être chargé.', app.T.danger);
                app.updateSystemInfo();
                app.refreshControls();
                app.alert(sprintf('Impossible de charger %s.\n\n%s', ...
                    app.relPath(app.IndexFile), ME.message), 'Erreur de chargement');
                return;
            end

            if ~isempty(dlg) && isvalid(dlg)
                dlg.Message = 'Vérification des métadonnées…';
            end
            info = app.loadMetadata();
            app.closeDialog(dlg);

            if isnan(app.Cfg.decision.threshold)
                app.setLibraryStatus('uncalibrated');
                app.alert(app.uncalibratedHelp(), 'Seuil non calibré', 'warning');
            else
                app.setLibraryStatus('ready');
            end
            if any(strcmp(info.status, {'partial', 'incompatible', 'error'}))
                app.alert(app.metaSummary(true), 'Métadonnées', 'warning');
            end
            app.resetResultCard();
            app.updateSystemInfo();
            app.refreshControls();
            ok = true;
        end

        function info = loadMetadata(app)
            %LOADMETADATA Lit data/metadata.csv, vérifie chaque ligne et
            %   attache la table validée à app.Index.metadata (en mémoire).
            %
            %   Contrôles, pour chaque ligne :
            %     - song_id entier, unique, compris entre 1 et N (N = numel(audio_files)) ;
            %     - fma_id égal au numéro FMA du fichier audio_files{song_id} ;
            %     - colonne file : même nom de fichier que audio_files{song_id}.
            %   Une ligne qui échoue n'est pas affichée (titre « non disponible »).
            %
            %   La table produite a exactement une ligne par song_id (ligne k =
            %   morceau k), format attendu par classify_match.m.
            file = app.MetadataFile;
            N = numel(app.AudioFiles);
            info = struct('file', file, 'status', 'absent', 'nRows', 0, ...
                'nValid', 0, 'nRefs', N, 'verified', N > 0, 'checks', '', ...
                'issues', {{}});

            % Retirer d'abord d'éventuelles métadonnées précédentes
            if isstruct(app.Index) && isfield(app.Index, 'metadata')
                app.Index = rmfield(app.Index, 'metadata');
            end

            if ~isfile(file)
                info.issues = {sprintf('Fichier introuvable : %s', app.relPath(file))};
                app.MetaInfo = info;
                return;
            end

            % ---- Lecture (toutes les colonnes en texte, conversion contrôlée)
            try
                opts = detectImportOptions(file, 'FileType', 'text', ...
                    'Delimiter', ',', 'Encoding', 'UTF-8');
                opts = setvartype(opts, opts.VariableNames, 'string');
                Tm = readtable(file, opts);
            catch ME
                info.status = 'error';
                info.issues = {sprintf('Lecture impossible : %s', ME.message)};
                app.MetaInfo = info;
                return;
            end
            info.nRows = height(Tm);

            col = @(key) AudioID.findColumn(Tm, key);
            cId = col('song_id');
            cTitle = col('title');
            if isempty(cId) || isempty(cTitle)
                info.status = 'error';
                info.issues = {'Colonnes obligatoires absentes : song_id et title.'};
                app.MetaInfo = info;
                return;
            end
            getS = @(c) AudioID.cleanText(Tm, c);
            sid = str2double(getS(cId));
            title = getS(cTitle);
            artist = getS(col('artist'));
            genre = getS(col('genre'));
            fmaTxt = getS(col('fma_id'));
            fileTxt = getS(col('file'));
            durTxt = getS(col('duration_s'));
            hasFma = ~isempty(col('fma_id'));
            hasFile = ~isempty(col('file'));

            % ---- Nombre de morceaux de référence
            okId = ~isnan(sid) & sid >= 1 & sid == round(sid);
            if N == 0
                % audio_files absent : correspondance non vérifiable
                N = max([0; sid(okId)]);
                info.nRefs = N;
            end
            issues = {};
            if any(~okId)
                issues{end + 1} = sprintf('%d ligne(s) sans song_id valide ignorée(s).', sum(~okId));
            end
            out = okId & sid > N;
            if any(out)
                issues{end + 1} = sprintf('song_id hors bibliothèque (1 à %d) : %s.', ...
                    N, AudioID.listIds(sid(out)));
                okId(out) = false;
            end
            dupIds = [];
            if any(okId)
                [u, ~, ic] = unique(sid(okId));
                dupIds = u(accumarray(ic(:), 1) > 1);
            end
            if ~isempty(dupIds)
                issues{end + 1} = sprintf('song_id en double : %s.', AudioID.listIds(dupIds));
                okId(ismember(sid, dupIds)) = false;
            end

            % ---- Correspondance avec audio_files
            nR = info.nRows;
            fmaOK = true(nR, 1);
            fileOK = true(nR, 1);
            fileChecked = false(nR, 1);
            fmaBad = [];
            fileBad = [];
            fileComparable = true;
            if info.verified
                for r = find(okId)'
                    [~, refName, refExt] = fileparts(app.AudioFiles{sid(r)});
                    refFma = str2double(refName);
                    if hasFma
                        v = str2double(fmaTxt(r));
                        if isnan(v) || (~isnan(refFma) && v ~= refFma)
                            fmaOK(r) = false;
                            fmaBad(end + 1) = sid(r); %#ok<AGROW>
                        end
                    end
                    if hasFile && strlength(fileTxt(r)) > 0
                        [~, n2, e2] = fileparts(char(fileTxt(r)));
                        fileChecked(r) = true;
                        if ~strcmpi([n2 e2], [refName refExt])
                            fileOK(r) = false;
                            fileBad(end + 1) = sid(r); %#ok<AGROW>
                        end
                    end
                end
                if any(fileChecked) && ~any(fileOK(fileChecked))
                    % Convention de nommage différente : contrôle non concluant
                    issues{end + 1} = ['Colonne file non comparable aux chemins audio_files : ' ...
                        'vérification par fma_id uniquement.'];
                    fileOK(:) = true;
                    fileBad = [];
                    fileComparable = false;
                end
                if ~isempty(fmaBad)
                    issues{end + 1} = sprintf('fma_id différent du fichier audio indexé : song_id %s.', ...
                        AudioID.listIds(fmaBad));
                end
                if ~isempty(fileBad)
                    issues{end + 1} = sprintf('Colonne file différente de audio_files : song_id %s.', ...
                        AudioID.listIds(fileBad));
                end
            else
                issues{end + 1} = ['audio_files absent de l''index : correspondance ' ...
                    'avec les fichiers audio non vérifiable.'];
            end
            valid = okId & fmaOK & fileOK;

            % ---- Table alignée sur song_id (ligne k = morceau k)
            ids = (1:N)';
            m = table(ids, strings(N, 1), strings(N, 1), strings(N, 1), nan(N, 1), ...
                nan(N, 1), strings(N, 1), false(N, 1), 'VariableNames', ...
                {'song_id', 'title', 'artist', 'genre', 'fma_id', 'duration_s', 'file', 'valid'});
            rows = find(valid);
            k = sid(rows);
            m.title(k) = title(rows);
            m.artist(k) = artist(rows);
            m.genre(k) = genre(rows);
            m.fma_id(k) = str2double(fmaTxt(rows));
            m.duration_s(k) = str2double(durTxt(rows));
            m.file(k) = fileTxt(rows);
            m.valid(k) = true;

            missingIds = setdiff(ids, k);
            if ~isempty(missingIds)
                issues{end + 1} = sprintf('%d morceau(x) sans métadonnées validées : %s.', ...
                    numel(missingIds), AudioID.listIds(missingIds));
            end

            info.nValid = numel(rows);
            checks = {'song_id'};
            if info.verified && hasFma, checks{end + 1} = 'fma_id'; end
            if info.verified && hasFile && any(fileChecked) && fileComparable
                checks{end + 1} = 'fichier';
            end
            info.checks = strjoin(checks, ', ');
            info.issues = issues;
            if N > 0 && info.nValid == N
                info.status = 'ok';
            elseif info.nValid > 0
                info.status = 'partial';
            else
                info.status = 'incompatible';
            end

            if info.nValid > 0
                app.Index.metadata = m;     % en mémoire uniquement
            end
            app.MetaInfo = info;
        end

        function s = metaSummary(app, long)
            %METASUMMARY Texte de synthèse sur l'état des métadonnées.
            mi = app.MetaInfo;
            if isempty(mi)
                s = '—';
                return;
            end
            switch mi.status
                case 'ok'
                    s = sprintf('%d/%d morceaux vérifiés (%s)', mi.nValid, mi.nRefs, mi.checks);
                case 'partial'
                    s = sprintf('Partielles : %d/%d morceaux validés', mi.nValid, mi.nRefs);
                case 'incompatible'
                    s = 'Incompatibles avec l''index : titres non affichés';
                case 'error'
                    s = 'Illisibles : titres non affichés';
                otherwise
                    s = 'Absentes : titres non affichés';
            end
            if nargin > 1 && long
                s = sprintf('Métadonnées (%s) : %s.', app.relPath(mi.file), s);
                if ~isempty(mi.issues)
                    s = sprintf('%s\n\n- %s', s, strjoin(mi.issues, sprintf('\n- ')));
                end
                s = sprintf(['%s\n\nLes morceaux concernés restent reconnus ; seul leur titre ' ...
                    'n''est pas affiché.'], s);
            end
        end

        function txt = rebuildHelp(app)
            txt = sprintf([ ...
                'Le fichier d''index est introuvable :\n%s\n\n' ...
                'Ce fichier (environ 300 Mo) est volontairement exclu du dépôt Git. ' ...
                'Pour le reconstruire, ouvrir MATLAB à la racine du projet puis exécuter, ' ...
                'dans l''ordre et dans la même session :\n\n' ...
                '1. run(''experiments/setup_database.m'')  : construction de l''index (dossier fma_small)\n' ...
                '2. run(''experiments/create_queries.m'')  : génération des requêtes\n' ...
                '3. run(''experiments/calibrate_threshold.m'')  : calibration de cfg.decision.threshold\n' ...
                '4. save(''results/fingerprint_index.mat'', ''index'', ''cfg'', ''audio_files'', ''-v7.3'')\n\n' ...
                'Relancer ensuite AudioID, ou utiliser « Changer d''index… » pour ' ...
                'sélectionner un fichier existant.'], app.IndexFile);
        end

        function txt = uncalibratedHelp(~)
            txt = sprintf([ ...
                'La configuration sauvegardée avec l''index ne contient pas de seuil ' ...
                '(cfg.decision.threshold = NaN).\n\n' ...
                'Les scores restent calculés, mais la décision connu / inconnu est indéterminée.\n\n' ...
                'Pour calibrer : run(''experiments/calibrate_threshold.m'') puis ' ...
                'save(''results/fingerprint_index.mat'', ''index'', ''cfg'', ''audio_files'', ''-v7.3'').']);
        end
    end

    % =====================================================================
    %  Construction de l'interface
    % =====================================================================
    methods (Access = private)
        function buildUI(app, visible)
            T = app.T;
            % Taille initiale adaptée à l'écran
            ss = get(groot, 'ScreenSize');
            w = min(1400, ss(3) - 60);
            h = min(880, ss(4) - 90);
            pos = [max(1, (ss(3) - w) / 2), max(40, (ss(4) - h) / 2), w, h];

            app.UIFigure = uifigure( ...
                'Name', 'AudioID — Acoustic Fingerprinting & Music Recognition', ...
                'Color', T.bg, 'Position', pos, 'Visible', 'off', ...
                'AutoResizeChildren', 'off', ...
                'CloseRequestFcn', @(~, ~) delete(app));

            main = uigridlayout(app.UIFigure, [2 1], ...
                'RowHeight', {64, '1x'}, 'ColumnWidth', {'1x'}, ...
                'Padding', [24 16 24 16], 'RowSpacing', 14, 'BackgroundColor', T.bg);
            app.buildHeader(main);

            app.BodyGrid = uigridlayout(main, [1 2], 'ColumnWidth', {390, '1x'}, ...
                'RowHeight', {'1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 16, ...
                'BackgroundColor', T.bg);
            app.BodyGrid.Layout.Row = 2;
            app.BodyGrid.Layout.Column = 1;

            app.buildRecognitionZone(app.BodyGrid);
            app.buildAnalysisZone(app.BodyGrid);

            app.resetResultCard();
            app.showPage(2);
            app.refreshControls();
            app.UIFigure.SizeChangedFcn = @(~, ~) app.onResize();
            app.onResize();
            app.UIFigure.Visible = visible;
            drawnow;
        end

        % ---------------------------------------------------------------
        function buildHeader(app, parent)
            T = app.T;
            g = uigridlayout(parent, [2 4], ...
                'ColumnWidth', {52, '1x', 260, 300}, 'RowHeight', {36, 24}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 14, 'RowSpacing', 2, ...
                'BackgroundColor', T.bg);
            g.Layout.Row = 1;
            g.Layout.Column = 1;
            app.HeaderGrid = g;

            ax = uiaxes(g);
            ax.Layout.Row = [1 2];
            ax.Layout.Column = 1;
            app.drawLogo(ax);

            ttl = app.label(g, 'AudioID', 28, T.text, 'bold');
            ttl.Layout.Row = 1;
            ttl.Layout.Column = 2;
            ttl.VerticalAlignment = 'bottom';

            sub = app.label(g, 'Acoustic Fingerprinting & Music Recognition', 13, T.muted);
            sub.Layout.Row = 2;
            sub.Layout.Column = 2;
            sub.VerticalAlignment = 'top';

            % Indicateur d'état de la bibliothèque
            pill = uigridlayout(g, [1 2], 'ColumnWidth', {14, '1x'}, 'RowHeight', {'1x'}, ...
                'Padding', [12 2 12 2], 'ColumnSpacing', 6, 'BackgroundColor', T.panel2);
            pill.Layout.Row = 1;
            pill.Layout.Column = 3;
            app.StatusDot = app.label(pill, '●', 14, T.muted);
            app.StatusText = app.label(pill, 'Initialisation…', 12, T.text, 'bold');

            app.IndexPathLabel = app.label(g, '', 11, T.muted);
            app.IndexPathLabel.Layout.Row = 2;
            app.IndexPathLabel.Layout.Column = 3;

            act = uigridlayout(g, [1 2], 'ColumnWidth', {'1x', '1x'}, 'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 8, 'BackgroundColor', T.bg);
            act.Layout.Row = 1;
            act.Layout.Column = 4;
            app.LoadOtherButton = app.button(act, 'Changer d''index…', T.panel2, T.text, ...
                @(~, ~) app.onLoadOther());
            app.ExportButton = app.button(act, 'Exporter PNG', T.panel2, T.text, ...
                @(~, ~) app.onExport());
        end

        function drawLogo(app, ax)
            %DRAWLOGO Pastille originale : disque bleu et barres d'onde.
            T = app.T;
            ax.BackgroundColor = T.bg;
            ax.Color = 'none';
            ax.XColor = 'none';
            ax.YColor = 'none';
            ax.Toolbar.Visible = 'off';
            disableDefaultInteractivity(ax);
            hold(ax, 'on');
            th = linspace(0, 2*pi, 120);
            fill(ax, cos(th), sin(th), T.accent2, 'EdgeColor', 'none');
            h = [0.30 0.62 1.00 0.55 0.25];
            xs = linspace(-0.48, 0.48, 5);
            for i = 1:numel(h)
                plot(ax, [xs(i) xs(i)], [-h(i) h(i)] * 0.55, '-', ...
                    'Color', [1 1 1], 'LineWidth', 3);
            end
            hold(ax, 'off');
            axis(ax, 'equal');
            xlim(ax, [-1.05 1.05]);
            ylim(ax, [-1.05 1.05]);
        end

        % ---------------------------------------------------------------
        function buildRecognitionZone(app, parent)
            T = app.T;
            col = uigridlayout(parent, [3 1], ...
                'RowHeight', {app.FileCardH, app.MicCardH, app.MinResultH}, ...
                'ColumnWidth', {'1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 12, ...
                'BackgroundColor', T.bg);
            col.Layout.Row = 1;
            col.Layout.Column = 1;
            % Défilement vertical si la fenêtre est plus petite que le contenu
            AudioID.setIfProp(col, 'Scrollable', 'on');
            app.LeftGrid = col;

            % ---- Carte : fichier audio
            g = app.card(col, 1, {20, 22, 18, 36}, 'Fichier audio');
            app.FileNameLabel = app.label(g, 'Aucun fichier sélectionné', 15, T.text, 'bold');
            app.FileNameLabel.Layout.Row = 2;
            app.FileInfoLabel = app.label(g, ...
                'WAV, FLAC, MP3, M4A… (formats lus par audioread)', 12, T.muted);
            app.FileInfoLabel.Layout.Row = 3;
            bg = uigridlayout(g, [1 2], 'ColumnWidth', {'1x', '1x'}, 'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 10, 'BackgroundColor', T.panel);
            bg.Layout.Row = 4;
            app.BrowseButton = app.button(bg, 'Choisir un fichier…', T.panel2, T.text, ...
                @(~, ~) app.onBrowse());
            app.IdentifyButton = app.button(bg, 'Identifier', T.accent2, [1 1 1], ...
                @(~, ~) app.onIdentifyFile());

            % ---- Carte : microphone
            g = app.card(col, 2, {20, 30, 36, 8, 18}, 'Microphone');
            dg = uigridlayout(g, [1 4], 'ColumnWidth', {56, '1x', '1x', '1x'}, ...
                'RowHeight', {'1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
                'BackgroundColor', T.panel);
            dg.Layout.Row = 2;
            lab = app.label(dg, 'Durée', 12, T.muted);
            lab.Layout.Column = 1;
            durs = [3 5 10];
            app.DurButtons = gobjects(1, numel(durs));
            for i = 1:numel(durs)
                d = durs(i);
                b = uibutton(dg, 'state', 'Text', sprintf('%d s', d), ...
                    'FontName', T.font, 'FontSize', 13, 'FontWeight', 'bold', ...
                    'BackgroundColor', T.panel2, 'FontColor', T.text, ...
                    'ValueChangedFcn', @(~, ~) app.selectDuration(d));
                b.Layout.Column = i + 1;
                app.DurButtons(i) = b;
            end
            app.selectDuration(5);

            app.RecordButton = app.button(g, '●  Écouter et identifier', T.accent, T.ink, ...
                @(~, ~) app.onRecord());
            app.RecordButton.Layout.Row = 3;

            % Barre de progression : deux cellules dont les poids varient
            app.RecBarGrid = uigridlayout(g, [1 2], 'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 0, 'BackgroundColor', T.panel2);
            app.RecBarGrid.Layout.Row = 4;
            uilabel(app.RecBarGrid, 'Text', '', 'BackgroundColor', T.accent);
            uilabel(app.RecBarGrid, 'Text', '', 'BackgroundColor', T.panel2);
            app.setProgress(0);

            app.RecLabel = app.label(g, 'Prêt. macOS peut demander l''accès au micro.', 12, T.muted);
            app.RecLabel.Layout.Row = 5;

            % ---- Carte : résultat
            %   source | statut | titre | artiste · genre | détail | champs
            g = app.card(col, 3, {20, 4, 18, 30, 46, 20, 40, '1x'}, 'Résultat');
            app.CardStripe = uilabel(g, 'Text', '', 'BackgroundColor', T.panel2);
            app.CardStripe.Layout.Row = 2;
            app.CardSource = app.label(g, '', 11, T.accent, 'bold');
            app.CardSource.Layout.Row = 3;
            app.CardStatus = app.label(g, '', 22, T.text, 'bold');
            app.CardStatus.Layout.Row = 4;
            app.CardTitle = app.label(g, '', 17, T.text, 'bold');
            app.CardTitle.Layout.Row = 5;
            app.CardTitle.VerticalAlignment = 'top';
            AudioID.setIfProp(app.CardTitle, 'WordWrap', 'on');
            app.CardSubtitle = app.label(g, '', 13, T.muted);
            app.CardSubtitle.Layout.Row = 6;
            app.CardDetail = app.label(g, '', 12, T.muted);
            app.CardDetail.Layout.Row = 7;
            app.CardDetail.VerticalAlignment = 'top';
            AudioID.setIfProp(app.CardDetail, 'WordWrap', 'on');

            names = {'Identifiant', 'Fichier de référence', 'Score S1', 'Score S2', ...
                'Seuil de décision', 'Position (référence)', 'Temps de traitement'};
            fg = uigridlayout(g, [numel(names) 2], 'ColumnWidth', {140, '1x'}, ...
                'RowHeight', repmat({'1x'}, 1, numel(names)), 'Padding', [0 0 0 0], ...
                'RowSpacing', 2, 'ColumnSpacing', 8, 'BackgroundColor', T.panel);
            fg.Layout.Row = 8;
            app.FieldValues = gobjects(1, numel(names));
            for i = 1:numel(names)
                l = app.label(fg, names{i}, 12, T.muted);
                l.Layout.Row = i;
                l.Layout.Column = 1;
                v = app.label(fg, '—', 13, T.text, 'bold');
                v.Layout.Row = i;
                v.Layout.Column = 2;
                app.FieldValues(i) = v;
            end
        end

        % ---------------------------------------------------------------
        function buildAnalysisZone(app, parent)
            T = app.T;
            p = uipanel(parent, 'BackgroundColor', T.panel, 'BorderType', 'none');
            p.Layout.Row = 1;
            p.Layout.Column = 2;
            g = uigridlayout(p, [2 1], 'RowHeight', {34, '1x'}, 'ColumnWidth', {'1x'}, ...
                'Padding', [16 14 16 14], 'RowSpacing', 12, 'BackgroundColor', T.panel);

            % Navigation (onglets personnalisés, largeur proportionnelle)
            names = {'Signal', 'Spectrogramme', 'Constellation', 'Alignement', ...
                'Système', 'Historique'};
            nav = uigridlayout(g, [1 numel(names)], ...
                'ColumnWidth', repmat({'1x'}, 1, numel(names)), ...
                'RowHeight', {'1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6, ...
                'BackgroundColor', T.panel);
            nav.Layout.Row = 1;
            app.NavButtons = gobjects(1, numel(names));
            for i = 1:numel(names)
                k = i;
                b = uibutton(nav, 'state', 'Text', names{i}, 'FontName', T.font, ...
                    'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', T.panel2, ...
                    'FontColor', T.muted, 'ValueChangedFcn', @(~, ~) app.showPage(k));
                b.Layout.Column = i;
                app.NavButtons(i) = b;
            end

            % Pages superposées dans la même cellule ; une seule visible
            content = uigridlayout(g, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.panel);
            content.Layout.Row = 2;
            app.Pages = gobjects(1, numel(names));
            for i = 1:numel(names)
                pg = uipanel(content, 'BackgroundColor', T.panel, 'BorderType', 'none');
                pg.Layout.Row = 1;
                pg.Layout.Column = 1;
                app.Pages(i) = pg;
            end
            % Légendes au-dessus des graphiques : les détails longs y sont
            % placés pour que les titres d'axes restent courts et lisibles.
            app.PageCaptions = gobjects(1, 4);

            % 1. Signal temporel
            pg = uigridlayout(app.Pages(1), [2 1], 'RowHeight', {36, '1x'}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 4, 'BackgroundColor', T.panel);
            app.PageCaptions(1) = app.caption(pg, 1);
            app.AxSignal = app.makeAxes(pg);
            app.AxSignal.Layout.Row = 2;

            % 2. Spectrogramme (+ constellation superposable)
            pg = uigridlayout(app.Pages(2), [3 1], 'RowHeight', {36, '1x', 24}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 4, 'BackgroundColor', T.panel);
            app.PageCaptions(2) = app.caption(pg, 1);
            app.AxSpec = app.makeAxes(pg);
            app.AxSpec.Layout.Row = 2;
            bot = uigridlayout(pg, [1 2], 'ColumnWidth', {320, '1x'}, 'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], 'BackgroundColor', T.panel);
            bot.Layout.Row = 3;
            app.PeaksCheck = uicheckbox(bot, 'Text', 'Superposer la constellation des maxima', ...
                'Value', true, 'FontName', T.font, 'FontSize', 12, 'FontColor', T.text, ...
                'ValueChangedFcn', @(~, ~) app.onTogglePeaks());
            app.SpecInfoLabel = app.label(bot, '', 12, T.muted);
            app.SpecInfoLabel.HorizontalAlignment = 'right';

            % 3. Constellation
            pg = uigridlayout(app.Pages(3), [2 1], 'RowHeight', {36, '1x'}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 4, 'BackgroundColor', T.panel);
            app.PageCaptions(3) = app.caption(pg, 1);
            app.AxConst = app.makeAxes(pg);
            app.AxConst.Layout.Row = 2;

            % 4. Alignement temporel
            pg = uigridlayout(app.Pages(4), [3 2], 'RowHeight', {36, '1x', 40}, ...
                'ColumnWidth', {'3x', '2x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4, ...
                'ColumnSpacing', 14, 'BackgroundColor', T.panel);
            app.PageCaptions(4) = app.caption(pg, 1);
            app.PageCaptions(4).Layout.Column = [1 2];
            app.AxHist = app.makeAxes(pg);
            app.AxHist.Layout.Row = 2;
            app.AxHist.Layout.Column = 1;
            app.AxCand = app.makeAxes(pg);
            app.AxCand.Layout.Row = 2;
            app.AxCand.Layout.Column = 2;
            app.HistNote = app.label(pg, '', 12, T.muted);
            app.HistNote.Layout.Row = 3;
            app.HistNote.Layout.Column = [1 2];
            app.HistNote.VerticalAlignment = 'top';
            AudioID.setIfProp(app.HistNote, 'WordWrap', 'on');

            % 5. Informations système
            infoNames = {'État de la bibliothèque', 'Fichier d''index', ...
                'Signatures distinctes', 'Morceaux de référence', ...
                'Fréquence d''échantillonnage', 'Seuil de décision', 'Analyse TFCT', ...
                'Sélection des pics', 'Empreintes', 'Métadonnées', ...
                'Chargements de l''index', 'Reconnaissances (session)', 'Version MATLAB'};
            n = numel(infoNames);
            pg = uigridlayout(app.Pages(5), [n + 1, 2], 'ColumnWidth', {220, '1x'}, ...
                'RowHeight', [repmat({24}, 1, n), {'1x'}], 'Padding', [4 4 4 4], ...
                'RowSpacing', 4, 'ColumnSpacing', 12, 'BackgroundColor', T.panel);
            AudioID.setIfProp(pg, 'Scrollable', 'on');
            app.InfoValues = gobjects(1, n);
            for i = 1:n
                l = app.label(pg, infoNames{i}, 12, T.muted);
                l.Layout.Row = i;
                l.Layout.Column = 1;
                v = app.label(pg, '—', 13, T.text, 'bold');
                v.Layout.Row = i;
                v.Layout.Column = 2;
                app.InfoValues(i) = v;
            end
            app.InfoNotes = uitextarea(pg, 'Editable', 'off', 'FontName', T.font, ...
                'FontSize', 12, 'FontColor', T.text, 'BackgroundColor', T.panel2);
            app.InfoNotes.Layout.Row = n + 1;
            app.InfoNotes.Layout.Column = [1 2];

            % 6. Historique de session
            pg = uigridlayout(app.Pages(6), [2 2], 'RowHeight', {'1x', 34}, ...
                'ColumnWidth', {'1x', 200}, 'Padding', [0 0 0 0], 'RowSpacing', 8, ...
                'BackgroundColor', T.panel);
            app.HistoryTable = uitable(pg, ...
                'ColumnName', {'Heure', 'Source', 'Résultat', 'Morceau', 'S1', 'S2', 'Temps (ms)'}, ...
                'RowName', {}, 'Data', cell(0, 7), 'FontName', T.font, 'FontSize', 12, ...
                'BackgroundColor', [T.panel2; T.panel], 'ForegroundColor', T.text);
            app.HistoryTable.Layout.Row = 1;
            app.HistoryTable.Layout.Column = [1 2];
            clr = app.button(pg, 'Effacer l''historique', T.panel2, T.text, ...
                @(~, ~) app.onClearHistory());
            clr.Layout.Row = 2;
            clr.Layout.Column = 2;
        end

        % ---------------------------------------------------------------
        function g = card(app, parent, row, rows, ttl)
            %CARD Panneau de carte avec un titre en capitales.
            T = app.T;
            p = uipanel(parent, 'BackgroundColor', T.panel, 'BorderType', 'none');
            p.Layout.Row = row;
            p.Layout.Column = 1;
            g = uigridlayout(p, [numel(rows) 1], 'RowHeight', rows, 'ColumnWidth', {'1x'}, ...
                'Padding', [18 12 18 12], 'RowSpacing', 6, 'BackgroundColor', T.panel);
            h = app.label(g, upper(ttl), 11, T.accent, 'bold');
            h.Layout.Row = 1;
        end

        function lbl = caption(app, parent, row)
            lbl = app.label(parent, '', 12, app.T.muted);
            lbl.Layout.Row = row;
            lbl.VerticalAlignment = 'center';
            AudioID.setIfProp(lbl, 'WordWrap', 'on');
        end

        function lbl = label(app, parent, txt, fsz, color, weight)
            if nargin < 4 || isempty(fsz), fsz = 13; end
            if nargin < 5 || isempty(color), color = app.T.text; end
            if nargin < 6, weight = 'normal'; end
            lbl = uilabel(parent, 'Text', txt, 'FontName', app.T.font, ...
                'FontSize', fsz, 'FontColor', color, 'FontWeight', weight);
        end

        function b = button(app, parent, txt, bg, fg, cb)
            b = uibutton(parent, 'push', 'Text', txt, 'FontName', app.T.font, ...
                'FontSize', 13, 'FontWeight', 'bold', 'BackgroundColor', bg, ...
                'FontColor', fg, 'ButtonPushedFcn', cb);
        end

        function ax = makeAxes(app, parent)
            T = app.T;
            ax = uiaxes(parent);
            ax.BackgroundColor = T.panel;
            ax.Color = T.plotbg;
            ax.FontName = T.font;
            ax.FontSize = 11;
            ax.Box = 'off';
            ax.GridColor = [1 1 1];
            ax.GridAlpha = 0.08;
            app.placeholder(ax, 'Lancez une reconnaissance pour afficher cette analyse.');
        end

        % ---------------------------------------------------------------
        function onResize(app)
            %ONRESIZE Adapte les dimensions fixes à la taille de la fenêtre.
            if isempty(app.LeftGrid) || ~isvalid(app.UIFigure)
                return;
            end
            pos = app.UIFigure.Position;
            W = pos(3);
            H = pos(4);

            % Colonne de gauche : 360 px sur petit écran, 390 px sinon
            if W < 1250
                leftW = 360;
            else
                leftW = 390;
            end
            app.BodyGrid.ColumnWidth = {leftW, '1x'};

            % En-tête : colonnes d'état et d'actions réduites si étroit
            if W < 1150
                app.HeaderGrid.ColumnWidth = {52, '1x', 210, 250};
            else
                app.HeaderGrid.ColumnWidth = {52, '1x', 260, 300};
            end

            % Carte résultat : occupe la hauteur restante (minimum garanti,
            % la colonne défile si la fenêtre est trop basse)
            avail = H - 16 - 16 - 64 - 14;
            resH = max(app.MinResultH, avail - app.FileCardH - app.MicCardH - 2 * 12);
            app.LeftGrid.RowHeight = {app.FileCardH, app.MicCardH, resH};

            % Historique : largeurs de colonnes calculées en pixels
            tableW = W - 48 - leftW - 16 - 32 - 4;
            fixed = [72 112 52 52 84];          % Heure, Résultat, S1, S2, Temps
            flex = max(260, tableW - sum(fixed) - 18);
            srcW = round(0.42 * flex);
            songW = flex - srcW;
            app.HistoryTable.ColumnWidth = {fixed(1), srcW, fixed(2), songW, ...
                fixed(3), fixed(4), fixed(5)};
        end
    end

    % =====================================================================
    %  Callbacks
    % =====================================================================
    methods (Access = private)
        function onBrowse(app)
            startDir = fullfile(app.Root, 'data', 'queries');
            if ~isfolder(startDir)
                startDir = app.Root;
            end
            filters = {'*.wav;*.flac;*.mp3;*.m4a;*.mp4;*.ogg;*.oga;*.opus;*.aif;*.aiff;*.aifc;*.au;*.snd', ...
                'Fichiers audio'; '*.*', 'Tous les fichiers (*.*)'};
            [f, d] = uigetfile(filters, 'Sélectionner un extrait musical', [startDir filesep]);
            app.focus();

            if isequal(f, 0)
                % Annulation : la sélection précédente est conservée
                if isempty(app.CurrentFile)
                    app.FileInfoLabel.Text = 'Sélection annulée.';
                else
                    app.FileInfoLabel.Text = ['Sélection annulée · ' app.CurrentInfo];
                end
                return;
            end

            filename = fullfile(d, f);
            try
                [x, Fs] = app.readAudio(filename);
                if isrow(x), x = x(:); end
                app.validateSignal(x, Fs);
            catch ME
                app.clearSelection();
                app.alert(ME.message, 'Fichier non exploitable');
                return;
            end

            dur = size(x, 1) / Fs;
            if size(x, 2) == 1
                ch = 'mono';
            else
                ch = sprintf('%d canaux', size(x, 2));
            end
            info = sprintf('%s · %.1f kHz · %s', AudioID.fmtDuration(dur), Fs / 1000, ch);

            app.CurrentFile = filename;
            app.CurrentX = x;
            app.CurrentFs = Fs;
            app.CurrentInfo = info;
            app.FileNameLabel.Text = f;
            AudioID.setIfProp(app.FileNameLabel, 'Tooltip', filename);
            if dur < app.ShortDuration
                app.FileInfoLabel.Text = [info ' · extrait court'];
                app.FileInfoLabel.FontColor = app.T.warn;
            else
                app.FileInfoLabel.Text = info;
                app.FileInfoLabel.FontColor = app.T.muted;
            end
            app.refreshControls();
        end

        function onIdentifyFile(app)
            if isempty(app.CurrentX)
                return;
            end
            [~, n, e] = fileparts(app.CurrentFile);
            app.setSourceBadge('file', [n e]);
            app.runGuarded(@() app.recognize(app.CurrentX, app.CurrentFs, 'file', [n e]));
        end

        function selectDuration(app, d)
            app.RecDuration = d;
            durs = [3 5 10];
            for i = 1:numel(app.DurButtons)
                on = (durs(i) == d);
                app.DurButtons(i).Value = on;
                if on
                    app.DurButtons(i).BackgroundColor = app.T.accent2;
                    app.DurButtons(i).FontColor = [1 1 1];
                else
                    app.DurButtons(i).BackgroundColor = app.T.panel2;
                    app.DurButtons(i).FontColor = app.T.text;
                end
            end
        end

        % ---- Microphone --------------------------------------------------
        function onRecord(app)
            %ONRECORD Démarre (ou interrompt) l'acquisition microphone.
            %   Un nouvel audiorecorder est créé à chaque acquisition et
            %   libéré à la fin (succès, annulation ou erreur).
            if app.isRecording()
                app.RecCancelled = true;
                stop(app.Recorder);          % déclenche onRecStop
                return;
            end
            if ~app.IsLoaded
                app.alert('La bibliothèque d''empreintes n''est pas chargée.', 'Microphone');
                return;
            end

            app.releaseRecorder();           % au cas où une acquisition précédente serait restée ouverte
            label = sprintf('%d s', app.RecDuration);

            % La carte et les graphiques ne montrent plus l'analyse précédente
            app.resetResultCard('Écoute en cours…', ...
                'Diffusez l''extrait à proximité du microphone.', app.T.accent);
            app.setSourceBadge('mic', label);
            app.resetAnalysis('Enregistrement au microphone en cours…');

            try
                rec = audiorecorder(app.MicFs, 16, 1);
            catch ME
                app.micFailed(ME, 'Aucun périphérique d''entrée audio n''est accessible.');
                return;
            end

            rec.TimerPeriod = 0.05;
            rec.TimerFcn = @(~, ~) app.onRecTick();
            rec.StopFcn = @(~, ~) app.onRecStop();
            app.Recorder = rec;
            app.RecCancelled = false;
            app.RecHandled = false;
            app.RecStart = tic;
            app.setProgress(0);

            try
                record(rec, app.RecDuration);
            catch ME
                app.micFailed(ME, 'Impossible de démarrer l''enregistrement.');
                return;
            end

            app.RecordButton.Text = '■  Arrêter';
            app.RecordButton.BackgroundColor = app.T.danger;
            app.RecLabel.Text = sprintf('Enregistrement… 0.0 / %d s', app.RecDuration);
            app.RecLabel.FontColor = app.T.accent;
            app.refreshControls();
        end

        function onRecTick(app)
            %ONRECTICK Mise à jour de la barre de progression pendant l'acquisition.
            if ~isvalid(app) || isempty(app.RecStart) || ~isvalid(app.UIFigure)
                return;
            end
            el = toc(app.RecStart);
            app.setProgress(min(el / app.RecDuration, 1));
            app.RecLabel.Text = sprintf('Enregistrement… %.1f / %d s', ...
                min(el, app.RecDuration), app.RecDuration);
            % Garde-fou si la fin d'enregistrement n'est pas signalée
            if el > app.RecDuration + 1.5 && app.isRecording()
                stop(app.Recorder);
            end
        end

        function onRecStop(app)
            %ONRECSTOP Fin d'acquisition : récupération du signal, libération
            %   du périphérique, contrôles, puis reconnaissance.
            if ~isvalid(app) || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            if app.RecHandled
                return;
            end
            app.RecHandled = true;
            rec = app.Recorder;
            cancelled = app.RecCancelled;
            dur = app.RecDuration;

            x = [];
            fs = app.MicFs;
            readErr = [];
            if ~cancelled
                try
                    x = getaudiodata(rec);
                    fs = rec.SampleRate;
                catch ME
                    readErr = ME;
                end
            end
            app.releaseRecorder();           % périphérique libéré dans tous les cas
            app.resetRecordUI();

            if cancelled
                app.setProgress(0);
                app.RecLabel.Text = 'Enregistrement annulé. Prêt.';
                app.resetResultCard('Enregistrement annulé', ...
                    'Aucune reconnaissance effectuée.', app.T.muted);
                app.setSourceBadge('mic', sprintf('%d s', dur));
                return;
            end
            if ~isempty(readErr)
                app.micFailed(readErr, 'Lecture du signal enregistré impossible.');
                return;
            end
            if numel(x) < 0.5 * dur * fs
                app.micFailed([], 'L''enregistrement a été interrompu avant d''être exploitable.');
                return;
            end
            if max(abs(x)) < 1e-4
                app.micFailed([], sprintf([ ...
                    'Le signal enregistré est silencieux.\n\n' ...
                    'Sur macOS, un micro refusé produit un signal nul sans message d''erreur. ' ...
                    'Autoriser MATLAB dans Réglages Système > Confidentialité et sécurité > Microphone, ' ...
                    'puis redémarrer MATLAB.']));
                return;
            end

            app.setProgress(1);
            app.RecLabel.Text = sprintf('Extrait de %d s capturé, analyse…', dur);
            app.runGuarded(@() app.recognize(x, fs, 'mic', sprintf('%d s', dur)));
            if isvalid(app)
                app.setProgress(0);
                app.RecLabel.FontColor = app.T.muted;
                app.RecLabel.Text = sprintf('Extrait de %d s analysé. Prêt pour un nouvel enregistrement.', dur);
            end
        end

        function micFailed(app, ME, msg)
            %MICFAILED Libère le micro, réinitialise l'interface et informe.
            %   Les erreurs renvoyées par le périphérique (par exemple
            %   « Device Error ») sont rapportées telles quelles : elles
            %   peuvent provenir du système audio de macOS et non d'AudioID.
            app.releaseRecorder();
            app.resetRecordUI();
            app.setProgress(0);
            app.RecLabel.Text = 'Échec de l''acquisition. Prêt pour un nouvel essai.';
            app.RecLabel.FontColor = app.T.warn;
            app.resetResultCard('Acquisition impossible', ...
                'Aucune reconnaissance effectuée (voir le message).', app.T.danger);
            app.setSourceBadge('mic', sprintf('%d s', app.RecDuration));

            full = msg;
            if ~isempty(ME)
                full = sprintf('%s\n\nMessage du périphérique : %s', msg, ME.message);
                if contains(ME.message, 'device', 'IgnoreCase', true)
                    full = sprintf(['%s\n\nCette erreur est renvoyée par le pilote audio ; ' ...
                        'elle peut se produire indépendamment d''AudioID. Pour le vérifier, ' ...
                        'tester audiorecorder seul dans MATLAB. Si l''erreur persiste, ' ...
                        'redémarrer le service audio de macOS (Terminal : sudo killall coreaudiod), ' ...
                        'puis réessayer.'], full);
                else
                    full = sprintf(['%s\n\nVérifier qu''un microphone est disponible et que ' ...
                        'MATLAB est autorisé à l''utiliser : Réglages Système > ' ...
                        'Confidentialité et sécurité > Microphone.'], full);
                end
            end
            app.alert(full, 'Microphone', 'warning');
        end

        function releaseRecorder(app)
            %RELEASERECORDER Arrête et détruit l'audiorecorder courant.
            rec = app.Recorder;
            app.Recorder = [];
            app.RecStart = [];
            if isempty(rec)
                return;
            end
            try
                rec.TimerFcn = '';
                rec.StopFcn = '';
            catch
            end
            try
                if isrecording(rec)
                    stop(rec);
                end
            catch
            end
            try
                delete(rec);
            catch
            end
        end

        function resetRecordUI(app)
            app.RecordButton.Text = '●  Écouter et identifier';
            app.RecordButton.BackgroundColor = app.T.accent;
            app.RecLabel.FontColor = app.T.muted;
            app.refreshControls();
        end

        % ---- Divers ------------------------------------------------------
        function onTogglePeaks(app)
            if ~isempty(app.LastDiag)
                app.plotSpectrogram();
            end
        end

        function onLoadOther(app)
            startDir = fullfile(app.Root, 'results');
            if ~isfolder(startDir), startDir = app.Root; end
            [f, d] = uigetfile({'*.mat', 'Index MATLAB (*.mat)'}, ...
                'Sélectionner un fichier d''index', [startDir filesep]);
            app.focus();
            if isequal(f, 0)
                return;
            end
            app.IndexFile = fullfile(d, f);
            app.Index = [];
            app.Cfg = [];
            app.AudioFiles = {};
            app.LastDiag = [];
            app.resetAnalysis('Lancez une reconnaissance pour afficher cette analyse.');
            app.loadLibrary();
        end

        function onExport(app)
            %ONEXPORT Capture de la fenêtre complète (figures du rapport).
            if isempty(which('exportapp'))
                app.alert('exportapp nécessite MATLAB R2020b ou ultérieur.', 'Export');
                return;
            end
            outDir = fullfile(app.Root, 'report');
            if ~isfolder(outDir), outDir = app.Root; end
            def = fullfile(outDir, sprintf('AudioID_%s.png', ...
                char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
            [f, d] = uiputfile({'*.png', 'Image PNG (*.png)'; '*.pdf', 'PDF (*.pdf)'}, ...
                'Exporter la fenêtre AudioID', def);
            app.focus();
            if isequal(f, 0)
                return;
            end
            try
                exportapp(app.UIFigure, fullfile(d, f));
                app.alert(sprintf('Capture enregistrée :\n%s', fullfile(d, f)), 'Export', 'success');
            catch ME
                app.alert(ME.message, 'Export impossible');
            end
        end

        function onClearHistory(app)
            app.History = app.History([]);
            app.refreshHistory();
            app.updateSystemInfo();
        end
    end

    % =====================================================================
    %  Affichage du résultat
    % =====================================================================
    methods (Access = private)
        function showResult(app, r, elapsed)
            T = app.T;
            s = app.LastSignal;
            thr = app.Cfg.decision.threshold;
            app.setSourceBadge(s.kind, s.label);

            v = repmat({'—'}, 1, 7);
            v{3} = sprintf('%d votes', r.score);
            v{4} = sprintf('%d votes', r.score2);
            if isnan(thr)
                v{5} = 'Non calibré';
            else
                v{5} = sprintf('%g votes', thr);
            end
            v{6} = 'Non applicable';
            v{7} = sprintf('%.0f ms', 1000 * elapsed);
            songTitle = '';
            subtitle = '';
            isKnown = isequal(r.is_known, true);

            if isnan(r.is_known)
                status = 'Décision indéterminée';
                color = T.warn;
                detail = sprintf(['Seuil non calibré : S1 = %d votes ne peut être comparé ' ...
                    'à aucun seuil (voir Système).'], r.score);
            elseif isKnown
                status = 'Morceau reconnu';
                color = T.success;
                meta = app.metaRow(r.song_id);
                v{1} = sprintf('#%d', r.song_id);
                if ~isempty(meta) && ~isnan(meta.fma_id)
                    v{1} = sprintf('#%d · FMA %d', r.song_id, meta.fma_id);
                end
                v{2} = app.referenceName(r.song_id);
                v{6} = sprintf('%.2f s', r.offset_s);
                songTitle = app.titleText(r);
                if isempty(meta)
                    subtitle = 'Artiste et genre non disponibles';
                else
                    subtitle = sprintf('Artiste : %s  ·  Genre : %s', ...
                        AudioID.orDash(meta.artist), AudioID.orDash(meta.genre));
                end
                detail = sprintf('%d empreintes alignées sur un même décalage (seuil : %g).', ...
                    r.score, thr);
            else
                status = 'Morceau non reconnu';
                color = T.danger;
                songTitle = 'Absent de la bibliothèque ou insuffisamment reconnu';
                if r.score == 0
                    detail = 'Aucune empreinte commune avec la bibliothèque.';
                else
                    detail = sprintf('Meilleur score S1 = %d votes, inférieur au seuil de %g votes.', ...
                        r.score, thr);
                end
            end

            app.CardStatus.Text = status;
            app.CardStatus.FontColor = color;
            app.CardStripe.BackgroundColor = color;
            app.CardTitle.Text = songTitle;
            if isKnown
                app.CardTitle.FontColor = T.text;
                app.CardTitle.FontSize = 17;
            else
                app.CardTitle.FontColor = T.muted;
                app.CardTitle.FontSize = 14;
            end
            app.CardSubtitle.Text = subtitle;
            app.CardDetail.Text = detail;
            for i = 1:numel(app.FieldValues)
                app.FieldValues(i).Text = v{i};
                AudioID.setIfProp(app.FieldValues(i), 'Tooltip', v{i});
            end
            AudioID.setIfProp(app.CardTitle, 'Tooltip', songTitle);
        end

        function resetResultCard(app, status, detail, color)
            if nargin < 2
                status = 'En attente';
                detail = 'Choisissez un fichier ou enregistrez un extrait au microphone.';
                color = app.T.muted;
            end
            app.CardSource.Text = '';
            app.CardStatus.Text = status;
            app.CardStatus.FontColor = color;
            app.CardStripe.BackgroundColor = app.T.panel2;
            app.CardTitle.Text = '';
            app.CardSubtitle.Text = '';
            app.CardDetail.Text = detail;
            for i = 1:numel(app.FieldValues)
                app.FieldValues(i).Text = '—';
            end
        end

        function setSourceBadge(app, kind, label)
            %SETSOURCEBADGE Indique clairement l'origine du signal analysé.
            app.CardSource.Text = AudioID.sourceText(kind, label, true);
            if strcmp(kind, 'mic')
                app.CardSource.FontColor = app.T.warn;
            else
                app.CardSource.FontColor = app.T.accent;
            end
        end

        function m = metaRow(app, id)
            %METAROW Ligne de métadonnées validée du morceau id ([] sinon).
            m = [];
            if isstruct(app.Index) && isfield(app.Index, 'metadata') && ...
                    id >= 1 && id <= height(app.Index.metadata) && ...
                    app.Index.metadata.valid(id)
                m = table2struct(app.Index.metadata(id, :));
            end
        end

        function t = titleText(~, r)
            %TITLETEXT Titre réel uniquement s'il provient des métadonnées.
            t = string(r.title);
            if isempty(t) || any(ismissing(t)) || strlength(t) == 0 || t == "inconnu"
                t = 'Titre non disponible';
            else
                t = char(t);
            end
        end

        function s = referenceName(app, id)
            %REFERENCENAME Nom du fichier de référence (pas un titre musical).
            s = 'Non disponible';
            if id >= 1 && id <= numel(app.AudioFiles)
                [~, n, e] = fileparts(app.AudioFiles{id});
                s = [n e];
            end
        end

        function addHistory(app, kind, label, r, elapsed)
            ttl = '';
            if isequal(r.is_known, true)
                ttl = sprintf('#%d', r.song_id);
                meta = app.metaRow(r.song_id);
                if ~isempty(meta) && strlength(meta.title) > 0
                    ttl = sprintf('#%d %s — %s', r.song_id, meta.title, AudioID.orDash(meta.artist));
                end
            end
            e = struct('time', char(datetime('now', 'Format', 'HH:mm:ss')), ...
                'kind', kind, 'source', AudioID.sourceText(kind, label, false), ...
                'outcome', AudioID.outcomeText(r), 'song_id', r.song_id, ...
                'title', ttl, 'score', r.score, 'score2', r.score2, ...
                'elapsed_ms', 1000 * elapsed);
            app.History(end + 1) = e;
            if numel(app.History) > app.MaxHistory
                app.History = app.History(end - app.MaxHistory + 1:end);
            end
            app.refreshHistory();
        end

        function refreshHistory(app)
            H = app.History(end:-1:1);          % plus récent en premier
            data = cell(numel(H), 7);
            for i = 1:numel(H)
                song = H(i).title;
                if isempty(song), song = '—'; end
                data(i, :) = {H(i).time, H(i).source, H(i).outcome, song, ...
                    H(i).score, H(i).score2, round(H(i).elapsed_ms)};
            end
            app.HistoryTable.Data = data;
        end
    end

    % =====================================================================
    %  Visualisations scientifiques (données issues de diag)
    % =====================================================================
    methods (Access = private)
        function plotAll(app)
            app.plotSignal();
            app.plotSpectrogram();
            app.plotConstellation();
            app.plotAlignment();
            app.updateSystemInfo();
        end

        function resetAnalysis(app, msg)
            %RESETANALYSIS Efface les graphiques de l'analyse précédente.
            axs = {app.AxSignal, app.AxSpec, app.AxConst, app.AxHist, app.AxCand};
            for i = 1:numel(axs)
                app.placeholder(axs{i}, msg);
            end
            for i = 1:numel(app.PageCaptions)
                app.PageCaptions(i).Text = '';
            end
            app.SpecInfoLabel.Text = '';
            app.HistNote.Text = '';
        end

        function plotSignal(app)
            %PLOTSIGNAL Signal d'entrée (mono, avant prétraitement).
            T = app.T;
            ax = app.AxSignal;
            s = app.LastSignal;
            app.clearAxes(ax);
            xm = mean(double(s.x), 2);
            n = numel(xm);
            dur = n / s.Fs;
            if n > 20000
                % Enveloppe min/max par blocs : tracé fidèle et léger
                B = ceil(n / 4000);
                nb = floor(n / B);
                X = reshape(xm(1:nb * B), B, nb);
                hi = max(X, [], 1);
                lo = min(X, [], 1);
                tc = ((0:nb - 1) * B + B / 2) / s.Fs;
                fill(ax, [tc, fliplr(tc)], [hi, fliplr(lo)], T.accent, ...
                    'EdgeColor', T.accent, 'LineWidth', 0.5);
            else
                plot(ax, (0:n - 1) / s.Fs, xm, 'Color', T.accent, 'LineWidth', 0.8);
            end
            xlim(ax, [0 dur]);
            a = max(abs(xm));
            if a > 0
                ylim(ax, 1.1 * [-a a]);
            end
            app.decorate(ax, 'Signal temporel', 'Temps (s)', 'Amplitude');
            app.PageCaptions(1).Text = sprintf( ...
                '%s · mono · %.1f kHz · %.2f s · signal d''entrée, avant prétraitement', ...
                AudioID.sourceText(s.kind, s.label, false), s.Fs / 1000, dur);
        end

        function plotSpectrogram(app)
            %PLOTSPECTROGRAM diag.S_dB, diag.t, diag.f (+ diag.peaks).
            T = app.T;
            ax = app.AxSpec;
            dg = app.LastDiag;
            c = app.Cfg;
            app.clearAxes(ax);
            if ~isfield(dg, 'S_dB') || isempty(dg.S_dB)
                app.placeholder(ax, 'Spectrogramme indisponible.');
                return;
            end
            S = dg.S_dB;
            vmax = max(S(:));
            imagesc(ax, dg.t, dg.f, S);
            axis(ax, 'xy');
            colormap(ax, T.cmap);
            ax.CLim = [vmax - app.DynRange, vmax];
            cb = colorbar(ax);
            cb.Color = T.muted;
            cb.Label.String = 'Magnitude (dB)';
            cb.Label.Color = T.muted;
            app.setLimits(ax, dg.t, [0 c.Fs / 2]);

            pk = dg.peaks;
            if app.PeaksCheck.Value && ~isempty(pk)
                hold(ax, 'on');
                xs = dg.t(pk(:, 1));
                ys = dg.f(pk(:, 2));
                scatter(ax, xs(:), ys(:), 16, T.peak, 'filled', ...
                    'MarkerEdgeColor', T.ink, 'LineWidth', 0.4);
                hold(ax, 'off');
            end
            app.decorate(ax, 'Spectrogramme (TFCT)', 'Temps (s)', 'Fréquence (Hz)');
            app.PageCaptions(2).Text = sprintf( ...
                '%s · signal prétraité à %d Hz · fenêtre de Hann N = %d, pas H = %d, Nfft = %d', ...
                AudioID.sourceText(app.LastSignal.kind, app.LastSignal.label, false), ...
                c.Fs, c.N, c.H, c.Nfft);
            app.SpecInfoLabel.Text = sprintf('%d trames × %d canaux · dynamique %d dB · %d maxima', ...
                numel(dg.t), numel(dg.f), app.DynRange, size(pk, 1));
        end

        function plotConstellation(app)
            %PLOTCONSTELLATION Constellation diag.peaks seule.
            T = app.T;
            ax = app.AxConst;
            dg = app.LastDiag;
            c = app.Cfg;
            app.clearAxes(ax);
            if ~isfield(dg, 'peaks') || isempty(dg.peaks)
                app.placeholder(ax, 'Aucun maximum spectral détecté.');
                app.PageCaptions(3).Text = '';
                return;
            end
            pk = dg.peaks;
            hold(ax, 'on');
            % Limites des bandes géométriques définies par cfg.peaks
            % (repère visuel uniquement, la sélection est faite par extract_peaks)
            P = c.peaks;
            edges = P.fmin * (P.fmax / P.fmin) .^ ((0:P.nbands) / P.nbands);
            lineCol = 0.55 * T.muted + 0.45 * T.plotbg;
            for e = edges
                yline(ax, e, ':', 'Color', lineCol, 'LineWidth', 0.8);
            end
            xs = dg.t(pk(:, 1));
            ys = dg.f(pk(:, 2));
            scatter(ax, xs(:), ys(:), 18, T.accent, 'filled', 'MarkerFaceAlpha', 0.9);
            hold(ax, 'off');
            app.setLimits(ax, dg.t, [0 c.Fs / 2]);
            app.decorate(ax, 'Constellation des maxima spectraux', 'Temps (s)', 'Fréquence (Hz)');
            app.PageCaptions(3).Text = sprintf(['%d maxima spectraux → %d empreintes ' ...
                '(paires de pics, fan-out %d) · pointillés : %d bandes de %g à %g Hz'], ...
                size(pk, 1), numel(dg.keys), c.hash.fanout, P.nbands, P.fmin, P.fmax);
        end

        function plotAlignment(app)
            %PLOTALIGNMENT Histogramme des décalages (diag.res) et candidats.
            T = app.T;
            ax = app.AxHist;
            ax2 = app.AxCand;
            dg = app.LastDiag;
            r = app.LastResult;
            c = app.Cfg;
            thr = c.decision.threshold;
            app.clearAxes(ax);
            app.clearAxes(ax2);

            res = dg.res;
            if isempty(res.song_id)
                app.placeholder(ax, 'Aucune empreinte commune : pas de vote d''alignement.');
                app.placeholder(ax2, 'Aucun candidat.');
                app.PageCaptions(4).Text = ['Aucune empreinte de la requête n''existe dans ' ...
                    'l''index.'];
                app.HistNote.Text = '';
                return;
            end

            known = isequal(r.is_known, true);
            if known
                pc = T.success;
            else
                pc = T.danger;
            end

            % Votes du meilleur candidat, regroupés par décalage (en trames)
            best = res.song_id(1);
            dt = c.H / c.Fs;
            d = res.delta_all(res.song_all == best);
            [u, ~, ic] = unique(d);
            cnt = accumarray(ic, 1);
            [cmax, imax] = max(cnt);
            yTop = 1.22 * max([cmax, thr], [], 'omitnan');

            bar(ax, u * dt, cnt, 1, 'FaceColor', T.accent2, 'EdgeColor', 'none');
            hold(ax, 'on');
            plot(ax, u(imax) * dt, cmax, 'v', 'MarkerSize', 9, ...
                'MarkerFaceColor', pc, 'MarkerEdgeColor', 'none');
            if known
                xline(ax, u(imax) * dt, '--', 'Color', pc, 'LineWidth', 1);
            end
            if ~isnan(thr)
                yline(ax, thr, '--', sprintf('Seuil = %g', thr), 'Color', T.warn, ...
                    'LineWidth', 1, 'LabelHorizontalAlignment', 'left', ...
                    'LabelVerticalAlignment', 'top', 'FontName', T.font, 'FontSize', 10);
            end
            hold(ax, 'off');
            ylim(ax, [0 yTop]);
            app.decorate(ax, 'Votes par décalage temporel', ...
                'Décalage Δ = t_référence − t_requête (s)', 'Nombre de votes');

            % Meilleurs candidats : S1, S2, ...
            n = min(5, numel(res.song_id));
            ids = res.song_id(1:n);
            sc = res.score(1:n);
            b = bar(ax2, 1:n, sc, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'none');
            cols = repmat(0.6 * T.accent2 + 0.4 * T.panel2, n, 1);
            cols(1, :) = pc;
            b.CData = cols;
            ax2.XTick = 1:n;
            ax2.XTickLabel = arrayfun(@(k) sprintf('#%d', k), ids, 'UniformOutput', false);
            if ~isnan(thr)
                hold(ax2, 'on');
                yline(ax2, thr, '--', 'Color', T.warn, 'LineWidth', 1);
                hold(ax2, 'off');
            end
            xlim(ax2, [0.4, n + 0.6]);
            ylim(ax2, [0 1.22 * max([sc(1), thr], [], 'omitnan')]);
            app.decorate(ax2, 'Meilleurs candidats', 'Morceau', 'Votes alignés');

            % Légende et note explicative (hors des axes pour éviter tout masquage)
            if known
                app.PageCaptions(4).Text = sprintf(['Morceau #%d : pic de %d votes à ' ...
                    'Δ = %.2f s (seuil %g) · 2e candidat : %d votes'], ...
                    best, cmax, u(imax) * dt, thr, r.score2);
                app.HistNote.Text = ['Un pic isolé signifie que de nombreuses empreintes ' ...
                    'partagent le même décalage : la requête est alignée temporellement ' ...
                    'sur ce morceau.'];
            else
                app.PageCaptions(4).Text = sprintf(['Meilleur candidat #%d (non retenu) : ' ...
                    '%d votes au maximum · seuil %g'], best, cmax, thr);
                app.HistNote.Text = ['Le maximum n''est pas retenu par la règle de décision : ' ...
                    'il n''est pas interprété comme une localisation temporelle.'];
            end
        end
    end

    % =====================================================================
    %  Informations système
    % =====================================================================
    methods (Access = private)
        function updateSystemInfo(app)
            v = repmat({'—'}, 1, numel(app.InfoValues));
            v{1} = char(app.StatusText.Text);
            v{2} = app.relPath(app.IndexFile);
            if app.IsLoaded
                c = app.Cfg;
                v{1} = sprintf('%s (chargée en %.1f s)', v{1}, app.LoadTime);
                v{3} = AudioID.fmtInt(double(app.Index.map.Count));
                if isempty(app.AudioFiles)
                    v{4} = 'Non disponible (audio_files absent)';
                else
                    v{4} = AudioID.fmtInt(numel(app.AudioFiles));
                end
                v{5} = sprintf('%d Hz', c.Fs);
                if isnan(c.decision.threshold)
                    v{6} = 'Non calibré (NaN)';
                else
                    v{6} = sprintf('%g votes (cfg sauvegardée)', c.decision.threshold);
                end
                v{7} = sprintf('Hann N = %d, H = %d, Nfft = %d · Δt = %.0f ms, Δf = %.2f Hz', ...
                    c.N, c.H, c.Nfft, 1000 * c.H / c.Fs, c.Fs / c.Nfft);
                v{8} = sprintf('%g–%g Hz, %d bandes, %d pics/bande/s', ...
                    c.peaks.fmin, c.peaks.fmax, c.peaks.nbands, c.peaks.per_band_per_s);
                v{9} = sprintf('Paires de pics, Δt %g–%g s, fan-out %d', ...
                    c.hash.dt_min, c.hash.dt_max, c.hash.fanout);
                v{10} = app.metaSummary(false);
            end
            v{11} = sprintf('%d', app.LoadCount);
            v{12} = sprintf('%d', numel(app.History));
            v{13} = version;
            for i = 1:numel(app.InfoValues)
                app.InfoValues(i).Text = v{i};
                AudioID.setIfProp(app.InfoValues(i), 'Tooltip', v{i});
            end

            if ~isfile(app.IndexFile)
                notes = strsplit(app.rebuildHelp(), newline)';
            elseif app.IsLoaded && isnan(app.Cfg.decision.threshold)
                notes = strsplit(app.uncalibratedHelp(), newline)';
            else
                notes = { ...
                    'Lecture des scores'; ...
                    ['S1 : nombre maximal d''empreintes de la requête partageant le même décalage ' ...
                    'temporel avec le meilleur morceau (pic de l''histogramme d''alignement).']; ...
                    'S2 : même grandeur pour le deuxième candidat.'; ...
                    ['Ces scores sont des nombres de votes, pas des probabilités. La décision ' ...
                    '« reconnu » correspond à S1 ≥ seuil, seuil calibré expérimentalement et ' ...
                    'sauvegardé dans cfg.decision.threshold.']; ''; ...
                    ['Temps de traitement : durée de l''appel à recognize_query (prétraitement, ' ...
                    'spectrogramme, pics, empreintes, recherche, alignement, décision), hors ' ...
                    'lecture du fichier et hors chargement de l''index.']};
            end
            mi = app.MetaInfo;
            if app.IsLoaded && ~isempty(mi)
                metaNotes = {''; 'Métadonnées'; sprintf('Fichier : %s', app.relPath(mi.file)); ...
                    sprintf('État : %s.', app.metaSummary(false)); ...
                    ['Attachées en mémoire à index.metadata (aucun fichier MAT écrit). ' ...
                    'Contrôles : song_id unique, fma_id et nom de fichier identiques à audio_files.']};
                if ~isempty(mi.issues)
                    metaNotes = [metaNotes; cellfun(@(s) ['- ' s], mi.issues(:), ...
                        'UniformOutput', false)];
                end
                notes = [notes(:); metaNotes];
            end
            app.InfoNotes.Value = notes;
        end
    end

    % =====================================================================
    %  Utilitaires
    % =====================================================================
    methods (Access = private)
        function [x, Fs] = readAudio(~, filename)
            if ~isfile(filename)
                error('AudioID:invalidFile', 'Fichier introuvable : %s', filename);
            end
            try
                [x, Fs] = audioread(filename);
            catch ME
                error('AudioID:invalidFile', ['Impossible de lire ce fichier audio.\n' ...
                    'Formats acceptés : ceux pris en charge par audioread ' ...
                    '(WAV, FLAC, MP3, M4A, OGG, AIFF…).\n\nDétail : %s'], ME.message);
            end
        end

        function validateSignal(app, x, Fs)
            if isempty(x) || ~isnumeric(x)
                error('AudioID:invalidSignal', 'Le signal audio est vide ou invalide.');
            end
            if ~isscalar(Fs) || ~isfinite(Fs) || Fs <= 0
                error('AudioID:invalidSignal', 'Fréquence d''échantillonnage invalide.');
            end
            if any(~isfinite(x(:)))
                error('AudioID:invalidSignal', ...
                    'Le signal contient des valeurs non finies (NaN ou Inf).');
            end
            dur = size(x, 1) / Fs;
            if dur < app.MinDuration
                error('AudioID:tooShort', ['Extrait trop court (%.2f s). Durée minimale : ' ...
                    '%.0f s. Les expériences utilisent des extraits de 3, 5 et 10 s.'], ...
                    dur, app.MinDuration);
            end
            if max(abs(double(x(:)))) < 1e-4
                error('AudioID:silent', ...
                    'Le signal est silencieux : aucune empreinte exploitable.');
            end
        end

        function runGuarded(app, fn)
            %RUNGUARDED Exécute une reconnaissance en verrouillant l'interface.
            app.setBusy(true);
            try
                fn();
            catch ME
                if isvalid(app)
                    app.resetResultCard('Analyse impossible', ME.message, app.T.danger);
                    app.alert(ME.message, 'Reconnaissance impossible');
                end
            end
            if isvalid(app)
                app.setBusy(false);
            end
        end

        function setBusy(app, tf)
            app.Busy = tf;
            if tf
                app.CardStatus.Text = 'Analyse en cours…';
                app.CardStatus.FontColor = app.T.accent;
                app.CardStripe.BackgroundColor = app.T.accent;
                app.CardTitle.Text = '';
                app.CardSubtitle.Text = '';
                app.CardDetail.Text = '';
            end
            app.refreshControls();
            drawnow;
        end

        function refreshControls(app)
            recording = app.isRecording();
            idle = ~app.Busy && ~recording;
            app.BrowseButton.Enable = AudioID.onoff(idle);
            app.IdentifyButton.Enable = AudioID.onoff(idle && app.IsLoaded && ~isempty(app.CurrentX));
            app.RecordButton.Enable = AudioID.onoff(app.IsLoaded && (~app.Busy || recording));
            for i = 1:numel(app.DurButtons)
                app.DurButtons(i).Enable = AudioID.onoff(idle);
            end
            app.LoadOtherButton.Enable = AudioID.onoff(idle);
            app.ExportButton.Enable = AudioID.onoff(~recording);
        end

        function tf = isRecording(app)
            tf = false;
            try
                tf = ~isempty(app.Recorder) && isrecording(app.Recorder);
            catch
            end
        end

        function setProgress(app, p)
            %SETPROGRESS Barre de progression : poids relatifs des deux cellules.
            p = max(0, min(1, p));
            if p <= 0
                app.RecBarGrid.ColumnWidth = {0, '1x'};
            elseif p >= 1
                app.RecBarGrid.ColumnWidth = {'1x', 0};
            else
                w = round(1000 * p);
                app.RecBarGrid.ColumnWidth = {sprintf('%dx', w), sprintf('%dx', 1000 - w)};
            end
        end

        function setLibraryStatus(app, state)
            T = app.T;
            switch state
                case 'loading'
                    col = T.warn;   txt = 'Chargement…';
                case 'ready'
                    col = T.success; txt = 'Bibliothèque prête';
                case 'uncalibrated'
                    col = T.warn;   txt = 'Seuil non calibré';
                case 'missing'
                    col = T.danger; txt = 'Index introuvable';
                otherwise
                    col = T.danger; txt = 'Erreur de chargement';
            end
            app.StatusDot.FontColor = col;
            app.StatusText.Text = txt;
            app.IndexPathLabel.Text = app.relPath(app.IndexFile);
            AudioID.setIfProp(app.IndexPathLabel, 'Tooltip', app.IndexFile);
        end

        function showPage(app, k)
            for i = 1:numel(app.Pages)
                on = (i == k);
                app.Pages(i).Visible = AudioID.onoff(on);
                app.NavButtons(i).Value = on;
                if on
                    app.NavButtons(i).BackgroundColor = app.T.accent2;
                    app.NavButtons(i).FontColor = [1 1 1];
                else
                    app.NavButtons(i).BackgroundColor = app.T.panel2;
                    app.NavButtons(i).FontColor = app.T.muted;
                end
            end
        end

        function clearSelection(app)
            app.CurrentFile = '';
            app.CurrentX = [];
            app.CurrentFs = [];
            app.CurrentInfo = '';
            app.FileNameLabel.Text = 'Aucun fichier sélectionné';
            AudioID.setIfProp(app.FileNameLabel, 'Tooltip', '');
            app.FileInfoLabel.Text = 'Fichier rejeté, choisissez-en un autre.';
            app.FileInfoLabel.FontColor = app.T.muted;
            app.refreshControls();
        end

        function clearAxes(~, ax)
            colorbar(ax, 'off');
            legend(ax, 'off');
            cla(ax);
            hold(ax, 'off');
            ax.XTickMode = 'auto';
            ax.YTickMode = 'auto';
            ax.XTickLabelMode = 'auto';
            ax.YTickLabelMode = 'auto';
            ax.XLimMode = 'auto';
            ax.YLimMode = 'auto';
            ax.YDir = 'normal';
        end

        function placeholder(app, ax, msg)
            app.clearAxes(ax);
            ax.XLim = [0 1];
            ax.YLim = [0 1];
            ax.XTick = [];
            ax.YTick = [];
            ax.XColor = 'none';
            ax.YColor = 'none';
            grid(ax, 'off');
            title(ax, '');
            xlabel(ax, '');
            ylabel(ax, '');
            text(ax, 0.5, 0.5, msg, 'HorizontalAlignment', 'center', ...
                'Color', app.T.muted, 'FontName', app.T.font, 'FontSize', 13, ...
                'Interpreter', 'none');
        end

        function decorate(app, ax, ttl, xl, yl)
            %DECORATE Titre court + axes (les détails vont dans la légende de page).
            T = app.T;
            ax.XColor = T.muted;
            ax.YColor = T.muted;
            title(ax, ttl, 'Color', T.text, 'FontName', T.font, 'FontSize', 13, ...
                'FontWeight', 'bold', 'Interpreter', 'none');
            xlabel(ax, xl, 'Color', T.muted, 'FontName', T.font, 'Interpreter', 'none');
            ylabel(ax, yl, 'Color', T.muted, 'FontName', T.font, 'Interpreter', 'none');
            grid(ax, 'on');
            ax.Layer = 'top';
        end

        function setLimits(~, ax, t, yl)
            if numel(t) > 1
                xlim(ax, [min(t) max(t)]);
            end
            ylim(ax, yl);
        end

        function tf = isShown(app)
            tf = ~isempty(app.UIFigure) && isvalid(app.UIFigure) && ...
                strcmp(char(app.UIFigure.Visible), 'on');
        end

        function focus(app)
            if app.isShown()
                figure(app.UIFigure);
            end
        end

        function alert(app, msg, ttl, icon)
            %ALERT Boîte de dialogue non bloquante ; console si fenêtre masquée.
            if nargin < 4, icon = 'error'; end
            if app.isShown()
                uialert(app.UIFigure, msg, ttl, 'Icon', icon);
            else
                fprintf('[AudioID] %s : %s\n', ttl, msg);
            end
        end

        function closeDialog(~, dlg)
            try
                if ~isempty(dlg) && isvalid(dlg)
                    close(dlg);
                end
            catch
            end
        end

        function s = relPath(app, p)
            s = char(p);
            if startsWith(s, [app.Root filesep])
                s = s(numel(app.Root) + 2:end);
            end
        end
    end

    methods (Static, Access = private)
        function T = theme()
            %THEME Palette sombre bleu nuit, accents bleu électrique et cyan.
            T.bg      = [0.031 0.043 0.075];
            T.panel   = [0.063 0.086 0.137];
            T.panel2  = [0.098 0.133 0.204];
            T.plotbg  = [0.024 0.035 0.063];
            T.text    = [0.925 0.945 0.980];
            T.muted   = [0.560 0.625 0.725];
            T.ink     = [0.020 0.040 0.080];
            T.accent  = [0.000 0.800 1.000];   % cyan
            T.accent2 = [0.180 0.420 1.000];   % bleu électrique
            T.success = [0.220 0.860 0.560];
            T.danger  = [1.000 0.420 0.460];
            T.warn    = [1.000 0.760 0.280];
            T.peak    = [1.000 0.760 0.280];   % maxima : contraste fort sur la carte bleue
            T.font    = 'Helvetica Neue';
            try
                if ~any(strcmp(listfonts, T.font))
                    T.font = 'Helvetica';
                end
            catch
                T.font = 'Helvetica';
            end
            % Carte de couleurs perceptuellement croissante (sombre -> clair)
            k = [0.020 0.030 0.070; 0.050 0.100 0.300; 0.100 0.300 0.750; ...
                 0.000 0.750 1.000; 0.850 0.970 1.000];
            T.cmap = interp1(linspace(0, 1, size(k, 1)), k, linspace(0, 1, 256));
        end

        function c = findColumn(Tm, key)
            %FINDCOLUMN Nom de colonne correspondant à key (insensible à la casse,
            %   tolérant à un préfixe parasite tel qu'un BOM UTF-8).
            names = Tm.Properties.VariableNames;
            low = lower(names);
            c = '';
            i = find(strcmp(low, key), 1);
            if isempty(i)
                i = find(endsWith(low, key), 1);
            end
            if ~isempty(i)
                c = names{i};
            end
        end

        function s = cleanText(Tm, c)
            %CLEANTEXT Colonne texte nettoyée (valeurs manquantes -> "").
            n = height(Tm);
            if isempty(c)
                s = strings(n, 1);
                return;
            end
            s = string(Tm.(c));
            s(ismissing(s)) = "";
            s = strtrim(s(:));
        end

        function s = listIds(ids)
            ids = sort(ids(:)');
            if numel(ids) > 8
                s = [sprintf('%d, ', ids(1:8)) sprintf('… (%d au total)', numel(ids))];
            else
                s = strjoin(arrayfun(@(k) sprintf('%d', k), ids, 'UniformOutput', false), ', ');
            end
        end

        function s = sourceText(kind, label, upperCase)
            switch kind
                case 'mic'
                    s = sprintf('Microphone · %s', label);
                case 'file'
                    s = sprintf('Fichier · %s', label);
                otherwise
                    s = sprintf('Signal · %s', label);
            end
            if upperCase
                s = ['SOURCE  ' upper(s)];
            end
        end

        function s = orDash(v)
            v = string(v);
            if isempty(v) || any(ismissing(v)) || strlength(v) == 0
                s = 'non renseigné';
            else
                s = char(v);
            end
        end

        function s = onoff(tf)
            if tf
                s = 'on';
            else
                s = 'off';
            end
        end

        function s = outcomeText(r)
            if isnan(r.is_known)
                s = 'Indéterminé';
            elseif r.is_known
                s = 'Reconnu';
            else
                s = 'Non reconnu';
            end
        end

        function s = fmtDuration(d)
            if d < 60
                s = sprintf('%.2f s', d);
            else
                s = sprintf('%d min %04.1f s', floor(d / 60), mod(d, 60));
            end
        end

        function s = fmtInt(n)
            s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1 ');
        end

        function setIfProp(obj, name, value)
            if isprop(obj, name)
                obj.(name) = value;
            end
        end
    end
end
