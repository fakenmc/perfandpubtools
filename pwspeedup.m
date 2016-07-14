function [avg_speedup, max_speedup, min_speedup, times, std_times, ...
    times_raw, fid, impl_legend, set_legend] = ...
    pwspeedup(do_plot, compare, varargin)
% PWSPEEDUP Determines pairwise speedups using folders of files containing
% benchmarking results, and optionally displays speedups in a bar plot.
%
% [s, smax, smin, t_avg, t_std, t_raw, fids, il, sl] = ...
%     SPEEDUP(do_plot, compare, varargin)
%
% Parameters:
%     do_plot - Draw speedup plot?
%                    -2 - Log plot (bars only) with error bars
%                    -1 - Regular plot with error bars
%                     0 - No plot
%                     1 - Regular plot
%                     2 - Log plot (bars only)
%    compare - Vector containing indexes of reference implementation from 
%              which to calculate speedups. Number of elements will 
%              determine number of plots.
%   varargin - Pairs of implementation name and implementation specs. An
%              implementation name is simply a string specifying the name
%              of an implementation. An implementation spec is a cell array
%              where each cell contains a struct with the following fields:
%                 sname - Name of setup, e.g. of series of runs with a 
%                         given parameter set.
%                folder - Folder with files containing benchmarking
%                         results.
%                files  - Name of files containing benchmarking results
%                         (use wildcards if necessary).
%                 csize - Computational size associated with setup (can be
%                         ignored if a plot was not requested).
%
% Output:
% avg_speedups - Cell array where each cell contains a matrix of average
%                speedups for a given implementation. Number of cells
%                depends on the number of elements in parameter "compare".
% max_speedups - Cell array where each cell contains a matrix of maximum
%                speedups for a given implementation. Number of cells
%                depends on the number of elements in parameter "compare".
% min_speedups - Cell array where each cell contains a matrix of minimum
%                speedups for a given implementation. Number of cells
%                depends on the number of elements in parameter "compare".
%        times - Matrix of average computational times where each row 
%                corresponds to an implementation and each column to a 
%                setup.
%    std_times - Matrix of the sample standard deviation of the 
%                computational times. Each row corresponds to an 
%                implementation and each column to a setup.
%    times_raw - Cell matrix where each cell contais a complete time struct 
%                for each setup. Rows correspond to implementations,
%                columns to setups.
%         fids - Figure IDs (only if doPlot == 1).
% impl_legends - Implementations legend.
%  set_legends - Setups legend.
%
%    
% Copyright (c) 2016 Nuno Fachada
% Distributed under the MIT License (See accompanying file LICENSE or copy 
% at http://opensource.org/licenses/MIT)
%

% compare must be a cell with two strings.
if ~iscellstr(compare) || numel(compare) ~= 2
    error('The "compare" argument must be a cell with two strings.');
end;

% Pairwise comparisons requires that name/spec pairs are themselves given
% in pairs
if mod(numel(varargin), 4) > 0
    error(['Pairwise speedups require that each '...
        'implementation name / implementation spec pair has a '...
        'corresponding name/spec pair.']);
end;         
        
% Number of pairs to compare
npairs = numel(varargin) / 4;
    
% Determine mean time and sample standard deviation for all implementations
% and setups
[times, std_times, times_raw, ~, impl_legend, set_legend] = ...
    perfstats(0, varargin{:});

% Use only first element of each pair for implementation legend
impl_legend = impl_legend((1:npairs) * 2 - 1);

% Get number of implementations and number of setups
[~, nset] = size(times);

% Setup output variables
avg_speedup = zeros(npairs, nset);
max_speedup = zeros(npairs, nset);
min_speedup = zeros(npairs, nset);
    
% Compare each pair
for pr = 1:npairs

    % Index of each pair
    pr1idx = pr * 2 - 1;
    pr2idx = pr * 2;

    % For each setup...
    for s = 1:nset

        % Determine speedups of pair 1 vs pair 2
        avg_speedup(pr, s) = ...
            times(pr2idx, s) / times(pr1idx, s);
        max_speedup(pr, s) = ...
            max(times_raw{pr2idx, s}.elapsed) / ...
            min(times_raw{pr1idx, s}.elapsed);
        min_speedup(pr, s) = ...
            min(times_raw{pr2idx, s}.elapsed) / ...
            max(times_raw{pr1idx, s}.elapsed);

    end;

end;

% Create a plot?
if do_plot
           
    % Create a new figure
    fid = figure();
        
    % Plot speedups versus the ith implementation
    if abs(do_plot) == 1
        % Y linear scale
        h = bar(avg_speedup);
    else
        % Y log scale requires this in Octave
        h = bar(avg_speedup, 'basevalue', 1);
    end;

    ylabel(['Speedup ' compare{1} ' vs ' compare{2}]);
    
    % Legends and x-ticks will be different if there is only one 
    % implementation to plot, or more than one implementation to plot
    
    if size(avg_speedup, 1) == 1 % Only one implementation
            
        % x tick labels will correspond to setup names
        set(gca, 'XTickLabel', set_legends);

        % Set x,y labels
        xlabel('Setups');

        % Draw error bars?
        hold on;
        if do_plot < 1

            % Determine x coord. for error bars
            if exist('OCTAVE_VERSION', 'builtin') ...
                || verLessThan('matlab', '8.4.0')
                % MATLAB <= R2014a or GNU Octave
                xdata = get(get(h, 'Children'), 'XData');
                xerrbpos = mean(xdata, 1);
            else
                % MATLAB >= 2014b
                xerrbpos =  get(h, 'XData');
            end;

            % Draw error bars
            errorbar(xerrbpos, avg_speedup, ...
                avg_speedup - min_speedup, ...
                max_speedup - avg_speedup, ...
                '+k');

        end;

    else % More than one implementation

        % x tick label will correspond to implementation names
        set(gca, 'XTickLabel', impl_legend);

        % Set legend for setups
        legend(set_legend);

        % Set x,y labels
        xlabel('Implementations');

        % Draw error bars?
        hold on;
        if do_plot < 1

            for i = 1:nset

                % Determine x coord. for error bars
                if exist('OCTAVE_VERSION', 'builtin') ...
                    || verLessThan('matlab', '8.4.0')
                    % MATLAB <= R2014a or GNU Octave
                    xdata = get(get(h(i), 'Children'), 'XData');
                    xerrbpos = mean(xdata, 1);
                else
                    % MATLAB >= 2014b
                    xerrbpos =  get(h(i), 'XData') + ...
                        get(h(i), 'XOffset');
                end;

                % Draw error bars
                errorbar(xerrbpos, avg_speedup(:, i), ...
                    avg_speedup(:, i) - min_speedup(:, i), ...
                    max_speedup(:, i) - avg_speedup(:, i), ...
                    '+k');

           end;

        end;            
    end;

    % Set grid
    grid on;

    % Log scale?
    if abs(do_plot) == 2
        set(gca, 'YScale', 'log');
    end;
 
end;