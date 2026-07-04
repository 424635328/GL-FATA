clc; clear; close all;

% 1. 定义 Sphere 测试函数 (全局最优值在原点，最小值为 0)
fobj = @(x) sum(x.^2); 

% 2. 算法参数设置
dim = 30;             % 维度
lb = -100;            % 下界
ub = 100;             % 上界
N = 30;               % 种群大小
MaxFEs = 100000;       % 最大评价次数

% 3. 运行 THASO 算法
[bestPos, gBestScore, cg_curve] = THASO(fobj, lb, ub, dim, N, MaxFEs);

% 4. 打印结果
fprintf('THASO 找到的最优适应度值为: %e\n', gBestScore);

% 5. 绘制收敛曲线
figure;
semilogy(cg_curve, 'LineWidth', 2, 'Color', 'b');
title('THASO 收敛曲线');
xlabel('迭代次数');
ylabel('全局最优适应度值 (log scale)');
grid on;