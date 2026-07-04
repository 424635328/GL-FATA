%% 初始化与清理
clear; clc; close all;
addpath(genpath(pwd));

% ================= 参数设置 =================
force_restart = true; % 设置为 true 以强制清除旧数据，从头开始跑 F1-F12
% ===========================================

run_times = 30;      % 独立运行次数
box_pp = 1;          % 1=绘制箱型图
save_mat_name = 'CEC2022_Data.mat'; % 数据保存文件名

% --- 定义测试函数与维度 ---
F_list = [1 2 3 4 5 6 7 8 9 10 11 12];
variables_no = 10; % 可选 2, 10, 20

% CEC标准计算量
MaxFEs = variables_no * 10000; 
pop_size = 30;
max_iter = round(MaxFEs / pop_size); 

% --- 定义对比算法列表 ---
Algo_List = {
    'GL_FATA', 'GL-FATA';
    'FATA',    'FATA';
    'ASFSSA',  'ASFSSA';
    'DBO',     'DBO';
    'PSO',     'PSO';
    'GWO',     'GWO';
    'SSA',     'SSA'
};
num_algos = size(Algo_List, 1);

% --- 颜色库 ---
mycolor = [
    0.85 0.33 0.10; % GL_FATA 
    0.47 0.67 0.19; % FATA
    0.00 0.45 0.74; % ASFSSA
    0.93 0.69 0.13; % DBO
    0.49 0.18 0.56; % PSO
    0.30 0.75 0.93; % GWO
    0.63 0.08 0.18; % SSA
    0.50 0.50 0.50  % 备用
];

%% 并行池配置
pool_obj = gcp('nocreate'); 
if isempty(pool_obj)
    parpool; 
end

%% 数据加载与初始化 (核心修复部分)
if force_restart
    if exist(save_mat_name, 'file')
        delete(save_mat_name);
        disp('警告：force_restart = true。已删除旧数据文件，即将从 F1 开始重新计算...');
    else
        disp('开始新的完整实验...');
    end
    SavedData = struct();
else
    % 断点续跑模式
    if exist(save_mat_name, 'file')
        load(save_mat_name, 'SavedData');
        disp('检测到历史数据，将在现有基础上继续运行...');
    else
        SavedData = struct();
        disp('未检测到历史数据，开始新的实验...');
    end
end

%% 结果统计容器初始化
RESULT_All = [];      
RankSum_All = [];     
TIME_All = [];        
Global_Mean_Matrix = zeros(length(F_list), num_algos); 

if box_pp == 1
    figure('Name', '算法对比箱型图', 'Color', 'w', 'Position', [50 50 1400 800]);
end

