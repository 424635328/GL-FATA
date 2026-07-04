%% CEC2022 数据导出专用脚本
% 功能：读取 CEC2022_Data.mat 并导出统计指标、原始数据、时间与排名
% 输出文件：
% 1. Table_Stats.xlsx       (包含 Min, Mean, Std, Median, Worst 汇总表)
% 2. Table_RawData.xlsx     (包含每个函数30次独立运行的原始数据，分Sheet存储)
% 3. Table_PValues.xlsx     (Wilcoxon 秩和检验 P值)
% 4. Table_Friedman.xlsx    (Friedman 排名统计)

clear; clc;

% ================= 配置 =================
mat_file = 'CEC2022_Data.mat';
% =======================================

%% 1. 数据加载与预处理
fprintf('>>> 正在加载数据文件: %s ...\n', mat_file);
if ~exist(mat_file, 'file')
    error(['错误：未找到文件 ', mat_file, '。请先运行主程序生成数据。']);
end
load(mat_file, 'SavedData');

% --- 自动识别有效的函数编号 ---
% 因为 SavedData.F 可能是 [1x12 struct] 但中间可能有空数据
valid_f_idx = [];
for i = 1:length(SavedData.F)
    if ~isempty(SavedData.F(i).Alg)
        valid_f_idx = [valid_f_idx, i];
    end
end
num_funcs = length(valid_f_idx);

% --- 自动识别算法名称 ---
first_func = valid_f_idx(1);
num_algos = length(SavedData.F(first_func).Alg);
Algo_List = cell(1, num_algos);
for i = 1:num_algos
    Algo_List{i} = SavedData.F(first_func).Alg(i).Name;
end

fprintf('    检测到函数数量: %d (F%s)\n', num_funcs, num2str(valid_f_idx));
fprintf('    检测到算法列表: %s\n', strjoin(Algo_List, ', '));

%% 2. 导出统计指标表 (Table_Stats.xlsx)
file_stats = 'Table_Stats.xlsx';
if exist(file_stats, 'file'), delete(file_stats); end

fprintf('\n>>> 正在生成统计指标表 (%s) ...\n', file_stats);

Header_Row = [{'Function', 'Metric'}, Algo_List];
Output_Cell = {};

% 准备用于 Friedman 检验的 Mean 矩阵
Friedman_Mean_Matrix = zeros(num_funcs, num_algos);

for f_i = 1:num_funcs
    fid = valid_f_idx(f_i);
    f_str = ['F', num2str(fid)];
    
    % 提取该函数下所有算法的数据
    row_min = {f_str, 'Min'};
    row_mean = {'', 'Mean'};
    row_std = {'', 'Std'};
    row_med = {'', 'Median'};
    row_worst = {'', 'Worst'};
    
    for a_i = 1:num_algos
        fitness = SavedData.F(fid).Alg(a_i).Fitness;
        % 剔除 NaN
        fitness = fitness(~isnan(fitness));
        
        if isempty(fitness)
            val_min=NaN; val_mean=NaN; val_std=NaN; val_med=NaN; val_worst=NaN;
        else
            val_min = min(fitness);
            val_mean = mean(fitness);
            val_std = std(fitness);
            val_med = median(fitness);
            val_worst = max(fitness);
        end
        
        % 记录 Mean 用于后续 Friedman 计算
        Friedman_Mean_Matrix(f_i, a_i) = val_mean;
        
        row_min{end+1} = val_min;
        row_mean{end+1} = val_mean;
        row_std{end+1} = val_std;
        row_med{end+1} = val_med;
        row_worst{end+1} = val_worst;
    end
    
    % 拼接到大表中
    Output_Cell = [Output_Cell; row_min; row_mean; row_std; row_med; row_worst];
    
    % 添加一个空行分隔函数
    Output_Cell = [Output_Cell; repmat({''}, 1, size(Output_Cell,2))]; 
end

writecell([Header_Row; Output_Cell], file_stats);
fprintf('    完成。\n');

%% 3. 导出原始数据 (Table_RawData.xlsx) - 每个函数一个 Sheet
file_raw = 'Table_RawData.xlsx';
if exist(file_raw, 'file'), delete(file_raw); end

fprintf('\n>>> 正在导出原始 30 次运行数据 (%s) ...\n', file_raw);

