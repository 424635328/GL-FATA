function [Xbest, XbestScore, Convergence_curve] = HMIFATA(fobj, lb, ub, dim, N, MaxFEs)
    if isscalar(lb), lb = ones(1, dim) .* lb; end
    if isscalar(ub), ub = ones(1, dim) .* ub; end

    worstInte = 0; bestInte = inf; gamma_coeff = 0.2; 
    XbestScore = inf; Xbest = zeros(1, dim);
    FEs = 0; it = 0; Convergence_curve = [];
    X = lb + rand(N, dim) .* (ub - lb);
    fitness = zeros(1, N) + inf;

    while FEs < MaxFEs
        for i = 1:N
            X(i, :) = max(min(X(i, :), ub), lb);
            if FEs < MaxFEs
                fitness(i) = fobj(X(i, :));
                FEs = FEs + 1;
                if fitness(i) < XbestScore
                    Xbest = X(i, :); XbestScore = fitness(i);
                end
            end
        end
        if FEs >= MaxFEs, break; end

        [sorted_fitness, sort_idx] = sort(fitness);
        worstFitness = sorted_fitness(end);
        elites = X(sort_idx(1:min(3, N)), :); 
        
        Integral = cumtrapz(sorted_fitness);
        if Integral(end) > worstInte, worstInte = Integral(end); end
        if Integral(end) < bestInte, bestInte = Integral(end); end
        IP = (Integral(end) - worstInte) / (bestInte - worstInte + 1e-15);
        IP = max(0, min(1, IP));

        alpha = max(tan(-(FEs / MaxFEs) + 1), 1e-10);
        beta = 1 / alpha;

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
                        rand_elite = elites(randi([1, size(elites,1)]), j);
                        % 修正为带方向的差分引力
                        X(i, j) = rand_elite + (rand_elite - X(i, j)) * Para1(j);
                    else
                        Xtemp = X(num, j) + Para2(j) * X(i, j);
                        X(i, j) = 0.5 * (gamma_coeff + 1) * (lb(j) + ub(j)) - gamma_coeff * Xtemp;
                    end
                end
            end
        end

        % 全局柯西变异 (Cauchy Mutation)
        if rand < 0.2
            cauchy_noise = tan(pi * (rand(1, dim) - 0.5));
            % 【关键修复】: 加入平方级别的二次收缩步长，避免柯西大数值在后期破坏精度
            step = 0.02 * (ub - lb) * (1 - FEs/MaxFEs)^2;
            
            Xbest_mut = Xbest + step .* cauchy_noise;
            Xbest_mut = max(min(Xbest_mut, ub), lb);
            if FEs < MaxFEs
                fit_mut = fobj(Xbest_mut);
                FEs = FEs + 1;
                if fit_mut < XbestScore
                    XbestScore = fit_mut; Xbest = Xbest_mut;
                end
            end
        end
        it = it + 1; Convergence_curve(it) = XbestScore;
    end
end