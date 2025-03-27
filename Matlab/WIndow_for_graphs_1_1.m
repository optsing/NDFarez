function analyze_frf_files()
    % Главная функция запуска программы

    % Создаем окно для выбора файлов
    [filenames, pathname] = uigetfile('*.frf', 'Выберите файлы .frf', 'MultiSelect', 'on');
    if isequal(filenames, 0)
        disp('Файлы не были выбраны.');
        return;
    end

    % Преобразуем в ячейку, если выбран только один файл
    if ~iscell(filenames)
        filenames = {filenames};
    end

    % Инициализация массивов для хранения данных
    SizeStandard_data = {};
    GenLib_data = {};
    Sizes = {};
    Concentrations = {};
    ReleaseTimes = {};
    SizeStandard_titles = {};
    GenLib_titles = {};

    % Обработка каждого файла
    for i = 1:length(filenames)
        file_path = fullfile(pathname, filenames{i});
        try
            % Чтение и парсинг XML-файла
            tree = xmlread(file_path);
            raw_title = char(tree.getElementsByTagName('Title').item(0).getTextContent());
            type_node = tree.getElementsByTagName('Type');
    
            if type_node.getLength() > 0
                type_value = char(type_node.item(0).getTextContent());
    
                if strcmp(type_value, 'AllelicLadder')
                    % Файл содержит AllelicLadder (SizeStandard)
                    size_standard_node = tree.getElementsByTagName('Sizes');
                    if size_standard_node.getLength() > 0
                        SizeStandard_titles{end+1} = raw_title;
    
                        % Извлекаем данные из <Sizes>
                        sizes = [];
                        concentrations = [];
                        release_times = [];
    
                        size_elements = size_standard_node.item(0).getElementsByTagName('double');
                        for j = 0:size_elements.getLength()-1
                            size_elem = size_elements.item(j);
                            sizes(end+1) = str2double(size_elem.getTextContent());
                            concentrations(end+1) = str2double(size_elem.getAttribute('Concentration'));
    
                            % Преобразование ReleaseTime в секунды
                            release_time_str = char(size_elem.getAttribute('ReleaseTime'));
                            time_parts = sscanf(release_time_str, '%d:%d:%d');
                            release_times(end+1) = time_parts(1) * 3600 + time_parts(2) * 60 + time_parts(3);
                        end
    
                        % Используем обновленную функцию для SizeStandard_data
                        SizeStandard_data{end+1} = extract_filtered_int_values(tree.getElementsByTagName('Point'));
                        Sizes{end+1} = sizes;
                        Concentrations{end+1} = concentrations;
                        ReleaseTimes{end+1} = release_times;
                    end
    
                elseif strcmp(type_value, 'Sample')
                    % Файл содержит GenLib
                    GenLib_titles{end+1} = ['GenLib_', raw_title];
                    GenLib_data{end+1} = extract_filtered_int_values(tree.getElementsByTagName('Point'));
                end
            end
    
        catch ME
            disp(['Ошибка при обработке файла ', filenames{i}, ': ', ME.message]);
        end
    end
    
    % Функция для извлечения int-значений, исключая единицы
    function values = extract_filtered_int_values(point_nodes)
        values = [];
    
        for i = 0:point_nodes.getLength()-1
            data_node = point_nodes.item(i).getElementsByTagName('Data');
            if data_node.getLength() > 0
                int_nodes = data_node.item(0).getElementsByTagName('int');
    
                for j = 0:int_nodes.getLength()-1
                    val = str2double(int_nodes.item(j).getTextContent());
                    if val ~= 1  % Игнорируем единицы
                        values(end+1) = val;
                    end
                end
            end
        end
    end


    % Создаем GUI
    create_gui(SizeStandard_titles, GenLib_titles, SizeStandard_data, GenLib_data, Sizes, Concentrations, ReleaseTimes);
end

function int_values = extract_int_values(points_node)
    % Извлечение значений <int> из узла <Point>
    int_values = [];
    for i = 0:points_node.getLength()-1
        point_data = points_node.item(i).getElementsByTagName('Data').item(0);
        ints = point_data.getElementsByTagName('int');
        if ints.getLength() == 1
            int_values(end+1) = str2double(char(ints.item(0).getTextContent()));
        elseif ints.getLength() > 1
            int_values(end+1) = str2double(char(ints.item(ints.getLength()-1).getTextContent()));
        end
    end
end

function values_array = extract_values(node, tag_name)
    % Извлечение значений <Sizes>, <Сoncentrations>, <ReleaseTimes>
    values_array = [];
    elements = node.getElementsByTagName(tag_name).item(0).getElementsByTagName('double');
    for i = 0:elements.getLength()-1
        values_array(end+1) = str2double(char(elements.item(i).getTextContent()));
    end
