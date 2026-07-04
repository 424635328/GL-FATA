function [bestPos,gBestScore,cg_curve]=GL_FATA(fobj,lb,ub,dim,N,MaxFEs)
% 改进版 FATA 算法
% 改进点:
% 1. Piecewise (PWLCM) 混沌映射初始化 (已修改)
% 2. 引入引导因子的折射更新策略
% 3. 针对全局最优的 Levy 飞行扰动

%% 初始化阶段
worstInte=0;
bestInte=Inf;
arf=0.2;
gBest=zeros(1,dim);
cg_curve=[];
gBestScore=inf;

% --- 修改处 1：调用新的 PWLCM 初始化函数 ---
Flight = initialization_PWLCM(N, dim, ub, lb);
fitness = zeros(N,1)+inf;

it=1;
FEs=0;

% 处理边界为向量的情况 (防止主函数传入标量导致后续逻辑出错)
if isscalar(lb)
    lb=ones(1,dim).*lb;
    ub=ones(1,dim).*ub;
end

%% 主循环
while  FEs < MaxFEs
    
    % 1. 边界检查与适应度计算
    for i=1:size(Flight,1)
        Flag4ub=Flight(i,:)>ub;
        Flag4lb=Flight(i,:)<lb;
        Flight(i,:)=(Flight(i,:).*(~(Flag4ub+Flag4lb)))+ub.*Flag4ub+lb.*Flag4lb;
        
        % 只有在FEs没用完时才计算
        if FEs < MaxFEs
            fitness(i)=fobj(Flight(i,:));
            FEs=FEs+1;
            
            % 更新全局最优
            if(gBestScore>fitness(i))
                gBestScore=fitness(i);
                gBest=Flight(i,:);
            end
        end
    end
    
    if FEs >= MaxFEs, break; end
    
    % 2. 排序与积分原理计算
    [Order,Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1); % 获取当前代最优个体的索引
    
    Integral=cumtrapz(Order);
    if Integral(N)>worstInte
        worstInte=Integral(N);
    end
    if Integral(N)<bestInte
        bestInte =Integral(N);
    end
    IP=(Integral(N)-worstInte)/(bestInte-worstInte+eps);
    
    % 计算动态参数 a 和 b
    a = tan(-(FEs/MaxFEs)+1);
    b = 1/tan(-(FEs/MaxFEs)+1);
    
    %% 3. 位置更新
    for i=1:size(Flight,1)
        Para1=a*rand(1,dim)-a*rand(1,dim);
        Para2=b*rand(1,dim)-b*rand(1,dim);
        p=((fitness(i)-worstFitness))/(gBestScore-worstFitness+eps);
        
        if rand > IP
            % 随机重置
            Flight(i,:) = (ub-lb).*rand(1,dim)+lb;
        else
            for j=1:dim
                num=floor(rand*N+1);
                if rand < p
                    % --- 改进策略: 区分最优个体与普通个体 ---
                    if i == BestIndi_Index
                        Flight(i,j) = gBest(j) + Flight(i,j).*Para1(j);
                    else
                        Flight(i,j) = gBest(j) + (gBest(j)-Flight(i,j)).*Para1(j)*1.832;
                    end
                else
                    % 第二阶段折射
                    Flight(i,j)=Flight(num,j)+Para2(j).*Flight(i,j);
                    % 全反射
                    Flight(i,j)=(0.5*(arf+1).*(lb(j)+ub(j))-arf.*Flight(i,j));
                end
            end
        end
    end
    
    %% 4. 莱维飞行策略
    if FEs < MaxFEs
        Levy_Prob = 0.2;
        
        if rand < Levy_Prob
            LF = Levy(dim);
            alpha = 0.01; % 步长缩放因子
            
            % 基于莱维飞行的位置更新
            gBest_new = gBest + alpha .* LF .* (ub - lb);
            
            gBest_new = max(gBest_new, lb);
            gBest_new = min(gBest_new, ub);
            
            % 计算新适应度
            fit_new = fobj(gBest_new);
            FEs = FEs + 1;
            
            % 贪婪更新
            if fit_new < gBestScore
                gBestScore = fit_new;
                gBest = gBest_new;
            end
        end
    end
    
    cg_curve(it)=gBestScore;
    it=it+1;
    bestPos=gBest;
end
end

%% 辅助函数：莱维飞行
function s = Levy(d)
beta = 1.5;
sigma = (gamma(1+beta)*sin(pi*beta/2)/(gamma((1+beta)/2)*beta*2^((beta-1)/2)))^(1/beta);
u = randn(1,d)*sigma;
v = randn(1,d);
step = u./abs(v).^(1/beta);
s = step;
end

%% --- 修改处 2：Piecewise (PWLCM) 混沌映射初始化函数 ---
function Positions = initialization_PWLCM(SearchAgents_no, dim, ub, lb)
% PWLCM 初始化
% SearchAgents_no: 种群数量 (N)
% dim: 维度
% ub, lb: 上下界

    Positions = zeros(SearchAgents_no, dim);
    
    % 统一处理边界，将其转换为向量，避免在循环中重复判断
    if isscalar(lb), lb = ones(1, dim) * lb; end
    if isscalar(ub), ub = ones(1, dim) * ub; end

    P = 0.4; % PWLCM 控制参数 (0 < P < 0.5)

    for i = 1:SearchAgents_no
        % 为每个个体生成一个初始随机种子
        x = rand; 
        
        for j = 1:dim
            % --- Piecewise Map 核心迭代公式 ---
            if x >= 0 && x < P
                x = x / P;
            elseif x >= P && x < 0.5
                x = (x - P) / (0.5 - P);
            elseif x >= 0.5 && x < (1 - P)
                x = (1 - P - x) / (0.5 - P);
            else
                x = (1 - x) / P;
            end
            
            % 映射到搜索空间 [lb, ub]
            Positions(i,j) = lb(j) + x * (ub(j) - lb(j));
        end
    end
end