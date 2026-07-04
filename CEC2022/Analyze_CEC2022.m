%% CEC2022 数据深度分析脚本
% 说明：读取 CEC2022_Data.mat 并生成统计图表
% 优化：加入对数坐标轴处理跑飞的异常值，采用矢量渲染解决图像模糊问题

clear; clc; close all;

% ==========================================
% 定义学术规范字体
cn_font = '宋体';
en_font = 'Times New Roman';
% ==========================================

%% 1. 加载数据
data_file = 'CEC2022_Data.mat';
if ~exist(data_file, 'file')
    error(['找不到文件: ', data_file, '，请先运行主程序生成数据。']);
end
load(data_file, 'SavedData');

% 自动解析数据结构
valid_funcs = find(~cellfun(@isempty, {SavedData.F.Alg})); 
if isempty(valid_funcs)
    error('数据结构为空或损坏。');
end

% 获取算法名称列表
First_F = SavedData.F(valid_funcs(1));
Algo_Names = {First_F.Alg.Name};
Algo_Names = strrep(Algo_Names, '_', '-');
Num_Algos = length(Algo_Names);
Num_Funcs = length(valid_funcs);
Func_Names = arrayfun(@(x) ['F', num2str(x)], valid_funcs, 'UniformOutput', false);

disp(['检测到 ', num2str(Num_Funcs), ' 个测试函数，', num2str(Num_Algos), ' 个对比算法。']);

%% 2. 数据提取与矩阵构建
Mean_Mat = zeros(Num_Funcs, Num_Algos);
Std_Mat  = zeros(Num_Funcs, Num_Algos);
Time_Mat = zeros(Num_Funcs, Num_Algos);
Rank_Mat = zeros(Num_Funcs, Num_Algos); 
All_Data_Cell = cell(Num_Funcs, 1); 

for i = 1:Num_Funcs
    f_idx = valid_funcs(i);
    current_f_data = [];
    
    for j = 1:Num_Algos
        fits = SavedData.F(f_idx).Alg(j).Fitness;
        times = SavedData.F(f_idx).Alg(j).Time;
        
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
        current_f_data = PadAndConcat(current_f_data, fits);
    end
    All_Data_Cell{i} = current_f_data;
    Rank_Mat(i, :) = tiedrank(Mean_Mat(i, :));
end

%% 3. 可视化：高质量箱型图 (优化版)
mycolor = [
    0.85 0.33 0.10; 0.47 0.67 0.19; 0.00 0.45 0.74; 0.93 0.69 0.13; 
    0.49 0.18 0.56; 0.30 0.75 0.93; 0.63 0.08 0.18; 0.50 0.50 0.50
];

