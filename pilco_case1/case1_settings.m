%% settings_tclab_plant.m
% *Sommario:* Configura lo scenario TCLab per PILCO.
%             Usa la dinamica della repository (NON Simulink).
%
% Passi principali:
%   1. Definizione dello stato e degli indici importanti
%   2. Parametri dello scenario (dt, T, H, ...)
%   3. Struttura del plant (sistema fisico)
%   4. Struttura della policy (rete RBF)
%   5. Struttura della funzione di costo
%   6. Struttura del modello GP della dinamica
%   7. Parametri per l'ottimizzazione della policy
%   8. Verbosità dei grafici
%   9. Inizializzazioni array

%% Codice

warning('off','all'); format short; format compact; 

% Aggiunge i path delle cartelle della repository PILCO
settings_dir = fileparts(mfilename('fullpath'));
if isempty(settings_dir), settings_dir = pwd; end
repo_root = fullfile(settings_dir, '..', '..');
addpath(fullfile(repo_root, 'base'), fullfile(repo_root, 'util'), ...
        fullfile(repo_root, 'gp'),   fullfile(repo_root, 'control'), ...
        fullfile(repo_root, 'loss'));

% Fissa i seed casuali per riproducibilità degli esperimenti
rand('seed',5); randn('seed',13); 


% =========================================================================
% 1. Definizione dello stato e degli indici importanti
% =========================================================================

% 1a. Rappresentazione completa dello stato del sistema:
%   1  T1   Temperatura dell'heater/sensore 1 [°C]
%   2  T2   Temperatura dell'heater/sensore 2 [°C]
%   (Q1 e Q2 sono le azioni, non fanno parte dello stato)

% 1b. Indici importanti - dicono a PILCO quali variabili usare per cosa:
%
%   odei  → indici delle variabili passate all'ODE solver (stati fisici)
%   augi  → indici di variabili "aumentate" aggiunte allo stato (es. angoli)
%   dyno  → indici degli output del modello GP (stati che il GP predice)
%   angi  → indici di variabili angolari (rappresentate come sin/cos)
%   dyni  → indici degli input al GP della dinamica
%   poli  → indici delle variabili usate come input alla policy
%   difi  → indici delle variabili apprese come differenze (ΔT invece di T)
%            → il GP impara ΔT1 = T1(t+1) - T1(t), più facile da apprendere

odei = [1 2];    % T1 e T2 vanno all'ODE solver
augi = [];       % nessuna variabile aumentata
dyno = [1 2];    % il GP predice T1 e T2
angi = [];       % nessuna variabile angolare
dyni = [1 2];    % il GP riceve T1 e T2 come input
poli = [1 2];    % la policy riceve T1 e T2 come input
difi = [1 2];    % il GP impara ΔT1 e ΔT2 (differenze, non valori assoluti)


% =========================================================================
% 2. Parametri dello scenario
% =========================================================================

dt = 20;            % [s] intervallo di campionamento: ogni 60s si decide un'azione
T  = 600;           % [s] durata totale di un episodio
H  = ceil(T/dt);    % numero di passi per episodio: H = T/dt = 10
                    % → ogni episodio è composto da 10 step da 60s

mu0 = [25 25]';     % stato iniziale medio: T1=25°C, T2=25°C (temperatura ambiente)
S0  = 0.5*eye(2);   % varianza dello stato iniziale: piccola incertezza sulla T iniziale

N = 5;              % numero di iterazioni del loop principale PILCO
                    % (trial reali sul sistema)

J = 15;             % numero di rollout casuali iniziali per raccogliere i primi dati 
K = 1;              % numero di stati iniziali su cui ottimizzare la policy
nc = 20;            % numero di neuroni della rete RBF usata come policy

% Stato iniziale per la simulazione interna (usato da learnPolicy)
% In genere uguale a mu0/S0, ma può essere diverso per robustezza

% =========================================================================
% 3. Struttura del plant (sistema fisico)
% =========================================================================

plant.dynamics = @dynamics_tclab_case1;   % funzione ODE che descrive la fisica del TCLab
                                    % (usata per simulare il sistema, non il GP!)
plant.noise = diag([0.1^2 0.01^2]); % rumore di misura su T1 (0.1°) e T2 (0.01°)
plant.dt    = dt;                   % intervallo di campionamento [s]
plant.ctrl  = @zoh;                 % zero-order-hold: l'azione rimane costante
                                    % per tutto l'intervallo dt
plant.odei  = odei;                 % indici per l'ODE solver
plant.augi  = augi;                 % indici variabili aumentate
plant.angi  = angi;                 % indici variabili angolari
plant.poli  = poli;                 % indici input alla policy
plant.dyno  = dyno;                 % indici output del GP
plant.dyni  = dyni;                 % indici input al GP
plant.difi  = difi;                 % indici variabili apprese come differenze
plant.prop  = @propagated;          % funzione per propagare la distribuzione
                                    % degli stati attraverso il GP (momento matching)
plant.draw = @draw_tclab;           % per plottare i dati

% =========================================================================
% 4. Struttura della policy
% =========================================================================
% La policy mappa [T1, T2] → Q1 ∈ [-maxU, +maxU]
% In dynamics_tclab_case1: Q1_reale = action(1) + 50
% Quindi action ∈ [-50, +50] → Q1_reale ∈ [0, 100] ✓
% PILCO usa gSat che satura in [-maxU, +maxU], quindi maxU = 50 è CORRETTO
% purché i targets iniziali siano positivi (verso riscaldamento).

