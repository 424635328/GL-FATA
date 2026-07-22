%% CEC2022 深度数据分析与可视化制图 (剔除 DBO，输出附录级表格)
clear; clc; close all;

cn_font = 'Microsoft YaHei'; % 统一中文字体，防止乱码

data_file = 'CEC2022_Data.mat';
if ~exist(data_file, 'file'), error(['找不到文件: ', data_file]); end
load(data_file, 'SavedData');

% =========================================================================
% 明确指定需要进行分析和制图的目标算法 (精准剔除 DBO 及其他不需要的算法)
% 注意：请确保 GL_FATA 放在第一位，作为 Wilcoxon 检验的基准
Target_Algos = {
    'GL_FATA', 'GL-FATA';
    'MFATA_Levy', 'MFATA-Levy';
    'IMFATA', 'IMFATA';
    'ASFSSA', 'ASFSSA';
    'PSO', 'PSO';
    'FATA', 'FATA';
    'GWO', 'GWO';
    'SSA', 'SSA'
};
% =========================================================================

Algo_Keys = Target_Algos(:, 1);
Algo_Names = Target_Algos(:, 2)';
Num_Algos = length(Algo_Keys);

valid_funcs = find(~cellfun(@isempty, {SavedData.F.Alg})); 
Num_Funcs = length(valid_funcs);
Func_Names = arrayfun(@(x) ['F', num2str(x)], valid_funcs, 'UniformOutput', false);

Mean_Mat = zeros(Num_Funcs, Num_Algos);
Rank_Mat = zeros(Num_Funcs, Num_Algos);
Time_Mat = zeros(Num_Funcs, Num_Algos); 
All_Data_Cell = cell(Num_Funcs, 1); 

% 1. 数据提取与过滤
for i = 1:Num_Funcs
    f_idx = valid_funcs(i);
    current_f_data = [];
    
    for j = 1:Num_Algos
        target_key = Algo_Keys{j};
        
        % 在历史数据中寻找匹配的算法
        match_idx = [];
        for k = 1:length(SavedData.F(f_idx).Alg)
            if strcmp(SavedData.F(f_idx).Alg(k).Name, target_key)
                match_idx = k; break;
            end
        end
        
        if ~isempty(match_idx)
            fits = SavedData.F(f_idx).Alg(match_idx).Fitness;
            fits = fits(~isnan(fits));
            if isempty(fits), Mean_Mat(i, j) = NaN; else, Mean_Mat(i, j) = mean(fits); end
            
            if isfield(SavedData.F(f_idx).Alg(match_idx), 'Time')
                times = SavedData.F(f_idx).Alg(match_idx).Time;
                times = times(~isnan(times));
                if isempty(times), Time_Mat(i, j) = NaN; else, Time_Mat(i, j) = mean(times); end
            else
                Time_Mat(i, j) = NaN;
            end
        else
            fits = []; Mean_Mat(i, j) = NaN; Time_Mat(i, j) = NaN;
        end
        
        current_f_data = PadAndConcat(current_f_data, fits);
    end
    All_Data_Cell{i} = current_f_data;
    Rank_Mat(i, :) = tiedrank(Mean_Mat(i, :));
end

% 对应 8 个目标算法的颜色库
mycolor = [
    0.85 0.33 0.10; % GL_FATA (橙红)
    0.47 0.67 0.19; % MFATA-Levy (草绿)
    0.93 0.69 0.13; % IMFATA  (黄/金)
    0.00 0.45 0.74; % ASFSSA (蓝)
    0.30 0.50 0.93; % PSO (灰蓝)
    0.10 0.40 0.20; % FATA (深绿)
    0.63 0.08 0.18; % GWO (深红)
    0.50 0.50 0.50  % SSA (灰)
];

%% ================== 控制台文本输出（完整统计表） ==================
disp('================================================================');
disp('A.2 Friedman 非参数检验结果');
disp('Summary');
disp(['Rank', char(9), 'Algorithm', char(9), 'Mean Rank']);

