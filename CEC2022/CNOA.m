function [bestPos,gBestScore,cg_curve]=CNOA(fobj,lb,ub,dim,N,MaxFEs)

%% ================= 初始化 =================
if isscalar(lb)
    lb = lb*ones(1,dim);
    ub = ub*ones(1,dim);
end

FEs = 0;
maxIter = ceil(MaxFEs / N);

narrative_max = 8;

% ---------- 初始化种群 ----------
for i = 1:N
    agents(i).position = lb + rand(1,dim).*(ub-lb);
    agents(i).fitness = fobj(agents(i).position);
    
    agents(i).model = randn(1,dim);
    agents(i).narratives = [];
    agents(i).trust = rand(1,N);
end

FEs = FEs + N;

% ---------- 全局最优 ----------
[fitnesses, idx] = sort([agents.fitness]);
gBestScore = fitnesses(1);
bestPos = agents(idx(1)).position;

cg_curve = zeros(1,maxIter);

%% ================= 主循环 =================
iter = 1;

while FEs < MaxFEs
    
    %% ===== 1. 个体认知搜索 =====
    for i = 1:N
        
        % --- 从叙事选择方向 ---
        if isempty(agents(i).narratives)
            dir = randn(1,dim);
        else
            k = randi(length(agents(i).narratives));
            dir = agents(i).narratives(k).direction;
        end
        
        % --- 认知模型融合 ---
        step = 0.6*dir + 0.4*agents(i).model;
        
        % --- 生成新解 ---
        new_pos = agents(i).position ...
            + 0.2*step ...
            + 0.05*randn(1,dim);
        
        % --- 边界处理 ---
        new_pos = max(new_pos, lb);
        new_pos = min(new_pos, ub);
        
        new_fit = fobj(new_pos);
        FEs = FEs + 1;
        
        % --- 成功更新 ---
        if new_fit < agents(i).fitness
            
            % ===== 创建叙事 =====
            direction = new_pos - agents(i).position;
            
            new_narrative.direction = direction;
            new_narrative.condition_center = agents(i).position;
            new_narrative.condition_radius = norm(direction)+1e-12;
            new_narrative.confidence = 1;
            
            agents(i).narratives = ...
                [agents(i).narratives, new_narrative];
            
            % 更新个体
            old_pos = agents(i).position;
            agents(i).position = new_pos;
            agents(i).fitness = new_fit;
            
            % 更新认知模型
            agents(i).model = ...
                0.7*agents(i).model + 0.3*(new_pos - old_pos);
        end
        
        if FEs >= MaxFEs
            break;
        end
        
    end
    
    %% ===== 2. 叙事传播 =====
    for i = 1:N
        
        trust = agents(i).trust;
        prob = trust / sum(trust);
        
        neighbors = find(rand(1,N) < prob);
        if isempty(neighbors)
            neighbors = randi(N);
        end
        
        for j = neighbors
            
            if ~isempty(agents(j).narratives)
                
                idx_n = randi(length(agents(j).narratives));
                incoming = agents(j).narratives(idx_n);
                
                % ===== 融合策略 =====
                if isempty(agents(i).narratives)
                    agents(i).narratives = incoming;
                else
                    if rand < 0.5
                        agents(i).narratives(end+1) = incoming;
                    else
                        k = randi(length(agents(i).narratives));
                        agents(i).narratives(k).direction = ...
                            0.5*agents(i).narratives(k).direction + ...
                            0.5*incoming.direction;
                        
                        agents(i).narratives(k).confidence = ...
                            agents(i).narratives(k).confidence + ...
                            incoming.confidence;
                    end
                end
                
            end
            
        end
        
    end
    
    %% ===== 3. 信任更新 =====
    fits = [agents.fitness];
    
    for i = 1:N
        for j = 1:N
            if fits(j) < fits(i)
                agents(i).trust(j) = agents(i).trust(j) + 0.01;
            else
                agents(i).trust(j) = agents(i).trust(j) * 0.99;
            end
        end
    end
    
    %% ===== 4. 认知遗忘 =====
    for i = 1:N
        
        if length(agents(i).narratives) > narrative_max
            
            conf = [agents(i).narratives.confidence];
            [~, idx] = sort(conf,'descend');
            
            agents(i).narratives = ...
                agents(i).narratives(idx(1:narrative_max));
        end
        
    end
    
    %% ===== 5. 更新全局最优 =====
    for i = 1:N
        if agents(i).fitness < gBestScore
            gBestScore = agents(i).fitness;
            bestPos = agents(i).position;
        end
    end
    
    cg_curve(iter) = gBestScore;
    iter = iter + 1;
    
end

end