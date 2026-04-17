%% case3_settings.m
% *Sommario:* Configurazione PILCO — Caso 3: Setpoint VARIABILE (scalinata) +
%             disturbo Q2 random, Tamb fissa.
%
% -------------------------------------------------------------------------
% STATO ESTESO: [e, T2, Tset, Q2]  (dim = 4)
%
%   e    = T1 - Tset   errore di inseguimento [°C]
%   T2   = temperatura heater 2 [°C]
%   Tset = setpoint corrente [°C]   dTset/dt = 0  (costante nell'episodio)
%   Q2   = potenza disturbo heater 2 [%]   dQ2/dt = 0
%
% PERCHÉ ERRORE e = T1 - Tset INVECE DI T1?
%   Con T1 nello stato, cost.target dovrebbe essere uguale a Tset che CAMBIA
%   tra episodi → impossibile con cost.target fisso di PILCO.
%   Con e nello stato: cost.target = [0;0;0;0], W = diag([1,0,0,0])
%   → INVARIANTE al setpoint: funziona per qualsiasi Tset.
%
% -------------------------------------------------------------------------
% SCELTA CRUCIALE DI Tset_train: INCLUDERE VALORI SOTTO T1_init
%
%   T1_init = 25°C (sistema freddo). Se Tset < 25°C allora:
%     e_init = T1_init - Tset > 0  ← sistema deve RAFFREDDARE (passivamente)
%
%   Questo è fondamentale per la scalinata di valutazione: quando il
%   riferimento scende (es. 55→38°C) la policy si trova con e >> 0.
%   Senza dati con e > 0 in training, il GP non ha mai visto il
%   raffreddamento passivo → policy impreparata.
%
%   Soluzione SEMPLICE: Tset_train = [20, 28, 35, 43, 50]°C
%     Tset=20°C → e_init = +5°C  ← GP impara Q1=0, T1 scende per irraggiamento
%     Tset=28°C → e_init = -3°C  ← quasi al setpoint, piccolo riscaldamento
%     Tset=35°C → e_init = -10°C ← riscaldamento moderato
%     Tset=43°C → e_init = -18°C ← riscaldamento forte
%     Tset=50°C → e_init = -25°C ← riscaldamento massimo
%
%   ZERO modifiche all'architettura: stessa struttura identica al Caso 2.
%   Il GP apprende naturalmente la fisica e>0 dagli episodi con Tset=20°C.
%
% -------------------------------------------------------------------------
% PERCHÉ Tset E Q2 NELLO STATO?
%   Tset: la potenza ottimale Q1 dipende da Tset (perdite radiative ∝ T⁴).
%         Con Tset nello stato la policy RBF mappa (e,Tset)→Q1 e impara
%         questa dipendenza non lineare.
%   Q2:   disturbo costante nell'episodio ma variabile tra episodi.
%         Il GP impara il suo effetto su T2 (e indirettamente su e) senza
%         che la policy debba reagirvi (poli=[1,3]).

warning('off','all'); format short; format compact;

try
    rd = '../../';
    addpath([rd 'base'],[rd 'util'],[rd 'gp'],[rd 'control'],[rd 'loss']);
catch
end

rand('seed',31); randn('seed',47);


% =========================================================================
% 1. INDICI STATO: [e, T2, Tset, Q2]
% =========================================================================

odei = [1 2 3 4];    % tutti e 4 gli stati nell'ODE (dTset=dQ2=0)
augi = [];
dyno = [1 2 3 4];    % GP predice [Δe, ΔT2, ΔTset≈0, ΔQ2≈0]
angi = [];
dyni = [1 2 3 4];    % GP riceve [e, T2, Tset, Q2] + azione u
poli = [1 3];        % policy: [e, Tset] → Q1  (T2 e Q2 non necessari per decidere Q1)
difi = [1 2 3 4];    % GP impara differenze


% =========================================================================
% 2. Setpoint training, disturbo Q2, scalinata valutazione
% =========================================================================

% Tset_train include 20°C < T1_init=25°C → e_init>0 → GP impara raffreddamento
Tset_train = [35, 28, 20, 43, 50];   % [°C] — include sottozero per coverage e>0
nT_train   = length(Tset_train);

% Q2 ciclato tra episodi: range [2,5]% come da specifica
Q2_levels  = [2.0, 3.5, 5.0, 2.5, 4.0];   % [%]
nQ2        = length(Q2_levels);

% Scalinata di valutazione: 4 gradini MAI VISTI (né valori né sequenza)
% Contiene sia salita (28→43→55) sia discesa (55→38): testa entrambe le direzioni
Tset_stair_eval = [28, 43, 55, 38];   % [°C]
Q2_eval = 2 + 3 * rand();             % [%] — valore random per eval
H_step_eval     = 20;                 % [step] per gradino: 20×20s = 400s

% Statistiche Tset training (usate per mu0Sim/S0Sim)
Tset_mean = mean(Tset_train);    % = 35.2°C
Tset_var  = var(Tset_train);     % ≈ 130.2°C²  (copre [20,50])

% Statistiche Q2
Q2_mean = mean(Q2_levels);       % = 3.4%
Q2_var  = var(Q2_levels);        % ≈ 1.43%²


% =========================================================================
% 3. Parametri temporali
% =========================================================================

T1_init = 25.0;       % T1 iniziale per ogni episodio [°C] (sistema freddo)
T2_init = 25.0;       % T2 iniziale
Tamb    = 25.0;       % temperatura ambiente fissa [°C]

dt   = 20;            % [s] intervallo di campionamento
T_ep = 600;           % [s] durata episodio training
H    = ceil(T_ep/dt); % = 30 step/episodio

N    = 5;             % iterazioni PILCO
J    = 15;            % rollout casuali (3 per Tset)
K    = 1;


% =========================================================================
% 4. Plant
% =========================================================================

plant.dynamics = @dynamics_tclab_case3;
plant.noise    = diag([0.5^2, 0.05^2, 0.001^2, 0.001^2]);
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
% 5. Policy RBF: [e, Tset] → Q1
% =========================================================================
%
% Ogni neurone ha centro (e_c, Tset_c) nel piano [e, Tset].
% Con Tset_train=[20..50] e T1_init=25°C, l'errore iniziale copre:
%   e ∈ [+5, -25]°C  → range di circa 30°C
% Aggiungiamo margine per la scalinata eval (e può arrivare a +17°C):
%   e ∈ [-30, +20]°C → mu0_pol centrato a -5, std≈13°C

policy.fcn  = @(policy,m,s)conCat(@congp,@gSat,policy,m,s);
policy.maxU = [50];

nc = 25;
mu0_pol = [T1_init - Tset_mean; Tset_mean];  % [≈-10.2; 35.2]
S0_pol  = diag([300, 200]);                    % std_e≈17°C, std_Tset≈14°C

policy.p.inputs  = gaussian(mu0_pol, S0_pol, nc)';
policy.p.targets = 0.1 * ones(nc, 1);

% Iperparametri: [s², l_e, l_Tset, s_noise] in log-scala
policy.p.hyp = log([1; 7; 7; 0.1]);


% =========================================================================
% 6. Funzione di costo: penalizza solo e
% =========================================================================

cost.fcn    = @lossSat;
cost.gamma  = 1;
cost.width  = 1;
cost.expl   = 0;
cost.target = [0; 0; 0; 0];
cost.W      = diag([1, 0, 0, 0]);
cost.z      = cost.target;


% =========================================================================
% 7. GP dinamica: input = [e, T2, Tset, Q2, u] = 5 colonne
% =========================================================================

dynmodel.fcn    = @gp1d;
dynmodel.train  = @train;
dynmodel.induce = zeros(200, 5, 1);

trainOpt = [100, 200];


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


% =========================================================================
% 10. Init dataset
% =========================================================================

x = []; y = [];
realCost = {};
latent   = {};
fantasy.mean = cell(1,N);
fantasy.std  = cell(1,N);
M     = cell(N,1);
Sigma = cell(N,1);

basename = 'tclab_case3_';


% =========================================================================
% 11. mu0Sim / S0Sim per learnPolicy
% =========================================================================
% Con T1_init=25 costante e Tset ~ N(Tset_mean, Tset_var):
%   e_init = T1_init - Tset  →  E[e] = 25 - Tset_mean ≈ -10.2°C
%   Var(e) = Var(Tset) = Tset_var  (T1_init costante)
%   Cov(e, Tset) = -Var(Tset) < 0  (correlazione negativa: alto Tset → basso e)
%
% Con Tset_train che copre [20,50]°C, Tset_var≈130 → std≈11.4°C
% PILCO simula su tutta la distribuzione Tset=[20..50] → policy robusta.

e_mean_sim = T1_init - Tset_mean;   % ≈ -10.2°C
e_var_sim  = Tset_var + 0.5;        % ≈ 130.7°C²

mu0Sim = [e_mean_sim; T2_init; Tset_mean; Q2_mean];   % 4×1

S0Sim = zeros(4, 4);
S0Sim(1,1) = e_var_sim;      % Var(e)
S0Sim(2,2) = 0.5;            % Var(T2)
S0Sim(3,3) = Tset_var;       % Var(Tset)
S0Sim(4,4) = Q2_var + 0.1;  % Var(Q2)
S0Sim(1,3) = -Tset_var;      % Cov(e,Tset) = -Var(Tset)  ← correlazione negativa
S0Sim(3,1) = -Tset_var;


% =========================================================================
% Riepilogo
% =========================================================================

fprintf('=== Configurazione Case 3: Setpoint variabile + Q2 disturbo ===\n');
fprintf('Stato: [e=T1-Tset, T2, Tset, Q2]  dim=%d\n', length(odei));
fprintf('Policy: [e, Tset] → Q1\n');
fprintf('Tset training  : %s °C  (include %.0f < T1_init=%.0f → e>0 coperta!)\n', ...
        mat2str(Tset_train), min(Tset_train), T1_init);
fprintf('  e_init range : [%+.0f, %+.0f]°C\n', T1_init-max(Tset_train), T1_init-min(Tset_train));
fprintf('Q2 disturbi    : %s %%\n', mat2str(Q2_levels));
fprintf('Scalinata eval : %s °C (mai vista)\n', mat2str(Tset_stair_eval));
fprintf('nc=%d RBF, H=%d step×dt=%ds, N=%d iter, J=%d casuali\n', nc, H, dt, N, J);
fprintf('mu0Sim         = [e=%.1f, T2=%.1f, Tset=%.1f, Q2=%.1f]\n', ...
        mu0Sim(1), mu0Sim(2), mu0Sim(3), mu0Sim(4));
fprintf('Cov(e,Tset)    = %.2f  corr(e,Tset) = %.3f\n', ...
        S0Sim(1,3), S0Sim(1,3)/sqrt(S0Sim(1,1)*S0Sim(3,3)));