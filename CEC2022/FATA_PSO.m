function [Xbest, XbestScore, Convergence_curve] = FATA_PSO(fobj, lb, ub, dim, N, MaxFEs)
    if isscalar(lb), lb = ones(1, dim) .* lb; end
    if isscalar(ub), ub = ones(1, dim) .* ub; end

    XbestScore = inf; Xbest = zeros(1, dim);
    FEs = 0; it = 0; Convergence_curve = [];
    
    X = lb + rand(N, dim) .* (ub - lb);
    V = zeros(N, dim);
    % 【关键修复】: 引入最大速度限制，防止粒子飞出宇宙边界
    Vmax = 0.15 .* (ub - lb); 
    
    pBest = X; pBestScore = inf(N, 1);
    fitness = inf(N, 1);
    stag_count = 0; 

    while FEs < MaxFEs
        for i = 1:N
            % 严格的边界钳制
            X(i, :) = max(min(X(i, :), ub), lb);
            
            if FEs < MaxFEs
                fitness(i) = fobj(X(i, :));
                FEs = FEs + 1;
                if fitness(i) < pBestScore(i)
                    pBestScore(i) = fitness(i); pBest(i, :) = X(i, :);
                end
                if fitness(i) < XbestScore
                    XbestScore = fitness(i); Xbest = X(i, :);
                    stag_count = 0; % 发现新解，重置停滞期
                end
            end
        end
        if FEs >= MaxFEs, break; end
        stag_count = stag_count + 1;
        
        % FATA 启发式动态参数
        alpha = max(tan(-(FEs / MaxFEs) + 1), 1e-10);
        w = 0.9 - 0.5 * (FEs / MaxFEs); 
        c1 = 1.5 * alpha; c2 = 2.0 * alpha; 

        [~, sort_idx] = sort(pBestScore);
        elite = pBest(sort_idx(1:min(3,N)), :); 

        for i = 1:N
            r1 = rand(1, dim); r2 = rand(1, dim);
            % PSO 速度更新
            V(i, :) = w * V(i, :) + c1 .* r1 .* (pBest(i, :) - X(i, :)) + c2 .* r2 .* (Xbest - X(i, :));
            
            % 【关键修复】: 对速度进行钳制
            V(i, :) = max(min(V(i, :), Vmax), -Vmax);
            X(i, :) = X(i, :) + V(i, :);
            
            % 聚类/精英靠拢机制
            if mod(it, 50) == 0 && it > 1 && rand < 0.3
                target = elite(randi([1, size(elite,1)]), :);
                X(i, :) = X(i, :) + rand * (target - X(i, :));
            end
        end

        % 停滞逃逸机制 (Stagnation Lévy Flight)
        if stag_count > 20
            beta_L = 1.5;
            sigma = (gamma(1+beta_L)*sin(pi*beta_L/2)/(gamma((1+beta_L)/2)*beta_L*2^((beta_L-1)/2)))^(1/beta_L);
            for k = N-4:N % 仅对最差的 5 个粒子进行扰动
                idx = sort_idx(k);
                LF = (randn(1,dim)*sigma) ./ abs(randn(1,dim)).^(1/beta_L);
                % 【关键修复】: 限制莱维跳跃的跨度
                X(idx, :) = Xbest + 0.05 .* LF .* (ub - lb);
            end
            stag_count = 0;
        end
        
        it = it + 1; Convergence_curve(it) = XbestScore;
    end
end