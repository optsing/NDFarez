function [updatedCrossings] = plotFigure(zrRef, crossings)

    % Define crossings as a global variable to track changes
    global updatedCrossings;
    updatedCrossings = crossings;
    
    % Variable to track currently highlighted point
    highlightedPoint = -1;
    highlightMarker = []; % Handle for highlight marker

    % Create a figure and make it modal (blocking execution)
    f = figure('Name', 'Корректировка площадей стандарта длин', 'NumberTitle', 'off');
    plot(zrRef, 'b');
    hold on;
    scatter(crossings, zrRef(crossings), 'g', 'filled');
    hold off;
    title('Корректировка площадей стандарта длин');

    % Set callback for clicks and mouse motion
    set(f, 'WindowButtonDownFcn', @(src, event) onClickStandardArea(src, event, zrRef));
    set(f, 'WindowButtonMotionFcn', @(src, event) onMouseMove(src, event, zrRef));
    
    % Set up to block the main code until user confirms or cancels
    set(f, 'CloseRequestFcn', @cancelChanges);
    
    % Add OK and Cancel buttons to finalize changes
    uicontrol('Style', 'pushbutton', 'String', 'OK', ...
              'Position', [20 20 50 20], ...
              'Callback', @confirmChanges);
    uicontrol('Style', 'pushbutton', 'String', 'Отмена', ...
              'Position', [80 20 70 20], ...
              'Callback', @cancelChanges);

    % Block the main execution until the figure is closed
    uiwait(f);

    function onMouseMove(~, ~, zrRef)
        % Get current point coordinates from the axis
        coords = get(gca, 'CurrentPoint');
        x = round(coords(1, 1));
        
        % Ensure x is within the bounds of the zrRef array
        if x < 1 || x > length(zrRef)
            if ishandle(highlightMarker)
                delete(highlightMarker);  % Remove highlight if out of bounds
            end
            highlightedPoint = -1; % Reset highlighted point
            return;
        end
        
        % Find the index of the closest point in zrRef
        [~, idx] = min(abs(zrRef - zrRef(x)));
        
        % If already highlighting the same point, do nothing
        if highlightedPoint == idx
            return;
        end
        
        % Remove previous highlight if necessary
        if ishandle(highlightMarker)
            delete(highlightMarker);
        end
        
        % Highlight the closest point on the graph (with a smaller marker)
        highlightedPoint = idx;
        hold on;
        highlightMarker = scatter(highlightedPoint, zrRef(highlightedPoint), 50, 'g', 'filled'); % Smaller size
        hold off;
    end

    function onClickStandardArea(~, ~, zrRef)
        % Only proceed if click occurs within axes limits
        ax = gca;
        coords = get(ax, 'CurrentPoint');
        x = round(coords(1, 1));
        y = coords(1, 2);

        % Ensure the click is inside the axes limits
        if x < ax.XLim(1) || x > ax.XLim(2) || y < ax.YLim(1) || y > ax.YLim(2)
            return; % Ignore clicks outside the axes range
        end
        
        % Ensure x is within the bounds and that the highlighted point is clicked
        if highlightedPoint < 1 || highlightedPoint > length(zrRef)
            return; % Ignore clicks outside the data range
        end
        
        % Check if the point already exists in updatedCrossings
        if ismember(highlightedPoint, updatedCrossings)
            % Remove the point if it's already selected
            updatedCrossings(updatedCrossings == highlightedPoint) = [];
        else
            % Add the point if it's not already selected
            updatedCrossings = sort([updatedCrossings(:); highlightedPoint]);
        end
        
        % Sort the updated crossings
        updatedCrossings = sort(updatedCrossings);
        
        % Update plot without resetting the axis limits
        ax = gca;
        currentXLim = ax.XLim;
        currentYLim = ax.YLim;
        
        % Clear only the scatter points and redraw the necessary parts
        delete(findobj(gca, 'Type', 'scatter'));
        plot(zrRef, 'b'); % Plot the data line
        hold on;
        scatter(updatedCrossings, zrRef(updatedCrossings), 'g', 'filled'); % Plot the updated points
        if ishandle(highlightMarker)
            scatter(highlightedPoint, zrRef(highlightedPoint), 50, 'g', 'filled'); % Keep the highlighted point (smaller size)
        end
        hold off;
        
        % Restore axis limits to maintain zoom level
        ax.XLim = currentXLim;
        ax.YLim = currentYLim;
    end

    function confirmChanges(~, ~)
        uiresume(f); % Resume main code execution
        close(f);    % Close the figure window
    end

    function cancelChanges(~, ~)
        disp('Анализ завершен.');
        uiresume(f); % Resume main code execution
        close(f); % Close the figure window without saving changes
    end
end
