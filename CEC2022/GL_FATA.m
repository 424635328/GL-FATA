function [bestPos, gBestScore, cg_curve] = GL_FATA(fobj, lb, ub, dim, N, MaxFEs)
% =========================================================================
% 改进版海市蜃楼算法 (GL-FATA)
% 核心改进:
% 1. Piecewise (PWLCM) 分段线性混沌映射初始化
% 2. 引入引导因子 (λ=2.0) 的差异化折射更新策略
% 3. 基于贪婪选择的全局最优 Levy 飞行扰动机制
% =========================================================================

%% 1. 初始化阶段
worstInte = 0;
bestInte  = Inf;
arf       = 0.2;
gBest     = zeros(1, dim);
cg_curve  = [];
gBestScore = inf;

% 统一处理边界为向量 (防止标量引发维度崩溃)
if isscalar(lb)
    lb = ones(1, dim) .* lb;
    ub = ones(1, dim) .* ub;
end

% --- 调用高维矩阵化去相关的 PWLCM 初始化 ---
Flight = initialization_PWLCM(N, dim, ub, lb);
fitness = zeros(N, 1) + inf;

it = 1;
FEs = 0;

%% 2. 算法主循环
while FEs < MaxFEs
    
    % 2.1 边界检查与适应度计算
    for i = 1:size(Flight, 1)
        % 越界修正
        Flag4ub = Flight(i, :) > ub;
        Flag4lb = Flight(i, :) < lb;
        Flight(i, :) = (Flight(i, :) .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;
        
        if FEs < MaxFEs
            fitness(i) = fobj(Flight(i, :));
            FEs = FEs + 1;
            
            % 更新全局最优记录
            if fitness(i) < gBestScore
                gBestScore = fitness(i);
                gBest = Flight(i, :);
            end
        end
    end
    
    if FEs >= MaxFEs, break; end
    
    % 2.2 排序与种群质量因子(IP)积分原理计算
    [Order, Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1); % 当前代最优个体索引
    
    Integral = cumtrapz(Order);
    current_Integral = Integral(N);
    
    if current_Integral > worstInte
        worstInte = current_Integral;
    end
    if current_Integral < bestInte
        bestInte = current_Integral;
    end
    
    IP = (current_Integral - worstInte) / (bestInte - worstInte + 1e-15);
    IP = max(0, min(1, IP)); % 确保概率在 [0,1] 之间
    
    % 计算动态折射参数 a 和 b (增加 1e-10 保护，防止末期出现 1/0=Inf)
    a = max(tan(-(FEs / MaxFEs) + 1), 1e-10);
    b = 1 / a;
    
    %% 2.3 位置更新阶段
    for i = 1:size(Flight, 1)
        Para1 = a * rand(1, dim) - a * rand(1, dim);
        Para2 = b * rand(1, dim) - b * rand(1, dim);
        p = (fitness(i) - worstFitness) / (gBestScore - worstFitness + 1e-15);
        
        if rand > IP
            % 随机散射 (随机重置)
            Flight(i, :) = (ub - lb) .* rand(1, dim) + lb;
        else
            for j = 1:dim
                num = randi([1, N]); % 替换 floor 随机数，更规范
                if rand < p
                    % --- 改进策略 2: 引导因子差异化折射 (严格贴合公式 2.16) ---
                    if i == BestIndi_Index
                        % 最优个体：自身精细搜索
                        Flight(i, j) = gBest(j) + Flight(i, j) .* Para1(j);
                    else
                        % 普通个体：引入引导因子 λ=2.0，利用差分信息加速逼近
                        Flight(i, j) = gBest(j) + (gBest(j) - Flight(i, j)) .* Para1(j) * 2.0;
                    end
                else
                    % 全反射机制
                    Flight(i, j) = Flight(num, j) + Para2(j) .* Flight(i, j);
                    Flight(i, j) = 0.5 * (arf + 1) .* (lb(j) + ub(j)) - arf .* Flight(i, j);
                end
            end
        end
    end
    
    %% 2.4 莱维飞行逃逸策略
    if FEs < MaxFEs
        Levy_Prob = 0.2;
        if rand < Levy_Prob
            LF = Levy(dim);
            alpha = 0.01; % 步长缩放因子
            
            % --- 改进策略 3: (严格贴合论文公式 2.20，使用当前位置与下界的信息) ---
            gBest_new = gBest + alpha .* LF .* (gBest - lb);
            
            % 越界修正
            gBest_new = max(gBest_new, lb);
            gBest_new = min(gBest_new, ub);
            
            % 贪婪更新机制
            fit_new = fobj(gBest_new);
            FEs = FEs + 1;
            if fit_new < gBestScore
                gBestScore = fit_new;
                gBest = gBest_new;
            end
        end
    end
    
    % 记录收敛曲线
    cg_curve(it) = gBestScore;
    it = it + 1;
    bestPos = gBest;
end
end


function s = Levy(d)
    beta = 1.5;
    sigma = (gamma(1 + beta) * sin(pi * beta / 2) / (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);
    u = randn(1, d) * sigma;
    v = randn(1, d);
    s = u ./ abs(v).^(1 / beta);
end


function Positions = initialization_PWLCM(SearchAgents_no, dim, ub, lb)
% 彻底打破维度间相关性的矩阵化 PWLCM 初始化
    
    Positions = zeros(SearchAgents_no, dim);
    P = 0.4; 
    
    % 矩阵化生成初始随机种子 (N x dim)，每个元素互相独立
    x = rand(SearchAgents_no, dim);
    
    % 迭代 10 次，丢弃前期的瞬态效应，让序列彻底进入混沌状态
    for k = 1:10
        idx1 = (x >= 0 & x < P);
        idx2 = (x >= P & x < 0.5);
        idx3 = (x >= 0.5 & x < (1 - P));
        idx4 = (x >= (1 - P) & x <= 1);
        
        x(idx1) = x(idx1) / P;
        x(idx2) = (x(idx2) - P) / (0.5 - P);
        x(idx3) = (1 - P - x(idx3)) / (0.5 - P);
        x(idx4) = (1 - x(idx4)) / P;
    end
    
    % 将 [0,1] 区间的优质混沌序列映射到实际的 [lb, ub] 搜索空间
    Positions = lb + x .* (ub - lb);
end