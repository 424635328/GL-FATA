%% CEC2022 数据深度分析脚本
% 说明：读取 CEC2022_Data.mat 并生成统计图表
% 注意：此代码仅分析最终结果，因为原始数据未保存收敛曲线数据。

clear; clc; close all;

%% 1. 加载数据
data_file = 'CEC2022_Data.mat';
if ~exist(data_file, 'file')
    error(['找不到文件: ', data_file, '，请先运行主程序生成数据。']);
end
load(data_file, 'SavedData');

% 自动解析数据结构
valid_funcs = find(~cellfun(@isempty, {SavedData.F.Alg})); % 找到有数据的函数索引
if isempty(valid_funcs)
    error('数据结构为空或损坏。');
end

% 获取算法名称列表（基于第一个有效函数）
First_F = SavedData.F(valid_funcs(1));
Algo_Names = {First_F.Alg.Name};
Algo_Names = strrep(Algo_Names, '_', '-');
Num_Algos = length(Algo_Names);
Num_Funcs = length(valid_funcs);
Func_Names = arrayfun(@(x) ['F', num2str(x)], valid_funcs, 'UniformOutput', false);

disp(['检测到 ', num2str(Num_Funcs), ' 个测试函数，', num2str(Num_Algos), ' 个对比算法。']);

%% 2. 数据提取与矩阵构建
% 初始化矩阵：行=函数，列=算法
Mean_Mat = zeros(Num_Funcs, Num_Algos);
Std_Mat  = zeros(Num_Funcs, Num_Algos);
Time_Mat = zeros(Num_Funcs, Num_Algos);
Rank_Mat = zeros(Num_Funcs, Num_Algos); % 用于Friedman

% 存储原始数据用于箱型图
All_Data_Cell = cell(Num_Funcs, 1); 

for i = 1:Num_Funcs
    f_idx = valid_funcs(i);
    current_f_data = [];
    
    for j = 1:Num_Algos
        % 提取适应度
        fits = SavedData.F(f_idx).Alg(j).Fitness;
        times = SavedData.F(f_idx).Alg(j).Time;
        
        % 移除 NaN (未运行的数据)
        fits = fits(~isnan(fits));
        times = times(~isnan(times));
        
        if isempty(fits)
            Mean_Mat(i, j) = NaN;
            Std_Mat(i, j) = NaN;
            Time_Mat(i, j) = NaN;
        else
            Mean_Mat(i, j) = mean(fits);
            Std_Mat(i, j) = std(fits);
            Time_Mat(i, j) = mean(times);
        end
        
        % 收集用于箱型图
        % 补齐长度以防不同算法运行次数不一致（虽不常见）
        current_f_data = PadAndConcat(current_f_data, fits);
    end
    
    All_Data_Cell{i} = current_f_data;
    
    % 计算当前函数的排名 (越小越好)
    Rank_Mat(i, :) = tiedrank(Mean_Mat(i, :));
end

%% 3. 可视化：高质量箱型图
% 定义颜色 (参考原始代码)
mycolor = [
    0.85 0.33 0.10; % Algo 1
    0.47 0.67 0.19; % Algo 2
    0.00 0.45 0.74; % Algo 3
    0.93 0.69 0.13; % Algo 4
    0.49 0.18 0.56; % Algo 5
    0.30 0.75 0.93; % Algo 6
    0.63 0.08 0.18; % Algo 7
    0.50 0.50 0.50  % Backup
];

figure('Name', 'BoxPlots Analysis', 'Color', 'w', 'Position', [100 100 1400 800]);
rows = ceil(Num_Funcs / 4);
for i = 1:Num_Funcs
    subplot(rows, 4, i);
    
    % 绘图
    data_to_plot = All_Data_Cell{i};
    if isempty(data_to_plot), continue; end
    
    box_handle = boxplot(data_to_plot, 'Symbol', '+', 'OutlierSize', 3);
    
    % 美化箱型图颜色
    h = findobj(gca, 'Tag', 'Box');
    num_boxes = size(data_to_plot, 2);
    for j = 1:num_boxes
        patch_idx = num_boxes - j + 1; % boxplot 句柄顺序是反的
        if patch_idx <= size(mycolor, 1)
            patch(get(h(j),'XData'), get(h(j),'YData'), mycolor(patch_idx,:), ...
                'FaceAlpha', 0.6, 'EdgeColor', 'none');
        end
    end
    
    set(gca, 'XTickLabel', Algo_Names, 'FontSize', 8);
    xtickangle(45);
    title(Func_Names{i}, 'FontWeight', 'bold');
    grid on;
    set(gca, 'GridAlpha', 0.3);
