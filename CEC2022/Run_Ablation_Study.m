function Run_Ablation_Study()
% =========================================================================
% GL_FATA 消融实验主程序 (针对 CEC 2022 测试集)
% 修改说明：已将 Tent 初始化替换为 PWLCM (分段线性混沌映射) 初始化
% =========================================================================

clc; clear; close all;

%% 1. 实验参数设置
ExpName = 'Ablation_Experiment_Results.mat'; % 结果保存文件名
dim = 20;                % 维度 (10 或 20)
N = 30;                  % 种群大小
MaxFEs = 10000 * dim;    % 最大评估次数
Runs = 30;               % 独立运行次数
Func_List = 1:12;        % CEC2022 函数编号 (1-12)
lb = -100;               % 下界
ub = 100;                % 上界

% 定义消融实验的算法变体
% 结构：Name, useChaos(是否使用混沌初始化), useGuide(引导因子), useLevy(莱维飞行)
% 注意：这里的 useChaos = 1 代表使用 PWLCM
Algo_Variants = {
    'FATA_Original',     0, 0, 0;  % 原始算法
    'GL_FATA_NoPWLCM',   0, 1, 1;  % 无混沌初始化 (即使用随机初始化)
    'GL_FATA_NoGuide',   1, 0, 1;  % 无引导折射
    'GL_FATA_NoLevy',    1, 1, 0;  % 无莱维飞行
    'GL_FATA_Final',     1, 1, 1;  % 完整改进算法 (Proposed with PWLCM)
    };

nAlgos = size(Algo_Variants, 1);
nFuncs = length(Func_List);

%% 2. 初始化或加载断点数据
if exist(ExpName, 'file')
    fprintf('检测到上次实验数据，正在加载并继续运行...\n');
    load(ExpName, 'ResultData',  'completed_runs');
else
    fprintf('开始新的实验...\n');
    ResultData = nan(nAlgos, nFuncs, Runs);
    completed_runs = false(nAlgos, nFuncs, Runs);
    save(ExpName, 'ResultData', 'completed_runs', 'Algo_Variants', 'Func_List');
end

%% 3. 主循环
for func_idx = 1:nFuncs
    fid = Func_List(func_idx);
    fprintf('\n================== 处理函数 F%d ==================\n', fid);
    
    for algo_idx = 1:nAlgos
        algo_name = Algo_Variants{algo_idx, 1};
        useChaos  = Algo_Variants{algo_idx, 2}; % 对应 PWLCM
        useGuide  = Algo_Variants{algo_idx, 3};
        useLevy   = Algo_Variants{algo_idx, 4};
        
        fprintf('  -> 算法: %-15s | ', algo_name);
        
        % 检查该组是否全部跑完，如果是则跳过 (为了兼容断点续传)
        if all(completed_runs(algo_idx, func_idx, :))
            fprintf('已完成 (Skipped)\n');
            continue;
        end

        % 预分配临时数组
        temp_res = nan(1, Runs);
        
        % 如果有并行工具箱，可将 for 改为 parfor
        for run = 1:Runs  
            
            % 检查该轮是否已跑完
            if completed_runs(algo_idx, func_idx, run)
                temp_res(run) = ResultData(algo_idx, func_idx, run);
                continue;
            end
            
            % 定义目标函数句柄 (适配 CEC2022 MEX 文件)
            fobj = @(x) cec22_wrapper(x, fid);
            
            % 设置随机种子，保证实验可复现性
            rand('state', sum(100*clock) + run); 
            
            % 运行通用 FATA 引擎
            [~, BestScore, ~] = Universal_FATA(fobj, lb, ub, dim, N, MaxFEs, ...
                useChaos, useGuide, useLevy);
            
            % 记录结果
            temp_res(run) = BestScore;
        end
        
        % 将结果写回矩阵并保存
        for run = 1:Runs
            if ~completed_runs(algo_idx, func_idx, run)
                ResultData(algo_idx, func_idx, run) = temp_res(run);
                completed_runs(algo_idx, func_idx, run) = true;
            end
        end
        
        % 保存进度
        save(ExpName, 'ResultData', 'completed_runs', 'Algo_Variants', 'Func_List');
        
        % 打印该组平均值
        current_mean = mean(ResultData(algo_idx, func_idx, :));
        fprintf('Mean: %.4e\n', current_mean);
    end
end

%% 4. 数据处理与统计分析 (生成 Excel 表格数据)
fprintf('\n================== 实验结束，正在生成统计报表 ==================\n');

Stats = struct();
% 找到 GL_FATA_Final 的索引
final_algo_idx = find(strcmp(Algo_Variants(:,1), 'GL_FATA_Final'));

