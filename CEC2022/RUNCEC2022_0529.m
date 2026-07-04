%% 初始化与清理
clear; clc; close all;
addpath(genpath(pwd));

force_restart = false; % 保持 false！安全重组历史数据

run_times = 30;      
save_mat_name = 'CEC2022_Data.mat'; 

F_list = [1 2 3 4 5 6 7 8 9 10 11 12];
variables_no = 20; 

MaxFEs = 300000; 
pop_size = 30;
max_iter = round(MaxFEs / pop_size); 

% === 剔除垫底算法及 DBO，保留 8 大核心精英算法 ===
Algo_List = {
    'GL_FATA',    'GL-FATA';    
    'MFATA_Levy', 'MFATA-Levy'; 
    'IMFATA',     'IMFATA';     
    'ASFSSA',     'ASFSSA';
    'PSO',        'PSO';
    'FATA',       'FATA'; 
    'GWO',        'GWO';
    'SSA',        'SSA'
};
num_algos = size(Algo_List, 1);

% 8 种专属颜色库
mycolor = [
    0.85 0.33 0.10; % GL_FATA (橙红)
    0.47 0.67 0.19; % MFATA_Levy (草绿)
    0.93 0.69 0.13; % IMFATA  (黄/金)
    0.00 0.45 0.74; % ASFSSA (蓝)
    0.30 0.50 0.93; % PSO (灰蓝)
    0.10 0.40 0.20; % FATA (深绿)
    0.63 0.08 0.18; % GWO (深红)
    0.50 0.50 0.50  % SSA (灰)
];

%% 平行池配置
pool_obj = gcp('nocreate'); 
if isempty(pool_obj), parpool; end

%% 自动筛选与安全重组 (自动清洗 DBO 及其他多余算法)
if exist(save_mat_name, 'file')
    temp_load = load(save_mat_name);
    if isfield(temp_load, 'SavedData')
        OldData = temp_load.SavedData;
        NewSavedData = struct();
        for f = 1:12
            if isfield(OldData, 'F') && length(OldData.F) >= f && ~isempty(OldData.F(f))
                NewSavedData.F(f).Alg = struct('Name', {}, 'Fitness', {}, 'Time', {});
                for a = 1:num_algos
                    target_name = Algo_List{a, 1};
                    found_in_old = false;
                    for old_a = 1:length(OldData.F(f).Alg)
                        if isfield(OldData.F(f).Alg(old_a), 'Name') && strcmp(OldData.F(f).Alg(old_a).Name, target_name)
                            NewSavedData.F(f).Alg(a).Name = target_name;
                            NewSavedData.F(f).Alg(a).Fitness = OldData.F(f).Alg(old_a).Fitness;
                            NewSavedData.F(f).Alg(a).Time = OldData.F(f).Alg(old_a).Time;
                            found_in_old = true; break;
                        end
                    end
                    if ~found_in_old
                        NewSavedData.F(f).Alg(a).Name = target_name;
                        NewSavedData.F(f).Alg(a).Fitness = nan(1, run_times);
                        NewSavedData.F(f).Alg(a).Time = nan(1, run_times);
                    end
                end
            end
        end
        SavedData = NewSavedData;
        save(save_mat_name, 'SavedData');
        disp('✅ 历史数据清洗成功！已剔除 DBO 等算法，8 大精英算法数据重组完毕。');
    else
        SavedData = struct();
    end
else
    SavedData = struct();
end

RESULT_All = []; RankSum_All = []; TIME_All = [];        
Global_Mean_Matrix = zeros(length(F_list), num_algos); 