end
sgtitle('CEC2022 Algorithm Fitness Distribution');

%% 4. 可视化：Friedman 平均排名 (Bar Chart)
Mean_Ranks = mean(Rank_Mat, 1, 'omitnan');
[Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
Sorted_Names = Algo_Names(Sort_Idx);

figure('Name', 'Friedman Mean Rank', 'Color', 'w', 'Position', [100 100 800 500]);
b = bar(Sorted_Ranks);
b.FaceColor = 'flat';
b.CData = mycolor(Sort_Idx, :); % 保持颜色与算法对应
text(1:length(Sorted_Ranks), Sorted_Ranks, num2str(Sorted_Ranks', '%.2f'), ...
    'vert', 'bottom', 'horiz', 'center', 'FontSize', 10);

ylabel('Mean Rank (Lower is Better)');
title('Friedman Test - Average Ranking');
set(gca, 'XTickLabel', Sorted_Names, 'FontSize', 11);
xtickangle(0);
grid on;

%% 5. 统计分析：Wilcoxon 秩和检验 (相对于第一个算法)
disp('==========================================================');
disp(['Wilcoxon Rank Sum Test (Reference Algorithm: ', Algo_Names{1}, ')']);
disp('Symbol: "+" = Reference is significantly better');
disp('        "-" = Reference is significantly worse');
disp('        "=" = No significant difference (p > 0.05)');
disp('==========================================================');

% 表头
fprintf('%-6s', 'Func');
for j = 2:Num_Algos
    fprintf('| %-10s ', Algo_Names{j});
end
fprintf('\n');

P_Value_Mat = zeros(Num_Funcs, Num_Algos-1);
Sign_Mat = strings(Num_Funcs, Num_Algos-1);

for i = 1:Num_Funcs
    fprintf('%-6s', Func_Names{i});
    
    % 获取基准算法数据 (假设它是第1个)
    ref_data = All_Data_Cell{i}(:, 1);
    ref_data = ref_data(~isnan(ref_data));
    
    for j = 2:Num_Algos
        comp_data = All_Data_Cell{i}(:, j);
        comp_data = comp_data(~isnan(comp_data));
        
        if isempty(ref_data) || isempty(comp_data)
            p = 1; 
            sym = '=';
        else
            p = ranksum(ref_data, comp_data);
        end
        
        if p < 0.05
            if mean(ref_data) < mean(comp_data)
                sym = '+'; % Ref 更好 (CEC是最小值优化)
            else
                sym = '-'; % Ref 更差
            end
        else
            sym = '=';
        end
        
        fprintf('| %-1s (%.1e) ', sym, p);
        
        P_Value_Mat(i, j-1) = p;
        Sign_Mat(i, j-1) = sym;
    end
    fprintf('\n');
end

%% 6. 可视化：计算耗时对比
figure('Name', 'Execution Time Analysis', 'Color', 'w', 'Position', [100 100 1000 600]);
b_time = bar(Time_Mat);
ylabel('Average Time (seconds)');
xlabel('Functions');
legend(Algo_Names, 'Location', 'best', 'Orientation', 'horizontal');
set(gca, 'XTickLabel', Func_Names);
title('Computational Cost Comparison');
grid on;

%% 7. 综合排名雷达图 (终极防遮挡优化版)
% 修复：底部标签被裁剪、填充色遮挡线条、画布边距不足的问题

figure('Name', 'Rank Radar Analysis', 'Color', 'w', 'Position', [100 50 900 850]); % 稍微调高高度

% --- 数据准备 ---
[n_vars, n_algos] = size(Rank_Mat);
angles = linspace(0, 2*pi, n_vars + 1);

% 动态确定最大刻度
max_rank_val = max(Rank_Mat(:));
max_radius = ceil(max_rank_val); 

% 样式定义
markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
linestyles = {'-', '-', '--', '-.', ':', '-', '--'};
markers = repmat(markers, 1, ceil(n_algos/length(markers)));
linestyles = repmat(linestyles, 1, ceil(n_algos/length(linestyles)));

% --- 1. 绘制背景网格 ---
hold on; axis equal; axis off;

% 绘制同心圆/多边形网格
grid_levels = 1:max_radius;
for i = grid_levels
    r_grid = repmat(i, 1, n_vars + 1);
    x_grid = r_grid .* cos(angles);
    y_grid = r_grid .* sin(angles);
    
    if i == max_radius
        plot(x_grid, y_grid, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0); % 外框
    else
        plot(x_grid, y_grid, '-', 'Color', [0.9 0.9 0.9], 'LineWidth', 0.5); % 内网格更淡
    end
    
    % 刻度数字
    text(0, i, num2str(i), 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, ...
        'Color', [0.5 0.5 0.5], 'BackgroundColor', 'w', 'Margin', 0.1);
end

% 绘制放射线
max_r_vec = repmat(max_radius, 1, n_vars + 1);
x_out = max_r_vec .* cos(angles);
y_out = max_r_vec .* sin(angles);
for i = 1:n_vars
    plot([0 x_out(i)], [0 y_out(i)], '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5);
    
    % --- 标签位置计算 (关键修改) ---
    % 增加偏移量：从 1.12 增加到 1.2，给文字留足空间
    label_radius = max_radius * 1.2; 
    lx = label_radius * cos(angles(i));
    ly = label_radius * sin(angles(i));
    
    % 智能对齐
    if abs(lx) < 0.1
        horz_align = 'center';
    elseif lx > 0
        horz_align = 'left';
    else
        horz_align = 'right';
    end
    
    text(lx, ly, Func_Names{i}, 'HorizontalAlignment', horz_align, ...
        'FontWeight', 'bold', 'FontSize', 10, 'Interpreter', 'none');
end

% --- 2. 绘制数据 (图层管理) ---
avg_ranks = mean(Rank_Mat, 1);
[~, sort_indices] = sort(avg_ranks, 'descend'); % 差的在下，好的在上

legend_h = gobjects(n_algos, 1);
legend_str = cell(n_algos, 1);

for k = 1:n_algos
    j = sort_indices(k); 
    ranks = Rank_Mat(:, j)';
    data_closed = [ranks, ranks(1)];
    
    x_data = data_closed .* cos(angles);
    y_data = data_closed .* sin(angles);
    
    col = mycolor(mod(j-1, size(mycolor,1))+1, :);
    is_best = (j == sort_indices(end)); 
    
    if is_best
        lw = 2.5; 
        fa = 0.08; % 降低最优算法透明度 (从0.15降到0.08)，减少对下方线条的遮挡
        line_style = '-';
        m_size = 6;
    else
        lw = 1.0; 
        fa = 0.0; % 其他算法完全不填充，彻底解决背景杂乱问题
        line_style = linestyles{k};
        m_size = 5;
    end
    
    % 填充 (仅最优算法填充淡淡的一层，其他的只画线)
    if is_best
        fill(x_data, y_data, col, 'FaceAlpha', fa, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    
    % 画线
    legend_h(k) = plot(x_data, y_data, ...
        'Color', col, ...
        'LineWidth', lw, ...
        'LineStyle', line_style, ...
        'Marker', markers{k}, ...
        'MarkerSize', m_size, ...
        'MarkerFaceColor', 'none'); % 改为空心，透过标记可以看到下面的线
        
    legend_str{k} = Algo_Names{j};
end

% --- 3. 关键修复：强制设置坐标轴范围 ---
% MATLAB 默认不会把 text 算进范围里，所以必须手动设置 padding
padding = max_radius * 1.4; % 预留 40% 的边距给标签和标题
xlim([-padding, padding]);
ylim([-padding, padding]);

% 图例重排
[~, original_order_idx] = sort(sort_indices); 
real_handles = legend_h(original_order_idx);
real_names = Algo_Names;

lgd = legend(real_handles, real_names, ...
    'Location', 'bestoutside', ... 
    'FontSize', 9);
title(lgd, 'Algorithms');

% 标题
title({'Algorithm Rank Stability Analysis'; '(Center=1=Best)'}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

hold off;
%% 辅助函数：处理不同长度数组的拼接
function out = PadAndConcat(existing_mat, new_col)
    n_rows = size(existing_mat, 1);
    new_len = length(new_col);
    
    if isempty(existing_mat)
        out = new_col(:); % 确保是列向量
        return;
    end
    
    if new_len > n_rows
        % 扩展现有矩阵
        padding = nan(new_len - n_rows, size(existing_mat, 2));
        existing_mat = [existing_mat; padding];
    elseif new_len < n_rows
        % 扩展新列
        new_col = [new_col(:); nan(n_rows - new_len, 1)];
    end
    
    out = [existing_mat, new_col(:)];
end