for func_idx = 1:nFuncs
    fid = Func_List(func_idx);
    Function_Struct = struct();
    
    for algo_idx = 1:nAlgos
        algo_name = Algo_Variants{algo_idx, 1};
        data = squeeze(ResultData(algo_idx, func_idx, :));
        
        % 计算指标
        Function_Struct.(algo_name).Best = min(data);
        Function_Struct.(algo_name).Worst = max(data);
        Function_Struct.(algo_name).Median = median(data);
        Function_Struct.(algo_name).Mean = mean(data);
        Function_Struct.(algo_name).Std = std(data);
        
        % Wilcoxon 检验 (对比 GL_FATA_Final)
        if algo_idx == final_algo_idx
            Function_Struct.(algo_name).p_value = NaN;
            Function_Struct.(algo_name).Sign = '=';
        else
            final_data = squeeze(ResultData(final_algo_idx, func_idx, :));
            p = ranksum(data, final_data);
            Function_Struct.(algo_name).p_value = p;
            
            % 判断显著性 (0.05)
            if p < 0.05
                if mean(data) < mean(final_data)
                    sig = '+'; 
                else
                    sig = '-'; 
                end
            else
                sig = '~'; % 无显著差异
            end
            Function_Struct.(algo_name).Sign = sig;
        end
    end
    Stats.(['F', num2str(fid)]) = Function_Struct;
end

save(ExpName, 'ResultData', 'completed_runs', 'Algo_Variants', 'Func_List', 'Stats');
fprintf('所有数据已保存至: %s\n', ExpName);

% 简单打印 F1 的结果示例
disp('F1 统计结果示例:');
disp(Stats.F1);
end

%% ========================================================================
%  通用 FATA 引擎 (集成了原始和改进逻辑)
% ========================================================================
function [bestPos, gBestScore, cg_curve] = Universal_FATA(fobj, lb, ub, dim, N, MaxFEs, useChaos, useGuide, useLevy)

% 初始化
worstInte = 0;
bestInte = Inf;
arf = 0.2;
gBest = zeros(1, dim);
gBestScore = inf;
cg_curve = [];

% --- 策略 1: 初始化 (PWLCM vs Random) ---
if useChaos
    Flight = initialization_PWLCM(N, dim, ub, lb); % 使用 PWLCM
else
    Flight = initialization_Random(N, dim, ub, lb); % 使用随机
end

fitness = zeros(N, 1) + inf;
FEs = 0;
it = 1;

% 确保边界是向量形式，方便计算
if isscalar(lb), lb = ones(1, dim) * lb; end
if isscalar(ub), ub = ones(1, dim) * ub; end

while FEs < MaxFEs
    
    % 边界检查与评估
    for i = 1:size(Flight, 1)
        % 简单的边界处理
        Flag4ub = Flight(i, :) > ub;
        Flag4lb = Flight(i, :) < lb;
        Flight(i, :) = (Flight(i, :) .* (~(Flag4ub + Flag4lb))) + ub .* Flag4ub + lb .* Flag4lb;
        
        if FEs < MaxFEs
            fit_val = fobj(Flight(i, :));
            fitness(i) = fit_val;
            FEs = FEs + 1;
            
            if fit_val < gBestScore
                gBestScore = fit_val;
                gBest = Flight(i, :);
            end
        end
    end
    
    if FEs >= MaxFEs, break; end
    
    % 排序与光照计算
    [Order, Index] = sort(fitness);
    worstFitness = Order(N);
    BestIndi_Index = Index(1); % 获取当前最优个体的索引
    
    Integral = cumtrapz(Order);
    if Integral(N) > worstInte, worstInte = Integral(N); end
    if Integral(N) < bestInte,  bestInte = Integral(N);  end
    IP = (Integral(N) - worstInte) / (bestInte - worstInte + eps);
    
    a = tan(-(FEs / MaxFEs) + 1);
    b = 1 / tan(-(FEs / MaxFEs) + 1);
    
    % 位置更新
    for i = 1:size(Flight, 1)
        Para1 = a * rand(1, dim) - a * rand(1, dim);
        Para2 = b * rand(1, dim) - b * rand(1, dim);
        p = ((fitness(i) - worstFitness)) / (gBestScore - worstFitness + eps);
        
        if rand > IP
            Flight(i, :) = (ub - lb) .* rand(1, dim) + lb;
        else
            for j = 1:dim
                num = floor(rand * N + 1);
                if rand < p
                    % --- 策略 2: 折射更新 ---
                    if useGuide
                        % 改进策略: 区分最优和普通个体
                        if i == BestIndi_Index
                            Flight(i, j) = gBest(j) + Flight(i, j) .* Para1(j);
                        else
                            % 引导因子 * 2.0
                            Flight(i, j) = gBest(j) + (gBest(j) - Flight(i, j)) .* Para1(j) * 2.0;
                        end
                    else
                        % 原版策略
                        Flight(i, j) = gBest(j) + Flight(i, j) .* Para1(j);
                    end
                else
                    % 第二阶段折射
                    Flight(i, j) = Flight(num, j) + Para2(j) .* Flight(i, j);
                    % 全反射
                    Flight(i, j) = (0.5 * (arf + 1) .* (lb(j) + ub(j)) - arf .* Flight(i, j));
                end
            end
        end
    end
    
    % --- 策略 3: 莱维飞行 ---
    if useLevy && (FEs < MaxFEs)
        Levy_Prob = 0.2;
        if rand < Levy_Prob
            LF = Levy(dim);
            alpha = 0.01;
            gBest_new = gBest + alpha .* LF .* (ub - lb);
            gBest_new = max(gBest_new, lb);
            gBest_new = min(gBest_new, ub);
            
            fit_new = fobj(gBest_new);
            FEs = FEs + 1;
            
            if fit_new < gBestScore
                gBestScore = fit_new;
                gBest = gBest_new;
            end
        end
    end
    
    cg_curve(it) = gBestScore;
    it = it + 1;
    bestPos = gBest;
