function [locs2, area, frg_area, rawRef, SD_molarity] = SDFind(rawRef, InLIZ, locs_pol, CONC) 
clearvars -except rawRef InLIZ locs_pol CONC; 
LIZ = fliplr(InLIZ);
x = (1: length(rawRef))';
rawRef = msbackadj(x, rawRef, 'WINDOWSIZE', 140, 'STEPSIZE', 40, 'SHOWPLOT', 0, 'QUANTILEVALUE', 0.1); % коррекция бейзлайна
zrRef = wden(rawRef,'sqtwolog','s','sln',1,'sym2'); % фильтр данных
plot(zrRef)
zrRef     = flipud(zrRef);
rawRef     = flipud(rawRef);

% Понадобится для отсеивания найденных пиков в соотвествии с выбранным законом
z = polyfit(InLIZ, locs_pol, 4); % полином 4 степени
new_LIZ = polyval(z, LIZ);
i = 2:length(new_LIZ);              
dLIZ = abs(new_LIZ(i) - new_LIZ(i-1));

threshold = quantile(zrRef, 0.995);  % для начала возьмем порог на уровне 99.5%, будем его снижать, если надо 

lizPeakIdx  = []; 
dataPeakIdx = []; 

%*** НАЙДЕМ В СПЕКТРЕ ПИКИ, СООТВЕТВУЮЩИЕ ПИКАМ СТАНДАРТА ***
for threshLoop = 1:30   % главный цикл (30 попыток)
    % ищем пики, пытаемся среди найденных отобрать подходящие, если не
    % удалось - снижаем порог и повторяем процедуру
    
    %** ИЩЕМ ПИКИ В СПЕКТРЕ **
    threshold = 0.9* threshold;

    for tc=1:20 
        [pks, locs] = findpeaks(zrRef, 'minpeakheight',threshold, 'MINPEAKDISTANCE', 8); 
        if length(locs) < length(LIZ)
            threshold = 0.9* threshold;
        else
            break;
        end
    end
        
    overmuch = 2.4; % порог, значение взято из опыта
    if length(pks) >= overmuch*length(LIZ)
        locs2 = [];
        break;
    end

    %** ОТСЕИВАЕМ ЛИШНИЕ **    
    lizPeakIdx  = []; % индекс текущего пика в стандарте
    dataPeakIdx = []; % индексы пиков в спектре

    for k=1:(length(LIZ)-1);
        for j= (k+1): length(locs); %paceLoop
            PACE = (locs(j) - locs(k))/dLIZ(1); % кандидат на "базовый шаг"
            pace = PACE;                        % pace - текущий шаг
            lizPeakIdx = [1]; % кандидат 
            dataPeakIdx =[1];
            iLiz=1;
            iDat=1;
            Dnext = 0;
            % проверим является ли кандидат на "базовый шаг" настоящим
            while Dnext < locs(end) && iLiz < length(LIZ) ;
                Dprev = locs(iDat);
                Dd    = pace*dLIZ(iLiz);
                Dnext = Dprev + Dd;
                dst   = abs(locs-Dnext);
                [idx idx] = min(dst);    % индекс ближайшего значения
                minmin    = dst(idx);
                if minmin < Dd/2    % пик лежит примерно там где и ожидалось
                    dataPeakIdx = [dataPeakIdx idx];            
                    pace = (locs(idx) - Dprev)/dLIZ(iLiz); % фактический шаг
                    iLiz = iLiz+1;            
                    iDat = idx;
                else
                    % пика в ожидаемом месте нет - возможно начальный пик ложный
                    iDat = dataPeakIdx(1) +1;   % примем следующий пик за начальный
                    dataPeakIdx = iDat;         
                    pace = PACE;
                    iLiz = 1;                   % стандарт начнем с начала
                end                
            end     
            if length(dataPeakIdx) == length(LIZ);
                break; % нужное количество пиков нашли - выходим из цикла
            end;
        end %j
        if length(dataPeakIdx) == length(LIZ);
            break; % нужное количество пиков нашли - выходим из этого цикла тоже
        end;    
    end %k
        
    if length(dataPeakIdx) == length(LIZ);
        break; % нужное количество пиков нашли - выходим из большого цикла тоже
    end

end % thresholdLoop

if  length(dataPeakIdx) == length(LIZ);
    locs2 = locs(dataPeakIdx); % отобранные пики
    % Нахождение минимумов
    filt_zrRef = sgolayfilt(zrRef, 1, 3);
    crossings2 = find(diff(filt_zrRef > 0));
    flip = -filt_zrRef;
    [peaks1, peakLocations1] = findpeaks(flip);
    crossings = union(peakLocations1, crossings2);
else
    locs2 = [];
end;

areas_num = [];

%*** нарисуем что нашли ***
if length(locs2) == length(LIZ)
       LIZ = LIZ';
       p = polyfit(locs2, LIZ, 4);
       pks2  = pks(dataPeakIdx);  % амплитуды отобранных пиков (нужны только для отладки)
        
       area = [];

       % строим площади под графиком и считаем их
       for i = 1:(length(crossings) - 1)
        
           % ищем индексы между текущей парой точек
           indices_between_peaks = locs2 >= crossings(i) & locs2 <= crossings(i+1);
                
           % считаем количество значений между текущей парой точек
           num_points_between_peaks = sum(indices_between_peaks);
                
           if num_points_between_peaks == 1
               x_points = crossings(i:i+1);
               for i = 1:length(x_points)-1
                   % Выделим текущую область
                   x_range = x_points(i):x_points(i+1);
                   y_range = rawRef(x_range);

                   % Убедимся, что размерности совпадают
                   if length(x_range) == length(y_range)
                       areas_num = integral(@(x) interp1(1:length(rawRef), rawRef, x, 'linear', 0), x_range(1), x_range(end), 'ArrayValued', true);
                       area = vertcat(area, areas_num);
                   end
               end
           end
       end
        
       area = flipud(area);
               
       % *** развернем обратно вектор обратно, чтобы индексы шли слева направо ***
       rawRef = flipud(rawRef);

       locs2 = locs2*(-1);
       locs2 = locs2+length(rawRef) + 1;
       locs2 = flipud(locs2);

       frg_area = [];
       disp('ch');
       disp(length(area));
       disp(length(LIZ));
       frg_area = area ./ (flipud(LIZ) .* flipud(LIZ)/100); % считает корректно, проверено
       area = area * 10^(-7);
       CONC = CONC';

       SD_molarity = ((CONC * 10^(-3)) ./ (649 * flipud(LIZ))) * 10^9; % в нмолях/л!
end