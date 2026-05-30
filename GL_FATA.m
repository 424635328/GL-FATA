function [bestPos,gBestScore,cg_curve]=GL_FATA(fobj,lb,ub,dim,N,MaxFEs)
% 改进点:
% 1. Piecewise (PWLCM) 混沌映射初始化
% 2. 引入引导因子的折射更新策略
% 3. 针对全局最优的 Levy 飞行扰动

worstInte=0;
bestInte=Inf;
arf=0.2;
gBest=zeros(1,dim);
cg_curve=[];
gBestScore=inf;

Flight = initialization_PWLCM(N, dim, ub, lb);
fitness = zeros(N,1)+inf;

it=1;
FEs=0;

if isscalar(lb)
    lb=ones(1,dim).*lb;
    ub=ones(1,dim).*ub;
end

while  FEs < MaxFEs
    
    for i=1:size(Flight,1)
        Flag4ub=Flight(i,:)>ub;
        Flag4lb=Flight(i,:)<lb;
        Flight(i,:)=(Flight(i,:).*(~(Flag4ub+Flag4lb)))+ub.*Flag4ub+lb.*Flag4lb;
        
        if FEs < MaxFEs
            fitness(i)=fobj(Flight(i,:));
            FEs=FEs+1;
            
            if(gBestScore>fitness(i))
                gBestScore=fitness(i);
                gBest=Flight(i,:);
            end
        end
    end
    
    if FEs >= MaxFEs, break; end
    
    [Order,Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1); 
    
    Integral=cumtrapz(Order);
    if Integral(N)>worstInte
        worstInte=Integral(N);
    end
    if Integral(N)<bestInte
        bestInte =Integral(N);
    end
    IP=(Integral(N)-worstInte)/(bestInte-worstInte+eps);
    
    a = tan(-(FEs/MaxFEs)+1);
    b = 1/tan(-(FEs/MaxFEs)+1);
    
    for i=1:size(Flight,1)
        Para1=a*rand(1,dim)-a*rand(1,dim);
        Para2=b*rand(1,dim)-b*rand(1,dim);
        p=((fitness(i)-worstFitness))/(gBestScore-worstFitness+eps);
        
        if rand > IP
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
                    Flight(i,j)=Flight(num,j)+Para2(j).*Flight(i,j);
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
            alpha = 0.01; 
            
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

%% --- Piecewise (PWLCM) 混沌映射初始化函数 ---
function Positions = initialization_PWLCM(SearchAgents_no, dim, ub, lb)
% SearchAgents_no: 种群数量 (N)
% dim: 维度
% ub, lb: 上下界

    Positions = zeros(SearchAgents_no, dim);
    
    % 统一处理边界，将其转换为向量
    if isscalar(lb), lb = ones(1, dim) * lb; end
    if isscalar(ub), ub = ones(1, dim) * ub; end

    P = 0.4; % PWLCM 控制参数
    x = rand; % 生成一个全局随机种子 (只生成一次)

    for j = 1:dim
        for i = 1:SearchAgents_no
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