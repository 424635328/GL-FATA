function [Xbest, XbestScore, Convergence_curve] = MFATA_Levy(fobj, lb, ub, dim, N, MaxFEs)
    if isscalar(lb), lb = ones(1, dim) .* lb; end
    if isscalar(ub), ub = ones(1, dim) .* ub; end

    worstInte = 0; bestInte = inf; gamma_coeff = 0.2; 
    XbestScore = inf; Xbest = zeros(1, dim);
    FEs = 0; it = 0; Convergence_curve = [];
    X = zeros(N, dim);
    for i = 1:N
        X(i, :) = lb + rand(1, dim) .* (ub - lb);
    end
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
                        X(i, j) = Xbest(j) + X(i, j) * Para1(j);
                    else
                        % MFATA-Levy 核心改进: 用莱维飞行替代部分全反射
                        if rand < 0.5 
                            beta_L = 1.5;
                            sigma = (gamma(1+beta_L)*sin(pi*beta_L/2)/(gamma((1+beta_L)/2)*beta_L*2^((beta_L-1)/2)))^(1/beta_L);
                            LF = (randn*sigma) / abs(randn)^(1/beta_L);
                            X(i, j) = X(i, j) + 0.01 * LF * (X(i, j) - Xbest(j));
                        else
                            Xtemp = X(num, j) + Para2(j) * X(i, j);
                            X(i, j) = 0.5 * (gamma_coeff + 1) * (lb(j) + ub(j)) - gamma_coeff * Xtemp;
                        end
                    end
                end
            end
        end
        it = it + 1; Convergence_curve(it) = XbestScore;
    end
end