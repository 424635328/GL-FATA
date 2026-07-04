# GL_FATA — 改进型 FATA 优化算法

[![MATLAB](https://img.shields.io/badge/MATLAB-R2016b%2B-blue)](https://www.mathworks.com/)
[![Paper](https://img.shields.io/badge/Paper-Neurocomputing%202024-green)](https://doi.org/10.1016/j.neucom.2024.128289)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**GL_FATA** 是对 **FATA（Fata Morgana Algorithm，海市蜃楼算法）** 元启发式算法的改进变体，在 *Neurocomputing*（2024）发表的原始 FATA 基础上引入三项关键改进，以加速收敛并提升解质量。

---

## 📋 目录

- [快速开始](#-快速开始)
- [算法改进](#-算法改进)
- [实验结果](#-实验结果)
- [项目结构](#-项目结构)
- [引用](#-引用)
- [许可证](#-许可证)

---

## 🚀 快速开始

### 运行 GL_FATA

```matlab
% 定义目标函数（以 Sphere 为例）
fobj = @(x) sum(x.^2);

% 问题设置
lb = -100;       % 下界
ub = 100;        % 上界
dim = 30;        % 维度
N = 30;          % 种群规模
MaxFEs = 15000;  % 最大函数评估次数

% 运行 GL_FATA
[bestPos, gBestScore, cg_curve] = GL_FATA(fobj, lb, ub, dim, N, MaxFEs);

% 绘制收敛曲线
semilogy(cg_curve, 'LineWidth', 1.5);
xlabel('迭代次数'); ylabel('最优适应度');
title('GL_FATA 收敛曲线'); grid on;
```

### 与原始 FATA 对比

```matlab
[~, score_FATA, curve_FATA] = FATA(fobj, lb, ub, dim, N, MaxFEs);
[~, score_GL,   curve_GL]   = GL_FATA(fobj, lb, ub, dim, N, MaxFEs);

semilogy(1:length(curve_FATA), curve_FATA, 'b-', ...
         1:length(curve_GL),   curve_GL,   'r--', 'LineWidth', 1.5);
legend('FATA', 'GL\_FATA'); grid on;
```

### 环境要求

- **MATLAB** R2016b 或更高版本（使用了隐式扩展和 `isscalar`）
- 无需额外工具箱，仅依赖 MATLAB 核心函数

---

## 🔧 算法改进

### 背景：FATA 算法

**FATA（Fata Morgana / 海市蜃楼算法）** 是一种基于种群的随机优化方法，灵感来源于**海市蜃光滤波原理**。它模拟光在密度变化的空气层中传播的行为：

| 阶段 | 机制 | 类比 |
|------|------|------|
| **光折射** | 通过个体质量因子 $p$ 和参数 $Para1$ 更新位置 | 光穿过不同折射率介质时弯曲 |
| **全内反射** | 利用邻域信息和参数 $Para2$ 更新位置 | 光在介质边界被完全反射回原介质 |

**种群质量因子** $IP$ 控制搜索阶段切换：
- $rand > IP$ → 全局随机重新初始化（探索）
- $rand \leq IP$ → 折射 / 反射搜索（开发）

### GL_FATA 的三处改进

| # | 改进 | 位置 | 机制 | 效果 |
|:-:|------|------|------|------|
| 1️⃣ | **PWLCM 混沌初始化** | `GL_FATA.m` 第 129 行 | 分段线性混沌映射生成均匀初始种群 | 提高初始多样性，降低早熟收敛风险 |
| 2️⃣ | **引导因子折射** | `GL_FATA.m` 第 72–77 行 | 最优个体保留原更新，普通个体增加梯度吸引项 $(Gbest^j - X\_i^j)$ | 加速收敛，区分探索与开发 |
| 3️⃣ | **Lévy 飞行扰动** | `GL_FATA.m` 第 86–110 行 | 以概率 $P_{Levy}=0.2$ 对全局最优施加长跳跃 | 帮助跳出局部最优 |

#### 1️⃣ PWLCM 混沌映射初始化

用 **PWLCM（分段线性混沌映射）** 替代均匀随机初始化：

$$
x_{t+1} =
\begin{cases}
x_t / P, & 0 \leq x_t < P \\
(x_t - P) / (0.5 - P), & P \leq x_t < 0.5 \\
(1 - P - x_t) / (0.5 - P), & 0.5 \leq x_t < (1 - P) \\
(1 - x_t) / P, & (1 - P) \leq x_t \leq 1
\end{cases}
$$

其中控制参数 $P = 0.4$。与标准随机初始化相比，PWLCM 生成的初始种群分布更均匀，方差更接近理论最优值 $1/12 \approx 0.0833$（代码验证：`cec2022/View.m`）。

#### 2️⃣ 引导因子折射策略

在折射阶段区分两类个体：

| 个体类型 | 更新公式 | 效果 |
|---------|----------|------|
| 最优个体 ($i = BestIndi$) | $X\_i^j = Gbest^j + X\_i^j \cdot Para1^j$ | 保留原行为，在全局最优附近精细探索 |
| 普通个体 | $X\_i^j = Gbest^j + (Gbest^j - X\_i^j) \cdot Para1^j \times 1.832$ | $(Gbest^j - X\_i^j)$ 梯度吸引项加速收敛 |

#### 3️⃣ 全局最优的 Lévy 飞行扰动

以概率 $P_{Levy} = 0.2$ 对全局最优解施加 Lévy 飞行：

$$Gbest' = Gbest + \alpha \cdot L(\beta) \cdot (ub - lb)$$

其中 $\alpha = 0.01$（步长缩放因子），$\beta = 1.5$。新候选解被裁剪到 $[lb, ub]$ 范围内并贪婪接受。

### 算法流程

```
┌──────────────────────────────────────┐
│ PWLCM 混沌映射初始化 (P = 0.4)       │  ← 改进 #1
└───────────┬──────────────────────────┘
            ↓
┌──────────────────────────────────────┐
│ 主循环 (while FEs < MaxFEs)          │
│   ├── 边界约束处理                    │
│   ├── 适应度评估                      │
│   ├── 种群质量因子 (IP) 计算          │
│   └── 位置更新：                      │
│        ├── rand > IP → 全局重新初始化 │
│        └── rand ≤ IP →               │
│             ├── rand < p →            │
│             │   光折射 + 引导因子     │  ← 改进 #2
│             └── else →                │
│                 全内反射               │
│                                      │
│   └── Lévy 飞行扰动 (20% 概率)      │  ← 改进 #3
└──────────────────────────────────────┘
            ↓
┌──────────────────────────────────────┐
│ 返回: bestPos, gBestScore, cg_curve  │
└──────────────────────────────────────┘
```

---

## 📊 实验结果

### 实验配置

| 参数 | 值 |
|------|-----|
| 测试集 | CEC2022（F1–F12：单峰、多峰、混合、组合函数） |
| 维度 | $D = 20$ |
| 种群规模 | $N = 30$ |
| 最大函数评估次数 | $MaxFEs = 300{,}000$ |
| 独立运行 | 30 次 / 算法 |
| 对比算法 | GL-FATA, FATA, ASFSSA, PSO, GWO, SSA |
| 统计检验 | Wilcoxon 秩和检验（$\alpha = 0.05$），Friedman 排名 |

> 运行代码：`cec2022/runsCEC2022_Main_Parallel.m`（并行版，可断点续跑）

### 箱线图：适应度分布

![CEC2022 箱线图](cec2022/RunCEC2022/Run0529/boxplots.jpg)

> 生成代码：`cec2022/Analyze_CEC2022.m`（第 69–127 行）。纵轴为对数坐标（代码第 100 行），避免算法性能悬殊时箱体被压扁。每种颜色对应一个算法，12 个子图对应 CEC2022 的 12 个测试函数。

**关键结果：**

| 函数 | 类型 | GL-FATA 表现 | 说明 |
|------|------|:---:|------|
| **F1** | 单峰 | ★★★★★ | 收敛到理论最优 $3.00 \times 10^2$，标准差 $2.69 \times 10^{-12}$，几乎零波动 |
| **F2** | 单峰 | ★★★★☆ | 均值 $4.46 \times 10^2$，与最优算法差距 < 5% |
| **F6** | 多峰 | ★★★★☆ | 均值 $4.89 \times 10^3$，仅略逊于 FATA（$4.40 \times 10^3$），远优于 GWO（$2.48 \times 10^5$）|
| **F9** | 组合 | ★★★★★ | 均值 $2.48 \times 10^3$ 与最优持平，标准差仅 $1.35 \times 10^{-2}$ |
| **F10** | 组合 | ★★★★★ | 均值 $2.50 \times 10^3$，标准差 $0.28$，显著优于 PSO（$3.02 \times 10^3$）|
| **F12** | 组合 | ★★★★★ | 均值 $2.96 \times 10^3$，在所有对比算法中排名第一 |

完整数据见 `cec2022/Result_Stats.xlsx`。

### Friedman 检验：算法排名

![Friedman 检验](cec2022/RunCEC2022/Run0529/Friedman.jpg)

> 生成代码：`cec2022/RunCEC2022/Run0529/Analyze_0529.m`（第 192–198 行）。排名基于 12 个函数上的平均表现，数值越低越好。



### 收敛曲线

![收敛曲线对比](cec2022/RunCEC2022/Run0529/xxt1.jpg)

GL-FATA 的 PWLCM 混沌初始化使算法从第一代起就具备更好的初始位置（见 `cec2022/View.m` 对比可视化），引导因子折射加速了中期收敛，Lévy 飞行在后期帮助跳出局部最优。

### 计算耗时

![运行时间对比](cec2022/RunCEC2022/Run0529/runtime.jpg)

> 生成代码：`cec2022/RunCEC2022/Run0529/Analyze_0529.m`（第 257–270 行）。

GL-FATA 的运行时间与原始 FATA 基本持平，三处改进均为轻量级操作，未引入显著计算开销。

### 消融实验

为验证每项改进的独立贡献，设计了 5 种变体进行对比（代码：`cec2022/Run_Ablation_Study.m`）：

| 变体 | PWLCM 初始化 | 引导因子折射 | Lévy 飞行 | 消融目标 |
|------|:-:|:-:|:-:|--------|
| FATA_Original | ✗ | ✗ | ✗ | 基准 |
| GL_FATA_NoPWLCM | ✗ | ✓ | ✓ | 验证混沌初始化 |
| GL_FATA_NoGuide | ✓ | ✗ | ✓ | 验证引导因子 |
| GL_FATA_NoLevy | ✓ | ✓ | ✗ | 验证 Lévy 飞行 |
| **GL_FATA_Final** | **✓** | **✓** | **✓** | **完整版本** |

完整消融数据见 `cec2022/Result_Summary_Table.csv`。

---

## 📁 项目结构

```
GL-FATA/
├── GL_FATA.m              # 改进型 GL_FATA 算法（本仓库核心）
├── FATA.m                 # 原始 FATA 算法实现
├── README.md              # 本文件
├── LICENSE                # MIT 许可协议
│
├── cec2022/               # CEC2022 实验评估
│   ├── runsCEC2022_Main_Parallel.m   # 主实验（并行执行 + 断点续跑）
│   ├── Analyze_CEC2022.m             # 分析生成箱线图
│   ├── Export.m                      # 导出统计/原始/排名数据到 Excel
│   ├── Run_Ablation_Study.m          # 消融实验
│   ├── Result_Stats.xlsx             # 统计数据（Min/Std/Mean/Median/Worst）
│   ├── Result_Friedman.xlsx          # Friedman 排名
│   ├── Result_RankSum.xlsx           # Wilcoxon 秩和检验
│   ├── Result_Summary_Table.csv      # 消融实验汇总
│   ├── CEC2022_Boxplot.png           # 箱线图
│   ├── THASO.m / GWO.m / PSO.m / SSA.m / DBO.m / ASFSSA.m  # 对比算法实现
│   ├── Get_Functions_cec2022.m       # CEC2022 测试函数封装
│   └── input_data22/                 # CEC2022 基准数据输入文件
│
└── cec2022/RunCEC2022/              # 多轮实验记录
    ├── Run0529/                      # 0529 版本实验（8 算法对比）
    │   ├── RUNCEC2022_0529.m         # 运行脚本
    │   ├── Analyze_0529.m            # 分析 + 制图（箱线/Friedman/雷达/耗时）
    │   ├── Friedman.jpg / leida.jpg / runtime.jpg / xxt1.jpg  # 结果图
    │   └── CEC2022_Complete_Stats.xlsx  # 完整统计
    ├── Run0208/ / Run0209/ / Run0125/ / Run0116/  # 历史实验记录
    └── Run0529/0529abla/             # 消融分析结果图
```

---

## 📖 引用

原始 FATA 算法：

```bibtex
@article{qi2024fata,
  title={FATA: An Efficient Optimization Method Based on Geophysics},
  author={Qi, Ailiang and Zhao, Dong and Heidari, Ali Asghar and Liu, Lei and Chen, Yi and Chen, Huiling},
  journal={Neurocomputing},
  pages={128289},
  year={2024},
  publisher={Elsevier},
  doi={10.1016/j.neucom.2024.128289}
}
```

---

## 🔗 相关算法

原始 FATA 作者团队开发的其它元启发式算法：

| 算法 | 年份 | 链接 |
|------|:----:|------|
| ECO（Ecosystem Optimizer） | 2024 | [🔗](http://www.aliasgharheidari.com/ECO.html) |
| AO（Aquila Optimizer） | 2024 | [🔗](http://www.aliasgharheidari.com/AO.html) |
| PO（Polar Lights Optimizer） | 2024 | [🔗](http://www.aliasgharheidari.com/PO.html) |
| RIME（雾凇优化算法） | 2023 | [🔗](http://www.aliasgharheidari.com/RIME.html) |
| INFO | 2022 | [🔗](http://www.aliasgharheidari.com/INFO.html) |
| RUN | 2021 | [🔗](http://www.aliasgharheidari.com/RUN.html) |
| HGS（Hunger Games Search） | 2021 | [🔗](http://www.aliasgharheidari.com/HGS.html) |
| SMA（Slime Mould Algorithm） | 2020 | [🔗](http://www.aliasgharheidari.com/SMA.html) |
| HHO（Harris Hawks Optimizer） | 2019 | [🔗](http://www.aliasgharheidari.com/HHO.html) |

---

## 📄 许可证

本项目采用 MIT 许可证 — 详见 [LICENSE](LICENSE) 文件。

原始 FATA 代码由原论文作者提供，仅供学术与研究使用。