end

function create_gui(SizeStandard_titles, GenLib_titles, SizeStandard_data, GenLib_data, Sizes, Concentrations, ReleaseTimes)
    % Создание GUI для отображения графиков

    % Основное окно
    f = figure('Name', 'Обработка файлов FRF', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.8]);

    % Заголовки
    uicontrol('Style', 'text', 'String', 'Стандарты длин', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.9, 0.15, 0.05]);
    uicontrol('Style', 'text', 'String', 'Геномные библиотеки', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.4, 0.15, 0.05]);

    % --- Панель для стандартов длин ---
    max_visible_standard = 6; % Количество видимых радиокнопок
    standard_buttons_group = uibuttongroup(f, 'Units', 'normalized', 'Position', [0.02, 0.6, 0.13, 0.3]);

    % Ползунок для стандартов длин
    num_standard_items = length(SizeStandard_titles);
    max_standard_index = max(0, num_standard_items - max_visible_standard);
    standard_scroll = uicontrol(f, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.15, 0.6, 0.01, 0.3], ...
        'Min', 0, 'Max', max_standard_index, ...
        'Value', max_standard_index, ... % Ползунок в верхнем положении
        'SliderStep', compute_slider_step(num_standard_items, max_visible_standard), ...
        'Callback', @(src, event) update_standard_list());

    % --- Панель для геномных библиотек ---
    max_visible_genlib = 6; % Количество видимых кнопок
    genlib_buttons_group = uipanel(f, 'Units', 'normalized', 'Position', [0.02, 0.1, 0.13, 0.3]);

    % Ползунок для геномных библиотек
    num_genlib_items = length(GenLib_titles);
    max_genlib_index = max(0, num_genlib_items - max_visible_genlib);
    genlib_scroll = uicontrol(f, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.15, 0.1, 0.01, 0.3], ...
        'Min', 0, 'Max', max_genlib_index, ...
        'Value', max_genlib_index, ... % Ползунок в верхнем положении
        'SliderStep', compute_slider_step(num_genlib_items, max_visible_genlib), ...
        'Callback', @(src, event) update_genlib_list());

    % Начальная отрисовка панелей
    draw_standard_list(1);
    draw_genlib_list(1);

    % --- Окно для графика стандартов длин ---
    axes_standard = axes('Units', 'normalized', 'Position', [0.2, 0.6, 0.75, 0.35]);
    title(axes_standard, 'График стандарта длин');

    % --- Окно для графика геномных библиотек ---
    axes_genlib = axes('Units', 'normalized', 'Position', [0.2, 0.1, 0.75, 0.35]);
    title(axes_genlib, 'График геномной библиотеки');

    % --- Кнопка "Анализ" ---
    uicontrol('Style', 'pushbutton', 'String', 'Анализ', ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'Units', 'normalized', 'Position', [0.85, 0.02, 0.1, 0.05], ...
        'Callback', @(src, event) analyze_data());

    % --- Вложенные функции ---
    function step = compute_slider_step(total_items, visible_items)
        % Вычисление шага ползунка
        if total_items <= visible_items
            step = [1, 1]; % Ползунок отключен
        else
            step = [1 / (total_items - visible_items), 1 / (total_items - visible_items)];
        end
    end

    function draw_standard_list(start_index)
        % Очистка панели
        delete(allchild(standard_buttons_group));
        % Отрисовка радиокнопок
        end_index = min(start_index + max_visible_standard - 1, length(SizeStandard_titles));
        for i = start_index:end_index
            uicontrol(standard_buttons_group, 'Style', 'radiobutton', ...
                'String', SizeStandard_titles{i}, ...
                'Units', 'normalized', 'Position', [0.05, 1 - (i - start_index + 1) * 0.15, 0.9, 0.1], ...
                'FontSize', 10, ...
                'Callback', @(src, event) plot_size_standard(i));
        end
    end

    function update_standard_list()
        % Обновление списка стандартов длин при перемещении ползунка
        current_value = get(standard_scroll, 'Value');
        start_index = max_standard_index - round(current_value) + 1;
        draw_standard_list(start_index);
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% 1. выбирает только первые шесть
    %% 2. сохраняет выбор из предыдущей работы
    %% 3. отображает проанализированные файлы в обратном порядке
    function draw_genlib_list(start_index)
        persistent genlib_selections;
        
        if isempty(genlib_selections)
            % Инициализация состояния чекбоксов (все выключены)
            genlib_selections = false(1, length(GenLib_titles));
        end

        % Очистка панели
        delete(allchild(genlib_buttons_group));
        
        % Отрисовка чекбокса "Выбрать всё"
        all_cb = uicontrol(genlib_buttons_group, 'Style', 'checkbox', ...
            'Units', 'normalized', 'Position', [0.02, 0.9, 0.6, 0.1], ...
            'String', 'Выбрать всё', ...
            'FontSize', 10, ...
            'Value', all(genlib_selections), ... % Проверка, выбраны ли все элементы
            'Callback', @(src, event) select_all_genlibs(get(src, 'Value')));

        % Расчет высоты и позиций элементов
        num_visible = max_visible_genlib;
        element_height = 0.8 / num_visible; % Общая высота панели - 0.8 (без чекбокса)
        gap = 0.02; % Зазор между элементами
    
        % Отрисовка чекбоксов и кнопок для каждой библиотеки
        end_index = min(start_index + num_visible - 1, length(GenLib_titles));
        for i = start_index:end_index
            % Индекс текущего элемента
            local_idx = i - start_index + 1;
    
            % Вычисление вертикальной позиции
            current_y = 0.925 - local_idx * (element_height + gap);
    
            % Чекбокс для выбора
            checkbox = uicontrol(genlib_buttons_group, 'Style', 'checkbox', ...
                'Units', 'normalized', 'Position', [0.05, current_y, 0.35, element_height], ...
                'Value', genlib_selections(i), ...
                'Callback', @(src, event) update_genlib_selection(i, get(src, 'Value')));
    
            % Кнопка для отображения графика
            uicontrol(genlib_buttons_group, 'Style', 'pushbutton', ...
                'String', GenLib_titles{i}, ...
                'Units', 'normalized', 'Position', [0.25, current_y, 0.55, element_height], ...
                'FontSize', 10, ...
                'Callback', @(src, event) plot_genlib(i));
            end
        
            % --- Вложенные функции ---
            function select_all_genlibs(value)
                % Выбор всех элементов
                genlib_selections(:) = value; % Устанавливаем состояние для всех
                draw_genlib_list(start_index); % Перерисовка списка
            end
        
            function update_genlib_selection(idx, value)
                % Обновление состояния конкретного чекбокса
                genlib_selections(idx) = value;
                
                % Снимаем галочку "Выбрать всё", если выбрано не всё
                set(all_cb, 'Value', all(genlib_selections));
            end         
        end
 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
    function update_genlib_list()
        % Обновление списка геномных библиотек при перемещении ползунка
        current_value = get(genlib_scroll, 'Value');
        start_index = max_genlib_index - round(current_value) + 1;
        draw_genlib_list(start_index);
    end

    function plot_size_standard(idx)
        plot(axes_standard, SizeStandard_data{idx}, 'LineWidth', 2);
        title(axes_standard, SizeStandard_titles{idx});
    end

    function plot_genlib(idx)
        plot(axes_genlib, GenLib_data{idx}, 'LineWidth', 2);
        title(axes_genlib, GenLib_titles{idx});
    end

    function check_genlib(idx)
        disp(['Выбрана библиотека: ', GenLib_titles{idx}]);
    end

    function analyze_data()
        % Нахождение выбранного стандарта длин
        selected_radio = findobj(standard_buttons_group.Children, 'Value', 1);
        if isempty(selected_radio)
            errordlg('Выберите стандарт длины для анализа!', 'Ошибка');
            return;
        end
    
        % Нахождение индекса выбранной радиокнопки
        selected_idx = find(standard_buttons_group.Children == selected_radio);
        idx = length(standard_buttons_group.Children) - selected_idx + 1; % Переворот из-за обратного порядка
    
        % Проверка наличия данных
        if idx > length(SizeStandard_data) || isempty(SizeStandard_data{idx})
            errordlg('Нет данных для выбранного стандарта длины.', 'Ошибка');
            return;
        end
    
        % Извлечение данных стандарта длин
        data = SizeStandard_data{idx};
        sizes = Sizes{idx};
        concentrations = Concentrations{idx};
        release_times = ReleaseTimes{idx};
        data = data'; % Транспонирование данных
    
        % Нахождение выбранных чекбоксов геномных библиотек
        all_checkboxes = findobj(genlib_buttons_group.Children, 'Style', 'checkbox');
        selected_checkboxes = all_checkboxes([all_checkboxes.Value] == 1);
    
        % Если не выбраны геномные библиотеки, показать ошибку
        if isempty(selected_checkboxes)
            errordlg('Выберите хотя бы одну геномную библиотеку!', 'Ошибка');
            return;
        end
    
        % Собираем индексы выбранных чекбоксов
        selected_indices = [];
        for i = 1:length(selected_checkboxes)
            checkbox = selected_checkboxes(i);
            checkbox_idx = find(all_checkboxes == checkbox);
            actual_idx = length(all_checkboxes) - checkbox_idx; % Переворот порядка
            if actual_idx > 0 && actual_idx <= length(GenLib_titles)
                selected_indices(end + 1) = actual_idx;
            end
        end
    
        % Проверка корректности индексов
        if any(selected_indices > length(GenLib_titles)) || isempty(selected_indices)
            errordlg('Некорректный выбор геномных библиотек.', 'Ошибка');
            return;
        end
    
        % Оставляем только выбранные библиотеки
        GenLib_titles = GenLib_titles(selected_indices);
        GenLib_data = GenLib_data(selected_indices);
    
        % Вызов функции анализа
        [peak, led_area, led_conc, ZrRef, SD_molarity] = SDFind(data, sizes, release_times, concentrations);
     
        % Предполагается, что GenLib_data содержит отобранные массивы данных
        results = {}; % Ячейка для хранения результатов
        for i = 1:length(GenLib_data)
            % Вызов функции GLFind для текущей геномной библиотеки
            [t_main, denoised_data, st_peaks, st_length, t_unrecognized_peaks, unrecognized_peaks, ...
                lib_length, LibPeakLocations, t_final_locations, final_filtered_below_threshold_locations, ...
                hpx, unr, stp, mainCorr, GLAreas, peaksCorr, library_peaks, areaCorr, molarity, ...
                maxLibPeak, maxLibValue, totalLibArea, totalLibConc, totalLibMolarity, ...
                x_fill, y_fill, x_Lib_fill, y_Lib_fill] = ...
                GLFind_1_3(GenLib_data{i}, peak, sizes, concentrations);
            
            % Сохранение результатов в структуру
            results{i} = struct( ...
                't_main', t_main, ...
                'denoised_data', denoised_data, ...
                'st_peaks', st_peaks, ...
                'st_length', st_length, ...
                't_unrecognized_peaks', t_unrecognized_peaks, ...
                'unrecognized_peaks', unrecognized_peaks, ...
                'lib_length', lib_length, ...
                'LibPeakLocations', LibPeakLocations, ...
                't_final_locations', t_final_locations, ...
                'final_filtered_below_threshold_locations', final_filtered_below_threshold_locations, ...
                'hpx', hpx, ...
                'unr', unr, ...
                'stp', stp, ...
                'mainCorr', mainCorr, ...
                'GLAreas', GLAreas, ...
                'peaksCorr', peaksCorr, ... 
                'library_peaks', library_peaks, ...  
                'areaCorr', areaCorr, ...
                'molarity', molarity, ...
                'maxLibPeak', maxLibPeak, ...
                'maxLibValue', maxLibValue, ...
                'totalLibArea', totalLibArea, ...
                'totalLibConc', totalLibConc, ...
                'totalLibMolarity', totalLibMolarity, ...
                'x_fill', x_fill, ...
                'y_fill', y_fill, ...
                'x_Lib_fill', x_Lib_fill, ...
                'y_Lib_fill', y_Lib_fill ...
            );
        end
        
        % Новый интерфейс для отображения результатов
        show_results(SizeStandard_titles{idx}, GenLib_titles, GenLib_data, ZrRef, peak, sizes, ...
            results, concentrations, led_area, peaksCorr, library_peaks, areaCorr, GLAreas, molarity, SD_molarity, ...
            maxLibPeak, maxLibValue, totalLibArea, totalLibConc, totalLibMolarity, x_fill, y_fill, x_Lib_fill, y_Lib_fill);
        close(f); % Закрытие текущего окна
    end

    % Ожидаем закрытия окна
    waitfor(f);