end
end

% ---------------- 辅助函数 ----------------

function val = cec22_wrapper(x, fid)
% CEC2022 Wrapper
val = cec22_func(x', fid);
end

function Positions = initialization_Random(N, dim, ub, lb)
% 标准随机初始化
Boundary_no = size(ub, 2); 
if Boundary_no == 1
    Positions = rand(N, dim) .* (ub - lb) + lb;
else
    Positions = zeros(N, dim);
    for i = 1:dim
        ub_i = ub(i);
        lb_i = lb(i);
        Positions(:, i) = rand(N, 1) .* (ub_i - lb_i) + lb_i;
    end
end
end

function Positions = initialization_PWLCM(N, dim, ub, lb)
% initialization_PWLCM: 使用分段线性混沌映射初始化种群
%
% 输入:
%   N: 种群大小
%   dim: 维度
%   ub: 上界 (标量或向量)
%   lb: 下界 (标量或向量)
% 输出:
%   Positions: 初始化后的种群矩阵 (N x dim)

    Positions = zeros(N, dim);
    p_pwlcm = 0.4; % PWLCM 控制参数，通常取 [0.2, 0.45]

    % 1. 生成初始混沌向量 (种子)
    % 我们可以对每个维度、每个个体都进行混沌迭代
    % 这里为了效率和混沌性，生成 N*dim 个随机数作为起点，然后迭代几次进入混沌状态
    chaos_val = rand(N, dim);
    
    % 可选：预热迭代 (去掉瞬态)
    for k = 1:10
         % 向量化操作需要小心，这里用双重循环最稳妥
        for i = 1:N
            for j = 1:dim
                c = chaos_val(i, j);
                if c < p_pwlcm
                    c = c / p_pwlcm;
                elseif c < 0.5
                    c = (c - p_pwlcm) / (0.5 - p_pwlcm);
                elseif c < 1 - p_pwlcm
                    c = (1 - p_pwlcm - c) / (0.5 - p_pwlcm);
                else
                    c = (1 - c) / p_pwlcm;
                end
                chaos_val(i, j) = c;
            end
        end
    end

    % 2. 映射到搜索空间
    for i = 1:N
        for j = 1:dim
            c = chaos_val(i, j);
            
            % 执行一次 PWLCM 迭代，保持序列连续性
            if c < p_pwlcm
                c = c / p_pwlcm;
            elseif c < 0.5
                c = (c - p_pwlcm) / (0.5 - p_pwlcm);
            elseif c < 1 - p_pwlcm
                c = (1 - p_pwlcm - c) / (0.5 - p_pwlcm);
            else
                c = (1 - c) / p_pwlcm;
            end
            
            % 将 [0,1] 的 c 映射到 [lb, ub]
            if length(ub) == 1
                pos = lb + c * (ub - lb);
                % 边界防护
                pos = max(lb, min(ub, pos));
                Positions(i, j) = pos;
            else
                pos = lb(j) + c * (ub(j) - lb(j));
                % 边界防护
                pos = max(lb(j), min(ub(j), pos));
                Positions(i, j) = pos;
            end
        end
    end
end

function s = Levy(d)
beta = 1.5;
sigma = (gamma(1 + beta) * sin(pi * beta / 2) / ...
    (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);
u = randn(1, d) * sigma;
v = randn(1, d);
s = u ./ abs(v).^(1 / beta);
end