%% FATA Algorithm with Debug/Snapshot Feature
function [bestPos, gBestScore, cg_curve, debugInfo] = FATA_Debug(fobj, lb, ub, dim, N, MaxFEs)

    % --- 初始化部分 ---
    worstInte = 0; 
    bestInte = Inf;
    noP = N;
    arf = 0.2; % 反射率
    gBest = zeros(1, dim);
    cg_curve = [];
    gBestScore = inf; 
    
    % 初始化种群
    Flight = initialization(noP, dim, ub, lb);
    fitness = zeros(noP, 1) + inf;
    
    it = 1;
    FEs = 0;
    
    % 边界处理
    if numel(lb) == 1, lb = ones(1, dim) * lb; end
    if numel(ub) == 1, ub = ones(1, dim) * ub; end
    
    % --- 可视化：预设 12 个快照的时间点 ---
    nSnapshots = 12;
    % 在 FEs 达到 1/12, 2/12 ... 12/12 时记录
    snapshot_targets = floor(linspace(MaxFEs/nSnapshots, MaxFEs, nSnapshots));
    snap_ptr = 1;
    debugInfo.Snapshots = cell(1, nSnapshots);
    debugInfo.Snapshot_FEs = zeros(1, nSnapshots);
    
    % 记录初始状态 (Frame 1)
    debugInfo.Snapshots{1} = Flight;
    debugInfo.Snapshot_FEs(1) = 0;
    snap_ptr = 2;

    % --- 主循环 ---
    while FEs < MaxFEs
        
        for i = 1:size(Flight, 1)
            % 边界检查
            Flag4ub = Flight(i, :) > ub;
            Flag4lb = Flight(i, :) < lb;
            Flight(i, :) = (Flight(i, :) .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;
            
            % 计算适应度
            FEs = FEs + 1;
            fitness(i) = fobj(Flight(i, :));
            
            % 更新全局最优
            if (gBestScore > fitness(i))
                gBestScore = fitness(i);
                gBest = Flight(i, :);
            end
            
            % --- 可视化核心：检查是否达到快照点 ---
            if snap_ptr <= nSnapshots && FEs >= snapshot_targets(snap_ptr)
                debugInfo.Snapshots{snap_ptr} = Flight;
                debugInfo.Snapshot_FEs(snap_ptr) = FEs;
                snap_ptr = snap_ptr + 1;
            end
            
            if FEs >= MaxFEs
                break;
            end
        end
        
        if FEs >= MaxFEs
            break;
        end

        % 排序以计算积分 (Mirage light filtering)
        [Order, ~] = sort(fitness);
        worstFitness = Order(N);
        % bestFitness = Order(1); % 未使用，注释掉以防警告

        %% The mirage light filtering principle
        Integral = cumtrapz(Order);
        if Integral(N) > worstInte
            worstInte = Integral(N);
        end
        if Integral(N) < bestInte
            bestInte = Integral(N);
        end
        % Eq.(4) population quality factor
        IP = (Integral(N) - worstInte) / (bestInte - worstInte + eps); 

        %% Calculation Para1 and Para2
        a = tan(-(FEs / MaxFEs) + 1);   % [0, 1.557]
        b = 1 / tan(-(FEs / MaxFEs) + 1); % [0.642, +inf]

        %% 更新位置
        for i = 1:size(Flight, 1)
            Para1 = a * rand(1, dim) - a * rand(1, dim); % Eq.(10)
            Para2 = b * rand(1, dim) - b * rand(1, dim); % Eq.(13)
            
            % Eq.(5) individual quality factor
            p = ((fitness(i) - worstFitness)) / (gBestScore - worstFitness + eps); 

            %% Eq.(1)
            if rand > IP
                Flight(i, :) = (ub - lb) .* rand + lb; % 随机重置
            else
                for j = 1:dim
                    num = floor(rand * N + 1);
                    if rand < p
                        % Light refraction (first phase) Eq.(8)
                        Flight(i, j) = gBest(j) + Flight(i, j) .* Para1(j);
                    else
                        % Light refraction (second phase) Eq.(11)
                        Flight(i, j) = Flight(num, j) + Para2(j) .* Flight(i, j);
                        % Light total internal reflection Eq.(14)
                        Flight(i, j) = (0.5 * (arf + 1) .* (lb(j) + ub(j)) - arf .* Flight(i, j));
                    end
                end
            end
        end
        
        cg_curve(it) = gBestScore;
        it = it + 1;
        bestPos = gBest;
    end
    
    % 确保所有快照都被填满（防止提前终止导致空缺）
    while snap_ptr <= nSnapshots
        debugInfo.Snapshots{snap_ptr} = Flight;
        debugInfo.Snapshot_FEs(snap_ptr) = FEs;
        snap_ptr = snap_ptr + 1;
    end
end

% ---------------------------------------------------------
% 辅助函数: initialization
% ---------------------------------------------------------
function Positions = initialization(SearchAgents_no, dim, ub, lb)
    Boundary_no = size(ub, 2);
    if Boundary_no == 1
        Positions = rand(SearchAgents_no, dim) .* (ub - lb) + lb;
    else
        % 如果 ub/lb 是向量
        Positions = zeros(SearchAgents_no, dim);
        for i = 1:dim
            ub_i = ub(i);
            lb_i = lb(i);
            Positions(:, i) = rand(SearchAgents_no, 1) .* (ub_i - lb_i) + lb_i;
        end
    end
end