%% 主循环
for f_idx = 1:length(F_list)
    func_num = F_list(f_idx);
    disp(['---------------- F', num2str(func_num), ' ----------------']);
    [lb, ub, dim, fobj] = Get_Functions_cec2022(func_num, variables_no);
    
    current_func_stats = []; current_func_pvals = [];
    current_func_times = []; z1_data = []; 
    
    for a_idx = 1:num_algos
        alg_name = Algo_List{a_idx, 1};
        history_fitness = []; history_time = []; data_exists = false;
        
        if isfield(SavedData, 'F') && length(SavedData.F) >= func_num && ...
           length(SavedData.F(func_num).Alg) >= a_idx && ...
           isfield(SavedData.F(func_num).Alg(a_idx), 'Fitness') && ...
           ~all(isnan(SavedData.F(func_num).Alg(a_idx).Fitness))
            history_fitness = SavedData.F(func_num).Alg(a_idx).Fitness;
            if isfield(SavedData.F(func_num).Alg(a_idx), 'Time')
                history_time = SavedData.F(func_num).Alg(a_idx).Time;
            end
            data_exists = true;
        end
        
        current_alg_fitness = zeros(1, run_times); current_alg_time = zeros(1, run_times);
        need_run_mask = true(1, run_times);
        
        if data_exists
            len = length(history_fitness); current_alg_fitness(1:len) = history_fitness;
            if ~isempty(history_time), current_alg_time(1:len) = history_time(1:len); else, current_alg_time(1:len) = NaN; end
            need_run_mask(1:len) = false; 
            disp([alg_name, ' -> 已读取缓存。']);
        end
        
        if any(need_run_mask)
            parfor nrun = 1:run_times
                if need_run_mask(nrun) == false, continue; end
                try
                    t_start = tic; 
                    switch alg_name
                        case 'GL_FATA',    [~, final_fitness, ~] = GL_FATA(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'IMFATA',     [~, final_fitness, ~] = IMFATA(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'MFATA_Levy', [~, final_fitness, ~] = MFATA_Levy(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'FATA',       [~, final_fitness, ~] = FATA(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'ASFSSA',     [final_fitness, ~, ~] = ASFSSA(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'PSO',        [final_fitness, ~, ~] = PSO(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'GWO',        [final_fitness, ~, ~] = GWO(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'SSA',        [final_fitness, ~, ~] = SSA(pop_size, max_iter, lb, ub, dim, fobj);
                    end
                    current_alg_time(nrun) = toc(t_start); 
                    current_alg_fitness(nrun) = final_fitness;
                catch ME
                    current_alg_fitness(nrun) = NaN; current_alg_time(nrun) = NaN;
                end
            end
        end
        
        SavedData.F(func_num).Alg(a_idx).Name = alg_name;
        SavedData.F(func_num).Alg(a_idx).Fitness = current_alg_fitness;
        SavedData.F(func_num).Alg(a_idx).Time = current_alg_time;
        save(save_mat_name, 'SavedData');
        
        valid_data = current_alg_fitness(~isnan(current_alg_fitness));
        if isempty(valid_data)
            stats_col = nan(5,1); avg_t=NaN; mean_v=NaN;
        else
            stats_col = [min(valid_data); std(valid_data); mean(valid_data); median(valid_data); max(valid_data)];
            mean_v = mean(valid_data); avg_t = mean(current_alg_time(~isnan(current_alg_time)));
        end
        
        current_func_stats = [current_func_stats, stats_col];
        current_func_times = [current_func_times, avg_t];
        Global_Mean_Matrix(f_idx, a_idx) = mean_v;
        
        if a_idx == 1
            z1_data = valid_data; 
        else
            if isempty(z1_data) || isempty(valid_data), pval = 1;
            else, pval = ranksum(z1_data, valid_data); if isnan(pval), pval = 1; end
            end
            current_func_pvals = [current_func_pvals, pval];
        end
    end
    RESULT_All = [RESULT_All; current_func_stats];
    RankSum_All = [RankSum_All; current_func_pvals];
    TIME_All = [TIME_All; current_func_times];
end

%% Excel 写入模块
ensure_char = @(x) cellstr(string(x)); 

% 1. 统计结果 Excel
try
    if exist('Result_Stats.xlsx', 'file'), delete('Result_Stats.xlsx'); end
    Row_Names = {}; Metrics = {'Min', 'Std', 'Mean', 'Median', 'Worst'};
    for i = 1:length(F_list)
        f_str = ['F', num2str(F_list(i))]; 
        for m = 1:5
            if m==1, Row_Names{end+1,1}=f_str; else, Row_Names{end+1,1}=''; end
        end
    end
    Header = [{'Function', 'Metric'}, cellstr(string(Algo_List(:,2)'))];
    writecell([Header; [Row_Names, repmat(Metrics', length(F_list), 1), num2cell(RESULT_All)]], 'Result_Stats.xlsx');
catch, end

% 2. Wilcoxon 秩和检验 Excel
try
    if exist('Result_RankSum.xlsx', 'file'), delete('Result_RankSum.xlsx'); end
    num_funcs = length(F_list); num_comparisons = num_algos - 1;
    RankSum_Symbols = cell(num_funcs, num_comparisons);
    WTL_Count = zeros(3, num_comparisons);
    for i = 1:num_funcs
        gl_mean = RESULT_All((i-1)*5 + 3, 1);
        for j = 1:num_comparisons
            comp_idx = j + 1; comp_mean = RESULT_All((i-1)*5 + 3, comp_idx); pval = RankSum_All(i, j);
            if pval < 0.05
                if gl_mean < comp_mean
                    RankSum_Symbols{i,j} = ['+ (', num2str(pval, '%.2e'), ')']; WTL_Count(1, j) = WTL_Count(1, j) + 1;
                else
                    RankSum_Symbols{i,j} = ['- (', num2str(pval, '%.2e'), ')']; WTL_Count(3, j) = WTL_Count(3, j) + 1;
                end
            else
                RankSum_Symbols{i,j} = ['= (', num2str(pval, '%.2e'), ')']; WTL_Count(2, j) = WTL_Count(2, j) + 1;
            end
        end
    end
    WTL_Row = cell(1, num_comparisons);
    for j = 1:num_comparisons
        WTL_Row{j} = sprintf('%d / %d / %d', WTL_Count(1,j), WTL_Count(2,j), WTL_Count(3,j));
    end
    RS_Algo_Header = ensure_char(Algo_List(2:end, 2)');
    RS_Header = [{'Function'}, RS_Algo_Header];
    Func_Col = cell(num_funcs + 1, 1);
    for i = 1:num_funcs, Func_Col{i} = ['F', num2str(F_list(i))]; end
    Func_Col{num_funcs + 1} = 'Total (+/=/−)';
    writecell([RS_Header; [Func_Col, [RankSum_Symbols; WTL_Row]]], 'Result_RankSum.xlsx');
catch, end

% 3. 运行时间 Excel
try
    if exist('Result_Time.xlsx', 'file'), delete('Result_Time.xlsx'); end
    Header = [{'Function'}, cellstr(string(Algo_List(:,2)'))];
    Func_Col = cell(length(F_list), 1);
    for i = 1:length(F_list), Func_Col{i} = ['F', num2str(F_list(i))]; end
    writecell([Header; [Func_Col, num2cell(TIME_All)]], 'Result_Time.xlsx');
catch, end

% 4. Friedman 排名 Excel
try
    if exist('Result_Friedman.xlsx', 'file'), delete('Result_Friedman.xlsx'); end
    Ranks_Matrix = zeros(size(Global_Mean_Matrix));
    for i = 1:size(Global_Mean_Matrix, 1), Ranks_Matrix(i, :) = tiedrank(Global_Mean_Matrix(i, :)); end
    Mean_Ranks = mean(Ranks_Matrix, 1);
    [Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
    Sorted_Algo_Names = cellstr(string(Algo_List(Sort_Idx, 2)'));
    Summary_Data = cell(num_algos, 3);
    for i = 1:num_algos, Summary_Data{i, 1}=i; Summary_Data{i, 2}=Sorted_Algo_Names{i}; Summary_Data{i, 3}=Sorted_Ranks(i); end
    writecell([{'Rank', 'Algorithm', 'Mean Rank'}; Summary_Data], 'Result_Friedman.xlsx');
catch, end

disp('✅ 8 算法全测试完美结束！已重写全部 Excel 文件。');