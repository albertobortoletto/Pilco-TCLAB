# PILCO-TCLab — Controllo termico data-efficient con Reinforcement Learning

Implementazione MATLAB dell'algoritmo **PILCO** (*Probabilistic Inference for Learning COntrol*) applicato al controllo di temperatura del dispositivo **TCLab** (*Temperature Control Lab*).

Il progetto dimostra come un approccio di *reinforcement learning* **model-based** possa apprendere un controllore termico di precisione da **poche decine di episodi**, senza alcuna conoscenza a priori della fisica del sistema.

> Elaborato per la prova finale — Corso di Laurea in Ingegneria Informatica
> Università degli Studi di Padova · Dipartimento di Ingegneria dell'Informazione
> **Laureando:** Alberto Bortoletto · **Relatore:** Prof. Mirco Rampazzo

---

## Indice

- [Motivazione](#motivazione)
- [Cos'è PILCO](#cosè-pilco)
- [Il sistema TCLab](#il-sistema-tclab)
- [Struttura del repository](#struttura-del-repository)
- [Casi di studio](#casi-di-studio)
- [Risultati principali](#risultati-principali)
- [Requisiti ed esecuzione](#requisiti-ed-esecuzione)
- [Riferimenti](#riferimenti)
- [Licenza](#licenza)

---

## Motivazione

Gli algoritmi di reinforcement learning **model-free** (Q-learning, DDPG, …) richiedono migliaia o milioni di interazioni con il sistema reale per convergere, rendendoli impraticabili su hardware fisico che si usura o è lento da azionare. Sul TCLab, dove ogni episodio richiede ~10 minuti di tempo reale, un approccio model-free sarebbe inapplicabile.

PILCO affronta il problema apprendendo un **modello probabilistico della dinamica** (un Gaussian Process) e usandolo per pianificare la politica in simulazione, riducendo drasticamente il numero di interazioni reali necessarie (**sample efficiency**).

## Cos'è PILCO

PILCO (Deisenroth & Rasmussen, 2011) è un metodo di *policy search* model-based che:

1. **Apprende un modello GP** della dinamica del sistema da tutti i dati raccolti finora;
2. **Ottimizza la politica** simulando internamente le traiettorie tramite *moment matching* (propagazione analitica dell'incertezza), senza toccare il sistema reale;
3. **Esegue un solo rollout reale** per iterazione, aggiunge i nuovi dati e ripete.

L'incertezza del GP viene propagata esplicitamente nella pianificazione, permettendo di **ridurre il model bias** e di ottenere un **gradiente analitico** del costo atteso rispetto ai parametri della politica.

## Il sistema TCLab

Il **TCLab** è uno shield per Arduino con due riscaldatori a transistor (Q₁, Q₂) e due termistori (T₁, T₂), con raffreddamento passivo. La sua dinamica è:

- **nonlineare** (perdite convettive e radiative ∝ T⁴), quindi non adeguatamente descritta da un modello lineare per grandi escursioni di temperatura;
- **lenta** (costanti di tempo ~20 s), quindi campionabile a bassa frequenza;
- soggetta a **disturbi ambientali** (la temperatura ambiente varia durante gli esperimenti).

Queste caratteristiche lo rendono un banco di prova ideale per valutare la sample efficiency di PILCO. In questo lavoro il TCLab è modellato tramite un **simulatore ODE**.

## Struttura del repository

L'implementazione è basata sulla repository MATLAB ufficiale di Deisenroth e Rasmussen ([UCL-SML/pilco-matlab](https://github.com/UCL-SML/pilco-matlab)) ed è organizzata in moduli riutilizzabili e cartelle specifiche per ogni caso di studio:

```
Pilco-TCLAB/
├── base/          # Loop principale di PILCO
│   ├── rollout.m         # esecuzione di un episodio
│   ├── trainDynModel.m   # addestramento del modello GP
│   ├── learnPolicy.m     # ottimizzazione della politica
│   └── propagated.m      # propagazione dei momenti con derivate
├── gp/            # Modelli Gaussian Process
│   ├── gp1d.m            # predizione GP con derivate
│   ├── train.m           # addestramento degli iperparametri
│   └── fitc.m            # GP sparso (FITC)
├── control/       # Politica di controllo
│   ├── congp.m           # politica RBF (controller-as-GP)
│   └── gSat.m            # saturazione del segnale di controllo
├── loss/          # Funzione di costo
│   └── lossSat.m         # costo saturante in [0,1]
├── pilco_case1/   # Caso 1 — setpoint fisso
├── pilco_case2/   # Caso 2 — robustezza alla temperatura ambiente
└── pilco_case3/   # Caso 3 — inseguimento di setpoint variabile
```

Ogni caso di studio è definito da tre elementi:

- un file **settings** — configurazione completa di stato, politica, costo e GP;
- un file **dynamics** — equazioni ODE del sistema;
- uno script **learn / eval** — loop di training e valutazione.

Questa organizzazione riflette una proprietà chiave del framework: **estendere il controllore a scenari più complessi aggiungendo variabili allo stato, senza modificare il nucleo dell'algoritmo**.

## Casi di studio

| Caso | Scenario | Stato | Sfida |
|------|----------|-------|-------|
| **1** | Setpoint fisso | `[T₁, T₂]` | Convergenza a un controllore stabile con interazioni minime |
| **2** | Robustezza ambientale | `[T₁, T₂, Tamb]` | Adattarsi a temperature ambiente diverse |
| **3** | Setpoint variabile | `[e, T₂, Tset, Q₂]` | Inseguire riferimenti diversi (salite/discese) con disturbo |

- **Caso 1 — Setpoint fisso.** Tset = 50 °C, Tamb = 25 °C, nessun disturbo. La politica mappa `[T₁, T₂] → Q₁`.
- **Caso 2 — Robustezza alla temperatura ambiente.** Tamb variata tra episodi ({25, 35, 40, 30} °C) e inclusa nello stato. La politica apprende a modulare la potenza in funzione dell'ambiente — più potenza a freddo, meno a caldo — **senza conoscere la fisica del sistema**.
- **Caso 3 — Inseguimento di setpoint variabile.** Formulazione basata sull'errore `e = T₁ − Tset`: una singola politica insegue setpoint diversi, incluse transizioni di salita e discesa, con il disturbo Q₂ catturato implicitamente dal GP.

## Risultati principali

- **Sample efficiency:** in tutti i casi PILCO converge a una politica efficace in **20–40 episodi** totali (rollout casuali inclusi) — ordini di grandezza in meno rispetto agli approcci model-free.
- **Caso 1:** controllore stabile in soli 5 rollout di training (+ 15 casuali iniziali), con errore a regime contenuto attorno a ±1 °C.
- **Comportamento adattivo emergente:** nel Caso 2 la dipendenza della potenza dalla temperatura ambiente è appresa dai dati, non programmata.
- **Confronto con controllore a isteresi** (stesso scenario, stesso disturbo):

  | Metrica | PILCO | Isteresi |
  |---|:---:|:---:|
  | RMSE di tracking [°C] | **4,52** | 4,86 |
  | Tempo entro ±2 °C | **80,0 %** | 48,8 % |
  | Costo medio (lossSat) | **0,448** | 0,622 |

  PILCO produce un controllo **modulato e continuo** (contro la commutazione on/off dell'isteresi), senza oscillazione permanente e con capacità di adattamento al contesto operativo.

## Requisiti ed esecuzione

**Requisiti**

- MATLAB *(testato su R____ — da specificare)*
- Optimization Toolbox (per l'ottimizzatore CG / L-BFGS)
- Il core della [pilco-matlab toolbox](https://github.com/UCL-SML/pilco-matlab) (incluso / da clonare — *specificare*)

**Esecuzione**

```matlab
% 1. Aggiungere i moduli al path
addpath(genpath('.'));

% 2. Eseguire uno dei casi di studio (es. Caso 1)
cd pilco_case1
settings_case1        % carica la configurazione
learn_case1           % avvia il loop di training PILCO

% 3. Valutare la politica appresa
eval_case1
```

> **Nota:** adattare i nomi degli script (`settings_*`, `learn_*`, `eval_*`) a quelli effettivi presenti nelle cartelle `pilco_case{1,2,3}/`.

## Riferimenti

1. M. P. Deisenroth, C. E. Rasmussen. *PILCO: A Model-Based and Data-Efficient Approach to Policy Search.* ICML, 2011.
2. M. P. Deisenroth. *Efficient Reinforcement Learning using Gaussian Processes.* KIT Scientific Publishing, 2010.
3. C. E. Rasmussen, C. K. I. Williams. *Gaussian Processes for Machine Learning.* MIT Press, 2006.
4. UCL-SML. *pilco-matlab* — implementazione MATLAB di riferimento. https://github.com/UCL-SML/pilco-matlab
5. APMonitor. *Temperature Control Lab (TCLab).* https://apmonitor.com/heat.htm

## Licenza

Questo lavoro deriva dalla [pilco-matlab toolbox](https://github.com/UCL-SML/pilco-matlab): consultare e rispettarne i termini di licenza per le parti di codice riutilizzate. *(Specificare qui la licenza scelta per il proprio codice — es. MIT — assicurandosi della compatibilità con quella originale.)*

---

*Repository a corredo dell'elaborato di laurea triennale in Ingegneria Informatica — Università degli Studi di Padova, A.A. 2025/2026.*
