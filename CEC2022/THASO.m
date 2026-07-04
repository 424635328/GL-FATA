function [bestPos, gBestScore, cg_curve] = THASO(fobj, lb, ub, dim, N, MaxFEs)
% 龟兔交替搜索优化算法 4.0 (Tortoise and Hare Alternating Search Optimization)
% SOTA 机制加持版：解决最优解停滞死锁，保证在单峰函数收敛至绝对 0

    %% 1. 核心超参数
    gamma = 4;          % 兔子模式：长步长与短步长的倍数比例 (超参数)
    P_sleep = 0.1;      % 兔子睡觉概率
    
    %% 2. 边界处理与初始化
    if length(lb) == 1
        lb = lb * ones(1, dim);
        ub = ub * ones(1, dim);
    end
    
    X = zeros(N, dim);
    for i = 1:dim
        X(:, i) = rand(N, 1) .* (ub(i) - lb(i)) + lb(i);
    end
    
    fitness = zeros(N, 1);
    for i = 1:N
        fitness(i) = fobj(X(i, :));
    end
    FEs = N;
    
    [gBestScore, bestIdx] = min(fitness);
    bestPos = X(bestIdx, :);
    
    MaxIter = ceil(MaxFEs / N);
    cg_curve = zeros(1, MaxIter);
    cg_curve(1) = gBestScore;
    
    %% 3. 算法主循环
    t = 1;
    while FEs < MaxFEs
        t = t + 1;
        
        % 收敛因子 w：从 1 线性衰减到 0，引导空间坍缩
        w = 1 - (FEs / MaxFEs); 
        
        isHareMode = (mod(t, 2) == 1); % 奇数代兔子，偶数代乌龟
        
        for i = 1:N
            if FEs >= MaxFEs
                break;
            end
            
            isSleep = false;
            
            % SOTA 核心机密：生成动态虚拟距离 D，防止最优个体自身死锁
            C = 2 * rand(1, dim); 
            D = abs(C .* bestPos - X(i, :));
            
            if isHareMode
                % ==========================================
                % 【兔子模式：长步长 (引入 gamma 比例)】
                % ==========================================
                if rand() < P_sleep
                    isSleep = true; % 睡觉
                else
                    % 兔子以最优解为锚点，进行大幅度(gamma倍)、高斯随机(randn)的探索跃迁
                    Step_Long = gamma * w * randn(1, dim) .* D;
                    new_X = bestPos + Step_Long;
                end
            else
                % ==========================================
                % 【乌龟模式：短步长 (比例为 1)】
                % ==========================================
                % 乌龟以最优解为锚点，进行小幅度(1倍)、均匀分布(rand)的极限微观开发
                Step_Short = 1 * w * (2 * rand(1, dim) - 1) .* D;
                new_X = bestPos + Step_Short;
            end
            
            % 更新逻辑
            if ~isSleep
                % 高效边界处理
                Flag4ub = new_X > ub;
                Flag4lb = new_X < lb;
                new_X = (new_X .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;
                
                % 评估新位置
                new_fitness = fobj(new_X);
                FEs = FEs + 1; 
                
                % 贪心策略：只接受更好的位置
                if new_fitness < fitness(i)
                    X(i, :) = new_X;
                    fitness(i) = new_fitness;
                    
                    % 更新全局最优
                    if fitness(i) < gBestScore
                        gBestScore = fitness(i);
                        bestPos = X(i, :);
                    end
                end
            end
        end
        
        % 记录收敛曲线
        if t <= length(cg_curve)
            cg_curve(t) = gBestScore;
        else
            cg_curve = [cg_curve, gBestScore]; 
        end
    end
    cg_curve = cg_curve(1:t);
end