for f_i = 1:num_funcs
    fid = valid_f_idx(f_i);
    sheet_name = ['F', num2str(fid)];
    
    % 构建矩阵: 行=次数, 列=算法
    % 先找到最大运行次数 (防止有的没跑完)
    max_runs = 0;
    for a_i = 1:num_algos
        max_runs = max(max_runs, length(SavedData.F(fid).Alg(a_i).Fitness));
    end
    
    raw_matrix = nan(max_runs, num_algos);
    for a_i = 1:num_algos
        d = SavedData.F(fid).Alg(a_i).Fitness;
        raw_matrix(1:length(d), a_i) = d(:);
    end
    
    % 写入 Header 和 数据
    writecell(Algo_List, file_raw, 'Sheet', sheet_name, 'Range', 'A1');
    writematrix(raw_matrix, file_raw, 'Sheet', sheet_name, 'Range', 'A2');
end
fprintf('    完成 (每个函数单独一个 Sheet)。\n');

%% 4. 导出秩和检验 P-Values (Table_PValues.xlsx)
file_pval = 'Table_PValues.xlsx';
if exist(file_pval, 'file'), delete(file_pval); end

fprintf('\n>>> 正在计算 Wilcoxon 秩和检验 (%s) ...\n', file_pval);

% 假设第1个算法是本算法，其他的都是对比算法
Base_Algo = Algo_List{1};
Comparison_Algos = Algo_List(2:end);
num_comp = length(Comparison_Algos);

PVal_Data = cell(num_funcs, num_comp + 1); % +1 是函数名列

for f_i = 1:num_funcs
    fid = valid_f_idx(f_i);
    PVal_Data{f_i, 1} = ['F', num2str(fid)];
    
    % 基准数据
    base_data = SavedData.F(fid).Alg(1).Fitness;
    base_data = base_data(~isnan(base_data));
    
    for c_i = 1:num_comp
        comp_idx = c_i + 1; % 在原列表中的索引
        comp_data = SavedData.F(fid).Alg(comp_idx).Fitness;
        comp_data = comp_data(~isnan(comp_data));
        
        if isempty(base_data) || isempty(comp_data)
            p = 1; 
        else
            p = ranksum(base_data, comp_data);
        end
        
        % 格式化 P值，加符号标记
        if p < 0.05
            p_str = sprintf('%.2e (+)', p); % 显著差异
        else
            p_str = sprintf('%.2e (=)', p); % 无显著差异
        end
        PVal_Data{f_i, c_i+1} = p_str;
    end
end

Header_Pval = [{'Function'}, Comparison_Algos];
writecell([Header_Pval; PVal_Data], file_pval);
fprintf('    完成 (对比基准: %s)。\n', Base_Algo);

%% 5. 导出 Friedman 排名 (Table_Friedman.xlsx)
file_rank = 'Table_Friedman.xlsx';
if exist(file_rank, 'file'), delete(file_rank); end

fprintf('\n>>> 正在计算 Friedman 排名 (%s) ...\n', file_rank);

% 计算排名矩阵
[rows, cols] = size(Friedman_Mean_Matrix);
Ranks = zeros(rows, cols);
for r = 1:rows
    Ranks(r, :) = tiedrank(Friedman_Mean_Matrix(r, :));
end

Mean_Ranks = mean(Ranks, 1);
[Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
Sorted_Algos = Algo_List(Sort_Idx);

% 准备 Summary Sheet
Summary_Data = cell(num_algos, 2);
for i = 1:num_algos
    Summary_Data{i, 1} = Sorted_Algos{i};
    Summary_Data{i, 2} = Sorted_Ranks(i);
end
Header_Sum = {'Algorithm', 'Mean Rank'};

% 准备 Detailed Sheet (每个函数上的排名)
Func_Col = cell(num_funcs, 1);
for i = 1:num_funcs, Func_Col{i} = ['F', num2str(valid_f_idx(i))]; end
Detail_Data = [Func_Col, num2cell(Ranks)];
Header_Detail = [{'Function'}, Algo_List];

writecell([Header_Sum; Summary_Data], file_rank, 'Sheet', 'Summary');
writecell([Header_Detail; Detail_Data], file_rank, 'Sheet', 'Details');

fprintf('    完成。\n');
fprintf('    排名第一的算法: %s (Mean Rank: %.4f)\n', Sorted_Algos{1}, Sorted_Ranks(1));

%% 结束
fprintf('\n=========================================\n');
fprintf('✅ 所有 Excel 文件导出完毕！\n');
fprintf('=========================================\n');