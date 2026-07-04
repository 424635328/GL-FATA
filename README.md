# GL_FATA — 改进型 FATA 优化算法

[![MATLAB](https://img.shields.io/badge/MATLAB-R2016b%2B-blue)](https://www.mathworks.com/)
[![Paper](https://img.shields.io/badge/Paper-Neurocomputing%202024-green)](https://doi.org/10.1016/j.neucom.2024.128289)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**GL_FATA** 是对 **FATA（海市蜃楼算法，Fata Morgana Algorithm）** 元启发式算法的改进变体。原始 FATA 受地球物理学中的**海市蜃光滤波现象**启发，发表于 *Neurocomputing*（2024）。GL_FATA 在此基础上引入三项关键改进，以加速收敛并提升解质量。

---

## 📋 目录

- [背景：FATA 算法](#-背景fata-算法)
- [GL_FATA 的三大改进](#-gl_fata-的三大改进)
- [算法流程](#-算法流程)
- [环境要求](#-环境要求)
- [快速开始](#-快速开始)
- [文件结构](#-文件结构)
- [常用测试函数](#-常用测试函数)
- [引用](#-引用)
- [许可证](#-许可证)

---

## 🌅 背景：FATA 算法

**FATA（Fata Morgana / 海市蜃楼算法）** 是一种基于种群的随机优化方法，灵感来源于**海市蜃光滤波原理**。它模拟光在密度变化的空气层中传播的行为，类比搜索代理在复杂适应度景观中的寻优过程。

FATA 包含两个主要阶段：

| 阶段 | 机制 | 类比 |
|------|------|------|
| **光折射（Light Refraction）** | 通过个体质量因子 $p$ 和参数 $Para1$ 更新位置 | 光穿过不同折射率的介质时发生弯曲 |
| **全内反射（Total Internal Reflection）** | 利用邻域信息和参数 $Para2$ 更新位置 | 光在介质边界被完全反射回原介质 |

**种群质量因子**（$IP$）通过对排序后的适应度值进行累积梯形积分计算得到，用于控制搜索阶段切换：
- $rand > IP$ → 全局随机重新初始化（探索）
- $rand \leq IP$ → 进入折射 / 反射搜索阶段（开发）

### 原始 FATA 核心公式

| 公式 | 表达式 | 作用 |
|------|--------|------|
| Eq.(4) | $IP = (I_N - I_{worst}) / (I_{best} - I_{worst} + \epsilon)$ | 种群质量因子 |
| Eq.(8) | $X_i^j = Gbest^j + X_i^j \cdot Para1^j$ | 第一折射阶段 |
| Eq.(11) | $X_i^j = X_{num}^j + Para2^j \cdot X_i^j$ | 邻域随机折射 |
| Eq.(14) | $X_i^j = 0.5(\alpha+1)(lb^j+ub^j) - \alpha \cdot X_i^j$ | 全内反射 |

> **参考文献：** Qi, A., Zhao, D., Heidari, A. A., Liu, L., Chen, Y., & Chen, H. (2024). FATA: An Efficient Optimization Method Based on Geophysics. *Neurocomputing*, 128289. DOI: [10.1016/j.neucom.2024.128289](https://doi.org/10.1016/j.neucom.2024.128289)

---

## 🚀 GL_FATA 的三大改进

GL_FATA 在原始 FATA 的基础上引入三项针对性改进：

### 1️⃣ PWLCM 混沌映射初始化

**文件：** `GL_FATA.m`，函数 `initialization_PWLCM`（第 129 行）

用 **PWLCM（分段线性混沌映射）** 替代均匀随机初始化，生成分布更均匀的初始候选解。这从第一代就提高了种群多样性，降低早熟收敛风险。

PWLCM 映射定义为：

$$
x_{t+1} =
\begin{cases}
x_t / P, & 0 \le x_t < P \\[2pt]
(x_t - P) / (0.5 - P), & P \le x_t < 0.5 \\[2pt]
(1 - P - x_t) / (0.5 - P), & 0.5 \le x_t < (1 - P) \\[2pt]
(1 - x_t) / P, & (1 - P) \le x_t \le 1
\end{cases}
$$

其中控制参数 $P = 0.4$。

### 2️⃣ 引导因子折射策略

**文件：** `GL_FATA.m`，第 72–77 行

在折射阶段区分**最优个体**和**普通个体**：

| 个体类型 | 更新规则 | 效果 |
|---------|----------|------|
| 最优个体 ($i = BestIndi$) | $X_i^j = Gbest^j + X_i^j \cdot Para1^j$ | 保留原始 FATA 行为，在全局最优附近探索 |
| 普通个体 | $X_i^j = Gbest^j + (Gbest^j - X_i^j) \cdot Para1^j \times 1.832$ | **向全局最优引导**，$(Gbest^j - X_i^j)$ 项产生梯度般的吸引力，加速收敛 |

### 3️⃣ 全局最优的 Lévy 飞行扰动

**文件：** `GL_FATA.m`，第 86–110 行

以概率 $P_{Levy} = 0.2$ 对全局最优解施加 **Lévy 飞行**：

$$Gbest' = Gbest + \alpha \cdot L(\beta) \cdot (ub - lb)$$

其中：
- $\alpha = 0.01$ — 步长缩放因子
- $L(\beta)$ — Lévy 分布，$\beta = 1.5$
- 新候选解被裁剪到 $[lb, ub]$ 范围内，并贪婪接受

该机制通过 Lévy 飞行特征性的长跳跃，帮助算法**跳出局部最优**。

---

## 📊 算法流程

```
  ┌──────────────────────────────────────┐
  │ PWLCM 混沌映射初始化                  │  ← 改进 #1
  │   → 控制参数 P = 0.4                 │
  └───────────┬──────────────────────────┘
              ↓
  ┌──────────────────────────────────────┐
  │ 主循环 (while FEs < MaxFEs)          │
  │   ├── 边界约束处理                    │
  │   ├── 适应度评估                      │
  │   ├── 种群质量因子 (IP) 计算          │
  │   ├── 参数更新 (a, b)                │
  │   └── 位置更新：                      │
  │        ├── rand > IP → 全局重新初始化 │
  │        └── rand ≤ IP →               │
  │             ├── rand < p →            │
  │             │   光折射 (Eq.8)        │
  │             │   + 引导因子           │  ← 改进 #2
  │             └── else →               │
  │                 全内反射 (Eq.14)     │
  │                                      │
  │   └── Lévy 飞行扰动 (20% 概率)      │  ← 改进 #3
  └──────────────────────────────────────┘
              ↓
  ┌──────────────────────────────────────┐
  │ 返回: bestPos, gBestScore, cg_curve  │
  └──────────────────────────────────────┘
```

---

## 💻 环境要求

- **MATLAB** R2016b 或更高版本（使用了隐式扩展和 `isscalar`）
- 无需额外工具箱（仅依赖 MATLAB 核心函数）

---

## 🚀 快速开始

### 在测试函数上运行 GL_FATA

```matlab
% 定义目标函数（例如 Sphere 函数）
fobj = @(x) sum(x.^2);

% 定义问题维度
lb = -100;       % 下界
ub = 100;        % 上界
dim = 30;        % 维度
N = 30;          % 种群规模
MaxFEs = 15000;  % 最大函数评估次数

% 运行 GL_FATA
[bestPos, gBestScore, cg_curve] = GL_FATA(fobj, lb, ub, dim, N, MaxFEs);

% 显示结果
disp(['最优适应度: ', num2str(gBestScore)]);
disp(['最优位置: ', mat2str(bestPos)]);

% 绘制收敛曲线（半对数坐标）
semilogy(cg_curve, 'LineWidth', 1.5);
xlabel('迭代次数');
ylabel('最优适应度');
title('GL_FATA 收敛曲线');
grid on;
```

### 对比运行原始 FATA 和 GL_FATA

```matlab
[bestPos_FATA, score_FATA, curve_FATA] = FATA(fobj, lb, ub, dim, N, MaxFEs);
[bestPos_GL,   score_GL,   curve_GL]   = GL_FATA(fobj, lb, ub, dim, N, MaxFEs);

% 对比绘制
semilogy(1:length(curve_FATA), curve_FATA, 'b-', ...
         1:length(curve_GL),   curve_GL,   'r--', 'LineWidth', 1.5);
legend('FATA', 'GL\_FATA');
xlabel('迭代次数');
ylabel('最优适应度');
title('FATA vs GL\_FATA 收敛对比');
grid on;
```

---

## 📁 文件结构

```
GL-FATA/
├── FATA.m          # 原始 FATA 算法实现
├── GL_FATA.m       # 改进型 GL_FATA 算法（本仓库）
├── README.md       # 本文件
├── LICENSE         # MIT 许可协议
└── .gitignore      # Git 忽略规则
```

---

## 📚 常用测试函数

GL_FATA 可在标准 CEC 基准函数上进行测试：

| 函数 | 类型 | 搜索范围 | 全局最小值 |
|------|------|---------|-----------|
| Sphere（球面） | 单峰 | $[-100, 100]^D$ | $f(0) = 0$ |
| Rosenbrock（罗斯布罗克） | 多峰 | $[-30, 30]^D$ | $f(1) = 0$ |
| Rastrigin（拉斯崔金） | 多峰 | $[-5.12, 5.12]^D$ | $f(0) = 0$ |
| Schwefel（施韦费尔） | 多峰 | $[-500, 500]^D$ | $f(420.9687) \approx -418.9829D$ |
| Griewank（格里旺克） | 多峰 | $[-600, 600]^D$ | $f(0) = 0$ |

---

## 📖 引用

如果您在研究中使用了 **GL_FATA**，请引用以下文献：

### 原始 FATA 论文

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

### GL_FATA 改进版本

```bibtex
@misc{glfata2024,
  title={GL\_FATA: 融合混沌映射初始化、引导因子折射与L{\'e}vy飞行的改进FATA优化算法},
  author={GL-FATA Contributors},
  year={2024},
  howpublished={\url{https://github.com/GL-FATA/GL-FATA}}
}
```

---

## 🔗 相关算法

原始 FATA 作者还开发了以下元启发式算法：

- [ECO（Ecosystem Optimizer，2024）](http://www.aliasgharheidari.com/ECO.html)
- [AO（Aquila Optimizer，天鹰优化器，2024）](http://www.aliasgharheidari.com/AO.html)
- [PO（Polar Lights Optimizer，极光优化器，2024）](http://www.aliasgharheidari.com/PO.html)
- [RIME（雾凇优化算法，2023）](http://www.aliasgharheidari.com/RIME.html)
- [INFO（2022）](http://www.aliasgharheidari.com/INFO.html)
- [RUN（2021）](http://www.aliasgharheidari.com/RUN.html)
- [HGS（Hunger Games Search，饥饿游戏搜索，2021）](http://www.aliasgharheidari.com/HGS.html)
- [SMA（Slime Mould Algorithm，黏菌算法，2020）](http://www.aliasgharheidari.com/SMA.html)
- [HHO（Harris Hawks Optimizer，哈里斯鹰优化器，2019）](http://www.aliasgharheidari.com/HHO.html)

---

## 📄 许可证

本项目采用 MIT 许可证 — 详见 [LICENSE](LICENSE) 文件。

原始 FATA 代码由原论文作者提供，仅供学术与研究使用。
