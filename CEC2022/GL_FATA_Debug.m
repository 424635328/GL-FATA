function [bestPos, gBestScore, cg_curve, debugInfo] = GL_FATA_Debug(fobj, lb, ub, dim, N, MaxFEs)
% GL_FATA_Debug: 记录完整历史轨迹版本

%% 初始化
worstInte=0; bestInte=Inf; arf=0.2;
gBest=zeros(1,dim); cg_curve=[]; gBestScore=inf;

% --- 统计与历史记录 ---
Levy_Stats = [0, 0]; 
History.Pos = {};   %用于存储每一代的粒子位置矩阵
History.gBest = []; %用于存储每一代的全局最优位置

Flight = initialization_Tent(N, dim, ub, lb); % 确保你已经修复了初始化函数
fitness = zeros(N,1)+inf;

it=1;
FEs=0;

if isscalar(lb), lb=ones(1,dim).*lb; ub=ones(1,dim).*ub; end

%% 主循环
while  FEs < MaxFEs
    
    % --- 1. 记录当前代的所有粒子位置 ---
    % 注意：为了节省内存，如果 MaxFEs 极大，可以每隔几代存一次。
    % 但对于 30000 FEs，完全存下没问题。
    History.Pos{it} = Flight; 
    
    % --- 边界检查与适应度 ---
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
    
    % --- 记录每一代的 gBest ---
    History.gBest(it, :) = gBest;
    
    if FEs >= MaxFEs, break; end
    
    % --- 排序与积分原理 ---
    [Order,Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1); 
    
    Integral=cumtrapz(Order);
    if Integral(N)>worstInte, worstInte=Integral(N); end
    if Integral(N)<bestInte, bestInte =Integral(N); end
    IP=(Integral(N)-worstInte)/(bestInte-worstInte+eps);
    
    a = tan(-(FEs/MaxFEs)+1);
    b = 1/tan(-(FEs/MaxFEs)+1);
    
    %% 位置更新 (修复了 rand 维度问题的版本)
    for i=1:size(Flight,1)
        Para1=a*rand(1,dim)-a*rand(1,dim);
        Para2=b*rand(1,dim)-b*rand(1,dim);
        p=((fitness(i)-worstFitness))/(gBestScore-worstFitness+eps);
        
        if rand > IP
            % [关键修复] 必须是 rand(1,dim)
            Flight(i,:) = (ub-lb).*rand(1,dim)+lb; 
        else
            for j=1:dim
                num=floor(rand*N+1);
                if rand < p
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
    
    %% 莱维飞行
    if FEs < MaxFEs
        Levy_Prob = 0.2;
        if rand < Levy_Prob
            Levy_Stats(1) = Levy_Stats(1) + 1;
            LF = Levy(dim);
            alpha = 0.01; 
            gBest_new = gBest + alpha .* LF .* (ub - lb);
            gBest_new = max(gBest_new, lb); gBest_new = min(gBest_new, ub);
            fit_new = fobj(gBest_new);
            FEs = FEs + 1;
            if fit_new < gBestScore
                gBestScore = fit_new;
                gBest = gBest_new;
                Levy_Stats(2) = Levy_Stats(2) + 1;
            end
        end
    end
    
    cg_curve(it)=gBestScore;
    it=it+1;
    bestPos=gBest;
end

% 记录最后一代
History.Pos{it} = Flight;
History.gBest(it, :) = gBest;

debugInfo.History = History;
debugInfo.LevyStats = Levy_Stats;
end

% --- 辅助函数保持不变 ---
function s = Levy(d)
beta = 1.5;
sigma = (gamma(1+beta)*sin(pi*beta/2)/(gamma((1+beta)/2)*beta*2^((beta-1)/2)))^(1/beta);
u = randn(1,d)*sigma;
v = randn(1,d);
step = u./abs(v).^(1/beta);
s = step;
end

function Positions = initialization_Tent(SearchAgents_no, dim, ub, lb)
% 已修复的 Tent 初始化
Positions = zeros(SearchAgents_no, dim);
if isscalar(lb), lb=ones(1,dim)*lb; end
if isscalar(ub), ub=ones(1,dim)*ub; end
for i = 1:SearchAgents_no
    for j = 1:dim
        z = rand; 
        for k=1:10, if z<0.5, z=2*z; else, z=2*(1-z); end; end % 预热
        Positions(i,j) = lb(j) + z * (ub(j) - lb(j));
    end
end
end