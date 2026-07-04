function Analyze_and_Plot_Results()
% =========================================================================
% GL_FATA 消融实验结果分析与绘图脚本 (Pro Version)
% 风格模仿：CEC2022 高级分析模板
% 功能：
% 1. 加载消融实验数据
% 2. 绘制高质量箱线图 (带自定义颜色填充，全局大横纵坐标)
% 3. 绘制 Friedman 平均排名图
% 4. 绘制排名雷达图 (展示稳定性)
% 5. 输出 Wilcoxon 检验统计表
% =========================================================================

clc; clear; close all;

%% 1. 全局样式与颜色定义
% 采用 CEC2022 模板的高级配色
mycolor = [
    0.85 0.33 0.10; % 橙红 (往往用于对比算法1)
    0.47 0.67 0.19; % 绿色
    0.00 0.45 0.74; % 蓝色
    0.93 0.69 0.13; % 黄色
    0.49 0.18 0.56; % 紫色
    0.30 0.75 0.93; % 浅蓝
    0.63 0.08 0.18; % 深红
    0.50 0.50 0.50  % 灰色
];

%% 2. 加载数据
FileName = 'Ablation_Experiment_Results.mat';
if ~exist(FileName, 'file')
    error(['找不到文件: ', FileName, '，请先运行主程序。']);
end
fprintf('正在加载数据: %s ...\n', FileName);
load(FileName, 'ResultData', 'Algo_Variants', 'Func_List');

% 解析基础信息
[nAlgos, nFuncs, nRuns] = size(ResultData);
Raw_Names = Algo_Variants(:, 1);

% 简化名称用于绘图 (移除下划线，简化前缀)
Plot_Names = strrep(Raw_Names, 'GL_FATA_', '');
Plot_Names = strrep(Plot_Names, 'FATA_', ''); 
Plot_Names = strrep(Plot_Names, '_', '-'); 

% 生成函数名列表
Func_Names = arrayfun(@(x) ['F', num2str(x)], Func_List, 'UniformOutput', false);

% 自动识别基准算法 (Final / Proposed)
Base_Idx = find(contains(Raw_Names, 'Final'), 1);
if isempty(Base_Idx), Base_Idx = nAlgos; end
fprintf('基准对比算法 (Proposed): %s\n', Plot_Names{Base_Idx});

%% 3. 数据预处理
Mean_Mat = zeros(nFuncs, nAlgos);
Rank_Mat = zeros(nFuncs, nAlgos);

% 整理数据用于绘图
All_Data_Cell = cell(nFuncs, 1);

for f = 1:nFuncs
    % 提取当前函数的所有算法数据 [Runs x Algos]
    % ResultData 是 [Algo, Func, Run]，需转置
    func_data = squeeze(ResultData(:, f, :))'; 
    All_Data_Cell{f} = func_data;
    
    % 计算均值
    Mean_Mat(f, :) = mean(func_data, 1);
end

% 计算每一行的排名
for f = 1:nFuncs
   Rank_Mat(f, :) = tiedrank(Mean_Mat(f, :)); 
end

%% 4. 可视化：高质量箱型图 (Box Plots)
fprintf('绘制箱线图...\n');
figure('Name', 'BoxPlots Analysis', 'Color', 'w', 'Position', [100 100 1400 800]);

cols_plot = 4;
rows_plot = ceil(nFuncs / cols_plot);

for i = 1:nFuncs
    subplot(rows_plot, cols_plot, i);
    
    data_to_plot = All_Data_Cell{i}; % [Runs x Algos]
    
    % 绘制基础箱线图
    boxplot(data_to_plot, 'Symbol', '+', 'OutlierSize', 3, 'Labels', Plot_Names);
    
    % --- 模仿核心：自定义填充颜色 ---
    h = findobj(gca, 'Tag', 'Box');
    num_boxes = size(data_to_plot, 2);
    for j = 1:num_boxes
        % boxplot 的句柄顺序通常是倒序的
        patch_idx = num_boxes - j + 1; 
        
        % 防止颜色索引越界
        color_idx = mod(patch_idx - 1, size(mycolor, 1)) + 1;
        
        patch(get(h(j),'XData'), get(h(j),'YData'), mycolor(color_idx,:), ...
            'FaceAlpha', 0.6, 'EdgeColor', 'none');
    end
    
    % 坐标轴与标题美化
    xtickangle(45);
    title(Func_Names{i}, 'FontWeight', 'bold');
    
    % 【修改点1】：删除了各个子图的局部纵坐标，为全局纵坐标留出空间
    % ylabel('适应度值', 'FontWeight', 'bold'); 
    
    grid on;
    set(gca, 'GridAlpha', 0.3, 'FontSize', 8);
    
    % 智能对数坐标：如果数据跨度大且非负，使用对数
    if min(data_to_plot(:)) > 0 && (max(data_to_plot(:)) / min(data_to_plot(:)) > 100)
        set(gca, 'YScale', 'log');
    end
