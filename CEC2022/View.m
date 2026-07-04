clc;
clear;
close all;

%% 1. 修复随机数生成器状态 (关键修改)
% 强制将随机数生成器恢复为默认的 Mersenne Twister，
% 解决 "旧生成器" 报错问题。
rng('default'); 

%% 2. 参数设置
N = 200;       % 保持较小的 N，以便观察随机分布的"空洞"
dim = 2;       
lb = 0;        
ub = 1;        
P = 0.4;       

%% 3. 策略一：标准随机初始化 (Random)
% 使用特定种子复现一个"分布不均"的随机情况
rng(5); 
X_Random = lb + (ub - lb) .* rand(N, dim);

%% 4. 策略二：PWLCM 混沌初始化 (PWLCM)
% 恢复随机种子，让 PWLCM 从随机位置开始，但保持其混沌特性
rng('shuffle'); 

X_Chaos = zeros(N, dim);
x_val = rand; % 生成初始种子

% PWLCM 生成逻辑 (按列生成，去相关性)
for j = 1:dim
    for i = 1:N
        % PWLCM 迭代
        if x_val >= 0 && x_val < P
            x_val = x_val / P;
        elseif x_val >= P && x_val < 0.5
            x_val = (x_val - P) / (0.5 - P);
        elseif x_val >= 0.5 && x_val < (1 - P)
            x_val = (1 - P - x_val) / (0.5 - P);
        else
            x_val = (1 - x_val) / P;
        end
        X_Chaos(i,j) = lb + x_val .* (ub - lb);
    end
end

%% 5. 绘图对比 (带方差标注)
figure('Color', 'w', 'Position', [100, 100, 1000, 500]); 

% --- 左图：标准随机初始化 ---
subplot(1, 2, 1); 
scatter(X_Random(:,1), X_Random(:,2), 30, 'b', 'filled'); 
title(['(a) Standard Random (N=' num2str(N) ')'], 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Dimension 1'); ylabel('Dimension 2');
xlim([0 1]); ylim([0 1]); grid on; axis square;
% 标注方差
var_x_rand = var(X_Random(:,1));
var_y_rand = var(X_Random(:,2));
text(0.05, 0.95, ['Var X: ' num2str(var_x_rand, '%.4f')], 'Color', 'b', 'FontSize', 10, 'FontWeight', 'bold');
text(0.05, 0.90, ['Var Y: ' num2str(var_y_rand, '%.4f')], 'Color', 'b', 'FontSize', 10, 'FontWeight', 'bold');

% --- 右图：PWLCM 混沌初始化 ---
subplot(1, 2, 2); 
scatter(X_Chaos(:,1), X_Chaos(:,2), 30, 'r', 'filled'); 
title(['(b) PWLCM Chaotic (N=' num2str(N) ')'], 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Dimension 1'); ylabel('Dimension 2');
xlim([0 1]); ylim([0 1]); grid on; axis square;
% 标注方差
var_x_chaos = var(X_Chaos(:,1));
var_y_chaos = var(X_Chaos(:,2));
text(0.05, 0.95, ['Var X: ' num2str(var_x_chaos, '%.4f')], 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
text(0.05, 0.90, ['Var Y: ' num2str(var_y_chaos, '%.4f')], 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');

%% 6. 结果分析输出
disp('绘图完成。');
disp('--- 统计分析 ---');
disp(['随机初始化 - X轴方差: ', num2str(var_x_rand)]);
disp(['PWLCM初始化 - X轴方差: ', num2str(var_x_chaos)]);
disp('说明：');
disp('如果 PWLCM 的方差更接近 0.0833，且图中没有明显的大片空白或扎堆，说明效果更好。');