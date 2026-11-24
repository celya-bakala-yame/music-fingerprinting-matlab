project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

%% Creation des requetes de calibration et evaluation

rng(2026);

durations = [3 5 10];
N_per_duration = 20;

sets = {'calibration', 'evaluation'};

for s = 1:2

    set_name = sets{s};

    output_dir = fullfile('data', 'queries', set_name);

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    query_id = 0;
    rows = cell(120, 5);

    for d = 1:numel(durations)

        Tq = durations(d);

        for category = 1:2

            for i = 1:N_per_duration

                query_id = query_id + 1;

                if category == 1

                    song_id = randi(numel(audio_files));
                    filename = audio_files{song_id};

                else

                    song_id = 0;

                    file_id = 100 + (s-1)*60 ...
                        + (d-1)*20 + i;

                    filename = fullfile( ...
                        files(file_id).folder, ...
                        files(file_id).name);

                end

                [x, Fs] = preprocess_audio(filename, cfg);

                L = Tq * Fs;

                % Separation temporelle des extraits
                if s == 1
                    debut = randi(floor(length(x)/2)-L+1);
                else
                    debut = randi([floor(length(x)/2)+1, ...
                        length(x)-L+1]);
                end

                query = x(debut:debut+L-1);

                start_s = (debut-1)/Fs;

                query_file = fullfile(output_dir, ...
                    sprintf('query_%03d.wav', query_id));

                audiowrite(query_file, query, Fs);

                rows(query_id,:) = {query_id, ...
                    query_file, song_id, start_s, Tq};

            end
        end
    end

    T = cell2table(rows, 'VariableNames', ...
        {'query_id', 'file', 'true_song_id', ...
        'start_s', 'duration_s'});

    writetable(T, fullfile('data', 'queries', ...
        [set_name '_list.csv']));

    fprintf('%s : %d requetes creees\n', ...
        set_name, height(T));

end

fprintf('\nCreation des requetes terminee.\n');