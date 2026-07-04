
%%
clear
clc
close all
addpath(genpath(pwd));
number=12; %选定优化函数，自行替换:F1~F12
variables_no = 10; % 可选 2, 10, 20
[lower_bound,upper_bound,variables_no,fobj]=Get_Functions_cec2022(number,variables_no);  % [lb,ub,D,y]：下界、上界、维度、目标函数表达式
pop_size=30;                      % population members 
max_iter=1000;                  % maximum number of iteration
%% ASFSSA
[ASFSSA_Best_score,Best_pos,ASFSSA_curve]=ASFSSA(pop_size,max_iter,lower_bound,upper_bound,variables_no,fobj);  % Calculating the solution of the given problem using ASFSSA 
display(['The best optimal value of the objective funciton found by ASFSSA  for ' [num2str(number)],'  is : ', num2str(ASFSSA_Best_score)]);
%% DBO
[DBO_Best_score,~,DBO_curve]=DBO(pop_size,max_iter,lower_bound,upper_bound,variables_no,fobj);
display(['The best optimal value of the objective funciton found by DBO  for ' [num2str(number)],'  is : ', num2str(DBO_Best_score)]);
%% PSO
[PSO_Best_score,~,PSO_curve]=PSO(pop_size,max_iter,lower_bound,upper_bound,variables_no,fobj);
display(['The best optimal value of the objective funciton found by PSO  for ' [num2str(number)],'  is : ', num2str(PSO_Best_score)]);
%% GWO
[GWO_Best_score,~,GWO_curve]=GWO(pop_size,max_iter,lower_bound,upper_bound,variables_no,fobj);
display(['The best optimal value of the objective funciton found by GWO  for ' [num2str(number)],'  is : ', num2str(GWO_Best_score)]);
%% SSA
[SSA_Best_score,~,SSA_curve]=SSA(pop_size,max_iter,lower_bound,upper_bound,variables_no,fobj);
display(['The best optimal value of the objective funciton found by SSA  for ' [num2str(number)],'  is : ', num2str(SSA_Best_score)]);
%% Figure
figure
CNT=20;
k=round(linspace(1,max_iter,CNT)); %随机选CNT个点
% 注意：如果收敛曲线画出来的点很少，随机点很稀疏，说明点取少了，这时应增加取点的数量，100、200、300等，逐渐增加
% 相反，如果收敛曲线上的随机点非常密集，说明点取多了，此时要减少取点数量
iter=1:1:max_iter;
    semilogy(iter(k),ASFSSA_curve(k),'b-^','linewidth',1);
    hold on
    semilogy(iter(k),DBO_curve(k),'m-*','linewidth',1);
    hold on
    semilogy(iter(k),PSO_curve(k),'y-p','linewidth',1);
    hold on
    semilogy(iter(k),GWO_curve(k),'c-s','linewidth',1);
    hold on
    semilogy(iter(k),SSA_curve(k),'r-v','linewidth',1);
grid on;
title('收敛曲线')
xlabel('迭代次数');
ylabel('适应度值');
box on
legend('ASFSSA','DBO','PSO','GWO','SSA')
set (gcf,'position', [300,300,600,330])

rmpath(genpath(pwd))


