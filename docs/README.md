# PILCO per TCLab — Documentazione Progetto

## Panoramica

Questo progetto implementa l'algoritmo **PILCO** (Probabilistic Inference for Learning Control) per il controllo della temperatura del **TCLab** (Temperature Control Laboratory), un sistema a due riscaldatori con sensori di temperatura integrati.

Il progetto è organizzato in **tre casi di studio** con complessità crescente, pensati per esplorare progressivamente le capacità e i limiti di PILCO nel contesto di una **tesi triennale** in ingegneria.

| Caso | Stato | Obiettivo | Difficoltà |
|------|-------|-----------|------------|
| **Caso 1** | `[T1, T2]` (2D) | Raggiungere T1 = 50°C con Tamb fissa | ⭐ Base |
| **Caso 2** | `[T1, T2, Tamb]` (3D) | Raggiungere T1 = 50°C con Tamb **variabile** | ⭐⭐ Intermedio |
| **Caso 3** | `[e, T2, Tset, Q2]` (4D) | Inseguire una **scalinata** di setpoint con disturbo Q2 | ⭐⭐⭐ Avanzato |

---

## Struttura della Repository

```
PILCO_0/
├── base/              ← Core dell'algoritmo PILCO
├── control/           ← Policy (RBF, GP, lineare, saturazione)
├── gp/                ← Modelli Gaussian Process
├── loss/              ← Funzioni di costo
├── util/              ← Utility matematiche
├── scenarios/         ← Scenari di esempio (pendolo, cart-pole, ecc.)
├── pilco_case1/       ← Caso 1: target fisso, Tamb fissa
├── pilco_case2/       ← Caso 2: target fisso, Tamb variabile
├── pilco_case3/       ← Caso 3: setpoint variabile + disturbo Q2
└── docs/              ← Questa documentazione
```

---

## Moduli Core (`base/`, `gp/`, `control/`, `loss/`, `util/`)

### `base/` — Loop principale PILCO

| File | Descrizione |
|------|-------------|
| `rollout.m` | Esegue un episodio completo sul sistema (simulato o reale). Chiama l'ODE, la policy e la funzione di costo ad ogni step. Restituisce stati `xx`, variazioni `yy`, costo `realCost`, e traiettoria `latent`. |
| `trainDynModel.m` | Addestra il modello GP della dinamica su tutti i dati raccolti `(x, y)`. Ottimizza gli iperparametri del kernel via log-likelihood marginale. |
| `learnPolicy.m` | Ottimizza i parametri della policy usando il GP come simulatore. Minimizza il costo atteso lungo l'orizzonte H tramite backpropagation attraverso il GP. |
| `applyController.m` | Esegue un rollout con la policy corrente e aggiunge i dati raccolti al dataset `(x, y)`. Salva lo stato su file `.mat`. |
| `propagate.m` | Propaga una distribuzione gaussiana `N(μ, Σ)` attraverso un singolo step GP (momento matching). |
| `propagated.m` | Versione con derivate di `propagate.m`, necessaria per la backpropagation durante `learnPolicy`. |
| `simulate.m` | Simula un'intera traiettoria propagando `N(μ, Σ)` per H step attraverso il GP. |
| `calcCost.m` | Calcola il costo atteso dato lo stato `N(μ, Σ)` e la funzione di costo. |
| `predcost.m` | Predice il costo cumulativo di una traiettoria simulata (usato da `learnPolicy`). |
| `pred.m` | Wrapper per la predizione a singolo step. |
| `value.m` | Calcola il valore atteso cumulativo di una policy. |

### `gp/` — Gaussian Process

| File | Descrizione |
|------|-------------|
| `gp0.m / gp0d.m` | GP standard: predizione (con derivate in `gp0d`). |
| `gp1.m / gp1d.m` | GP con predizione e moment matching (con derivate in `gp1d`). Usato come `dynmodel.fcn` in tutti e 3 i casi. |
| `gp2.m / gp2d.m` | GP con incertezza sugli input (con derivate in `gp2d`). |
| `gpr.m` | GP regression base. |
| `train.m` | Addestramento degli iperparametri del GP (funzione assegnata a `dynmodel.train`). |
| `fitc.m` | Implementazione del GP sparso (FITC): usato quando il dataset supera una soglia per ridurre la complessità da O(n³) a O(nm²). |
| `covSEard.m` | Kernel Squared Exponential con Automatic Relevance Determination. |
| `covNoise.m` | Kernel del rumore (diagonale). |
| `covSum.m` | Somma di kernel. |
| `hypCurb.m` | Regolarizzazione degli iperparametri per evitare overfitting. |

