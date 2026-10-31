## 1 项目背景与教学目标

### 1.1 课程历史与开设背景

本课程由**路科验证**与**西安电子科技大学微电子学院**自 2015 年起联合开设，聚焦 SystemVerilog 与 UVM 验证基础，面向具备数字电路和 Verilog 基础的本科生与研究生讲授芯片验证的理论知识和语言技能。

2021 年春，课程引入**西电广研院**，此后每年春秋两季均在不同校区和学院同步开展，课程体系持续迭代。

**2026 年春起**，原 SV 语言课程进一步扩展为“SV 设计 + SV/UVM 验证”综合课程设计实践——这也是本实验项目所依托的课程形态。

### 1.2 时代背景与培养导向

AI 大模型在软件编程领域的快速落地，以及国内外 IC 公司对“AI + IC 设计流程”的持续投入，使得验证工程师的工作方式正在发生结构性变化。在这一背景下，我们的培养目标是：

> **帮助初级工程师在进入验证岗位前打牢 SV/UVM 基础，使其能够适应 AI 生成代码、快速部署验证环境、完成测试收敛的新工作模式。**

为此，2026 年起本课程同步引导同学们借助国内外 AI 编程工具辅助完成部分 RTL 设计与验证任务，在真实工具链上积累工程经验，为应对未来行业变化做好准备。

### 1.3 前置课程要求

参加本课程实验的同学应已具备以下基础：

| 前置课程 | 所需能力 |
|---------|---------|
| 数字电路设计 | 理解组合逻辑、时序逻辑、状态机基本概念 |
| Verilog RTL 硬件设计语言 | 能读写模块端口、always 块、reg/wire 声明等基础 RTL |

### 1.4 课程技术覆盖范围

| 类别 | 内容 |
|------|------|
| 核心语言 | SystemVerilog（设计 + 验证语法） |
| 核心方法学 | UVM（Universal Verification Methodology）基础 |
| 工程配套技能 | Shell 脚本基础、Makefile 编写、Questasim 仿真器操作（借助 AI 工具快速上手） |
| AI 辅助实践 | 使用国内外 AI 编程工具辅助 RTL 与 TB 的编写、调试和迭代 |

---

> **重要提示**：本课程为**西电 SV+UVM 系统验证课程**的配套实验代码仓库。所有课程相关信息、实验要求以及 PPA-Lite 综合实验的详细说明，请参考以下两个链接：
> - 课程说明：https://shimo.im/docs/8gEe5I9djYxl9s6W
> - 实验说明：https://shimo.im/docs/m4kMMGXYbVTPedkD

---

## 2 项目概述

本项目为 **V1Pro 课程配套实验代码仓库**，包含以下两部分内容：

1. **课程练习代码示例**：随堂演示的 SystemVerilog 语言特性与验证方法
2. **参考实验代码**：MCDT（Memory Controller Data Transfer）模块的验证环境示例

> **注意**：PPA-Lite 项目（即本课程的最终综合实验）的设计代码与验证代码由参与课程实验的同学们自行开发完成。待课程结束后，我们将甄选优秀的 PPA-Lite 作业代码并入本仓库，供后续同学参考学习。

---

## 3 目录结构

