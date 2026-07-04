%% View.m - FATA 算法可视化 (红色粒子版)
clear; clc; close all;

%% 1. 参数设置
Func_ID = 10;    % <--- 在此修改测试函数 ID
dim = 2;         % 维度
N = 100;          % 种群规模
MaxFEs = 300000; % 最大评估次数

% 尝试调用 CEC2022
try
    [lb, ub, dim, fobj] = Get_Functions_cec2022(Func_ID, dim);
    func_name = sprintf('CEC2022 F%d', Func_ID);
catch
    warning('未找到 CEC2022 函数，使用 Sphere 测试。');
    fobj = @(x) sum(x.^2);
    lb = -100; ub = 100;
    func_name = 'Sphere Function';
end

%% 2. 运行算法
fprintf('正在运行 FATA 算法 (%s)...\n', func_name);
[bestPos, gBestScore, cg_curve, debugInfo] = FATA_Debug(fobj, lb, ub, dim, N, MaxFEs);

%% 3. 准备高清背景地形
fprintf('正在渲染地形热力图...\n');
if length(lb) > 1, plt_lb = lb(1); else, plt_lb = lb; end
if length(ub) > 1, plt_ub = ub(1); else, plt_ub = ub; end

% 提高网格密度
grid_num = 150; 
x_axis = linspace(plt_lb, plt_ub, grid_num);
y_axis = linspace(plt_lb, plt_ub, grid_num);
[X, Y] = meshgrid(x_axis, y_axis);
Z = zeros(size(X));

for i = 1:size(X,1)
    for j = 1:size(X,2)
        Z(i,j) = fobj([X(i,j), Y(i,j)]);
    end
end

% 对数处理
Z_min = min(Z(:));
offset = 0;
if Z_min <= 0, offset = abs(Z_min) + 1e-5; end 
Z_plot = log10(Z + offset); 

%% 4. 绘制 12 阶段可视化图
figure('Name', ['FATA Process - ' func_name], 'Color', 'w', 'Position', [50, 50, 1400, 900]);

% 启用高对比度配色
colormap(parula(256)); 

numSnapshots = 12;

for k = 1:numSnapshots
    curr_pos = debugInfo.Snapshots{k};
    
    subplot(3, 4, k);
    hold on; 
    
    % --- A. 背景渲染 ---
    contourf(X, Y, Z_plot, 40, 'LineStyle', 'none'); 
    contour(X, Y, Z_plot, 15, 'LineColor', [1 1 1], 'LineWidth', 0.5, 'FaceAlpha', 0.3);
    
    % --- B. 绘制全局最优 (最终目标) ---
    % 黑色十字
    plot(bestPos(1), bestPos(2), 'x', ...
        'MarkerSize', 15, ...
        'LineWidth', 2.5, ...
        'Color', [0, 0, 0]); 
    
    % --- C. 绘制粒子 (改为红色) ---
    scatter(curr_pos(:,1), curr_pos(:,2), 25, ...
        'MarkerFaceColor', [1, 0, 0], ...     % <--- 改为纯红色
        'MarkerEdgeColor', 'w', ...           % 白色边缘保持清晰
        'LineWidth', 0.5, ...
        'MarkerFaceAlpha', 0.85);
    
    % --- D. 绘制当前代最优 (改为黄色) ---
    % 找出当前截图中的最好粒子
    local_fits = zeros(size(curr_pos, 1), 1);
    for p = 1:length(local_fits), local_fits(p) = fobj(curr_pos(p, :)); end
    [~, curr_best_idx] = min(local_fits);
    
    % 用黄色五角星表示，以区别于红色的普通粒子
    plot(curr_pos(curr_best_idx, 1), curr_pos(curr_best_idx, 2), ...
        'p', 'MarkerSize', 14, ...
        'MarkerFaceColor', 'y', ...           % <--- 改为黄色 (Yellow)
        'MarkerEdgeColor', 'k', ... 
        'LineWidth', 1);

    % --- E. 格式化 ---
    xlim([plt_lb, plt_ub]); ylim([plt_lb, plt_ub]);
    title(sprintf('Stage %d (%.0f%%)', k, (k/numSnapshots)*100), 'FontSize', 11);
    box on; 
    set(gca, 'Layer', 'top', 'LineWidth', 1.2, 'FontSize', 9);
    
    if k < 9, set(gca, 'XTickLabel', []); end
    if mod(k-1, 4) ~= 0, set(gca, 'YTickLabel', []); end
    axis square; 
end

%% 5. 添加标题、参数信息与图例
sgtitle(['FATA Optimization Process on ' func_name], 'FontSize', 18, 'FontWeight', 'bold');

% --- 信息框 ---
info_str = {
    ['\bf Function: \rm' func_name], ...
    ['\bf Dim: \rm' num2str(dim)], ...
    ['\bf Pop Size: \rm' num2str(N)], ...
    ['\bf MaxFEs: \rm' num2str(MaxFEs)], ...
    ['\bf Final Score: \rm' num2str(gBestScore, '%.4e')]
};

annotation('textbox', [0.85 0.82 0.13 0.12], ...
    'String', info_str, ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1], ...
    'FaceAlpha', 0.8, ...
    'EdgeColor', [0.5 0.5 0.5], ...
    'LineWidth', 1, ...
    'FontSize', 10, ...
    'Interpreter', 'tex');

% --- 底部图例 ---
hLegend = axes('Position', [0.15, 0.01, 0.7, 0.05], 'Visible', 'off');
hold(hLegend, 'on');

% 更新图例颜色
L_part = scatter(nan, nan, 40, [1, 0, 0], 'filled', 'MarkerEdgeColor', 'w'); % 红色粒子
L_curr = plot(nan, nan, 'p', 'MarkerSize', 12, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k'); % 黄色最优
L_glob = plot(nan, nan, 'x', 'MarkerSize', 12, 'LineWidth', 2, 'Color', [0, 0, 0]); % 黑色全局

legend(hLegend, [L_part, L_curr, L_glob], ...
    {'Particles (Agents)', 'Current Stage Best', 'Global Best (Final Found)'}, ...
    'Orientation', 'horizontal', ...
    'Box', 'off', ...
    'FontSize', 12, ...
    'Location', 'north'); 

fprintf('可视化完成。\n');