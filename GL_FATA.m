function [bestPos, gBestScore, cg_curve] = GL_FATA(fobj, lb, ub, dim, N, MaxFEs)
% =========================================================================
% 改进版海市蜃楼算法 (GL-FATA)
% 核心改进:
% 1. Piecewise (PWLCM) 分段线性混沌映射初始化
% 2. 引入引导因子 (lambda = 2.0) 的差异化折射更新策略
% 3. 基于贪婪选择的全局最优 Levy 飞行扰动机制
% =========================================================================

%% 1. 初始化阶段
worstInte = 0;
bestInte = Inf;
arf = 0.2;
gBest = zeros(1, dim);
cg_curve = [];
gBestScore = inf;

% 统一处理边界为向量
if isscalar(lb)
    lb = ones(1, dim) .* lb;
    ub = ones(1, dim) .* ub;
end

Flight = initialization_PWLCM(N, dim, ub, lb);
fitness = zeros(N, 1) + inf;

it = 1;
FEs = 0;

%% 2. 算法主循环
while FEs < MaxFEs
    % 2.1 边界检查与适应度计算
    for i = 1:size(Flight, 1)
        Flag4ub = Flight(i, :) > ub;
        Flag4lb = Flight(i, :) < lb;
        Flight(i, :) = (Flight(i, :) .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;

        if FEs < MaxFEs
            fitness(i) = fobj(Flight(i, :));
            FEs = FEs + 1;

            if fitness(i) < gBestScore
                gBestScore = fitness(i);
                gBest = Flight(i, :);
            end
        end
    end

    if FEs >= MaxFEs
        break;
    end

    % 2.2 种群质量因子
    [Order, Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1);

    Integral = cumtrapz(Order);
    current_Integral = Integral(N);

    if current_Integral > worstInte
        worstInte = current_Integral;
    end
    if current_Integral < bestInte
        bestInte = current_Integral;
    end

    IP = (current_Integral - worstInte) / (bestInte - worstInte + 1e-15);
    IP = max(0, min(1, IP));

    a = max(tan(-(FEs / MaxFEs) + 1), 1e-10);
    b = 1 / a;

    %% 2.3 位置更新阶段
    for i = 1:size(Flight, 1)
        Para1 = a * rand(1, dim) - a * rand(1, dim);
        Para2 = b * rand(1, dim) - b * rand(1, dim);
        p = (fitness(i) - worstFitness) / (gBestScore - worstFitness + 1e-15);

        if rand > IP
            Flight(i, :) = (ub - lb) .* rand(1, dim) + lb;
        else
            for j = 1:dim
                num = randi([1, N]);
                if rand < p
                    if i == BestIndi_Index
                        Flight(i, j) = gBest(j) + Flight(i, j) .* Para1(j);
                    else
                        Flight(i, j) = gBest(j) + (gBest(j) - Flight(i, j)) .* Para1(j) * 2.0;
                    end
                else
                    Flight(i, j) = Flight(num, j) + Para2(j) .* Flight(i, j);
                    Flight(i, j) = 0.5 * (arf + 1) .* (lb(j) + ub(j)) - arf .* Flight(i, j);
                end
            end
        end
    end

    %% 2.4 Levy 飞行逃逸策略
    if FEs < MaxFEs && rand < 0.2
        LF = Levy(dim);
        alpha = 0.01;
        gBest_new = gBest + alpha .* LF .* (gBest - lb);
        gBest_new = max(gBest_new, lb);
        gBest_new = min(gBest_new, ub);

        fit_new = fobj(gBest_new);
        FEs = FEs + 1;
        if fit_new < gBestScore
            gBestScore = fit_new;
            gBest = gBest_new;
        end
    end

    cg_curve(it) = gBestScore;
    it = it + 1;
    bestPos = gBest;
end
end


function s = Levy(d)
beta = 1.5;
sigma = (gamma(1 + beta) * sin(pi * beta / 2) / ...
    (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);
u = randn(1, d) * sigma;
v = randn(1, d);
s = u ./ abs(v).^(1 / beta);
end


function Positions = initialization_PWLCM(SearchAgents_no, dim, ub, lb)
% 使用独立种子和预热迭代，减少维度间相关性。
P = 0.4;
x = rand(SearchAgents_no, dim);

for k = 1:10
    idx1 = x >= 0 & x < P;
    idx2 = x >= P & x < 0.5;
    idx3 = x >= 0.5 & x < (1 - P);
    idx4 = x >= (1 - P) & x <= 1;

    x(idx1) = x(idx1) / P;
    x(idx2) = (x(idx2) - P) / (0.5 - P);
    x(idx3) = (1 - P - x(idx3)) / (0.5 - P);
    x(idx4) = (1 - x(idx4)) / P;
end

Positions = lb + x .* (ub - lb);
end
