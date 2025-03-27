function [t_main, denoised_data, st_peaks, st_length, t_unrecognized_peaks, unrecognized_peaks, ...
    lib_length, LibPeakLocations, t_final_locations, final_Lib_local_minimums, ...
    hpx, unr, stp, mainCorr, all_areas, all_peaksCorr, all_peaks, all_areasConc, molarity, ...
    maxLibPeak, maxLibValue, totalLibArea, totalLibConc, totalLibMolarity, ... 
    x_fill, y_fill, x_Lib_fill, y_Lib_fill] = GLFind_1_1(data, peak, LIZ, CONC)

    data = data';

   % 1. Выбор первых 50 значений как шума
    noise = data(1:50);
   % Вычитание шума из данных
    denoised_data = data - mean(noise);
    x = (1: length(denoised_data))';
    denoised_data = msbackadj(x, denoised_data, 'WINDOWSIZE', 140, 'STEPSIZE', 300, 'SHOWPLOT', 0, 'QUANTILEVALUE', 0.05); % коррекция бейзлайна
    
    
  % 2. Обработка данных 
    filteredData = sgolayfilt(denoised_data, 1, 5);
        diffData = diff(filteredData);
    filteredDiffData = sgolayfilt(diffData, 1, 5);
        ddData = diff(filteredDiffData);
    filteredDDData = sgolayfilt(ddData, 1, 5);
    
   % Обратим значения данных в обратную сторону для отображения пиков
    flippedData = -filteredDDData;
    flippedData(flippedData < 0) = 0;
    
   % Нахождение пиков
    [peaks, peakLocations] = findpeaks(flippedData);
    
   % Создайте вектор для хранения выбранных пиков и их координат
    selectedPeakLocations = [];
    complete_Peaks_Locations = [];
    
    selectedPeaks = denoised_data(peakLocations);    
    threshold = mean(selectedPeaks) / 3;    % применили порог: береём среднюю высоту по всем найденным пикам и и делим на 3 (иначе слишком высоко)
    selectedPeaks (selectedPeaks < threshold) = []; % удалили все пики, которые лежат ниже порога
    
    selectedPeakLocations = find(ismember(denoised_data, selectedPeaks));
    selectedPeakLocations(selectedPeakLocations < 10 | selectedPeakLocations > (length(x)-10)) = [];

    if isempty(selectedPeakLocations)
        % Вывести диалоговое окно с предупреждением
        uiwait(msgbox('Пики не были найдены', 'Предупреждение', 'warn', 'modal'));
        
        % Завершить выполнение функции или скрипта
        return;
    end

    % Создаем массив standart_pks
    one_pks = [];

    % Проходим по каждому пику в selectedPeakLocations
    for i = 1:length(selectedPeakLocations)
        % Текущий индекс
        peak_idx = selectedPeakLocations(i);
                   
            % Находим границы от текущего selectedPeakLocations +-4
            left_idx = peak_idx - 4; 
            right_idx = peak_idx + 4;
            
            % Ищем максимум между текующими границами
            max_value = max(denoised_data(left_idx:right_idx)); % это по ОУ
            peak_idx = find(ismember(denoised_data, max_value)); % это перевод в ОХ
            
            % Находим границы от текущего максимального значения +-4
            left_idx = peak_idx - 4; 
            right_idx = peak_idx + 4;

            % Значения слева и справа
            left_value = denoised_data(left_idx);
            right_value = denoised_data(right_idx);
            
            % Проверяем, если обе точки ниже 90% от основного пика (если обе лежат ниже, значит это отдельный пик, а не часть локальных минимумов)
            if left_value < 0.9 * max_value && right_value < 0.9 * max_value
                % Добавляем в массив standart_pks максимальное значение
                one_pks = [one_pks; max_value];
                selectedPeakLocations(i) = peak_idx; % заменяем на найденный максимум 
            end       
        lonely_pks = find(ismember(denoised_data, one_pks)); % перевод в ОХ
    end

  % 3. Нахождение минимумов электрофореграммы 
    flip = -denoised_data;
    [peaks1, min_peakLocations] = findpeaks(flip, 'MinPeakDistance', 8);
    
    Peaks_threshold = 0.6 * mean(flip);
    
   % Удаление пиков, которые лежат ниже порога
    below_threshold = peaks1 < Peaks_threshold;
    all_local_minimums = min_peakLocations(below_threshold); % все минимумы, которые лежат ниже порога (в том числе одиночных пиков)
    min_peakLocations(below_threshold) = []; % удаляем из массива min_peakLocations все миниуммы, которые лежат ниже порога (оставляем только основные)
    
    crossings2 = find(diff(denoised_data > 0));
    
   % Объединение найденных пиков и точек пересечения
    complete_Peaks_Locations = union(min_peakLocations, crossings2);

  % 4. Калибровка данных
   % Инициализируйте переменные
    LibPeakLocations = [];
    Hidden_LibPeakLocations = [];

    unrecognized_peaks = [];
    pre_unrecognized_peaks = [];
    t_unrecognized_peaks = [];
    rest_peaks = [];

    st_length = [];
    lib_length = []; 
    min_st_length = [];

    st_areas = [];
    lib_areas = [];
    Hidden_lib_areas = [];
    unrec_areas = [];
    rest_peaks_areas = [];

    lib_one_area = [];    
    lib_one_areaConc = [];
    Hid_lib_peaksCorr = [];
    one_area = [];

    lib_molarity = [];

    final_Lib_local_minimums = [];
    Hidden_final_Lib_local_minimums = [];
    t_final_locations = [];

    x_fill_1 = [];
    x_Lib_fill_1 = [];
    y_fill = [];
    y_Lib_fill = [];
        
    st_peaks = vertcat(peak(1), peak(end));
    CONC = vertcat(CONC(1), CONC(end));
    
    inLIZ = LIZ';
    
    SDC = polyfit(peak, inLIZ, 5); % калибровка по стандарту
    SDC2 = polyfit(inLIZ, peak, 5); % калибровка в обратную сторону для проверки соотвествия границ

    for i = 1:length(lonely_pks)-1

            % Вычисление pace
            pace = st_peaks(2) - st_peaks(1);
            % Инициализация массивов
            st_length = lonely_pks(1); % Инициализируем массив st_length первым значением lonely_pks
            % Базовое значение
            base_value = lonely_pks(1);
                        
            % Поиск пиков
            for i = 2:length(lonely_pks)
                % Вычитание базового значения
                distance = lonely_pks(i) - base_value;
                % Проверка расстояния
                if abs(distance - pace) <= 0.2 * pace % Используем 20% допуск
                    st_length = vertcat(st_length, lonely_pks(i));
                else
                    pre_unrecognized_peaks = vertcat(pre_unrecognized_peaks, lonely_pks(i));
                end
            end

            if length(lonely_pks) > 1 && length(st_length) < 2
                st_length = vertcat(lonely_pks(1), lonely_pks(end));
            end

            if length(st_length) > 2
                % Создаем массив для хранения площадей
                areas = zeros(1, length(st_length) - 1);
                
                % Перебираем все значения, начиная со второго
                for i = 2:length(st_length)
                    % Определяем границы (±7)
                    left_idx = st_length(i) - 7;
                    right_idx = st_length(i) + 7;
                    
                    % Интегрируем площадь между границами
                    area = trapz(left_idx:right_idx, denoised_data(left_idx:right_idx));
                    
                    % Сохраняем площадь
                    areas(i - 1) = area;
                end
                
                % Находим индекс наибольшей площади
                [~, max_idx] = max(areas);
                
                % Выбираем соответствующее значение из st_length
                best_value = st_length(max_idx + 1); % +1 из-за смещения
                
                % Обновляем st_length
                st_length = [st_length(1), best_value];
            end           
    end     

    % В случае, если не было найдено ни одного реперного пика
        if length(st_length) ~= 2
                % Открываем диалоговое окно
                choice = questdlg('Реперные пики не найдены.', ...
                                  'Ошибка анализа', ...
                                  'Завершить анализ', 'Ввести вручную', 'Ввести вручную');
                
                % Обрабатываем выбор пользователя
                switch choice
                    case 'Завершить анализ'
                        % Завершить выполнение анализа
                        disp('Анализ завершен пользователем.');
                        return;
                    case 'Ввести вручную'
                        [st_length] = plotFigure(denoised_data, st_length);                        
                        selectedPeakLocations = vertcat(selectedPeakLocations, st_length);
                        selectedPeakLocations = unique(sort(selectedPeakLocations));
                end
        end
 
        pre_unrecognized_peaks = unique(pre_unrecognized_peaks);
        pre_unrecognized_peaks(ismember(pre_unrecognized_peaks, st_length)) = []; % если найденный неопознанный пик отнесён к реперному, то он удаляется из массива 

        % Проверка минимумов (массив complete_Peaks_Locations): если ближайший минимум дальше, чем 10, то переназначаем все минимумы текущего пика на 7
        for i = 1:length(st_length)
            % Ищем ближайшее значение в массиве complete_Peaks_Locations
            current_value = st_length(i);
            
            left_candidates = max(complete_Peaks_Locations(complete_Peaks_Locations < current_value));
            right_candidates = min(complete_Peaks_Locations(complete_Peaks_Locations > current_value));
            closest_value = vertcat(left_candidates, right_candidates);

            idx = abs(closest_value - current_value);     
                
            % Проверяем расстояние с двух сторон
            if any(idx > 10)
                % Если хотя бы одно расстояние превышает 10, добавляем значения в min_st_length
                min_st_length = vertcat(min_st_length, current_value - 7, current_value + 7);
                
            end
        end          

        % Объединяем массивы
        complete_Peaks_Locations = vertcat(complete_Peaks_Locations, min_st_length);
                            
        % Удаляем дубликаты и сортируем массив
        complete_Peaks_Locations = unique(complete_Peaks_Locations);

        % На случай, если репер и неопознанный пик находятся слишком близко (расстояние < 10) - иначе впоследствии программа не понимает,
        % какой минимум между ними должен быть (их минимумы накладываются)
        for i = 1:length(st_length)
            current_value = st_length(i);
            
            % Поиск значений в pre_unrecognized_peaks, лежащих в пределах [current_st_length - 10, current_st_length + 10]
            nearby_peaks = pre_unrecognized_peaks(pre_unrecognized_peaks >= (current_value - 10) & ...
                                                  pre_unrecognized_peaks <= (current_value + 10));

                for k = 1:numel(nearby_peaks)
                        % Берем первое найденное значение
                        target_peak = nearby_peaks(k);
        
                        % Определение диапазона в denoised_data для поиска минимума
                        range_start = min(current_value, target_peak);
                        range_end = max(current_value, target_peak);
                
                        % Поиск наименьшего значения в указанном диапазоне и его индекса
                        [min_value, min_index] = min(denoised_data(range_start:range_end));
                        min_index = min_index + range_start - 1; % Коррекция индекса
                
                        % Удаление значений из complete_Peaks_Locations, лежащих в этом диапазоне
                        complete_Peaks_Locations(complete_Peaks_Locations >= range_start & ...
                                                 complete_Peaks_Locations <= range_end) = [];
                
                        % Добавление найденного индекса в complete_Peaks_Locations
                        complete_Peaks_Locations = unique(sort([complete_Peaks_Locations(:); min_index(:)]));
                end            
        end
        
        % Удаляем пики, которые лежат за пределами реперов
        selectedPeakLocations = selectedPeakLocations (selectedPeakLocations >= st_length(1) & ...
            selectedPeakLocations <= st_length(end));

   % Этот блок приводит электрофореграмму геномной библиотеки и стандарта
   % длин в одну шкалу (выравнивает по ширине и высоте)
    px = polyfit(st_length, st_peaks, 1); % выравнивание по ширине
                
    t = 1:length(denoised_data);
    t_main = polyval(px, t); 
   
  % 5. Обработка данных с учётом калибровки
   % В этом блоке теперь находим и разбиваем все локальные пики по классам: реперные пики, пики геномной библиотеки и неопознанные пики  
    for i = 1:(length(complete_Peaks_Locations) - 1)
    
       % Как обычно проверяем наличие локальных максимумов между текущей парой локальных минимумов
        indices_between_peaks = selectedPeakLocations >= complete_Peaks_Locations(i) & selectedPeakLocations <= complete_Peaks_Locations(i+1);
       % Считаем количество точек, попавших в пару локальных минимумов
        num_points_between_peaks = sum(indices_between_peaks);
            
        if num_points_between_peaks < 4 && num_points_between_peaks > 0 % Эти точки относям к реперным пикам или неопознанным пикам
               
           % Отмечаем пространство между текущими точками
            x_points = complete_Peaks_Locations(i:i+1);
                            
           % Для подсчёта площадей
            for i = 1:length(x_points)-1
                    
               % Выделяем текущую область
                x_range = x_points(i):x_points(i+1);
                y_range = denoised_data(x_range);
   
                   % Проверка наличия значений из unrecognized_peaks в x_range
                    if any(ismember(x_range, unrecognized_peaks)) % неопознанный пик
                        unrecognized_peaks = [unrecognized_peaks, pre_unrecognized_peaks(i)]; % на случай, если неопознанных пиков было найдено больше (часть принадлежит ГБ)

                        % Определяем x-координаты области
                        x_fill_1 = linspace(x_range(1), x_range(end), 100); % Разбиваем на 100 точек для плавности                                             
                        % Получаем соответствующие y-координаты, используя интерполяцию
                        y_fill = interp1(1:length(denoised_data), denoised_data, x_fill_1, 'linear', 0);
                    
                    elseif any(ismember(x_range, st_length))                      
                        area = integral(@(x) interp1(1:length(denoised_data), denoised_data, x, 'linear', 0), x_range(1), x_range(end), 'ArrayValued', true); % реперный пик
                        st_areas = vertcat(st_areas, area);  
                    end
            end
    
        elseif num_points_between_peaks >= 4
            
            f = complete_Peaks_Locations(i+1);

           % Найдем максимальное значение denoised_data между текущими точками
           % Получаем индексы для complete_Peaks_Locations
            start_index = complete_Peaks_Locations(i);
            end_index = complete_Peaks_Locations(i+1);

           % Находим максимальное значение между этими индексами
            [max_valueLib, max_index] = max(denoised_data(start_index:end_index));
            maxLibValue = find(denoised_data == max_valueLib);
            maxLibValueCorr = polyval(SDC, maxLibValue);

            lower_bound = maxLibValueCorr - 200;
            upper_bound = maxLibValueCorr + 200;
         
            lower_bound = polyval(SDC2, lower_bound);
            upper_bound = polyval(SDC2, upper_bound);
           
            % Проверяем, лежит ли диапазон внутри [start_index, end_index]
            if lower_bound > start_index || upper_bound < end_index
                % Если диапазон выходит за пределы, создаем плавный диапазон
                x_Lib_fill_1 = linspace(start_index, end_index, 100); % Разбиваем на 100 точек для плавности
                
                % Интерполируем значения y для x_fill_1
                y_Lib_fill = interp1(1:length(denoised_data), denoised_data, x_Lib_fill_1, 'linear', 0);
            end
           
           %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%              
        
            final_Lib_local_minimums = [final_Lib_local_minimums; selectedPeakLocations(indices_between_peaks); f]; % берём текущую пару точек вместо 
            % локальных минимумов (теперь это просто один большой пик ГБ)
           
            % Ищем локальные максимумы между найденными локальными минимумами final_Lib_local_minimums 
            for i = 1:length(final_Lib_local_minimums)-1
                 % Ищем индексы массива denoised_data, которые находятся между final_Lib_local_minimums(i) и final_Lib_local_minimums(i+1)
                 x_start = final_Lib_local_minimums(i);
                 x_end = final_Lib_local_minimums(i+1);
                            
                 % Находим соответствующие индексы в массиве denoised_data
                 indices = find((x >= x_start) & (x <= x_end)); % где x — это массив координат по оси x для denoised_data
                                                                            
                 % Находим максимальное значение в массиве denoised_data между этими индексами
                 [max_value, max_index] = max(denoised_data(indices));
                        
                 indices_max_value = find(denoised_data == max_value);
                           
                 % Добавляем это максимальное значение в LibPeakLocations
                 LibPeakLocations = vertcat(LibPeakLocations, indices_max_value);                           
             end
                
             LibPeakLocations = unique(LibPeakLocations);

             % На случай, если алгоритм посчитал тонкие ГБ (типа
             % фаикс) в качестве большой библиотеки
             diff_values = abs(denoised_data(LibPeakLocations) - max_valueLib); % вычитаем из найденных пиков ГБ максимальный пик
                    
             % Определяем порог 20% от maxLibValue - расстояние (высота) между пиками не должно быть больше, чем 20% от
             % максимального пика: максимум на 100, минимум на 50, расстояние между ними 50 > 20 - это плохо (+1 на следующем шагу); 
             % минимум на 90, расстояние 10 < 20 - хорошо (0)
             threshold = 0.2 * max_valueLib; 
                    
             % Проверяем, какие значения превышают порог и заполняем check_LibPeaks
             check_LibPeaks = diff_values > threshold; % ищем пики, которые расположены слишком низко (ниже, чем 20% от максимального пика): если больше порога, то возвращается 1 (находим их количество)
                    
             % Считаем разницу между длиной LibPeakLocations и количеством "плохих" значений
             diff_count = length(LibPeakLocations) - sum(check_LibPeaks);
                                      
             % Если больше 50% значений превышают порог, удаляем массивы
             if diff_count < 0.3 * length(LibPeakLocations)
                 LibPeakLocations = []; 
             else
                 [Hidden_LibPeakLocations, Hidden_lib_areas, Hidden_final_Lib_local_minimums] = Hid_fun(denoised_data, start_index, end_index, px, Hidden_lib_areas, maxLibValue);
             end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    end
        
    % Подсчёт концентраций и молярности по реперам (ГБ будет дальше)
    mainCorr = polyval(SDC, t_main);
    st_peaksCorr = polyval(SDC, st_peaks);

    st_areas = vertcat(st_areas(1), st_areas(end));
    led_one_area = st_areas ./ (st_peaksCorr/100); % считает корректно, проверено
    a = polyfit(led_one_area, CONC, 1);

    st_molarity = ((CONC * 10^(-3)) ./ (649 * st_peaksCorr)) * 10^9;  

        % Если ГБ гладкая/фаикс/слишком низкая (не была найдена и идентифицирована как ГБ)
        if isempty(Hidden_LibPeakLocations)

            rest_peaks = selectedPeakLocations; % Собираем все найденные пики
            % Удаляем значения из rest_peaks, которые попадают в диапазон реперных пиков
            rest_peaks = rest_peaks(~((rest_peaks >= (st_length(1) - 10) & rest_peaks <= (st_length(1) + 10)) | ...
                                      (rest_peaks >= (st_length(2) - 10) & rest_peaks <= (st_length(2) + 10))));

            % Инициализация массива для хранения площадей                   
            rest_Peaks_Locations = vertcat(complete_Peaks_Locations, all_local_minimums); % Объединяем все минимумы: общие и локальные

            % Проходим по парам пиков
            i = 1;
            while i <= length(rest_Peaks_Locations) - 1
                % Индексы точек между текущей парой пиков
                indices_between_peaks = rest_peaks >= rest_Peaks_Locations(i) & ...
                                        rest_peaks <= rest_Peaks_Locations(i+1);         
               
                % Количество точек между пиками
                num_points_between_peaks = sum(indices_between_peaks);
                peaks_between = rest_peaks(indices_between_peaks); % это координаты rest_peaks, которые попали в указанный выше диапазон
                       
                if num_points_between_peaks > 1
        
                    new_peak = mean(peaks_between(1:2)); % Среднее значение rest_peaks между двумя соседствующими пиками (минимум между двумя текущими значениями)                    
                    rest_Peaks_Locations = unique(sort([rest_Peaks_Locations(:); new_peak])); % Добавляем новый минимум: если между текущими минимумами нашли несколько максимумов, добавляем новые минимумы, чтобы разделить эти максимумы

                    i = i - 1;
                elseif num_points_between_peaks == 1
                    % Определяем границы текущей области
                    x_points = rest_Peaks_Locations(i:i+1);
                    
                    % Рассчитываем площади между пиками
                    for j = 1:length(x_points) - 1
                        
                        x_range = x_points(j):x_points(j+1);
                        
                        % Интегрируем площадь под кривой
                        area = integral(@(x) interp1(1:length(denoised_data), denoised_data, x, 'linear', 0), x_range(1), x_range(end), 'ArrayValued', true);                        
                        % Добавляем площадь в массив rest_peaks_areas
                        rest_peaks_areas = vertcat(rest_peaks_areas, area); 

                    end
                end
                i = i + 1;
            end

                % Находим индекс наибольшей площади
                [max_area, max_index] = max(rest_peaks_areas);             
                
                % Записываем соответствующий пик в LibPeakLocations
                LibPeakLocations = rest_peaks(max_index);

                % Находим минимумы, которые принадлежат найденному максимому
                start_index = max(rest_Peaks_Locations(rest_Peaks_Locations < LibPeakLocations));
                end_index = min(rest_Peaks_Locations(rest_Peaks_Locations > LibPeakLocations)); 

                [Hidden_LibPeakLocations, Hidden_lib_areas, Hidden_final_Lib_local_minimums] = Hid_fun(denoised_data, start_index, end_index, px, Hidden_lib_areas, LibPeakLocations);
                 
                % Определяем "неопознанные" пики и их площади
                unrecognized_peaks = rest_peaks;
                unrec_areas = rest_peaks_areas;
                
                % Удаляем главный пик и его площадь из "неопознанных"
                unrecognized_peaks(max_index) = [];
                unrec_areas(max_index) = []; 
                
                final_Lib_local_minimums = vertcat(Hidden_final_Lib_local_minimums(1), Hidden_final_Lib_local_minimums(end));    
   
        end

        Hid_lib_length = polyval(px, Hidden_LibPeakLocations); % пересчёт по времени
        Hid_lib_peaksCorr = polyval(SDC, Hid_lib_length);

        Hid_one_area = Hidden_lib_areas ./ (Hid_lib_peaksCorr/100); % пересчёт по длине
        Hid_one_areaConc = polyval(a, Hid_one_area); % находим концентрацию в нг/мкл
        Hid_molarity = ((Hid_one_areaConc * 10^(-3)) ./ (649 * Hid_lib_peaksCorr)) * 10^9; % в нмолях/л!

                % Если ГБ содержит локальные пики и она была идентифицирована как
        % ГБ (был найдет максимум и скрытые пики):
        if isempty(rest_peaks_areas)

            % Проверка на то, лежат ли LibPeakLocations в пределах Hidden_LibPeakLocations: если нет, то удаляются
            check_LibPeakLocations = LibPeakLocations(LibPeakLocations < Hidden_LibPeakLocations(1) | LibPeakLocations > Hidden_LibPeakLocations(end));
            
            % Проверяем, если хотя бы одно значение лежит за границами
            if ~isempty(check_LibPeakLocations)
                % Удаляем все элементы check_LibPeakLocations из LibPeakLocations
                LibPeakLocations(ismember(LibPeakLocations, check_LibPeakLocations)) = [];
                % Добавляем самое первое значение Hidden_LibPeakLocations в качестве первой границы
                if any(check_LibPeakLocations < Hidden_LibPeakLocations(1))
                    LibPeakLocations = vertcat(Hidden_LibPeakLocations(1), LibPeakLocations);
                    left_candidates = max(final_Lib_local_minimums(final_Lib_local_minimums < LibPeakLocations(1)));
                    final_Lib_local_minimums(final_Lib_local_minimums < left_candidates) = []; % удаляем лишние минимумы, чтобы отображались только для отсеянных пиков ГБ (нужно для графиков)
                end
            
                % Аналогично для второй границы
                if any(check_LibPeakLocations > Hidden_LibPeakLocations(end))
                    LibPeakLocations = vertcat(LibPeakLocations, Hidden_LibPeakLocations(end));
                    right_candidates = min(final_Lib_local_minimums(final_Lib_local_minimums > LibPeakLocations(end)));
                    final_Lib_local_minimums(final_Lib_local_minimums > right_candidates) = [];
                end
            end
            
            % Сортируем массив
            LibPeakLocations = unique(sort(LibPeakLocations));

            % считаем концентрации ГБ
            lib_length = polyval(px, LibPeakLocations);   % пересчёт по времени   
            lib_peaksCorr = polyval(SDC, lib_length);   % пересчёт по длинам   

                % Находим индексы элементов LibPeakLocations в Hidden_LibPeakLocations
                [~, indices] = ismember(LibPeakLocations, Hidden_LibPeakLocations);
                indices = indices(indices > 0); % Убираем нули (если элемент не найден)
         
                % Суммируем площади по индексам
                prev_idx = 1;

                % Так как Hidden_LibPeakLocations - это куски фрагментов по 1 пн, а LibPeakLocations - это фрагменты, которые были
                % найдены (нужно для визуализации), нам нужно найти концентрацию этих фрагментов: концентрация каждого
                % фрагмента - сумма предыдущего площадей Hidden_LibPeakLocations
                for i = 1:length(indices)
                    current_idx = indices(i);

                    lib_areas = vertcat(lib_areas, sum(Hidden_lib_areas(prev_idx:current_idx))); % площадь
                    lib_one_area = vertcat(lib_one_area, sum(Hid_one_area(prev_idx:current_idx))); % площадь на 1 пн
                    lib_one_areaConc = vertcat(lib_one_areaConc, sum(Hid_one_areaConc(prev_idx:current_idx))); % концентрация
                    lib_molarity = vertcat(lib_molarity, sum(Hid_molarity(prev_idx:current_idx))); % молярность
                   
                    prev_idx = current_idx + 1; % Начинаем следующий интервал с нового индекса +1
                end        
        
        % Если ГБ гладкая/фаикс/слишком низкая (потому что там всего один пик - нет локальных)
        elseif ~isempty(rest_peaks_areas)              
            % считаем концентрации ГБ
            lib_length = polyval(px, LibPeakLocations);      
            lib_peaksCorr = polyval(SDC, lib_length);

            maxLibValue = LibPeakLocations;

            lib_areas = sum(Hidden_lib_areas);
            lib_one_area = sum(Hid_one_area);
            lib_one_areaConc = sum(Hid_one_areaConc);
            lib_molarity = sum(Hid_molarity); 
        end
        
        one_area = vertcat(led_one_area(1), lib_one_area, led_one_area(end)); % площадь на один фрагмент, не нужен в коде, но может понадобиться для проверки!!!
        all_areasConc = vertcat(CONC(1), lib_one_areaConc, CONC(end)); % концентрация
        all_areas = vertcat(st_areas(1), lib_areas, st_areas(end)); % общая площадь фрагмента
        molarity = vertcat(st_molarity(1), lib_molarity, st_molarity(end)); % молярность      

        all_peaks = vertcat(st_length(1), LibPeakLocations, st_length(end)); % время выхода
        all_peaksCorr = vertcat(st_peaksCorr(1), lib_peaksCorr, st_peaksCorr(end)); % длина в пн
        
        t_final_locations = polyval(px, final_Lib_local_minimums);
        t_unrecognized_peaks = polyval(px, unrecognized_peaks); % пересчёт по времени неизвестных пиков
        unrecognized_peaksCorr = polyval(SDC, t_unrecognized_peaks); % только неопознанные пики
        maxLibPeak = mainCorr(maxLibValue); % максимальный пик библиотеки 
            
        totalLibArea = sum(lib_areas); 
        totalLibConc = sum(lib_one_areaConc);    
        totalLibMolarity = sum(lib_molarity);

    % Закрашиваем красным ложные пики и широкую библиотеку
    if ~isempty(x_fill_1)
        x_fill_1 = [x_fill_1(1), x_fill_1(end)]; 
        x_fill_1 = t_main(x_fill_1);
        x_fill = linspace(x_fill_1(1), x_fill_1(end), 100);
    else
        x_fill = [];
    end

    if ~isempty(x_Lib_fill_1)
        x_Lib_fill_1 = [x_Lib_fill_1(1), x_Lib_fill_1(end)]; 
        x_Lib_fill_1 = t_main(x_Lib_fill_1);
        x_Lib_fill = linspace(x_Lib_fill_1(1), x_Lib_fill_1(end), 100);
    else
        x_Lib_fill = [];
    end      

    hpx = round(lib_peaksCorr);
    unr = round(unrecognized_peaksCorr);
    stp = vertcat(LIZ(1), LIZ(end));