end

% 全局大标题
sgtitle('适应度分布 (消融实验)', 'FontSize', 18, 'FontWeight', 'bold');

% =========================================================================
% 【修改点2】: 添加大的、全局的中文横纵坐标
% =========================================================================
% 创建一个透明的全局坐标轴，大小涵盖主图表区域
global_ax = axes('Position', [0.12, 0.12, 0.78, 0.78], 'Visible', 'off'); 

% 在透明坐标系上强制显示 XLabel 和 YLabel
global_ax.XLabel.Visible = 'on';
global_ax.YLabel.Visible = 'on';

% 设置大字体的全局横纵坐标，并利用 Units = 'normalized' 手动微调偏移量
% 避免横坐标和子图倾斜的算法名字 (xtickangle) 重叠
xlabel(global_ax, '算 法 变 体', 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'k', ...
    'Units', 'normalized', 'Position', [0.5, -0.09, 0]);

ylabel(global_ax, '适 应 度 值', 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'k', ...
    'Units', 'normalized', 'Position', [-0.07, 0.5, 0]);
% =========================================================================

%% 5. 可视化：Friedman 平均排名 (Bar Chart)
fprintf('绘制排名图...\n');
Mean_Ranks = mean(Rank_Mat, 1);
[Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
Sorted_Names = Plot_Names(Sort_Idx);

figure('Name', 'Friedman Mean Rank', 'Color', 'w', 'Position', [150 150 800 500]);
b = bar(Sorted_Ranks);
b.FaceColor = 'flat';

% 应用颜色：注意要对应原始算法的索引颜色
for k = 1:length(Sort_Idx)
    orig_idx = Sort_Idx(k);
    color_idx = mod(orig_idx - 1, size(mycolor, 1)) + 1;
    b.CData(k, :) = mycolor(color_idx, :);
end

% 柱顶数值
text(1:length(Sorted_Ranks), Sorted_Ranks, num2str(Sorted_Ranks', '%.2f'), ...
    'vert', 'bottom', 'horiz', 'center', 'FontSize', 10, 'FontWeight', 'bold');

ylabel('平均排名 (越小越好)', 'FontSize', 12, 'FontWeight', 'bold'); 
xlabel('算法变体', 'FontSize', 12, 'FontWeight', 'bold'); 
title('Friedman 检验 - 平均排名', 'FontSize', 14, 'FontWeight', 'bold');

set(gca, 'XTickLabel', Sorted_Names, 'FontSize', 11);
xtickangle(30);
grid on;

%% 6. 统计分析：Wilcoxon 秩和检验表 (Console Output)
fprintf('\n');
disp('========================================================================');
disp(['Wilcoxon 秩和检验 (基准算法: ', Plot_Names{Base_Idx}, ')']);
disp('符号说明: "+" = 提出算法显著更优 (Win)');
disp('          "-" = 提出算法显著较差 (Loss)');
disp('          "=" = 无显著性差异 (Tie)');
disp('========================================================================');

% 打印表头
fprintf('%-6s', 'Func');
for j = 1:nAlgos
    if j == Base_Idx, continue; end
    fprintf('| %-15s ', Plot_Names{j});
end
fprintf('\n%s\n', repmat('-', 1, 90));

% 循环计算并打印
Win = 0; Tie = 0; Loss = 0;

for i = 1:nFuncs
    fprintf('%-6s', Func_Names{i});
    
    ref_data = All_Data_Cell{i}(:, Base_Idx); % Proposed data
    
    for j = 1:nAlgos
        if j == Base_Idx, continue; end
        
        comp_data = All_Data_Cell{i}(:, j);
        p = ranksum(ref_data, comp_data); 
        
        sym = '=';
        if p < 0.05
            if mean(ref_data) < mean(comp_data)
                sym = '+'; % Proposed 均值更小 (更好)
                Win = Win + 1;
            else
                sym = '-';
                Loss = Loss + 1;
            end
        else
            Tie = Tie + 1;
        end
        
        fprintf('| %-1s (p=%.1e)   ', sym, p);
    end
    fprintf('\n');
end
fprintf('\n[总结] 胜(Win): %d | 平(Tie): %d | 负(Loss): %d\n', Win, Tie, Loss);

%% 7. 可视化：综合排名雷达图 (Rank Radar)
fprintf('绘制雷达图...\n');

figure('Name', 'Rank Radar Analysis', 'Color', 'w', 'Position', [200 50 900 850]);

% --- 参数设置 ---
angles = linspace(0, 2*pi, nFuncs + 1);
max_rank_val = nAlgos; % 最大排名就是算法总数
max_radius = ceil(max_rank_val);

% 样式定义
markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p'};
linestyles = {'-', '--', '-.', ':', '-', '--', '-.', ':'};

% 确保样式数量足够
markers = repmat(markers, 1, ceil(nAlgos/length(markers)));
linestyles = repmat(linestyles, 1, ceil(nAlgos/length(linestyles)));

hold on; axis equal; axis off;

% A. 绘制背景网格
grid_levels = 1:max_radius;
for r = grid_levels
    r_grid = repmat(r, 1, nFuncs + 1);
    x_grid = r_grid .* cos(angles);
    y_grid = r_grid .* sin(angles);
    
    if r == max_radius
        plot(x_grid, y_grid, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0); % 外边框
    else
        plot(x_grid, y_grid, '-', 'Color', [0.9 0.9 0.9], 'LineWidth', 0.5); % 内网格
    end
    % 刻度
    text(0, r, num2str(r), 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'k', 'BackgroundColor', 'w');
end

% B. 绘制放射轴线与标签
max_r_vec = repmat(max_radius, 1, nFuncs + 1);
x_out = max_r_vec .* cos(angles);
y_out = max_r_vec .* sin(angles);

for i = 1:nFuncs
    plot([0 x_out(i)], [0 y_out(i)], '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
    
    % 标签位置
    label_r = max_radius * 1.15;
    lx = label_r * cos(angles(i));
    ly = label_r * sin(angles(i));
    
    % 对齐逻辑
    if abs(lx) < 0.1, ha = 'center';
    elseif lx > 0,    ha = 'left';
    else,             ha = 'right';
    end
    
    text(lx, ly, Func_Names{i}, 'HorizontalAlignment', ha, ...
        'FontWeight', 'bold', 'FontSize', 10);
end

% C. 绘制数据 (排序：让表现好的在最上面绘制)
% 计算每个算法的总平均排名
[~, sort_indices] = sort(mean(Rank_Mat, 1), 'descend'); % 差的在下(底层)，好的在上(顶层)

legend_h = [];
legend_str = {};

for k = 1:nAlgos
    alg_idx = sort_indices(k);
    
    % 闭合数据环
    ranks = Rank_Mat(:, alg_idx)';
    data_closed = [ranks, ranks(1)];
    
    x_data = data_closed .* cos(angles);
    y_data = data_closed .* sin(angles);
    
    % 获取对应颜色
    col_idx = mod(alg_idx - 1, size(mycolor, 1)) + 1;
    col = mycolor(col_idx, :);
    
    % 样式逻辑：Best 算法加粗且稍微填充
    is_best = (alg_idx == Base_Idx); 
    
    if is_best
        lw = 2.5;
        alpha_val = 0.1; % 仅填充最优算法，避免混乱
        m_size = 6;
        l_style = '-';
    else
        lw = 1.2;
        alpha_val = 0.0;
        m_size = 5;
        l_style = linestyles{alg_idx};
    end
    
    % 填充
    if alpha_val > 0
        fill(x_data, y_data, col, 'FaceAlpha', alpha_val, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    
    % 画线
    h_line = plot(x_data, y_data, ...
        'Color', col, 'LineWidth', lw, 'LineStyle', l_style, ...
        'Marker', markers{alg_idx}, 'MarkerSize', m_size, 'MarkerFaceColor', 'w');
end

% D. 设置显示范围与图例
padding = max_radius * 1.4;
xlim([-padding, padding]);
ylim([-padding, padding]);

% 重建图例句柄以匹配 Plot_Names 的顺序
real_handles = gobjects(nAlgos, 1);
for k = 1:nAlgos
    col_idx = mod(k - 1, size(mycolor, 1)) + 1;
    real_handles(k) = plot(nan, nan, 'Color', mycolor(col_idx, :), ...
        'LineWidth', 2, 'Marker', markers{k}, 'LineStyle', linestyles{k});
end

legend(real_handles, Plot_Names, 'Location', 'bestoutside', 'FontSize', 10);
title({'算法排名稳定性分析'; '(中心点 = 排名第1 = 最优)'}, ...
    'FontSize', 14, 'FontWeight', 'bold');

hold off;

fprintf('所有图表绘制完成。\n');

end