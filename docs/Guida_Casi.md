# Guida ai Tre Casi di Studio — PILCO per TCLab

## Indice

1. [Introduzione: Perché Tre Casi?](#1-introduzione-perché-tre-casi)
2. [Caso 1: Regolazione a Setpoint Fisso](#2-caso-1-regolazione-a-setpoint-fisso)
3. [Caso 2: Robustezza alla Temperatura Ambiente](#3-caso-2-robustezza-alla-temperatura-ambiente)
4. [Caso 3: Inseguimento di Riferimento Variabile](#4-caso-3-inseguimento-di-riferimento-variabile)
5. [Tabella Comparativa dei Tre Casi](#5-tabella-comparativa-dei-tre-casi)
6. [Limiti e Potenzialità di PILCO per la Tesi](#6-limiti-e-potenzialità-di-pilco-per-la-tesi)
7. [Consigli per la Scrittura della Tesi](#7-consigli-per-la-scrittura-della-tesi)

---

## 1. Introduzione: Perché Tre Casi?

I tre casi seguono una **progressione pedagogica** che dimostra come PILCO possa essere esteso a problemi di controllo sempre più realistici senza modificare l'algoritmo core. Ogni caso introduce una nuova sfida:

```
Caso 1 (baseline)     →  "PILCO funziona?"
Caso 2 (robustezza)   →  "PILCO generalizza?"
Caso 3 (tracking)     →  "PILCO insegue riferimenti variabili?"
```

Questa progressione è ideale per una **tesi triennale** perché:
- Il Caso 1 dimostra la comprensione del framework
- Il Caso 2 analizza la capacità di generalizzazione
- Il Caso 3 affronta un problema di controllo realistico

---

## 2. Caso 1: Regolazione a Setpoint Fisso

### Obiettivo
Portare la temperatura T1 dell'heater 1 dal valore iniziale (25°C) al target di 50°C, con temperatura ambiente fissa Tamb = 25°C.

### Stato del Sistema
```
stato = [T1, T2]    →  2 dimensioni
```

| Variabile | Significato | Ruolo |
|-----------|-------------|-------|
| T1 | Temperatura heater 1 | **Controllata** (obiettivo: T1 → 50°C) |
| T2 | Temperatura heater 2 | Non controllata, ma modellata dal GP |

### Scelta del Setpoint e Tamb

| Parametro | Valore | Motivazione |
|-----------|--------|-------------|
| T_target | 50°C | Raggiungibile con potenza limitata (Q1 ∈ [0,100]%), sufficientemente lontano da Tamb per testare il riscaldamento attivo |
| Tamb | 25°C (fissa) | Condizione nominale, semplifica il problema |
| T_init | [25, 25]°C | Equilibrio termico con l'ambiente |

### Parametri Chiave

| Parametro | Valore | Significato |
|-----------|--------|-------------|
| dt | 20 s | Intervallo di campionamento |
| T_ep | 600 s (10 min) | Durata episodio |
| H | 30 step | Passi per episodio |
| J | 15 | Rollout casuali iniziali |
| N | 5 | Iterazioni PILCO |
| nc | 20 | Neuroni RBF della policy |
| maxU | 50 | Azione in [-50, +50] → potenza [0, 100]% |

### Configurazione degli Indici PILCO

```matlab
odei = [1 2];    % T1, T2 nell'ODE
dyno = [1 2];    % GP predice ΔT1, ΔT2
dyni = [1 2];    % GP riceve [T1, T2] come input
poli = [1 2];    % Policy vede [T1, T2]
difi = [1 2];    % GP impara differenze (ΔT = T(t+1) - T(t))
```

### Funzione di Costo

```matlab
cost.fcn    = @lossSat;        % quadratica saturante: 0 al target, 1 lontano
cost.target = [50; 50];        % obiettivo (solo T1 conta per via di W)
cost.W      = diag([1, 0]);    % penalizza SOLO T1 (T2 ignorata)
cost.width  = 1;               % scala la sensibilità del costo
```

### Cosa dimostra il Caso 1
- ✅ PILCO impara a controllare un sistema fisico non lineare (Stefan-Boltzmann)
- ✅ Il modello GP apprende la dinamica solo dai dati
- ✅ La policy RBF converge a una strategia di riscaldamento efficace
- ✅ Il costo reale decresce con le iterazioni PILCO

---

## 3. Caso 2: Robustezza alla Temperatura Ambiente

### Obiettivo
Stesso target T1 = 50°C, ma la temperatura ambiente **varia tra episodi**. La policy deve generalizzare su Tamb mai viste durante il training.

### Stato del Sistema
```
stato = [T1, T2, Tamb]    →  3 dimensioni
```

| Variabile | Significato | Ruolo | Novità vs Caso 1 |
|-----------|-------------|-------|-------------------|
| T1 | Temp. heater 1 | Controllata | — |
| T2 | Temp. heater 2 | Modellata dal GP | — |
| Tamb | Temp. ambiente | **Contesto**: costante per episodio, variabile tra episodi | ✨ **Nuova** |

### Perché Estendere lo Stato con Tamb?

Senza Tamb nello stato, se alleniamo PILCO a 25°C e poi lo testiamo a 40°C:
- Il GP ha imparato `f(T1, T2, u) → ΔT`, ma **non sa che la dinamica è cambiata**
- La policy dà la stessa azione per ogni Tamb → **sbagliata**

Con Tamb nello stato:
- Il GP impara `f(T1, T2, Tamb, u) → ΔT`: conosce la dipendenza da Tamb
- La policy attiva neuroni RBF diversi per Tamb diverse → **policy adattiva**

### Temperature Ambiente

| Set | Valori [°C] | Scopo |
|-----|-------------|-------|
| **Training** | [25, 35, 40, 30] | Copertura del range operativo |
| **Valutazione** | [12, 45, 38, 60] | Test generalizzazione: interpolazione (38°C) e extrapolazione (12°C, 60°C) |

### Stato Iniziale: Equilibrio Termico
```matlab
mu0 = [Tamb_tt; Tamb_tt; Tamb_tt]    % T1 = T2 = Tamb (sistema spento)
```
Questo è fisicamente realistico: se il laboratorio è a 12°C, all'accensione anche T1=T2=12°C.

### Differenze Chiave rispetto al Caso 1

| Aspetto | Caso 1 | Caso 2 |
|---------|--------|--------|
| Stato | 2D | **3D** |
| Policy input | [T1, T2] | **[T1, Tamb]** (poli=[1,3]) |
| GP input | [T1, T2, u] (3D) | **[T1, T2, Tamb, u]** (4D) |
| T2 nella policy | Sì | **No** (non serve per decidere Q1) |
| Training loop | 1 rollout per iterazione | **4 rollout per iterazione** (uno per Tamb) |
| mu0Sim | Fisso | Correlato: Cov(T1,Tamb) = Var(Tamb) |

### Perché poli = [1, 3] e NON [1, 2, 3]?

T2 non entra nella policy perché:
1. **Non la controlliamo** → conoscerla non aiuta a decidere Q1
2. **Riduce lo spazio** da R³ a R²: meno neuroni necessari, convergenza più rapida
3. T2 entra comunque nel GP (dyni=[1,2,3]) → il modello sa che T2 influenza ΔT1

### Covarianza mu0Sim / S0Sim

Poiché T1_init = T2_init = Tamb (equilibrio), la matrice di covarianza iniziale ha correlazioni:

```matlab
% Cov(T1, Tamb) = Var(Tamb) → correlazione piena
S0Sim = Tamb_var * ones(3,3) + diag([1.0, 1.0, 0.001]);
```

Questo dice a PILCO che la simulazione interna copre **tutte le Tamb plausibili**, producendo una policy robusta anziché specializzata.

### Cosa dimostra il Caso 2
- ✅ PILCO generalizza a condizioni mai viste (interpolazione Tamb=38°C)
- ✅ La policy RBF si adatta automaticamente a Tamb diverse
- ⚠️ L'extrapolazione estrema (Tamb=12°C, 60°C) è più difficile
- ✅ Il framework si estende facilmente aggiungendo variabili di contesto

---

## 4. Caso 3: Inseguimento di Riferimento Variabile

### Obiettivo
Inseguire una **scalinata di setpoint** composta da gradini mai visti durante il training, in presenza di un disturbo casuale Q2 sull'heater 2.

### Stato del Sistema
```
stato = [e, T2, Tset, Q2]    →  4 dimensioni
```

| Variabile | Significato | Ruolo | Novità vs Caso 2 |
|-----------|-------------|-------|-------------------|
| e = T1 − Tset | Errore di inseguimento | **Controllato** (obiettivo: e → 0) | ✨ Sostituisce T1 |
| T2 | Temp. heater 2 | Modellata | — |
| Tset | Setpoint corrente | Contesto (dTset/dt = 0) | ✨ **Nuovo** |
| Q2 | Disturbo heater 2 [%] | Disturbo (dQ2/dt = 0) | ✨ **Nuovo** |

### Perché Usare l'Errore e = T1 − Tset?

**Problema fondamentale**: PILCO ha un `cost.target` **fisso**. Se il setpoint cambia tra episodi:
- Con T1 nello stato → `cost.target(1)` dovrebbe cambiare ad ogni Tset → **impossibile**
- Con e nello stato → `cost.target = [0; 0; 0; 0]` → **invariante** ✅

```
Tset = 35°C  →  obiettivo: e = T1 - 35 → 0  →  cost.target = [0,0,0,0]
Tset = 50°C  →  obiettivo: e = T1 - 50 → 0  →  cost.target = [0,0,0,0]  (stesso!)
```

### Setpoint di Training e Valutazione

| Set | Valori [°C] | Scopo |
|-----|-------------|-------|
| **Training** | [35, 28, **20**, 43, 50] | 20°C < T1_init=25°C → **copre e > 0** (raffreddamento passivo) |
| **Scalinata eval** | [28 → 43 → **55** → 38] | Include salita e discesa, 55°C fuori dal range training |

#### Perché includere Tset = 20°C nel training?

Con T1_init = 25°C e Tset = 20°C:
- e_init = 25 − 20 = **+5°C** → il sistema deve **raffreddare** (Q1 ≈ 0)
- Senza dati con e > 0, il GP non ha mai visto il raffreddamento passivo
- La scalinata di valutazione include la discesa 55 → 38°C, che genera e > 0

### Disturbo Q2

```matlab
Q2_levels = [2.0, 3.5, 5.0, 2.5, 4.0];   % [%] ciclati tra episodi
Q2_eval   = 2 + 3 * rand();               % valore random per la valutazione
```

Q2 agisce sull'heater 2 come disturbo costante per episodio. Il GP impara il suo effetto su T2 (e indirettamente su e), ma la policy **non lo vede** (poli=[1,3]) perché non è necessario per decidere Q1.

### Funzione di Costo — Invariante al Setpoint

```matlab
cost.target = [0; 0; 0; 0];         % e=0 → T1 = Tset ✅
cost.W      = diag([1, 0, 0, 0]);   % solo l'errore conta
```

### Covarianza Iniziale — Correlazione Negativa

```matlab
Cov(e, Tset) = −Var(Tset)    % e = T1_init − Tset → correlazione NEGATIVA
```

Alto Tset → basso e_init (il sistema deve riscaldare molto).  
Questa correlazione è fondamentale per una simulazione interna realistica.

### Valutazione a Scalinata

La valutazione **propaga lo stato fisico** tra gradini successivi:

```
Gradino 1: Tset=28°C, T1_init=25°C → e=−3°C → ... → T1_fin ≈ 28°C
Gradino 2: Tset=43°C, T1_init=T1_fin → e=28−43=−15°C → ... → T1_fin ≈ 43°C
Gradino 3: Tset=55°C, T1_init=T1_fin → e=43−55=−12°C → ... → T1_fin ≈ 55°C
Gradino 4: Tset=38°C, T1_init=T1_fin → e=55−38=+17°C → ... → T1_fin ≈ 38°C (DISCESA!)
```

La discesa 55→38°C è la prova più dura: e_init = +17°C, il GP deve prevedere il raffreddamento passivo.

### Cosa dimostra il Caso 3
- ✅ Una sola policy gestisce setpoint diversi grazie all'errore e = T1 − Tset
- ✅ L'inclusione di Tset < T1_init nel training copre scenari di raffreddamento
- ✅ Q2 come disturbo non degrada significativamente le prestazioni
- ⚠️ L'extrapolazione (Tset=55°C > max(Tset_train)=50°C) è il punto più critico
- ✅ La scalinata dimostra tracking sequenziale con stato propagato

---

## 5. Tabella Comparativa dei Tre Casi

|  | **Caso 1** | **Caso 2** | **Caso 3** |
|--|-----------|-----------|-----------|
| **Stato** | `[T1, T2]` (2D) | `[T1, T2, Tamb]` (3D) | `[e, T2, Tset, Q2]` (4D) |
| **Input policy** | `[T1, T2]` | `[T1, Tamb]` | `[e, Tset]` |
| **Input GP** | `[T1, T2, u]` (3D) | `[T1, T2, Tamb, u]` (4D) | `[e, T2, Tset, Q2, u]` (5D) |
| **Target costo** | `[50, 50]` | `[50, 0, 0]` | `[0, 0, 0, 0]` |
| **Pesi W** | `diag([1, 0])` | `diag([1, 0, 0])` | `diag([1, 0, 0, 0])` |
| **Tamb** | 25°C fissa | [25, 35, 40, 30]°C | 25°C fissa |
| **Tset** | 50°C fisso | 50°C fisso | [35, 28, 20, 43, 50]°C |
| **Q2** | 0% | 0% | [2, 3.5, 5, 2.5, 4]% |
| **dt** | 20 s | 20 s | 20 s |
| **H** | 30 step | 30 step | 30 step |
| **J (casuali)** | 15 | 12 | 15 |
| **N (iterazioni)** | 5 | 5 | 5 |
| **nc (neuroni)** | 20 | 20 | 25 |
| **Rollout/iter** | 1 | 4 (uno per Tamb) | 5 (uno per Tset) |
| **GP induce** | zeros(300,3,1) | zeros(200,4,1) | zeros(200,5,1) |
| **Valutazione** | -- | Tamb=[12,45,38,60] | Scalinata [28→43→55→38] |

---

## 6. Limiti e Potenzialità di PILCO per la Tesi

### ✅ Potenzialità (Punti di Forza)

1. **Data efficiency**: PILCO impara da pochi episodi reali (J+N ≈ 20-40 rollout totali), ideale per sistemi fisici costosi da interrogare.

2. **Model-based**: il GP funge da simulatore interno, riducendo il numero di interazioni reali necessarie.

3. **Analitically tractable**: la propagazione dell'incertezza N(μ,Σ) attraverso il GP è in forma chiusa (moment matching), permettendo backpropagation esatta.

4. **Framework estensibile**: come dimostrato nei 3 casi, basta aggiungere variabili allo stato per gestire nuove sfide (Tamb, Tset, Q2) **senza modificare l'algoritmo**.

5. **Policy flessibile**: la RBF (congp) cattura non linearità forti (come la dipendenza T⁴ nel bilancio radiativo) con pochi neuroni (nc=20-25).

6. **Costo saturante**: `lossSat` è bounded in [0,1], evita gradienti esplosivi durante l'ottimizzazione della policy.

### ⚠️ Limiti (Punti Deboli)

1. **Scalabilità**: il GP ha complessità O(n³) con n punti di training. Il GP sparso (FITC) mitiga il problema, ma per dataset molto grandi (>1000 transizioni) diventa lento.

2. **Dimensionalità dello stato**: all'aumentare della dimensione (2D → 3D → 4D), il GP richiede più dati per apprendere la dinamica in tutte le regioni. Nel Caso 3, lo spazio degli input GP è 5D (e, T2, Tset, Q2, u).

3. **Extrapolazione**: il GP è affidabile **solo nell'intervallo dei dati di training**. Testare Tamb=60°C (Caso 2) o Tset=55°C (Caso 3) è extrapolazione e le prestazioni possono degradare.

4. **Singolo orizzonte temporale**: PILCO ottimizza su un orizzonte H fisso. Per la scalinata (Caso 3) si addestra su H=30 step ma si valuta con H_step_eval=20 step per gradino — l'orizzonte di training potrebbe non essere ottimale per i transitori.

5. **Nessun vincolo duro**: PILCO non impone vincoli esplici su temperatura massima o variazione dell'azione. La saturazione `gSat` limita Q1 in [0,100]%, ma T1 potrebbe superare limiti fisici.

6. **Ottimizzazione locale**: `minimize.m` (BFGS) trova minimi locali. La policy finale dipende dall'inizializzazione dei pesi `policy.p.targets` e dei centri `policy.p.inputs`.

7. **No stato parzialmente osservabile**: PILCO assume stato completamente osservabile. Se un sensore fosse difettoso, il framework non ha un meccanismo di stima dello stato (es. filtro di Kalman).

8. **Fenomeno di ill-conditioning**: con molti dati simili (es. rollout a Tamb vicine nel Caso 2), la matrice kernel K diventa mal condizionata. Mitigato con `plant.noise` adeguato e GP sparso.

### 📊 Dove PILCO è ideale (e dove no)

| Scenario | PILCO adatto? | Perché |
|----------|:-------------:|--------|
| Sistema a bassa dimensione (2-6D) | ✅ | GP efficiente |
| Pochi dati disponibili | ✅ | Data-efficient per design |
| Dinamica liscia e continua | ✅ | GP con kernel SE la modella bene |
| Sistema con attrito/contatto | ⚠️ | Discontinuità nella dinamica |
| Stato > 10 dimensioni | ❌ | GP curse of dimensionality |
| Dati abbondanti (>10⁴) | ❌ | Deep RL più efficiente |
| Vincoli di sicurezza stretti | ❌ | Nessun meccanismo di vincolo duro |

---

## 7. Consigli per la Scrittura della Tesi

### Struttura Suggerita

1. **Introduzione**: motivazione del controllo termico, limiti del PID classico
2. **Background**: GP, PILCO, TCLab (modello fisico)
3. **Caso 1**: baseline, dimostrazione funzionamento PILCO
4. **Caso 2**: estensione a Tamb variabile, analisi generalizzazione
5. **Caso 3**: tracking setpoint, analisi scalinata, limiti dell'extrapolazione
6. **Conclusioni**: sintesi dei risultati, confronto tra i casi, lavori futuri

### Metriche da Riportare

Per ogni caso, riportare:

| Metrica | Descrizione |
|---------|-------------|
| Costo reale per iterazione | Deve decrescere → learning curve |
| Errore finale T1 − target | Precisione del controllo |
| Tempo di assestamento | Quanto velocemente raggiunge il target |
| Confronto training vs eval | Quanto il costo di eval è vicino a quello di training |

### Figure Chiave

- **Caso 1**: Figura 10 — learning curve e traiettorie T1
- **Caso 2**: Figura 11 (training) + Figura 12 (generalizzazione su Tamb mai viste)
- **Caso 3**: Figura 13 (training per Tset) + Figura 14 (scalinata con T1, errore e, Q1)

### Possibili Sviluppi Futuri

- Implementazione su TCLab **fisico** (non solo simulato)
- Confronto con PID auto-tuned e MPC
- Estensione a 2 azioni (Q1 e Q2 entrambe controllate)
- Uso di Deep PILCO per stati ad alta dimensionalità
- Aggiunta di vincoli di sicurezza (safe PILCO / barrier functions)