```
rkv_v1pro_labs/
├── lecture/                 # 课程讲义配套代码示例
│   ├── lec1/               # 第1讲：SystemVerilog 基础
│   │   ├── data_type.sv           # 数据类型
│   │   ├── interface_type.sv      # 接口类型
│   │   ├── string_type.sv         # 字符串类型
│   │   └── sv_for_design.sv       # SV 设计语法
│   ├── lec2/               # 第2讲：面向对象与包
│   │   ├── array_type.sv          # 数组类型
│   │   ├── class_encapsulation.sv  # 类封装
│   │   ├── class_inheritance.sv   # 类继承
│   │   └── package_usage.sv       # 包的使用
│   ├── lec3/               # 第3讲：验证方法学基础
│   │   ├── constrained_random.sv  # 约束随机
│   │   ├── virtual_methods.sv      # 虚方法
│   │   ├── interprocess_sync.sv   # 进程同步
│   │   ├── thread_control.sv      # 线程控制
│   │   └── task_and_function.sv   # 任务与函数
│   └── excercises/         # 课堂练习
│       ├── array_assignment.sv           # 数组赋值练习
│       ├── constraint_dynamic_control.sv  # 约束动态控制
│       └── data_types_verilog_diff_sv.sv   # Verilog 与 SV 数据类型对比
│
└── mcdt-lab/               # MCDT 参考实验代码
    ├── mcdt/               # MCDT 模块 RTL 代码（已提供）
    │   ├── mcdt.v          # MCDT 顶层模块
    │   ├── arbiter.v       # 仲裁器模块
    │   └── slave_fifo.v    # 从机 FIFO 模块
    ├── lab0/               # 实验0：Verilog 验证入门
    ├── lab1/               # 实验1：基础验证环境搭建
    ├── lab2/               # 实验2：激励生成与数据比对
    ├── lab3/               # 实验3：UVM 验证环境（带参考代码）
    └── lab4/               # 实验4：综合验证
```

### 3.1 lecture/ 目录说明

`lecture/` 目录包含课程各讲次的配套代码示例，旨在帮助同学理解 SystemVerilog 语言特性和验证方法。每个子目录对应一个讲次，包含多个 `.sv` 源文件，可在 Questasim 等仿真器中直接运行学习。

### 3.2 mcdt-lab/ 目录说明

`mcdt-lab/` 目录提供 MCDT（Multi-Channel Data Transfer）模块的参考验证代码。该模块是一个简单的内存控制器数据通路模块，用于验证实践教学。

- **mcdt/ 子目录**：包含 MCDT 模块的 RTL 代码（Verilog），这部分代码由课程预先提供，学生在此基础上编写验证代码。
- **lab0 ~ lab4 子目录**：对应从易到难的 5 个实验阶段，每个实验包含：
  - `V1实验X.docx`：实验指导文档（X 为实验编号）
  - `Makefile`：编译和仿真脚本
  - `tb.sv` 或 `tb1.v`：测试文件
  - `mcdt_pkg.sv`（部分实验）：验证包
  - `mcdt_pkg_ref.sv`（部分实验）：参考实现

#### 实验内容概览

| 实验 | 名称 | 说明 |
|-----|------|------|
| lab0 | Verilog 验证入门 | 熟悉 Questasim 基本操作，编写简单的 Verilog TB |
| lab1 | 基础验证环境搭建 | 构建基础的验证环境，掌握事务级建模方法 |
| lab2 | 激励生成与数据比对 | 实现激励生成与响应检查 |
| lab3 | UVM 验证环境 | 引入 UVM 框架，构建标准化的验证环境 |
| lab4 | 综合验证 | 综合运用所学知识，完成完整验证流程 |

---

## 4 快速开始

### 4.1 环境准备

本项目代码可在以下环境中运行：

- **仿真器**：Questasim（推荐）、VCS、Verilator 等支持 SystemVerilog 的仿真器
- **构建工具**：Makefile（各目录已配置，用于Questasim仿真）

### 4.2 运行示例

以 `lecture/lec1/data_type.sv` 为例：

```bash
cd lecture/lec1
make comp
make run
```

以 `mcdt-lab/lab1` 为例：

```bash
cd mcdt-lab/lab1
make comp
make run
```

---

## 5 参与贡献

本仓库欢迎以下形式的贡献：

- **提交 PPA-Lite 优秀作业**：课程结束后，优秀的 PPA-Lite 设计验证代码将被收录
- **发现错误或有改进建议**：欢迎提交 Issue 或 Pull Request

---

## 6 联系方式

如有问题，请联系课程负责老师或助教。