% 【优化】添加 'Renderer', 'painters' 强制矢量渲染，彻底解决坐标轴模糊问题
figure('Name', '适应度分布箱线图', 'Color', 'w', 'Position', [100 100 1400 800], 'Renderer', 'painters');
rows = ceil(Num_Funcs / 4);
for i = 1:Num_Funcs
    subplot(rows, 4, i);
    data_to_plot = All_Data_Cell{i};
    if isempty(data_to_plot), continue; end
    
    % 【优化】防止有0值导致对数坐标报错，将极小值截断为 1e-12（仅为画图不报错，不影响实际评估）
    data_to_plot(data_to_plot <= 0) = 1e-12; 
    
    % 【优化】增加异常值的大小，设置箱体线条粗细让图表更清晰
    box_handle = boxplot(data_to_plot, 'Symbol', 'o', 'OutlierSize', 4, 'Widths', 0.5);
    set(box_handle, 'LineWidth', 1.2); % 加粗线条
    
    h = findobj(gca, 'Tag', 'Box');
    num_boxes = size(data_to_plot, 2);
    for j = 1:num_boxes
        patch_idx = num_boxes - j + 1; 
        if patch_idx <= size(mycolor, 1)
            patch(get(h(j),'XData'), get(h(j),'YData'), mycolor(patch_idx,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
        end
    end
    
    % 【核心优化】设置 Y 轴为对数尺度，完美解决“算法跑飞导致箱线图压扁”的问题
    set(gca, 'YScale', 'log');
    
    % 设置刻度数字/英文算法名为 Times New Roman
    set(gca, 'FontName', en_font);
    set(gca, 'XTickLabel', Algo_Names, 'FontSize', 8, 'FontName', en_font);
    xtickangle(45);
    
    % 标题为纯英文 F1, F2... 使用 Times New Roman
    title(Func_Names{i}, 'FontWeight', 'bold', 'FontName', en_font);
    
    % 【优化】只开启 Y 轴网格和次级网格，避免 X 轴网格线干扰视线
    grid on; set(gca, 'GridAlpha', 0.3, 'XGrid', 'off', 'YMinorGrid', 'on', 'MinorGridAlpha', 0.15);
end
% 标题中英混排，利用 TeX 语法精准控制字体
sgtitle(['\fontname{', en_font, '}CEC2022 \fontname{', cn_font, '}测试函数适应度分布箱线图'], 'FontWeight', 'bold', 'FontSize', 16);

% =========================================================================
global_ax = axes('Position', [0.12, 0.12, 0.78, 0.78], 'Visible', 'off', 'HitTest', 'off'); 
global_ax.XLabel.Visible = 'on'; global_ax.YLabel.Visible = 'on';

% 纯中文使用宋体
xlabel(global_ax, '算 法 变 体', 'FontSize', 18, 'FontWeight', 'normal', 'FontName', cn_font, 'Color', 'k', ...
    'Units', 'normalized', 'Position', [0.5, -0.09, 0]);

% 【优化】Y轴标签注明这是对数尺度
ylabel(global_ax, '适 应 度 值', 'FontSize', 18, 'FontWeight', 'normal', 'FontName', cn_font, 'Color', 'k', ...
    'Units', 'normalized', 'Position', [-0.07, 0.5, 0]);
% =========================================================================

%% 4. 可视化：Friedman 平均排名 (Bar Chart)
Mean_Ranks = mean(Rank_Mat, 1, 'omitnan');
[Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
Sorted_Names = Algo_Names(Sort_Idx);

figure('Name', 'Friedman 平均排名', 'Color', 'w', 'Position', [100 100 800 500], 'Renderer', 'painters');
b = bar(Sorted_Ranks); b.FaceColor = 'flat'; b.CData = mycolor(Sort_Idx, :);

text(1:length(Sorted_Ranks), Sorted_Ranks, num2str(Sorted_Ranks', '%.2f'), ...
    'vert', 'bottom', 'horiz', 'center', 'FontSize', 10, 'FontName', en_font);

set(gca, 'FontName', en_font);
ylabel('平均排名 (越小越好)', 'FontSize', 11, 'FontName', cn_font);
title(['\fontname{', en_font, '}Friedman \fontname{', cn_font, '}检验 - 算法平均排名'], 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'XTickLabel', Sorted_Names, 'FontSize', 11, 'FontName', en_font);
xtickangle(0); grid on;

%% 5. 统计分析：Wilcoxon 秩和检验 (相对于第一个算法)
disp('==========================================================');
disp(['Wilcoxon 秩和检验 (基准算法: ', Algo_Names{1}, ')']);
disp('符号: "+" = 基准算法显著更优');
disp('      "-" = 基准算法显著较差');
disp('      "=" = 无显著差异 (p > 0.05)');
disp('==========================================================');

fprintf('%-6s', '函数');
for j = 2:Num_Algos, fprintf('| %-10s ', Algo_Names{j}); end
fprintf('\n');

for i = 1:Num_Funcs
    fprintf('%-6s', Func_Names{i});
    ref_data = All_Data_Cell{i}(:, 1); ref_data = ref_data(~isnan(ref_data));
    
    for j = 2:Num_Algos
        comp_data = All_Data_Cell{i}(:, j); comp_data = comp_data(~isnan(comp_data));
        if isempty(ref_data) || isempty(comp_data)
            p = 1; sym = '=';
        else
            p = ranksum(ref_data, comp_data);
        end
        if p < 0.05
            if mean(ref_data) < mean(comp_data), sym = '+'; else, sym = '-'; end
        else
            sym = '=';
        end
        fprintf('| %-1s (%.1e) ', sym, p);
    end
    fprintf('\n');
end

%% 6. 可视化：计算耗时对比
figure('Name', '计算耗时分析', 'Color', 'w', 'Position', [100 100 1000 600], 'Renderer', 'painters');
b_time = bar(Time_Mat);

set(gca, 'FontName', en_font); 
ylabel('平均运行耗时 (秒)', 'FontSize', 11, 'FontName', cn_font);
xlabel('测试函数', 'FontSize', 11, 'FontName', cn_font);

lgd_time = legend(Algo_Names, 'Location', 'best', 'Orientation', 'horizontal', 'FontName', en_font);
title(lgd_time, '对比算法', 'FontName', cn_font);
set(gca, 'XTickLabel', Func_Names, 'FontName', en_font);

title(['\fontname{', cn_font, '}各算法在 \fontname{', en_font, '}CEC2022 \fontname{', cn_font, '}测试集上的计算耗时对比'], 'FontSize', 14, 'FontWeight', 'bold');
grid on;

%% 7. 综合排名雷达图 
figure('Name', '排名雷达图分析', 'Color', 'w', 'Position', [100 50 900 850], 'Renderer', 'painters'); 
[n_vars, n_algos] = size(Rank_Mat);
angles = linspace(0, 2*pi, n_vars + 1);
max_radius = ceil(max(Rank_Mat(:))); 

markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
linestyles = {'-', '-', '--', '-.', ':', '-', '--'};
markers = repmat(markers, 1, ceil(n_algos/length(markers)));
linestyles = repmat(linestyles, 1, ceil(n_algos/length(linestyles)));

hold on; axis equal; axis off;
for i = 1:max_radius
    r_grid = repmat(i, 1, n_vars + 1);
    x_grid = r_grid .* cos(angles); y_grid = r_grid .* sin(angles);
    
    if i == max_radius, plot(x_grid, y_grid, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0); 
    else, plot(x_grid, y_grid, '-', 'Color', [0.9 0.9 0.9], 'LineWidth', 0.5); end
    
    text(0, i, num2str(i), 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, ...
        'Color', [0.5 0.5 0.5], 'BackgroundColor', 'w', 'Margin', 0.1, 'FontName', en_font);
end

max_r_vec = repmat(max_radius, 1, n_vars + 1);
x_out = max_r_vec .* cos(angles); y_out = max_r_vec .* sin(angles);
for i = 1:n_vars
    plot([0 x_out(i)], [0 y_out(i)], '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5);
    label_radius = max_radius * 1.2; 
    lx = label_radius * cos(angles(i)); ly = label_radius * sin(angles(i));
    if abs(lx) < 0.1, horz_align = 'center'; elseif lx > 0, horz_align = 'left'; else, horz_align = 'right'; end
    
    text(lx, ly, Func_Names{i}, 'HorizontalAlignment', horz_align, ...
        'FontWeight', 'bold', 'FontSize', 11, 'Interpreter', 'none', 'FontName', en_font);
end

avg_ranks = mean(Rank_Mat, 1);
[~, sort_indices] = sort(avg_ranks, 'descend'); 
legend_h = gobjects(n_algos, 1);
for k = 1:n_algos
    j = sort_indices(k); ranks = Rank_Mat(:, j)'; data_closed = [ranks, ranks(1)];
    x_data = data_closed .* cos(angles); y_data = data_closed .* sin(angles);
    col = mycolor(mod(j-1, size(mycolor,1))+1, :); is_best = (j == sort_indices(end)); 
    
    if is_best, lw = 2.5; fa = 0.08; line_style = '-'; m_size = 6;
    else, lw = 1.0; fa = 0.0; line_style = linestyles{k}; m_size = 5; end
    
    if is_best, fill(x_data, y_data, col, 'FaceAlpha', fa, 'EdgeColor', 'none', 'HandleVisibility', 'off'); end
    legend_h(k) = plot(x_data, y_data, 'Color', col, 'LineWidth', lw, 'LineStyle', line_style, 'Marker', markers{k}, 'MarkerSize', m_size, 'MarkerFaceColor', 'none'); 
end

padding = max_radius * 1.4; 
xlim([-padding, padding]); ylim([-padding, padding]);
[~, original_order_idx] = sort(sort_indices); real_handles = legend_h(original_order_idx);

lgd = legend(real_handles, Algo_Names, 'Location', 'bestoutside', 'FontSize', 9, 'FontName', en_font);
title(lgd, '对比算法', 'FontName', cn_font);

title({['\fontname{', cn_font, '}算法排名稳定性分析雷达图']; ...
       ['\fontname{', cn_font, '}(中心\fontname{', en_font, '}=1=\fontname{', cn_font, '}最优)']}, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');
hold off;

%% 辅助函数
function out = PadAndConcat(existing_mat, new_col)
    n_rows = size(existing_mat, 1); new_len = length(new_col);
    if isempty(existing_mat), out = new_col(:); return; end
    if new_len > n_rows
        padding = nan(new_len - n_rows, size(existing_mat, 2));
        existing_mat = [existing_mat; padding];
    elseif new_len < n_rows
        new_col = [new_col(:); nan(n_rows - new_len, 1)];
    end
    out = [existing_mat, new_col(:)];
end