Mean_Ranks = mean(Rank_Mat, 1, 'omitnan');
[Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
Sorted_Names = Algo_Names(Sort_Idx);

for i = 1:Num_Algos
    fprintf('%d\t%s\t%.4f\n', i, Sorted_Names{i}, Sorted_Ranks(i));
end

disp(' ');
disp('Details');
fprintf('Function\t');
for j = 1:Num_Algos
    fprintf('%s\t', Algo_Names{j});
end
fprintf('\n');

for i = 1:Num_Funcs
    fprintf('F%d\t', valid_funcs(i));
    for j = 1:Num_Algos
        fprintf('%g\t', Rank_Mat(i, j));
    end
    fprintf('\n');
end
disp('================================================================');

disp('A.3 Wilcoxon 秩和检验结果');
fprintf('Function\t');
for j = 2:Num_Algos
    fprintf('%s\t', Algo_Names{j});
end
fprintf('\n');

WTL_Count = zeros(3, Num_Algos - 1); % Win, Tie, Loss 统计

for i = 1:Num_Funcs
    fprintf('F%d\t', valid_funcs(i));
    
    ref_data = All_Data_Cell{i}(:, 1);
    ref_data = ref_data(~isnan(ref_data));
    
    for j = 2:Num_Algos
        comp_data = All_Data_Cell{i}(:, j);
        comp_data = comp_data(~isnan(comp_data));
        
        if isempty(ref_data) || isempty(comp_data)
            p = 1; sym = '=';
        else
            p = ranksum(ref_data, comp_data);
            if isnan(p), p = 1; end
        end
        
        if p < 0.05
            if mean(ref_data) < mean(comp_data)
                sym = '+'; WTL_Count(1, j-1) = WTL_Count(1, j-1) + 1;
            else
                sym = '-'; WTL_Count(3, j-1) = WTL_Count(3, j-1) + 1;
            end
        else
            sym = '='; WTL_Count(2, j-1) = WTL_Count(2, j-1) + 1;
        end
        
        fprintf('%s (%.2e)\t', sym, p);
    end
    fprintf('\n');
end

fprintf('Total (+/=/−)\t');
for j = 1:(Num_Algos - 1)
    fprintf('%d / %d / %d\t', WTL_Count(1, j), WTL_Count(2, j), WTL_Count(3, j));
end
fprintf('\n');
disp('================================================================');

%% ================== 制图模块 ==================

% 1. 可视化：高质量箱型图 
figure('Name', '适应度分布箱线图', 'Color', 'w', 'Position', [50 50 1400 800]);
rows = ceil(Num_Funcs / 4);
for i = 1:Num_Funcs
    subplot(rows, 4, i);
    data_to_plot = All_Data_Cell{i};
    if isempty(data_to_plot), continue; end
    
    box_handle = boxplot(data_to_plot, 'Symbol', '+', 'OutlierSize', 3);
    h = findobj(gca, 'Tag', 'Box');
    num_boxes = size(data_to_plot, 2);
    for j = 1:num_boxes
        patch_idx = num_boxes - j + 1; 
        if patch_idx <= size(mycolor, 1)
            patch(get(h(j),'XData'), get(h(j),'YData'), mycolor(patch_idx,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        end
    end
    set(gca, 'XTickLabel', Algo_Names, 'FontSize', 8, 'FontName', cn_font);
    xtickangle(45); title(Func_Names{i}, 'FontWeight', 'bold', 'FontName', cn_font);
    grid on; set(gca, 'GridAlpha', 0.3);
end
sgtitle('CEC2022 测试函数适应度分布箱线图', 'FontSize', 16, 'FontWeight', 'bold', 'FontName', cn_font);

% 2. Friedman 平均排名柱状图
figure('Name', 'Friedman 平均排名', 'Color', 'w', 'Position', [100 100 800 500]);
b = bar(Sorted_Ranks); b.FaceColor = 'flat'; b.CData = mycolor(Sort_Idx, :);
text(1:length(Sorted_Ranks), Sorted_Ranks, num2str(Sorted_Ranks', '%.2f'), 'vert', 'bottom', 'horiz', 'center', 'FontSize', 10, 'FontName', cn_font);
ylabel('平均排名 (越小越好)', 'FontName', cn_font);
title('Friedman 检验 - 算法平均排名', 'FontName', cn_font, 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'XTickLabel', Sorted_Names, 'FontSize', 11, 'FontName', cn_font); grid on;

% 3. 综合排名雷达图 
figure('Name', '算法排名稳定性分析雷达图', 'Color', 'w', 'Position', [100 50 900 850]);
angles = linspace(0, 2*pi, Num_Funcs + 1);
max_radius = ceil(max(Rank_Mat(:))); 

markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
linestyles = {'-', '-', '--', '-.', ':', '-', '--', '-', '-.'};
markers = repmat(markers, 1, ceil(Num_Algos/length(markers)));
linestyles = repmat(linestyles, 1, ceil(Num_Algos/length(linestyles)));

hold on; axis equal; axis off;
for i = 1:max_radius
    r_grid = repmat(i, 1, Num_Funcs + 1);
    x_grid = r_grid .* cos(angles); y_grid = r_grid .* sin(angles);
    if i == max_radius, plot(x_grid, y_grid, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0); 
    else, plot(x_grid, y_grid, '-', 'Color', [0.9 0.9 0.9], 'LineWidth', 0.5); end
    text(0, i, num2str(i), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.5 0.5 0.5], 'BackgroundColor', 'w', 'Margin', 0.1, 'FontName', cn_font);
end

max_r_vec = repmat(max_radius, 1, Num_Funcs + 1);
x_out = max_r_vec .* cos(angles); y_out = max_r_vec .* sin(angles);
for i = 1:Num_Funcs
    plot([0 x_out(i)], [0 y_out(i)], '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5);
    label_radius = max_radius * 1.2; 
    lx = label_radius * cos(angles(i)); ly = label_radius * sin(angles(i));
    if abs(lx) < 0.1, horz_align = 'center'; elseif lx > 0, horz_align = 'left'; else, horz_align = 'right'; end
    text(lx, ly, Func_Names{i}, 'HorizontalAlignment', horz_align, 'FontWeight', 'bold', 'FontSize', 11, 'Interpreter', 'none', 'FontName', cn_font);
end

[~, sort_indices] = sort(Mean_Ranks, 'descend'); 
legend_h = gobjects(Num_Algos, 1);
for k = 1:Num_Algos
    j = sort_indices(k); 
    ranks = Rank_Mat(:, j)';
    data_closed = [ranks, ranks(1)];
    x_data = data_closed .* cos(angles); y_data = data_closed .* sin(angles);
    col = mycolor(mod(j-1, size(mycolor,1))+1, :);
    
    is_best = (j == sort_indices(end)); 
    if is_best
        lw = 2.5; fa = 0.08; line_style = '-'; m_size = 6;
        fill(x_data, y_data, col, 'FaceAlpha', fa, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    else
        lw = 1.0; fa = 0.0; line_style = linestyles{k}; m_size = 5;
    end
    legend_h(k) = plot(x_data, y_data, 'Color', col, 'LineWidth', lw, 'LineStyle', line_style, 'Marker', markers{k}, 'MarkerSize', m_size, 'MarkerFaceColor', 'none'); 
end

padding = max_radius * 1.4; 
xlim([-padding, padding]); ylim([-padding, padding]);
[~, original_order_idx] = sort(sort_indices); 
real_handles = legend_h(original_order_idx);
lgd = legend(real_handles, Algo_Names, 'Location', 'bestoutside', 'FontSize', 9, 'FontName', cn_font);
title(lgd, '对比算法', 'FontName', cn_font);
title({'算法排名稳定性分析雷达图'; '(中心=1=最优)'}, 'FontSize', 14, 'FontWeight', 'bold', 'FontName', cn_font);
hold off;

% 4. 运行时间（计算耗时）对比柱状图
figure('Name', '计算耗时对比', 'Color', 'w', 'Position', [150 150 1000 500]);
b_time = bar(Time_Mat, 'grouped');
for k = 1:Num_Algos
    b_time(k).FaceColor = mycolor(k, :);
    b_time(k).EdgeColor = 'none'; 
end
ylabel('平均运行耗时 (秒)', 'FontName', cn_font, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('测试函数', 'FontName', cn_font, 'FontSize', 11, 'FontWeight', 'bold');
title('各算法在 CEC2022 测试集上的计算耗时对比', 'FontName', cn_font, 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTick', 1:Num_Funcs, 'XTickLabel', Func_Names, 'FontSize', 10, 'FontName', cn_font);
lgd_time = legend(Algo_Names, 'Location', 'eastoutside', 'FontSize', 9, 'FontName', cn_font);
title(lgd_time, '对比算法', 'FontName', cn_font);
grid on; set(gca, 'GridAlpha', 0.3);

%% 辅助函数
function out = PadAndConcat(existing_mat, new_col)
    n_rows = size(existing_mat, 1); new_len = length(new_col);
    if isempty(existing_mat), out = new_col(:); return; end
    if new_len > n_rows, padding = nan(new_len - n_rows, size(existing_mat, 2)); existing_mat = [existing_mat; padding];
    elseif new_len < n_rows, new_col = [new_col(:); nan(n_rows - new_len, 1)]; end
    out = [existing_mat, new_col(:)];
end