end

function [Hidden_LibPeakLocations, Hidden_lib_areas, Hidden_final_Lib_local_minimums] = Hid_fun(denoised_data, start_index, end_index, px, Hidden_lib_areas, maxLibValue)                           

                median_before_max = median(start_index:maxLibValue); % Находим медианное значение между start_index и maxLibValue (левая середина пика ГБ)                    
                median_after_max = median(maxLibValue:end_index); % Находим медианное значение между maxLibValue и end_index (правая середина пика ГБ)
                                               
                % Создаем массив из двух медианных значений
                median_values = vertcat(median_before_max, median_after_max);
                rounded_values = round(median_values);

                % Создаем массив чисел от первого округленного значения до второго с шагом 1
                Hidden_LibPeakLocations = (rounded_values(1):rounded_values(2))';
                Hidden_final_Lib_local_minimums = vertcat(start_index, Hidden_LibPeakLocations); % все площади

               % ДЛЯ ЗАКРАСКИ И ОБЩЕЙ ПЛОЩАДИ
                for i = 1:length(Hidden_final_Lib_local_minimums)-1
                    
                    H_x_range1 = Hidden_final_Lib_local_minimums(i):Hidden_final_Lib_local_minimums(i+1);

                   % Поиск площади методом Симпсона
                    area = integral(@(x) interp1(1:length(denoised_data), denoised_data, x, 'linear', 0), H_x_range1(1), H_x_range1(end), 'ArrayValued', true);
                    Hidden_lib_areas = vertcat(Hidden_lib_areas, area);                        
                end
end