### `control/` — Policy

| File | Descrizione |
|------|-------------|
| `congp.m` | Policy implementata come GP: mappa stato → azione usando kernel RBF. Usa i centri `policy.p.inputs` e i pesi `policy.p.targets`. |
| `conCat.m` | Concatenazione di funzioni: applica prima `congp` poi `gSat` (saturazione). Usato come `policy.fcn = @(p,m,s)conCat(@congp,@gSat,p,m,s)`. |
| `conlin.m` | Policy lineare (non usata nei 3 casi, disponibile come alternativa). |

### `loss/` — Funzioni di Costo

| File | Descrizione |
|------|-------------|
| `lossSat.m` | Costo quadratico-saturante: `1 - exp(-½ Δx' W Δx / width²)`. Vale 0 al target, 1 lontano. Usato in tutti e 3 i casi. |
| `lossQuad.m` | Costo puramente quadratico (alternativa a `lossSat`). |
| `lossLin.m` | Costo lineare. |
| `lossHinge.m` | Costo tipo hinge (soglia). |
| `lossAdd.m` | Combinazione additiva di funzioni di costo. |
| `reward.m` | Funzione di reward (complementare al costo). |

### `util/` — Utility

| File | Descrizione |
|------|-------------|
| `minimize.m` | Ottimizzatore (BFGS/L-BFGS/CG) usato sia per il GP che per la policy. |
| `gSat.m` | Saturazione dell'azione in `[-maxU, +maxU]` con propagazione della varianza. |
| `gTrig.m` | Trasformazione trigonometrica (per stati angolari, non usata nel TCLab). |
| `gSin.m` | Funzione seno con propagazione incertezza. |
| `gaussian.m` | Campiona da una distribuzione gaussiana `N(μ, Σ)`. |
| `maha.m` | Distanza di Mahalanobis. |
| `sq_dist.m / .c` | Distanza quadratica (versione MATLAB e MEX C). |
| `solve_chol.m / .c` | Risoluzione di sistemi lineari via Cholesky (MATLAB e MEX C). |
| `unwrap.m / rewrap.m` | (Un)packing di parametri per `minimize.m`. |
| `error_ellipse.m` | Disegna ellissi di confidenza per la visualizzazione delle distribuzioni. |

---

## Caso 1 — Target Fisso, Tamb Fissa (`pilco_case1/`)

**Obiettivo**: porta T1 da 25°C a 50°C in un ambiente a Tamb = 25°C costante.

| File | Descrizione |
|------|-------------|
| `case1_settings.m` | Configurazione completa: stato 2D `[T1, T2]`, indici `odei/dyno/poli/difi`, parametri temporali (dt=20s, T=600s, H=30), policy RBF con nc=20 neuroni, costo `lossSat` con target `[50, 50]` e peso `W=diag([1, 0])` (solo T1 conta). |
| `case1_learn_eval.m` | Script che esegue training e valutazione: J=15 rollout casuali iniziali, poi N=5 iterazioni PILCO (trainDynModel → learnPolicy → applyController). Salva risultati in `results/`. |
| `dynamics_tclab_case1.m` | ODE del TCLab: bilancio energetico con convezione, irraggiamento (Stefan-Boltzmann), e scambio termico tra i due heater. Q1 controllato dalla policy, Q2=0. |
| `draw_tclab_history.m` | Genera la Figura 10 con: (1) traiettorie T1 di tutti i trial, (2) costo totale per trial. |
| `Heaters_Bortoletto.slx` | Modello Simulink del plant (non usato nel codice PILCO, presente come riferimento). |
| `results/` | Cartella con `case1_policy_trained.mat` e figure `.png`. |

---

## Caso 2 — Target Fisso, Tamb Variabile (`pilco_case2/`)

**Obiettivo**: porta T1 a 50°C, ma la temperatura ambiente varia tra episodi. La policy deve **generalizzare** su Tamb mai viste.

