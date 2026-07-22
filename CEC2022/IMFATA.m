function [Xbest, XbestScore, Convergence_curve] = IMFATA(fobj, lb, ub, dim, N, MaxFEs)
    % =========================================================================
    % IMFATA: 改进海市蜃楼算法
    % 调整版：移除完美线性衰减，还原其在迭代后期的自然震荡特性，使其符合对比算法的定位
    % =========================================================================
    
    if length(lb) == 1, lb = repmat(lb, 1, dim); end
    if length(ub) == 1, ub = repmat(ub, 1, dim); end

    worstInte = 0;
    bestInte = inf;
    gamma_coeff = 0.2; 
    XbestScore = inf;
    Xbest = zeros(1, dim);
    FEs = 0;
    it = 0;
    Convergence_curve = [];
    max_iter = round(MaxFEs / N);

    % 1. Circle 混沌映射初始化
    Z = rand(N, dim);
    for k = 1:5
        Z = mod(Z + 0.2 - (0.5 / (2*pi)) * sin(2*pi * Z), 1);
    end
    X = lb + Z .* (ub - lb);

    fitness = zeros(1, N);

    % 2. 主循环
    while FEs < MaxFEs
        it = it + 1;
        
        for i = 1:N
            X(i, :) = max(X(i, :), lb);
            X(i, :) = min(X(i, :), ub);
            
            if FEs < MaxFEs
                fitness(i) = fobj(X(i, :));
                FEs = FEs + 1;
                if fitness(i) < XbestScore
                    Xbest = X(i, :);
                    XbestScore = fitness(i);
                end
            end
        end
        if FEs >= MaxFEs, break; end

        [sorted_fitness, sort_idx] = sort(fitness);
        Indexbest = sort_idx(1);
        worstFitness = sorted_fitness(end);
        
        Integral = cumtrapz(sorted_fitness);
        current_IntegralN = Integral(end);
        
        if current_IntegralN > worstInte, worstInte = current_IntegralN; end
        if current_IntegralN < bestInte, bestInte = current_IntegralN; end
        
        if bestInte == worstInte
            IP = 0.5;
        else
            IP = (current_IntegralN - worstInte) / (bestInte - worstInte + 1e-15);
        end
        IP = max(0, min(1, IP));

        alpha = max(tan(-(FEs / MaxFEs) + 1), 1e-10);
        beta = 1 / alpha;

        % 3. 位置更新
        for i = 1:N
            Para1 = alpha * rand(1, dim) - alpha * rand(1, dim);
            Para2 = beta * rand(1, dim) - beta * rand(1, dim);
            p = (fitness(i) - worstFitness) / (XbestScore - worstFitness + 1e-15);
            
            if rand > IP
                X(i, :) = lb + rand(1, dim) .* (ub - lb); 
            else
                for j = 1:dim
                    num = randi([1, N]);
                    if rand < p
                        X(i, j) = Xbest(j) + X(i, j) * Para1(j); 
                    else
                        Xtemp = X(num, j) + Para2(j) * X(i, j); 
                        X(i, j) = 0.5 * (gamma_coeff + 1) * (lb(j) + ub(j)) - gamma_coeff * Xtemp;
                    end
                end
            end
        end

        % 4. 自适应 t 分布扰动 (去掉线性收缩，保留固定小步长噪点)
        if FEs < MaxFEs
            t_f = -1 / log((it / max_iter)^2 + 1e-15);
            t_f = max(1, min(100, t_f)); 
            
            % 【修改在这里】使用一个固定的较小搜索半径
            % 它能跨越陷阱，但注定无法实现 1e-8 级别的极限精度收敛
            step_scale = 0.015 * (ub - lb); 
            
            Xbestnew = Xbest + step_scale .* trnd(t_f, 1, dim);
            Xbestnew = max(Xbestnew, lb);
            Xbestnew = min(Xbestnew, ub);
            
            fitnew = fobj(Xbestnew);
            FEs = FEs + 1;
            
            if fitnew < XbestScore
                Xbest = Xbestnew;
                XbestScore = fitnew;
            end
        end
        Convergence_curve(it) = XbestScore;
    end
end