%% 主循环：遍历函数
for f_idx = 1:length(F_list)
    func_num = F_list(f_idx);
    disp('--------------------------------');
    disp(['正在计算 F', num2str(func_num), ' ...']);
    
    [lb, ub, dim, fobj] = Get_Functions_cec2022(func_num, variables_no);
    
    current_func_stats = []; 
    current_func_pvals = [];
    current_func_times = []; 
    box_plot_data = []; 
    
    z1_data = []; 
    
    %% 内循环：遍历算法
    for a_idx = 1:num_algos
        alg_name = Algo_List{a_idx, 1};
        
        % --- 读取历史数据 ---
        history_fitness = [];
        history_time = [];
        
        % 检查 SavedData 中是否已有该函数该算法的数据
        data_exists = false;
        if isfield(SavedData, 'F') && length(SavedData.F) >= func_num && ...
           ~isempty(SavedData.F(func_num)) && ...
           length(SavedData.F(func_num).Alg) >= a_idx && ...
           ~isempty(SavedData.F(func_num).Alg(a_idx)) && ...
           isfield(SavedData.F(func_num).Alg(a_idx), 'Fitness') && ...
           ~all(isnan(SavedData.F(func_num).Alg(a_idx).Fitness))
       
            history_fitness = SavedData.F(func_num).Alg(a_idx).Fitness;
            if isfield(SavedData.F(func_num).Alg(a_idx), 'Time')
                history_time = SavedData.F(func_num).Alg(a_idx).Time;
            end
            data_exists = true;
        end
        
        current_alg_fitness = zeros(1, run_times);
        current_alg_time = zeros(1, run_times);
        need_run_mask = true(1, run_times);
        
        if data_exists
            len = length(history_fitness);
            current_alg_fitness(1:len) = history_fitness;
            if ~isempty(history_time) && length(history_time) >= len
                current_alg_time(1:len) = history_time(1:len);
            else
                current_alg_time(1:len) = NaN; 
            end
            need_run_mask(1:len) = false; 
            disp([alg_name, ' -> 检测到已有数据，跳过计算。']);
        end
        
        % --- 并行计算 ---
        % 仅当 need_run_mask 中有 true 时才真正跑
        if any(need_run_mask)
            parfor nrun = 1:run_times
                if need_run_mask(nrun) == false, continue; end
                
                final_fitness = 0;
                elapsed_time = 0;
                try
                    t_start = tic; 
                    switch alg_name
                        case 'GL_FATA'
                            [~, final_fitness, ~] = GL_FATA(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'FATA'
                            [~, final_fitness, ~] = FATA(fobj, lb, ub, dim, pop_size, MaxFEs);
                        case 'ASFSSA'
                            [final_fitness, ~, ~] = ASFSSA(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'DBO'
                            [final_fitness, ~, ~] = DBO(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'PSO'
                            [final_fitness, ~, ~] = PSO(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'GWO'
                            [final_fitness, ~, ~] = GWO(pop_size, max_iter, lb, ub, dim, fobj);
                        case 'SSA'
                            [final_fitness, ~, ~] = SSA(pop_size, max_iter, lb, ub, dim, fobj);
                        otherwise
                            error(['未定义的算法: ', alg_name]);
                    end
                    elapsed_time = toc(t_start);
                catch ME
                    warning(['Runs Error: ', alg_name]);
                    final_fitness = NaN; elapsed_time = NaN;
                end
                current_alg_fitness(nrun) = final_fitness;
                current_alg_time(nrun) = elapsed_time;
            end
        end
        
        % 每次跑完一个算法，立刻保存到内存结构体
        SavedData.F(func_num).Alg(a_idx).Name = alg_name;
        SavedData.F(func_num).Alg(a_idx).Fitness = current_alg_fitness;
        SavedData.F(func_num).Alg(a_idx).Time = current_alg_time;
        
        % 实时保存到硬盘 (关键修复)
        save(save_mat_name, 'SavedData');
        
        % 统计
        valid_data = current_alg_fitness(~isnan(current_alg_fitness));
        valid_time = current_alg_time(~isnan(current_alg_time));
        
        if isempty(valid_data)
            best_v=NaN; std_v=NaN; mean_v=NaN; med_v=NaN; worst_v=NaN; avg_t=NaN;
        else
            best_v = min(valid_data);
            std_v  = std(valid_data);
            mean_v = mean(valid_data);
            med_v  = median(valid_data);
            worst_v= max(valid_data);
            avg_t  = mean(valid_time);
        end
        
        stats_col = [best_v; std_v; mean_v; med_v; worst_v];
        current_func_stats = [current_func_stats, stats_col];
        current_func_times = [current_func_times, avg_t];
        
        Global_Mean_Matrix(f_idx, a_idx) = mean_v;
        
        box_plot_data = [box_plot_data, current_alg_fitness']; 
        
        % 秩和检验
        if a_idx == 1
            z1_data = valid_data; pval = NaN;
        else
            if isempty(z1_data) || isempty(valid_data), pval = 1;
            else, pval = ranksum(z1_data, valid_data); if isnan(pval), pval = 1; end
            end
        end
        if a_idx > 1, current_func_pvals = [current_func_pvals, pval]; end
        
        % 仅当真的跑了（而不是跳过）时才打印，避免刷屏
        if any(need_run_mask)
            disp([alg_name, ' -> Mean:', num2str(mean_v), ' Time:', num2str(avg_t), 's']);
        end
    end
    
    RESULT_All = [RESULT_All; current_func_stats];
    RankSum_All = [RankSum_All; current_func_pvals];
    TIME_All = [TIME_All; current_func_times];
    
    %% 绘制箱型图
    if box_pp == 1
        subplot(3, 4, f_idx);
        box_handle = boxplot(box_plot_data, 'Symbol', 'o', 'OutlierSize', 4);
        set(box_handle, 'LineWidth', 1.0);
        h = findobj(gca, 'Tag', 'Box');
        num_boxes = size(box_plot_data, 2);
        for j = 1:num_boxes
            patch_idx = num_boxes - j + 1; 
            if patch_idx <= size(mycolor, 1)
               patch(get(h(j),'XData'), get(h(j),'YData'), mycolor(patch_idx,:), ...
                   'FaceAlpha', 0.6, 'LineWidth', 0.8);
            end
        end
        set(gca, 'XTickLabel', Algo_List(:,2));
        xtickangle(45); title(['F', num2str(func_num)]);
        drawnow; % 强制刷新绘图
    end
end

if box_pp == 1, saveas(gcf, 'CEC2022_Boxplot.png'); end

%% ================== 结果写入Excel ==================
ensure_char = @(x) cellstr(string(x)); 

% 1. 统计结果
try
    if exist('Result_Stats.xlsx', 'file'), delete('Result_Stats.xlsx'); end
    Row_Names = {}; Metrics = {'Min', 'Std', 'Mean', 'Median', 'Worst'};
    for i = 1:length(F_list)
        f_str = ['F', num2str(F_list(i))]; 
        for m = 1:length(Metrics)
            if m == 1, Row_Names{end+1, 1} = f_str; else, Row_Names{end+1, 1} = ''; end
        end
    end
    Metric_Col = repmat(Metrics', length(F_list), 1);
    Algo_Header = ensure_char(Algo_List(:,2)');
    Header = [{'Function', 'Metric'}, Algo_Header];
    writecell([Header; [Row_Names, Metric_Col, num2cell(RESULT_All)]], 'Result_Stats.xlsx');
    disp('已保存: Result_Stats.xlsx');
catch ME, warning(['写入统计Excel失败: ' ME.message]); end

% 2. 秩和
try
    if exist('Result_RankSum.xlsx', 'file'), delete('Result_RankSum.xlsx'); end
    Algo_Header = ensure_char(Algo_List(2:end, 2)');
    RS_Header = [{'Function'}, Algo_Header];
    Func_Col = cell(length(F_list), 1);
    for i = 1:length(F_list), Func_Col{i} = ['F', num2str(F_list(i))]; end
    writecell([RS_Header; [Func_Col, num2cell(RankSum_All)]], 'Result_RankSum.xlsx');
    disp('已保存: Result_RankSum.xlsx');
catch ME, warning(['写入秩和Excel失败: ' ME.message]); end

% 3. 时间
try
    if exist('Result_Time.xlsx', 'file'), delete('Result_Time.xlsx'); end
    Algo_Header = ensure_char(Algo_List(:, 2)');
    T_Header = [{'Function'}, Algo_Header];
    Func_Col = cell(length(F_list), 1);
    for i = 1:length(F_list), Func_Col{i} = ['F', num2str(F_list(i))]; end
    writecell([T_Header; [Func_Col, num2cell(TIME_All)]], 'Result_Time.xlsx');
    disp('已保存: Result_Time.xlsx');
catch ME, warning(['写入时间Excel失败: ' ME.message]); end

% 4. Friedman
try
    if exist('Result_Friedman.xlsx', 'file'), delete('Result_Friedman.xlsx'); end
    Ranks_Matrix = zeros(size(Global_Mean_Matrix));
    for i = 1:size(Global_Mean_Matrix, 1)
        Ranks_Matrix(i, :) = tiedrank(Global_Mean_Matrix(i, :));
    end
    Mean_Ranks = mean(Ranks_Matrix, 1);
    [Sorted_Ranks, Sort_Idx] = sort(Mean_Ranks);
    Sorted_Algo_Names = ensure_char(Algo_List(Sort_Idx, 2)');
    
    Summary_Header = {'Rank', 'Algorithm', 'Mean Rank'};
    Summary_Data = cell(num_algos, 3);
    for i = 1:num_algos
        Summary_Data{i, 1} = i;
        Summary_Data{i, 2} = Sorted_Algo_Names{i};
        Summary_Data{i, 3} = Sorted_Ranks(i);
    end
    
    Algo_Header = ensure_char(Algo_List(:,2)');
    Detail_Header = [{'Function'}, Algo_Header];
    Func_Col = cell(length(F_list), 1);
    for i = 1:length(F_list), Func_Col{i} = ['F', num2str(F_list(i))]; end
    Detail_Data = [Detail_Header; [Func_Col, num2cell(Ranks_Matrix)]];
    
    writecell([Summary_Header; Summary_Data], 'Result_Friedman.xlsx', 'Sheet', 'Summary');
    writecell(Detail_Data, 'Result_Friedman.xlsx', 'Sheet', 'Details');
    disp('已保存: Result_Friedman.xlsx');
    
    disp(' ');
    disp('=== Friedman Mean Rank ===');
    disp(table((1:num_algos)', string(Sorted_Algo_Names)', Sorted_Ranks', 'VariableNames', {'Rank', 'Algorithm', 'MeanRank'}));
catch ME, warning(['写入Friedman Excel失败: ' ME.message]); end

disp('✅ 所有运行完美结束！');