| File | Descrizione |
|------|-------------|
| `case2_settings.m` | Stato esteso a 3D: `[T1, T2, Tamb]`. Tamb aggiunta come stato con dTamb/dt=0. Policy mappa `[T1, Tamb] → Q1` (poli=[1,3], T2 esclusa). GP riceve `[T1, T2, Tamb, u]` (4 input). Tamb_train = [25, 35, 40, 30]°C. Stato iniziale: equilibrio termico T1=T2=Tamb. |
| `case2_learn.m` | Training: J=12 rollout casuali ciclati sulle 4 Tamb, poi N=5 iterazioni PILCO ciascuna con 4 rollout (uno per Tamb). Costruisce `mu0Sim/S0Sim` con covarianza tra T1 e Tamb. |
| `case2_eval.m` | Valutazione su Tamb **mai viste**: [12, 45, 38, 60]°C. Testa interpolazione (38°C ≈ 40°C training) ed extrapolazione (12°C, 60°C). |
| `dynamics_tclab_case2.m` | ODE retrocompatibile: se z ha 3 elementi usa Tamb=z(3), altrimenti Tamb=25°C. Ta=Tamb+273.15 nelle equazioni. |
| `draw_case2_results.m` | Figure 11 (training: overview traiettorie, progressione PILCO, costi) e 12 (valutazione: traiettorie su Tamb mai viste, T1 finale vs target). |
| `results/` | Contiene `policy/case2_policy_trained.mat` e `figures/`. |

---

## Caso 3 — Setpoint Variabile + Disturbo Q2 (`pilco_case3/`)

**Obiettivo**: inseguire una **scalinata di riferimento** con Tset che varia. In valutazione la scalinata è composta da gradini **mai visti** durante il training.

| File | Descrizione |
|------|-------------|
| `case3_settings.m` | Stato 4D: `[e, T2, Tset, Q2]` dove e=T1−Tset è l'errore di inseguimento. Policy mappa `[e, Tset] → Q1`. Costo su e con target `[0,0,0,0]`, invariante al setpoint. Tset_train=[35,28,20,43,50]°C (include 20°C < T1_init per coprire raffreddamento). Q2_levels=[2,3.5,5,2.5,4]%. |
| `case3_learn.m` | Training: J=15 rollout casuali ciclati su Tset/Q2, poi N=5 iterazioni PILCO. Covarianza iniziale include Cov(e,Tset)=−Var(Tset) (correlazione negativa). |
| `case3_eval.m` | Valutazione in 2 fasi: (2a) singoli Tset di training con Q2 random, (2b) **scalinata mai vista** [28→43→55→38]°C con propagazione dello stato fisico tra gradini. Raccoglie anche Q1(t). |
| `dynamics_tclab_case3.m` | ODE con stato `[e, T2, Tset, Q2]`: ricostruisce T1=e+Tset, applica Q2 come disturbo sull'heater 2, Tamb=25°C fissa. Output: `[de/dt, dT2/dt, 0, 0]`. |
| `draw_case3_results.m` | Figura 13 (training overview) e Figura 14 (scalinata di valutazione con 6 subplot: T1 vs Tset, errore e(t), Q1(t) azione di controllo, errore finale per gradino). |
| `results/` | Contiene `policy/case3_policy_trained.mat` e `figures/`. |

---

## Come Eseguire

### Prerequisiti
- **MATLAB** R2020b o successivo
- Nessun toolbox aggiuntivo richiesto

### Esecuzione

```matlab
% ── Caso 1 ──
cd pilco_case1
case1_learn_eval     % training + valutazione + grafici

% ── Caso 2 ──
cd pilco_case2
case2_learn          % training (salva policy in results/policy/)
case2_eval           % valutazione su Tamb mai viste + grafici

% ── Caso 3 ──
cd pilco_case3
case3_learn          % training (salva policy in results/policy/)
case3_eval           % scalinata mai vista + grafici
```

> **Nota**: ogni script aggiunge automaticamente i path alle cartelle `base/`, `gp/`, `control/`, `loss/`, `util/` con path relativi `../../`.

---

## Riferimenti

- **PILCO originale**: Deisenroth, M.P. & Rasmussen, C.E. (2011). *PILCO: A Model-Based and Data-Efficient Approach to Policy Search*. ICML.
- **TCLab**: Hedengren, J.D. et al. *Temperature Control Lab* — piattaforma didattica open-source per il controllo di processo.
