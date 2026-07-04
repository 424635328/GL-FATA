%% GWO 算法 12帧全过程观测脚本
clear; clc; close all;

% 1. 设置参数
Func_ID = 10;   % 建议选择 F10 (多峰) 以观察狼群包围过程
dim = 2;        % 必须为 2 维以进行散点可视化
N = 500;         % 种群大小 (SearchAgents_no)
Max_iter = 5000; % 最大迭代次数

% 获取函数 (如果没有 cec2022 文件，这里定义一个简单的测试函数)
try
    [lb, ub, dim, fobj] = Get_Functions_cec2022(Func_ID, dim);
catch
    % 如果没有 CEC2022，使用 Rastrigin 函数作为替代演示
    fprintf('未找到 Get_Functions_cec2022，使用 Rastrigin 函数演示...\n');
    fobj = @(x) sum(x.^2 - 10*cos(2*pi*x) + 10);
    lb = [-5.12, -5.12];
    ub = [5.12, 5.12];
end

% 2. 运行改进的 GWO 算法 (带 Debug 信息记录)
fprintf('正在运行 GWO (记录12帧数据)...\n');
[Alpha_score, Alpha_pos, cg_curve, debugInfo] = GWO_Debug(N, Max_iter, lb, ub, dim, fobj);

%% 3. 核心可视化：12阶段演化图
% 布局：3行 x 4列
figure('Name', 'GWO 狼群演化全过程 (12 Frames)', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

% 预计算等高线 (背景)
x_range = linspace(lb(1), ub(1), 100);
y_range = linspace(lb(1), ub(1), 100);
[X, Y] = meshgrid(x_range, y_range);
Z = zeros(size(X));
for i = 1:size(X,1)
    for j = 1:size(X,2)
        Z(i,j) = fobj([X(i,j), Y(i,j)]);
    end
end

% 循环绘制 12 张图
num_frames = length(debugInfo.Snapshots);
for k = 1:num_frames
    subplot(3, 4, k); % 3行4列布局
    
    % 1. 画背景等高线
    contour(X, Y, Z, 20, 'LineColor', [0.85 0.85 0.85]); 
    hold on;
    
    % 2. 画所有灰狼 (蓝色圆点 - Omega Wolves)
    pos = debugInfo.Snapshots{k};
    scatter(pos(:,1), pos(:,2), 25, 'filled', ...
            'MarkerFaceColor', [0.5, 0.5, 0.5], 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    
    % 3. 画头狼 Alpha (红色五角星 - 当前最优)
    % 从快照中重新计算适应度找出当前的 Alpha (或者近似认为种群中最优者)
    fit_snap = arrayfun(@(idx) fobj(pos(idx,:)), 1:N);
    [~, min_idx] = min(fit_snap);
    plot(pos(min_idx,1), pos(min_idx,2), 'rp', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    
    % 4. 画最终全局最优位置 (黑色十字)
    plot(Alpha_pos(1), Alpha_pos(2), 'k+', 'MarkerSize', 15, 'LineWidth', 2);
    
    % 格式调整
    xlim([lb(1), ub(1)]);
    ylim([lb(1), ub(1)]);
    
    % 标题显示进度
    current_iter = debugInfo.Snapshot_Iters(k);
    progress = (current_iter / Max_iter) * 100;
    title(sprintf('Iter %d: %.1f%%', current_iter, progress), 'FontSize', 10);
    
    if k == 1 || k == 5 || k == 9
        ylabel('Dim 2');
    end
    if k >= 9
        xlabel('Dim 1');
    end
    
    box on;
end

sgtitle(['GWO Search Process (Alpha Wolf Guidance)'], 'FontSize', 14, 'FontWeight', 'bold');

%% 4. 辅助分析图 (收敛曲线)
figure('Name', 'GWO 收敛曲线', 'Color', 'w', 'Position', [200, 200, 600, 300]);

semilogy(cg_curve, 'LineWidth', 2, 'Color', '#D95319');
title(['GWO Convergence (Best: ' num2str(Alpha_score) ')']); 
xlabel('Iteration'); 
ylabel('Fitness (Log)'); 
grid on;
xlim([1 Max_iter]);

%% ---------------------------------------------------------
%  GWO 改进版函数 (GWO_Debug)
%  说明：在原版基础上增加了快照记录功能
% ---------------------------------------------------------
function [Alpha_score, Alpha_pos, Convergence_curve, debugInfo] = GWO_Debug(SearchAgents_no, Max_iter, lb, ub, dim, fobj)

    % 初始化 Alpha, Beta, Delta
    Alpha_pos = zeros(1, dim);
    Alpha_score = inf; 

    Beta_pos = zeros(1, dim);
    Beta_score = inf; 

    Delta_pos = zeros(1, dim);
    Delta_score = inf; 

    % 初始化位置
    Positions = initialization(SearchAgents_no, dim, ub, lb);

    Convergence_curve = zeros(1, Max_iter);
    
    % --- Debug: 准备记录 12 帧快照 ---
    % 计算需要记录快照的迭代索引 (均匀分布)
    snapshot_indices = unique(round(linspace(1, Max_iter, 12)));
    % 确保最后一代也被记录
    if snapshot_indices(end) ~= Max_iter
        snapshot_indices(end+1) = Max_iter;
    end
    debugInfo.Snapshots = cell(1, length(snapshot_indices));
    debugInfo.Snapshot_Iters = snapshot_indices;
    snap_count = 1;
    % -------------------------------

    l = 0; % Loop counter

    while l < Max_iter
        for i = 1:size(Positions, 1)  
           % 边界处理
           Flag4ub = Positions(i, :) > ub;
           Flag4lb = Positions(i, :) < lb;
           Positions(i, :) = (Positions(i, :) .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;               

           % 计算适应度
           fitness = fobj(Positions(i, :));

           % 更新 Alpha, Beta, Delta
           if fitness < Alpha_score 
               Alpha_score = fitness; 
               Alpha_pos = Positions(i, :);
           end

           if fitness > Alpha_score && fitness < Beta_score 
               Beta_score = fitness; 
               Beta_pos = Positions(i, :);
           end

           if fitness > Alpha_score && fitness > Beta_score && fitness < Delta_score 
               Delta_score = fitness; 
               Delta_pos = Positions(i, :);
           end
        end

        a = 2 - l * ((2) / Max_iter); % a 从 2 线性减少到 0

        % 更新位置
        for i = 1:size(Positions, 1)
            for j = 1:size(Positions, 2)     

                r1 = rand(); r2 = rand();
                A1 = 2 * a * r1 - a; 
                C1 = 2 * r2; 
                D_alpha = abs(C1 * Alpha_pos(j) - Positions(i, j)); 
                X1 = Alpha_pos(j) - A1 * D_alpha; 

                r1 = rand(); r2 = rand();
                A2 = 2 * a * r1 - a; 
                C2 = 2 * r2; 
                D_beta = abs(C2 * Beta_pos(j) - Positions(i, j)); 
                X2 = Beta_pos(j) - A2 * D_beta;       

                r1 = rand(); r2 = rand(); 
                A3 = 2 * a * r1 - a; 
                C3 = 2 * r2; 
                D_delta = abs(C3 * Delta_pos(j) - Positions(i, j)); 
                X3 = Delta_pos(j) - A3 * D_delta;             

                Positions(i, j) = (X1 + X2 + X3) / 3;
            end
        end
        
        l = l + 1;    
        Convergence_curve(l) = Alpha_score;
        
        % --- Debug: 记录快照 ---
        if ismember(l, snapshot_indices)
            debugInfo.Snapshots{snap_count} = Positions;
            snap_count = snap_count + 1;
        end
        % ----------------------
    end
end

% ---------------------------------------------------------
%  初始化函数
% ---------------------------------------------------------
function Positions = initialization(SearchAgents_no, dim, ub, lb)
    Boundary_no = size(ub, 2); 
    if Boundary_no == 1
        Positions = rand(SearchAgents_no, dim) .* (ub - lb) + lb;
    end
    if Boundary_no > 1
        for i = 1:dim
            ub_i = ub(i);
            lb_i = lb(i);
            Positions(:, i) = rand(SearchAgents_no, 1) .* (ub_i - lb_i) + lb_i;
        end
    end
end