policy.fcn = @(policy,m,s)conCat(@congp,@gSat,policy,m,s);
% conCat: concatena due funzioni
% congp:  policy implementata come GP (calcola l'azione dato lo stato)
% gSat:   saturazione dell'azione nell'intervallo [-maxU, +maxU]

policy.maxU = [50];   % azione massima: Q1 può andare da -50 a +50
                      % (corrisponde a 0-100% di potenza nell'heater)

% Così i centri coprono la traiettoria attesa T1 ∈ [25, 45]°C
S0_policy = diag([25, 4]);   % std≈5°C su T1, std≈2°C su T2

policy.p.inputs = gaussian(mu0(poli), S0_policy(poli,poli), nc)';
% centri delle RBF: nc=20 punti campionati casualmente intorno allo stato iniziale
% → sono i punti dove la policy è "ancorata" nello spazio degli stati
% dimensione: nc x length(poli) = 20 x 2

policy.p.targets = 0.1 * ones(nc,1);  % inizia con azione piccola verso il target

policy.p.hyp = log([1; 5; 5; 0.1]);
% iperparametri del kernel della policy (in scala logaritmica perché devono essere >0):
%   exp(hyp(1)) = σ²      varianza del segnale
%   exp(hyp(2)) = ℓ_T1    length scale per T1 (quanto "pesa" T1 nella similarità)
%   exp(hyp(3)) = ℓ_T2    length scale per T2 (quanto "pesa" T2 nella similarità)
%   exp(hyp(4)) = σ_noise rumore della policy
% dimensione: 4 x n_azioni = 4 x 1


% =========================================================================
% 5. Struttura della funzione di costo
% =========================================================================

cost.fcn    = @lossSat;         % funzione di costo quadratica saturante:
                                % vale 0 se siamo al target, 1 se siamo lontani
cost.gamma  = 1;                % fattore di sconto (1 = nessuno sconto nel tempo)
cost.width  = 1;                % Mantienilo a 1 se usi già W per scalare
cost.expl   = 0;                % parametro di esplorazione (0 = nessun bonus esplorazione)
cost.target = [50 50]';         % stato target: T1=40°C, T2=23°C
cost.W      = diag([1, 0]);     % Pesiamo solo T1. T2 è libero (peso 0).
                                % W(1,1)=0.04 → controlliamo T1
                                % W(2,2)=0 → ignoriamo T2 (non ci interessa)
cost.z = cost.target;

% =========================================================================
% 6. Struttura del modello GP della dinamica
% =========================================================================

dynmodel.fcn    = @gp1d;            % funzione per fare predizioni con il GP
                                    % gp1d: GP con derivate (necessario per backprop)
dynmodel.train  = @train;           % funzione per addestrare il GP (ottimizza iperparametri)
dynmodel.induce = zeros(300,3,1);   % punti induttivi per il GP sparso (sparse GP / FITC)
                                    % usato quando i dati sono molti per efficienza

trainOpt = [300 300];               % numero massimo di line search per addestrare il GP:
                                    % trainOpt(1) = 300 → GP completo (pochi dati)
                                    % trainOpt(2) = 300 → GP sparso FITC (molti dati)


% =========================================================================
% 7. Parametri per l'ottimizzazione della policy (learnPolicy)
% =========================================================================

opt.length   = 150;     % numero massimo di line search per ottimizzare la policy
opt.MFEPLS   = 30;      % numero massimo di valutazioni della funzione per line search
opt.verbosity = 1;      % livello di dettaglio dell'output (0=silenzioso, 1=normale, 3=verbose)
opt.method   = 'BFGS';  % algoritmo di ottimizzazione:
                        % 'BFGS'  → Broyden-Fletcher-Goldfarb-Shanno (default, robusto)
                        % 'LBFGS' → L-BFGS (memory-efficient per molti parametri)
                        % 'CG'    → Gradient Coniugato


% =========================================================================
% 8. Verbosità dei grafici
% =========================================================================

plotting.verbosity = 0;   % 0 → nessun grafico
                          % 1 → grafici principali (traiettorie, costi)
                          % 2 → tutti i grafici (anche diagnostici GP)


% =========================================================================
% 9. Inizializzazioni array
% =========================================================================

x = []; y = [];   % dataset per il GP: x = stati, y = variazioni di stato (ΔT)
                  % vengono riempiti durante i rollout e usati da trainDynModel

% Celle per salvare i risultati di ogni iterazione PILCO:
fantasy.mean = cell(1,N);   % media delle traiettorie simulate
fantasy.std  = cell(1,N);   % deviazione standard delle traiettorie simulate
realCost     = cell(1,N);   % costo reale misurato ad ogni trial 
M            = cell(N,1);   % media dello stato lungo il rollout simulato
Sigma        = cell(N,1);   % varianza dello stato lungo il rollout simulato

basename = 'tclab_';        % prefisso per i file di salvataggio automatico
                            % es: 'tclab_1_H1.mat', 'tclab_2_H1.mat', ...

fprintf('=== Configurazione TCLab PILCO ===\n');
fprintf('Target: T1 = %.1f°C\n', cost.target(1));
fprintf('Width: %.1f°C\n', cost.width);
fprintf('maxU: %.0f (azione in [-%d,+%d] → PWM [0,100])\n', ...
        policy.maxU, policy.maxU, policy.maxU);
fprintf('H=%d step × dt=%ds = %ds per episodio\n', H, dt, T);
fprintf('J=%d rollout iniziali, N=%d iterazioni PILCO\n', J, N);

% =========================================================================
% 10. Media e Varianza della simulazione
% =========================================================================
mu0Sim(odei,:) = mu0; S0Sim(odei,odei) = S0;
mu0Sim = mu0Sim(dyno); S0Sim = S0Sim(dyno,dyno);