end

function show_results(SizeStandard_titles, GenLib_titles, GenLib_data, ZrRef, peak, sizes, ...
    results, concentrations, led_area, peaksCorr, library_peaks, areaCorr, GLAreas, molarity, SD_molarity, ...
    maxLibPeak, maxLibValue, totalLibArea, totalLibConc, totalLibMolarity, x_fill, y_fill, x_Lib_fill, y_Lib_fill)

    % Основное окно
    fig = figure('Name', 'Обработка файлов FRF', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.8]);

    % Панель для стандартов длин
    uicontrol('Style', 'text', 'String', 'Стандарты длин', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.9, 0.15, 0.05]);
    standard_list = uicontrol('Style', 'listbox', 'String', SizeStandard_titles, ...
        'Units', 'normalized', 'Position', [0.02, 0.6, 0.15, 0.3], ...
        'Callback', @plot_size_standard, ...
        'FontSize', 12);
    
    % Панель для геномных библиотек
    uicontrol('Style', 'text', 'String', 'Геномные библиотеки', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02, 0.4, 0.15, 0.05]);
    genlib_list = uicontrol('Style', 'listbox', 'String', GenLib_titles, ...
        'Units', 'normalized', 'Position', [0.02, 0.1, 0.15, 0.3], ...
        'Callback', @plot_genlib, ...
        'FontSize', 12);

    % Окно для графика стандарта длин
    axes_standard = axes('Units', 'normalized', 'Position', [0.2, 0.6, 0.75, 0.35]);
    title(axes_standard, 'График стандарта длин');

    % Окно для графика геномных библиотек
    axes_genlib = axes('Units', 'normalized', 'Position', [0.2, 0.1, 0.75, 0.35]);
    title(axes_genlib, 'График геномной библиотеки');

    % Кнопка "Отчёт" для стандарта длин
    uicontrol('Style', 'pushbutton', 'String', 'Отчёт', ...
        'Units', 'normalized', 'Position', [0.86, 0.53, 0.09, 0.04], ...
        'FontSize', 14, 'Callback', @show_calibration_curve_and_table);

    % Кнопка "Отчёт" для геномной библиотеки
    uicontrol('Style', 'pushbutton', 'String', 'Отчёт', ...
        'Units', 'normalized', 'Position', [0.86, 0.03, 0.09, 0.04], ...
        'FontSize', 14, 'Callback', @show_genlib_report);

    % Построение графиков стандарта длин и геномной библиотеки при загрузке
    plot_size_standard();
    plot_genlib();

    function plot_size_standard(~, ~)
        % График анализа стандарта длин
        pks = ZrRef(peak);
        plot(axes_standard, ZrRef, 'LineWidth', 2);
        hold(axes_standard, 'on');
        x = (1: length(ZrRef))';
    
        % Добавление рисок и значений на ось x
        xticks(axes_standard, peak);
        xticklabels(axes_standard, string(sizes));
        set(axes_standard, 'FontSize', 16); % Увеличенный размер шрифта для оси X
    
        % Отметка пиков
        stem(axes_standard, peak, pks, 'r');
        for i = 1:length(peak)
            text(axes_standard, peak(i), pks(i) + 0.01 * max(pks), ...
                sprintf('%d', sizes(i)), 'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'right', 'FontSize', 18);
        end
    
        xlabel(axes_standard, 'Длина фрагментов, пн', 'FontSize', 16); % Название оси X
        ylabel(axes_standard, 'Интенсивность', 'FontSize', 16); % Название оси Y
        title(axes_standard, ['Стандарт длин: ', SizeStandard_titles], 'FontSize', 18); % Заголовок графика
        grid(axes_standard, 'on');
        hold(axes_standard, 'off');
    
        % Настройка оси X для графика стандарта длин
        xlim(axes_standard, [0 max(x)]);
    
        % Построение хроматограммы и размещение панели справа
        chromatogram = build_chromatogram(ZrRef);
        chromatogram_panel = uipanel('Parent', gcf, 'Units', 'normalized', 'Position', [0.956, 0.599, 0.04, 0.351]);
        axes_chromatogram = axes('Parent', chromatogram_panel, 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
        imagesc(axes_chromatogram, flipud(chromatogram));
        colormap(axes_chromatogram, gray); % Использование шкалы серого для отображения интенсивности
        caxis(axes_chromatogram, [0, 245]);
        axis(axes_chromatogram, 'tight');
        set(axes_chromatogram, 'YDir', 'reverse');
        set(axes_chromatogram, 'XTick', [], 'YTick', []);
    end

    % Вложенная функция для построения графика геномной библиотеки
    function plot_genlib(~, ~)
        % Индекс выбранного элемента в списке геномных библиотек
        selected_idx = genlib_list.Value;
    
        % Проверка, что выбранный индекс корректен
        if isempty(selected_idx) || selected_idx > length(results)
            return;
        end
    
        % Извлечение данных из предварительно сохраненных результатов
        current_result = results{selected_idx}; % Сохраняем в переменную перед использованием
    
        t_main = current_result.t_main;
        denoised_data = current_result.denoised_data;
        st_peaks = current_result.st_peaks;
        st_length = current_result.st_length;
        t_unrecognized_peaks = current_result.t_unrecognized_peaks;
        unrecognized_peaks = current_result.unrecognized_peaks;
        lib_length = current_result.lib_length;
        LibPeakLocations = current_result.LibPeakLocations;
        t_final_locations = current_result.t_final_locations;
        final_filtered_below_threshold_locations = current_result.final_filtered_below_threshold_locations;
        hpx = current_result.hpx;
        unr = current_result.unr;
        stp = current_result.stp;
        mainCorr = current_result.mainCorr;
        x_fill = current_result.x_fill;
        y_fill = current_result.y_fill;
        x_Lib_fill = current_result.x_Lib_fill;
        y_Lib_fill = current_result.y_Lib_fill;
    
        % Очистка текущих осей графика геномной библиотеки
        cla(axes_genlib);
    
        % Построение основного графика на существующих осях
        plot(axes_genlib, t_main, denoised_data, 'LineWidth', 2);
        hold(axes_genlib, 'on');
   
        % Добавление элементов графика
        plot(axes_genlib, st_peaks, denoised_data(st_length), 'rx', 'MarkerSize', 18, 'LineWidth', 2);
        plot(axes_genlib, t_unrecognized_peaks, denoised_data(unrecognized_peaks), 'b*', 'MarkerSize', 18, 'LineWidth', 2);
        scatter(axes_genlib, lib_length, denoised_data(LibPeakLocations), 90, 'filled', ...
                'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'r');

        if ~isempty(x_fill)
        fill([x_fill, fliplr(x_fill)], [y_fill, zeros(size(y_fill))], ...
           'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'Parent', axes_genlib);
        end

        if ~isempty(x_Lib_fill)
        fill([x_Lib_fill, fliplr(x_Lib_fill)], [y_Lib_fill, zeros(size(y_Lib_fill))], ...
           'r', 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'Parent', axes_genlib);
        end
    
        % Отображение прямых между выбранными и оригинальными пиками
        for i = 1:length(t_final_locations)            
            line(axes_genlib, [t_final_locations(i), t_final_locations(i)], ...
                 [0, denoised_data(round(final_filtered_below_threshold_locations(i)))], ...
                 'Color', 'b', 'LineStyle', '--');
        end
    
        % Пунктирная линия на у=0
        line(axes_genlib, xlim(axes_genlib), [0, 0], 'Color', 'k', 'LineStyle', '--');
    
        % Добавление рисок и значений на ось x
        xticks(axes_genlib, peak);
        xticklabels(axes_genlib, string(sizes));
        set(axes_genlib, 'FontSize', 16);
    
        % Добавление значений коррекции пиков и высших точек
        for i = 1:length(st_peaks)
            text(axes_genlib, st_peaks(i), denoised_data(st_length(i)) + 0.01 * max(denoised_data), ...
                 sprintf('%d', stp(i)), ...
                 'VerticalAlignment', 'bottom', ...
                 'HorizontalAlignment', 'right', ...
                 'FontSize', 18);
        end
    
        for i = 1:length(hpx)
            text(axes_genlib, lib_length(i), denoised_data(LibPeakLocations(i)) + 0.05 * max(denoised_data), ...
                 sprintf('%d', hpx(i)), ...
                 'VerticalAlignment', 'bottom', ...
                 'HorizontalAlignment', 'right', ...
                 'Rotation', 90, ...
                 'FontSize', 13);
        end
    
        for i = 1:length(unr)
            text(axes_genlib, t_unrecognized_peaks(i), denoised_data(unrecognized_peaks(i)) + 0.01 * max(denoised_data), ...
                 sprintf('%d', unr(i)), ...
                 'VerticalAlignment', 'bottom', ...
                 'HorizontalAlignment', 'right', ...
                 'FontSize', 18);
        end
    
        % Подписи осей и заголовок
        xlabel(axes_genlib, 'Длина фрагментов, пн', 'FontSize', 16);
        ylabel(axes_genlib, 'Интенсивность', 'FontSize', 16);
        title(axes_genlib, ['Геномная библиотека: ', GenLib_titles{selected_idx}], 'FontSize', 18);
        grid(axes_genlib, 'on');
    
        % Настройка оси X
        xlim(axes_genlib, [0 max(t_main)]);
    
        % Настройка Data Cursor для интерактивности
        dcm = datacursormode(gcf);
        set(dcm, 'UpdateFcn', @(src, event) customDataCursor(src, event, t_main, mainCorr));
    
        hold(axes_genlib, 'off');

        % Пользовательская функция для Data Cursor
        function txt = customDataCursor(~, event_obj, t_main, mainCorr)
            % Получаем координаты точки
            pos = get(event_obj, 'Position');
            x_value = pos(1);
            
            % Находим индекс ближайшей точки по времени
            [~, idx] = min(abs(t_main - x_value));
            
            % Соответствующая длина фрагмента
            corresponding_length = mainCorr(idx);
            
            % Формируем текст для отображения
            txt = {['Интенсивность: ', num2str(pos(2))], ...
                   ['Длина фрагмента: ', num2str(corresponding_length)]};
        end
        
        
        % Построение хроматограммы справа от графика геномной библиотеки
        chromatogram = build_chromatogram(denoised_data);
        chromatogram_panel = uipanel('Parent', gcf, 'Units', 'normalized', 'Position', [0.956, 0.099, 0.04, 0.351]);
        axes_chromatogram = axes('Parent', chromatogram_panel, 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
        imagesc(axes_chromatogram, flipud(chromatogram));
        colormap(axes_chromatogram, gray); % Использование шкалы серого для отображения интенсивности
        caxis(axes_chromatogram, [0, 245]);
        axis(axes_chromatogram, 'tight');
        set(axes_chromatogram, 'XTick', [], 'YTick', []);
    end
    
    function chromatogram = build_chromatogram(data)
        % Построение хроматограммы
        num_points = length(data);
        chromatogram = zeros(num_points, 1); % Хроматограмма будет представлена столбцом
        max_value = max(data);
        for i = 1:num_points
            height = i; % Высота полосы определяется номером точки
            width = 0.1;  % Ширина одной полоски
            value = data(i); % Интенсивность для текущей точки
            fill_height = round((value / max_value) * height); % Определение высоты заполняющей полоски
            chromatogram(i) = fill_height; % Сохранение высоты заполненной полоски в хроматограмме
        end
    end

    % Функция для отображения калибровочной кривой и таблицы
    function show_calibration_curve_and_table(~, ~)
        % Создание главного окна
        fig = figure('Name', ['Стандарт длин: ', SizeStandard_titles], 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.4, 0.3, 0.3, 0.5]);
    
        % Создание панели для графика
        graphPanel = uipanel('Parent', fig, 'Units', 'normalized', ...
            'Position', [0, 0.5, 1, 0.5]); % Верхняя половина окна
        
        % Ось для графика калибровочной кривой
        axes('Parent', graphPanel);
        scatter(sizes, peak, 'filled'); % Рассеянный график
        hold on;
    
        % Подгонка полинома 4-й степени
        p = polyfit(sizes, peak, 4); % Подгонка полинома
        LIZ_fit = linspace(min(sizes), max(sizes), 100); % Генерация точек по оси X
        locs_fit = polyval(p, LIZ_fit); % Вычисление соответствующих значений Y
    
        % Построение калибровочной кривой
        plot(LIZ_fit, locs_fit, 'r-', 'LineWidth', 2); % Красная линия для подгонки
        xlabel('Длина фрагментов, пн');
        ylabel('Время выхода, с');
        title('Калибровочная кривая');
        grid on;
        hold off;
    
        % Создание панели для таблицы
        tablePanel = uipanel('Parent', fig, 'Units', 'normalized', ...
            'Position', [0, 0, 1, 0.5]); % Нижняя половина окна

        % Округление данных
        sizes = round(sizes(:)); % Округление до целых
        peak = round(peak(:)); % Округление до сотых
        led_area = round(led_area(:) * 100) / 100; % Округление до сотых

        % Данные для таблицы
        rowNames = arrayfun(@num2str, (1:length(sizes))', 'UniformOutput', false);
        SDTable = [sizes(:), concentrations(:), SD_molarity(:), peak(:), led_area(:)];
    
        % Преобразование числовых данных в строки с нужным форматом
        formatted_SDTable = cell(size(SDTable));
        for i = 1:size(SDTable, 1)
            for j = 1:size(SDTable, 2)
                if mod(SDTable(i, j), 1) == 0 % Проверка, является ли число целым
                    formatted_SDTable{i, j} = sprintf('%d', SDTable(i, j)); % Целое число
                else
                    % Проверка, нужно ли отображать только один знак после запятой
                    if round(SDTable(i, j) * 10) == SDTable(i, j) * 10
                        formatted_SDTable{i, j} = sprintf('%.1f', SDTable(i, j)); % Один знак после запятой
                    else
                        formatted_SDTable{i, j} = sprintf('%.2f', SDTable(i, j)); % Два знака после запятой
                    end
                end
            end
        end

        % Построение таблицы
        uitable('Parent', tablePanel, 'Data', formatted_SDTable, ...
            'ColumnName', {'Длина фрагментов, пн', 'Концентрация, нг/мкл', 'Молярность, нмоль/л', 'Время выхода, с', 'Площадь * 10^7'}, ...
            'RowName', rowNames, 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    end

    % Функция для отображения таблицы геномной библиотеки
    function show_genlib_report(~, ~)
        % Получение индекса выбранной библиотеки
        selected_idx = genlib_list.Value;
        
        % Проверка корректности индекса
        if isempty(selected_idx) || selected_idx <= 0 || selected_idx > length(results)
            errordlg('Пожалуйста, выберите библиотеку из списка.', 'Ошибка');
            return;
        end
        
        % Извлечение данных для выбранной библиотеки
        current_result = results{selected_idx};
        
        % Формирование данных для первой таблицы
        
        areaCorr = current_result.areaCorr;
        molarity = current_result.molarity;
        peaksCorr = round(current_result.peaksCorr);
        library_peaks = round(current_result.library_peaks);        
        GLAreas = round(current_result.GLAreas * 100) / 100;        
        
        if isempty(peaksCorr) || isempty(library_peaks)
            errordlg('Нет данных для выбранной библиотеки.', 'Ошибка');
            return;
        end
        
        % Создание окна с таблицей
        figure('Name', ['Геномная библиотека: ', GenLib_titles{selected_idx}], ...
               'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.5, 0.1, 0.35, 0.4]);
        
        % Форматирование данных для первой таблицы
        rowNames = arrayfun(@num2str, (1:length(peaksCorr))', 'UniformOutput', false);
        data = [peaksCorr(:), areaCorr(:), molarity(:), library_peaks(:), GLAreas(:)];
        
        % Преобразование числовых данных в строки с нужным форматом
        formatted_data = arrayfun(@(x) sprintf('%.2f', x), data, 'UniformOutput', false);

        formatted_data = cell(size(data));
        for i = 1:size(data, 1)
            for j = 1:size(data, 2)
                if mod(data(i, j), 1) == 0 % Проверка, является ли число целым
                    formatted_data{i, j} = sprintf('%d', data(i, j)); % Целое число
                else
                    % Проверка, нужно ли отображать только один знак после запятой
                    if round(data(i, j) * 10) == data(i, j) * 10
                        formatted_data{i, j} = sprintf('%.1f', data(i, j)); % Один знак после запятой
                    else
                        formatted_data{i, j} = sprintf('%.2f', data(i, j)); % Два знака после запятой
                    end
                end
            end
        end
        
        % Отображение первой таблицы
        uitable('Data', formatted_data, ...
                'ColumnName', {'Длина фрагментов, пн', 'Концентрация, нг/мкл', 'Молярность, нмоль/л', 'Время выхода, с', 'Площадь * 10^7'}, ...
                'RowName', rowNames, ...
                'Units', 'normalized', ...
                'Position', [0, 0.2, 1, 0.8]);
        
        % Формирование данных для второй таблицы
        maxLibPeak = round(current_result.maxLibPeak);
        maxLibValue = round(current_result.maxLibValue);
        totalLibArea = round(current_result.totalLibArea * 100) / 100;
        totalLibConc = round(current_result.totalLibConc * 100) / 100;
        totalLibMolarity = round(current_result.totalLibMolarity * 100) / 100;
        
        % Форматирование данных для второй таблицы
        second_rowNames = arrayfun(@num2str, (1:length(maxLibPeak))', 'UniformOutput', false);
        second_data = [maxLibPeak(:), totalLibConc(:), totalLibMolarity(:), maxLibValue(:), totalLibArea(:)];
        
        % Преобразование числовых данных в строки с нужным форматом
        formatted_second_data = cell(size(second_data));
        for i = 1:size(second_data, 1)
            for j = 1:size(second_data, 2)
                if mod(second_data(i, j), 1) == 0 % Проверка, является ли число целым
                    formatted_second_data{i, j} = sprintf('%d', second_data(i, j)); % Целое число
                else
                    % Проверка, нужно ли отображать только один знак после запятой
                    if round(second_data(i, j) * 10) == second_data(i, j) * 10
                        formatted_second_data{i, j} = sprintf('%.1f', second_data(i, j)); % Один знак после запятой
                    else
                        formatted_second_data{i, j} = sprintf('%.2f', second_data(i, j)); % Два знака после запятой
                    end
                end
            end
        end
        
        % Отображение второй таблицы
        uitable('Data', formatted_second_data, ...
                'ColumnName', {'Длина максимального фрагмента, пн', 'Концентрация геномной библиотеки, нг/мкл', ...
                'Молярность геномной библиотеки, пмоль/л', 'Время выхода максимального фрагмента, с', 'Площадь геномной библиотеки * 10^7'}, ...
                'RowName', second_rowNames, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, 0.2], ...
                'ColumnWidth', {120});
    end
end