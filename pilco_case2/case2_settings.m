%% case2_settings.m
% *Sommario:* Configurazione PILCO per il Caso 2: Tamb VARIABILE, setpoint fisso.
%
% DIFFERENZE rispetto al Caso 1:
%   - Stato esteso a 3D: [T1, T2, Tamb]
%   - Tamb è aggiunta come terza variabile di stato (dTamb/dt = 0 nell'ODE)
%   - La policy ora mappa [T1, T2, Tamb] → Q1: può adattarsi a Tamb diverse
%   - GP della dinamica riceve Tamb come input → impara dipendenza da Tamb
%   - dynmodel.induce: 4 input (T1,T2,Tamb,u) invece di 3
%   - policy.p.hyp: 5 iperparametri invece di 4 (ℓ_Tamb aggiunto)
%
% PERCHÉ ESTENDERE LO STATO CON Tamb?
%   Senza Tamb nello stato, se alleniamo PILCO a 25°C e poi lo testiamo a 40°C:
%   - Il GP ha imparato f(T1,T2,u) → ΔT, ma non sa che la dinamica è cambiata
%   - La policy non "vede" che Tamb è diversa: darà la stessa azione → sbagliata
%   Con Tamb nello stato:
%   - Il GP impara f(T1,T2,Tamb,u) → ΔT: conosce la dipendenza da Tamb
%   - La policy vede Tamb e attiva neuroni RBF diversi per Tamb diverse
%   - Risultato: policy ROBUSTA su temperature ambiente non viste in training
%
% PERCHÉ RBF E NON POLICY LINEARE?
%   Una policy lineare sarebbe: Q1 = w1*T1 + w2*T2 + w3*Tamb + w0
%   Problemi:
%   1. Non lineare: la potenza ottimale NON è lineare in Tamb.
%      A Tamb=12°C (freddo) servono molti più watt che a Tamb=40°C (già caldo):
%      la relazione è dominata dal termine radiativo ∝ (T^4 - Tamb^4), fortemente NL.
%   2. Interazioni: l'effetto di Tamb sulla Q1 ottimale dipende anche da T1 corrente
%      → serve cross-term T1*Tamb, non catturabile da un modello lineare semplice.
%   3. PILCO internamente propaga N(mu,Sigma) degli stati attraverso la policy.
%      Per la policy RBF (congp) questo si fa in forma chiusa via kernel quadrature.
%      La policy lineare NON è il tipo di funzione nativo di PILCO: congp è l'opzione
%      ottimale perché è coerente con il framework GP di tutto il resto.
%   4. La policy RBF attiva neuroni DIVERSI per Tamb diverse: il neurone con centro
%      vicino a (T1≈37, Tamb≈40) imparerà a ridurre Q1, mentre quello vicino a
%      (T1≈37, Tamb≈12) imparerà ad aumentarla. Questo è esattamente il comportamento
%      adattivo che vogliamo.

warning('off','all'); format short; format compact;
% warning('off','all') include il warning "R-matrix ill-conditioned" di gp2d.
% Non e' un errore fatale: PILCO aggiunge jitter e continua. Con plant.noise
% adeguato (vedi sotto) il problema appare raramente.

settings_dir = fileparts(mfilename('fullpath'));
if isempty(settings_dir), settings_dir = pwd; end
repo_root = fullfile(settings_dir, '..', '..');
addpath(fullfile(repo_root, 'base'), fullfile(repo_root, 'util'), ...
        fullfile(repo_root, 'gp'),   fullfile(repo_root, 'control'), ...
        fullfile(repo_root, 'loss'));

rand('seed',11); randn('seed',23);


% =========================================================================
% 1. STATO ESTESO: [T1, T2, Tamb]  (dim = 3)
% =========================================================================
%
%   1  T1    Temperatura heater/sensore 1 [°C]    ← controllata
%   2  T2    Temperatura heater/sensore 2 [°C]    ← non controllata
%   3  Tamb  Temperatura ambiente [°C]             ← NUOVA: costante per episodio,
%                                                     varia tra episodi di training
%
% Tamb viene trattata come uno stato (dTamb/dt = 0 nell'ODE) perché:
%   - Non è un'azione (non la controlliamo)
%   - Non è rumore (è misurabile con un termometro)
%   - È un "context" che influenza la dinamica di T1 e T2
%   - Includerla nello stato è il modo standard per gestire parametri variabili
%     in un framework GP/PILCO senza modificare l'architettura del modello

odei = [1 2 3];    % T1, T2, Tamb → ODE (dTamb/dt=0 in dynamics_tclab.m)
augi = [];         % nessuna variabile aumentata
dyno = [1 2 3];    % GP predice ΔT1, ΔT2, ΔTamb (≈0 per Tamb)
angi = [];         % nessuna variabile angolare
dyni = [1 2 3];    % GP dinamica riceve [T1, T2, Tamb] come input (T2 serve per predire ΔT1)
poli = [1 3];      % policy riceve SOLO [T1, Tamb] → mappa (T1,Tamb)→Q1
                   % T2 NON entra nella policy: non la controlliamo e non ci serve
                   % per decidere Q1. Riduce lo spazio della policy da R³ a R²:
                   % meno parametri, convergenza più rapida, nessuna perdita di controllo.
difi = [1 2 3];    % GP impara differenze: ΔT1, ΔT2, ΔTamb
                   % ΔTamb ≈ 0 sempre (Tamb costante nell'episodio)


% =========================================================================
% 2. Temperature ambiente: training e valutazione
% =========================================================================

Tamb_train = [25, 35, 40, 30];   % Tamb viste durante il training [°C]
nT_train   = length(Tamb_train);
%nT_eval    = length(Tamb_eval);

% Statistiche Tamb di training (usate per mu0Sim/S0Sim della simulazione interna)
Tamb_mean = mean(Tamb_train);     % ≈ 32.5°C
Tamb_var  = var(Tamb_train);      % ≈ 31.25 °C² (std ≈ 5.6°C)


% =========================================================================
% 3. Parametri scenario
% =========================================================================

T_init = 25;          % temperatura iniziale di T1 e T2 [°C] (uguale per tutti gli episodi)

dt   = 20;            % [s] intervallo di campionamento
T_ep = 600;           % [s] durata episodio
H    = ceil(T_ep/dt); % = 30 step per episodio

N    = 5;             % iterazioni PILCO
J    = 12;            % rollout casuali iniziali (3 per ogni Tamb_train)
K    = 1;
% nc (neuroni RBF) è definito nella sezione Policy qui sotto,
% insieme ai centri: nc=20 per spazio 2D [T1, Tamb]

mu0 = [T_init; T_init; Tamb_mean];   % stato iniziale "nominale" (Tamb = media training)
S0  = diag([0.5, 0.5, 0.001]);       % T1,T2 con piccola incertezza; Tamb nota precisamente


% =========================================================================
% 4. Plant
% =========================================================================

plant.dynamics = @dynamics_tclab_case2;          % ODE modificata (backward compatible)
plant.noise    = diag([0.5^2, 0.05^2, 0.01^2]);
%                             ↑ T1     ↑ T2      ↑ Tamb (misurata con precisione)
% NOTA: T1=0.5^2 (era 0.1^2) e T2=0.05^2 (era 0.01^2).
% Valori più alti aggiungono jitter implicito alla diagonale di K nel GP,
% prevenendo l'ill-conditioning quando i punti di training sono vicini
% (es. rollout su Tamb simili producono traiettorie quasi identiche).
% 0.5°C di rumore su T1 è fisicamente realistico per il sensore del TCLab.
plant.dt       = dt;
plant.ctrl     = @zoh;
plant.odei     = odei;
plant.augi     = augi;
plant.angi     = angi;
plant.poli     = poli;
plant.dyno     = dyno;
plant.dyni     = dyni;
plant.difi     = difi;
plant.prop     = @propagated;
plant.draw     = @draw_tclab;


% =========================================================================
% 5. Policy RBF: mappa [T1, Tamb] → Q1
% =========================================================================
%
% STRUTTURA (congp + gSat):
%   pi(x) = sum_i alpha_i * k(x, c_i)   saturato in [-maxU, +maxU]
%
%   dove:
%   - c_i in R²  sono i centri RBF in spazio [T1, Tamb]      (policy.p.inputs, nc×2)
%   - alpha_i    sono i pesi ottimizzati da PILCO              (policy.p.targets, nc×1)
%   - k(x,c) = s² * exp(-½ * [(x1-c1)²/l_T1² + (x2-c2)²/l_Tamb²])
%
% poli = [1 3]: la policy vede T1 (variabile controllata) e Tamb (contesto).
% T2 NON entra nella policy perché:
%   1. Non la controlliamo → conoscerla non aiuta a scegliere Q1
%   2. Riduce lo spazio da R³ a R²: meno neuroni necessari, convergenza più rapida
%   3. T2 entra comunque nel GP della dinamica (dyni=[1 2 3]) → il modello
%      sa che T2 esiste e influenza ΔT1, ma la policy non ne ha bisogno
%
% INTUIZIONE GEOMETRICA (spazio 2D ora):
%   Ogni neurone RBF ha un centro (T1_c, Tamb_c) nel piano [T1, Tamb].
%   Il neurone vicino a (T1≈37, Tamb≈12) impara: "fa freddo, scalda di più".
%   Il neurone vicino a (T1≈37, Tamb≈40) impara: "fa caldo, scalda meno".
%   Con nc=20 neuroni in R² si copre bene lo spazio operativo.

policy.fcn  = @(policy,m,s)conCat(@congp,@gSat,policy,m,s);
policy.maxU = [50];

% Centri RBF: campionati nello spazio [T1, Tamb] (2D, poli=[1 3])
nc = 20;           % ridotto da 30: in R² bastano meno neuroni (regola: nc >= 5*dim = 10)
mu0_pol = [(T_init+50)/2; Tamb_mean];   % [T1≈37.5°C, Tamb≈32.5°C]
S0_pol  = diag([100, Tamb_var + 100]);  % T1 da 25 a 50°C, Tamb copre [12,45]°C
%               ↑ T1: std≈10°C          ↑ Tamb: std≈11°C

policy.p.inputs  = gaussian(mu0_pol, S0_pol, nc)';   % nc×2  (poli=[1,3] → 2 colonne)
policy.p.targets = 0.1 * ones(nc, 1);                 % pesi iniziali piccoli

% Iperparametri kernel (log-scala): [sigma², l_T1, l_Tamb, sigma_noise]
% 2 length scale invece di 3: T2 rimosso dalla policy
policy.p.hyp = log([1; 5; 5; 0.1]);
%                   ↑s²  ↑lT1 ↑lTamb ↑sn


% =========================================================================
% 6. Funzione di costo
% =========================================================================
% Penalizza solo T1. T2 e Tamb sono irrilevanti per il costo.
% cost.W(3,3)=0 → ΔTamb non contribuisce mai al costo, anche se è nello stato.

cost.fcn    = @lossSat;
cost.gamma  = 1;
cost.width  = 1;
cost.expl   = 0;
cost.target = [50; 0; 0];    % solo T1_target=50°C conta; T2 e Tamb azzerati
cost.W      = diag([1, 0, 0]);       % solo T1 nel costo (W(2,2)=W(3,3)=0)
cost.z      = cost.target;


% =========================================================================
% 7. Modello GP della dinamica
% =========================================================================
% In Caso 1: input GP = [T1, T2, u]    → 3 dimensioni → induce: zeros(300,3,1)
% In Caso 2: input GP = [T1, T2, Tamb, u] → 4 dimensioni → induce: zeros(300,4,1)

dynmodel.fcn    = @gp1d;
dynmodel.train  = @train;
dynmodel.induce = zeros(200, 4, 1);   % ridotto da 300: meno punti = K_uu meglio condizionata

trainOpt = [100, 200];
% Ridotto da [300,500]: iterazioni troppo aggressive portano in zone numericamente
% instabili nelle prime iter PILCO quando i dati sono ancora pochi.


% =========================================================================
% 8. Ottimizzazione policy
% =========================================================================

opt.length    = 150;
opt.MFEPLS    = 30;
opt.verbosity = 1;
opt.method    = 'BFGS';


% =========================================================================
% 9. Visualizzazione
% =========================================================================

plotting.verbosity = 0;
%   0 → nessun grafico durante learnPolicy
%   1 → grafici principali (utile per debug, rallenta un po')


% =========================================================================
% 10. Init array dataset
% =========================================================================

x = []; y = [];
realCost = {};
latent   = {};
fantasy.mean = cell(1,N);
fantasy.std  = cell(1,N);
M     = cell(N,1);
Sigma = cell(N,1);

basename = 'tclab_case2_';


% =========================================================================
% 11. mu0Sim / S0Sim per learnPolicy (simulazione interna PILCO)
% =========================================================================
% CRUCIALE: mu0Sim e S0Sim determinano da dove PILCO inizia la sua simulazione
% interna durante l'ottimizzazione della policy.
%
% Per il Caso 2, vogliamo ottimizzare la policy su TUTTE le Tamb di training.
% Metodo: impostiamo S0Sim(3,3) = var(Tamb_train) ≈ 31.25°C²
% → PILCO simula internamente partendo da Tamb ~ N(32.5, 31.25)
% → il gradiente della policy viene calcolato mediando su tutte le Tamb plausibili
% → risultato: policy ROBUSTA e adattiva, non ottimizzata per una sola Tamb
%
% Nota: var([25,35,40,30]) = 31.25 → std ≈ 5.6°C, che copre bene il range [25,40].

mu0Sim = zeros(max(odei), 1);          % inizializzazione esplicita 3×1
S0Sim  = zeros(max(odei), max(odei));  % inizializzazione esplicita 3×3

mu0Sim(odei) = [T_init; T_init; Tamb_mean];
S0Sim(odei, odei) = diag([0.5, 0.5, Tamb_var]);
%                              ↑T1   ↑T2  ↑Tamb: varianza sull'intero range training

mu0Sim = mu0Sim(dyno);       % riga→colonna, seleziona solo indici dyno
S0Sim  = S0Sim(dyno, dyno);  % matrice 3×3


% =========================================================================
% Riepilogo
% =========================================================================

fprintf('=== Configurazione Case 2: Tamb variabile ===\n');
fprintf('Stato: [T1, T2, Tamb] - dim=%d\n', length(odei));
fprintf('Tamb training  : %s °C\n', mat2str(Tamb_train));
fprintf('Tamb valutaz.  : %s °C\n', mat2str(Tamb_eval));
fprintf('Target T1      : %.0f°C\n', cost.target(1));
fprintf('nc=%d centri RBF, H=%d step × dt=%ds\n', nc, H, dt);
fprintf('J=%d rollout casuali, N=%d iterazioni PILCO\n', J, N);
fprintf('mu0Sim Tamb    : %.1f°C ± %.1f°C (std)\n', Tamb_mean, sqrt(Tamb_var));