# PILCO-TCLab — Thermal control with model-based Reinforcement Learning

**English** · [Italiano](README.it.md)

MATLAB implementation of the **PILCO** algorithm (*Probabilistic Inference for Learning COntrol*) applied to temperature control of the **TCLab** (*Temperature Control Lab*) device.

The project shows how a **model-based** reinforcement learning approach can learn an accurate thermal controller from **a few dozen episodes**, with no prior knowledge of the system's physics.

> Final dissertation — B.Sc. in Computer Engineering
> University of Padua · Department of Information Engineering
> **Author:** Alberto Bortoletto · **Supervisor:** Prof. Mirco Rampazzo

---

## Contents

- [Motivation](#motivation)
- [What PILCO is](#what-pilco-is)
- [The TCLab system](#the-tclab-system)
- [Repository layout](#repository-layout)
- [Case studies](#case-studies)
- [Key results](#key-results)
- [Requirements and usage](#requirements-and-usage)
- [Documentation](#documentation)
- [References](#references)
- [License](#license)

---

## Motivation

**Model-free** reinforcement learning algorithms (Q-learning, DDPG, …) need thousands or millions of interactions with the real system to converge, which makes them impractical on physical hardware that wears out or is slow to actuate. On the TCLab, where a single episode takes ~10 minutes of wall-clock time, a model-free approach would be unusable.

PILCO addresses this by learning a **probabilistic model of the dynamics** (a Gaussian Process) and using it to plan the policy in simulation, drastically cutting the number of real interactions required.

## What PILCO is

PILCO (Deisenroth & Rasmussen, 2011) is a model-based *policy search* method that:

1. **Learns a GP model** of the system dynamics from all data collected so far;
2. **Optimises the policy** by simulating trajectories internally through *moment matching* (analytic uncertainty propagation), without touching the real system;
3. **Runs a single real rollout** per iteration, adds the new data and repeats.

GP uncertainty is propagated explicitly during planning, which **reduces model bias** and yields an **analytic gradient** of the expected cost with respect to the policy parameters.

## The TCLab system

The **TCLab** is an Arduino shield with two transistor heaters (Q₁, Q₂) and two thermistors (T₁, T₂), cooled passively. Its dynamics are:

- **nonlinear** (convective and radiative losses ∝ T⁴), so a linear model does not describe large temperature excursions well;
- **slow** (time constants ~20 s), so low sampling rates suffice;
- subject to **ambient disturbances** (room temperature drifts during experiments).

Together these make it an ideal testbed for PILCO. In this work the TCLab is modelled through an **ODE simulator**.

## Repository layout

The implementation builds on Deisenroth and Rasmussen's official MATLAB repository ([UCL-SML/pilco-matlab](https://github.com/UCL-SML/pilco-matlab)) and is organised into reusable modules plus one folder per case study:

```
Pilco-TCLAB/
├── base/          # PILCO main loop
│   ├── rollout.m         # run one episode
│   ├── trainDynModel.m   # train the GP dynamics model
│   ├── learnPolicy.m     # optimise the policy
│   └── propagated.m      # moment propagation with derivatives
├── gp/            # Gaussian Process models
│   ├── gp1d.m            # GP prediction with derivatives
│   ├── train.m           # hyperparameter training
│   └── fitc.m            # sparse GP (FITC)
├── control/       # Control policy
│   └── congp.m           # RBF policy (controller-as-GP)
├── loss/          # Cost function
│   └── lossSat.m         # saturating cost in [0,1]
├── util/          # Numerical utilities
│   ├── minimize.m        # self-contained BFGS / L-BFGS / CG optimiser
│   └── gSat.m            # control-signal saturation
├── scenarios/           # Reference scenarios from the original toolbox
│                        # (pendulum, cart-pole, unicycle, …)
├── pilco_case1/         # Case 1 — fixed setpoint
├── pilco_case2/         # Case 2 — ambient-temperature robustness
├── pilco_case3/         # Case 3 — variable setpoint tracking
├── pilco_vs_isteresi/   # PILCO vs hysteresis controller comparison
└── docs/                # Thesis (PDF) and case-by-case guide
```

Each case study is defined by three pieces:

- a **settings** file — full configuration of state, policy, cost and GP;
- a **dynamics** file — the system's ODE equations;
- a **learn / eval** script — the training and evaluation loop.

`pilco_vs_isteresi/` holds the **comparison against a reference hysteresis controller**: the on/off (±δ band) controller implementation and the script that runs both controllers on the same scenario — same disturbance, same noise, same cost function — computing the comparison metrics (RMSE, share of time within ±2 °C, mean cost).

This layout reflects a key property of the framework: **extending the controller to harder scenarios means adding variables to the state, not changing the core algorithm**.

## Case studies

| Case | Scenario | State | Challenge |
|------|----------|-------|-----------|
| **1** | Fixed setpoint | `[T₁, T₂]` | Converge to a stable controller with minimal interaction |
| **2** | Ambient robustness | `[T₁, T₂, Tamb]` | Adapt to different ambient temperatures |
| **3** | Variable setpoint | `[e, T₂, Tset, Q₂]` | Track different references (up and down) under disturbance |

- **Case 1 — Fixed setpoint.** Tset = 50 °C, Tamb = 25 °C, no disturbance. The policy maps `[T₁, T₂] → Q₁`.
- **Case 2 — Ambient-temperature robustness.** Tamb varies across episodes ({25, 35, 40, 30} °C) and is included in the state. The policy learns to modulate power as a function of the environment — more power when cold, less when warm — **without being told the system's physics**.
- **Case 3 — Variable setpoint tracking.** An error-based formulation, `e = T₁ − Tset`: a single policy tracks different setpoints, including rising and falling transitions, with the Q₂ disturbance captured implicitly by the GP.

## Key results

- **Number of episodes:** in every case PILCO converges to an effective policy within **20–40 total episodes**, initial random rollouts included.
- **Case 1:** a stable controller after just 5 training rollouts (plus 15 initial random ones), with steady-state error around ±1 °C.
- **Emergent adaptive behaviour:** in Case 2 the dependence of power on ambient temperature is learned from data, not programmed.
- **Comparison against a hysteresis controller** (same scenario, same disturbance):

  | Metric | PILCO | Hysteresis |
  |---|:---:|:---:|
  | Tracking RMSE [°C] | **4.52** | 4.86 |
  | Time within ±2 °C | **80.0 %** | 48.8 % |
  | Mean cost (lossSat) | **0.448** | 0.622 |

  PILCO produces **modulated, continuous** control (as opposed to the hysteresis controller's on/off switching), with no permanent oscillation and the ability to adapt to the operating context.

## Requirements and usage

**Requirements**

- **MATLAB** R2020b or later.
- **No additional toolboxes.** Optimisation uses `util/minimize.m`, a self-contained BFGS / L-BFGS / CG implementation shipped with the repository — the Optimization Toolbox is not required.
- The pilco-matlab core is **already included** in this repository (`base/`, `gp/`, `control/`, `loss/`, `util/`); there is nothing extra to clone.

**Usage**

Each case-study script adds the module folders to the MATLAB path on its own, using paths relative to its own folder, so run them from inside their directory.

```matlab
% ── Case 1 — fixed setpoint (training and evaluation in one script) ──
cd pilco_case1
case1_learn_eval        % → results/case1_policy_trained.mat, results/figures/

% ── Case 2 — ambient-temperature robustness ──
cd pilco_case2
case2_learn             % training → results/policy/case2_policy_trained.mat
case2_eval              % evaluation on ambient temperatures never seen in training

% ── Case 3 — variable setpoint tracking ──
cd pilco_case3
case3_learn             % training
case3_eval              % evaluation on an unseen setpoint staircase

% ── PILCO vs hysteresis comparison ──
cd pilco_vs_isteresi
compare_hysteresis_pilco   % runs both controllers and computes the metrics
```

Plots are regenerated by the `draw_*` scripts inside each case folder (`draw_case1.m`, `draw_case2.m`, `draw_case3_step.m` and their `*_training` counterparts).

## Documentation

- [`docs/Tesi_PILCO_RL_Alberto_Bortoletto.pdf`](docs/Tesi_PILCO_RL_Alberto_Bortoletto.pdf) — the full dissertation (in Italian).
- [`docs/Guida_Casi.md`](docs/Guida_Casi.md) — a detailed walkthrough of the three case studies (in Italian): design choices, parameters, what each case demonstrates, and PILCO's limits.

## References

1. M. P. Deisenroth, C. E. Rasmussen. *PILCO: A Model-Based and Data-Efficient Approach to Policy Search.* ICML, 2011.
2. M. P. Deisenroth. *Efficient Reinforcement Learning using Gaussian Processes.* KIT Scientific Publishing, 2010.
3. C. E. Rasmussen, C. K. I. Williams. *Gaussian Processes for Machine Learning.* MIT Press, 2006.
4. UCL-SML. *pilco-matlab* — reference MATLAB implementation. https://github.com/UCL-SML/pilco-matlab
5. APMonitor. *Temperature Control Lab (TCLab).* https://apmonitor.com/heat.htm

## License

This work derives from the [pilco-matlab toolbox](https://github.com/UCL-SML/pilco-matlab): please refer to and respect its licence terms for the reused portions of the code.

---

*Companion repository to the B.Sc. dissertation in Computer Engineering — University of Padua, academic year 2025/2026.*
