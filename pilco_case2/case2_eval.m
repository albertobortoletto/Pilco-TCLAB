%% case2_eval.m
% *Sommario:* Valutazione e plot — Caso 2: Tamb VARIABILE.
%
% Prerequisito: eseguire prima case2_learn.m che produce
%   results/policy/case2_policy_trained.mat
%
% Cosa fa questo script:
%   Fase 1 → Carica policy addestrata da results/policy/
%   Fase 2 → Valuta la policy su Tamb MAI VISTE durante il training
%             Tamb_eval = [12, 45, 38, 60]°C
%   Fase 3 → Genera i grafici (Figure 11 e 12) e li salva in results/figures/
%
% NESSUN RETRAINING: la policy è usata esattamente come prodotta da case2_learn.m.
% Questo testa la generalizzazione: la RBF policy con Tamb nello stato
% dovrebbe dare buone prestazioni anche su Tamb non viste in training.

%% =========================================================================
%% FASE 1: Carica policy addestrata
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

policy_dir = fullfile(script_dir, 'results', 'policy');
fig_dir    = fullfile(script_dir, 'results', 'figures');

if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

load_path = fullfile(policy_dir, 'case2_policy_trained.mat');

if ~exist(load_path, 'file')
    error('File non trovato: %s\nEsegui prima case2_learn.m', load_path);
end

fprintf('=== Caricamento policy da: %s ===\n', load_path);
load(load_path);   % carica: policy, dynmodel, x, y, latent, realCost,
                   %         cost, plant, H, dt, J, N,
                   %         Tamb_train, Tamb_eval, nT_train, nT_eval, T_init,
                   %         Tamb_mean, Tamb_var, opt, trainOpt, plotting,
                   %         odei, dyno, poli, difi, mu0Sim, S0Sim

Tamb_eval = [12, 45, 38, 60]; % Sovrascrivi le Tamb_eval lette dal file .mat
nT_eval = length(Tamb_eval);  % Aggiorna coerentemente il numero di test

% Ricarica i path della repository (potrebbero non essere nel path corrente)
try
    rd = '../../';
    addpath([rd 'base'], [rd 'util'], [rd 'gp'], [rd 'control'], [rd 'loss']);
catch
end

fprintf('Policy caricata. Training summary:\n');
fprintf('  Tamb training : %s °C\n', mat2str(Tamb_train));
fprintf('  Tamb eval     : %s °C\n', mat2str(Tamb_eval));
fprintf('  Rollout totali: %d\n', length(latent));


%% =========================================================================
%% FASE 2: Valutazione su Tamb mai viste
%% =========================================================================
% Tamb_eval = [12, 45, 38, 60]: nessuna di queste era in Tamb_train=[25,35,40,30].
%
% Risultati attesi:
%   - Tamb=38°C  → molto vicina a Tamb_train=40°C: ottimo
%   - Tamb=20°C  → vicina a Tamb_train=25°C: buono
%   - Tamb=45°C  → extrapolazione leggera: discreto
%   - Tamb=12°C  → extrapolazione più marcata (freddo estremo): accettabile

fprintf('\n=== FASE 2: Valutazione generalizzazione ===\n');
fprintf('Tamb valutazione: %s °C (MAI viste nel training)\n', mat2str(Tamb_eval));
fprintf('%s\n', repmat('-',1,65));

latent_eval   = cell(1, nT_eval);
realCost_eval = cell(1, nT_eval);

for te = 1:nT_eval
    Tamb_te = Tamb_eval(te);
    mu0_te  = [Tamb_te; Tamb_te; Tamb_te];   % T1=T2=T_init, Tamb_te corrente
    S0_te   = diag([0.5, 0.5, 0.001]);

    [~, ~, rc, lt] = rollout(gaussian(mu0_te, S0_te), policy, H, plant, cost);

    latent_eval{te}   = lt;
    realCost_eval{te} = rc;

    T1_fin = lt(end, 1);
    err    = T1_fin - cost.target(1);

    % Indica se in/out range training
    in_range = (Tamb_te >= min(Tamb_train)) && (Tamb_te <= max(Tamb_train));
    tag = '';
    if ~in_range, tag = ' [extrap]'; end

    fprintf('  Tamb=%3.0f°C%s | Costo=%.4f | T1_fin=%.1f°C | Errore=%+.1f°C\n', ...
            Tamb_te, tag, sum(rc), T1_fin, err);
end
fprintf('%s\n', repmat('-',1,65));


%% =========================================================================
%% FASE 3: Grafici e salvataggio figure
%% =========================================================================

fprintf('\n=== FASE 3: Generazione grafici ===\n');

% --- Vecchio draw (storico training + eval) ---
% draw_case2_results(latent, realCost, latent_eval, realCost_eval, ...
%                    plant, cost, J, N, Tamb_train, Tamb_eval);

% --- Nuovo draw_case2: stitching dei rollout eval in una traiettoria continua ---
T1_full_c2 = []; T2_full_c2 = []; Q1_full_c2 = [];
ref_full_c2 = []; cost_full_c2 = []; err_full_c2 = [];
Q2_full_c2 = []; t_full_c2 = [];
seg_switch_t_c2 = [];
Tset_seg_c2 = cost.target(1) * ones(1, nT_eval);   % Tset fisso 50°C per tutti
t_offset_c2 = 0;

for te = 1:nT_eval
    lt_te = latent_eval{te};
    n_te  = size(lt_te, 1);                          % H+1 punti
    T1_te = lt_te(:, 1);
    T2_te = lt_te(:, 2);
    t_te  = (0:n_te-1)' * dt + t_offset_c2;         % [s]
    ref_te = cost.target(1) * ones(n_te, 1);
    err_te = T1_te - ref_te;

    rc_te = realCost_eval{te}(:);
    cost_te = [rc_te(1); rc_te];                     % allinea a (H+1)

    % Q1: non disponibile direttamente, usa placeholder NaN
    Q1_te = NaN(n_te, 1);

    % Q2: nel Caso 2 non c'è disturbo Q2 esplicito nello stato per eval
    Q2_te = zeros(n_te, 1);

    if te == 1
        T1_full_c2   = T1_te;   T2_full_c2   = T2_te;
        ref_full_c2  = ref_te;  err_full_c2  = err_te;
        cost_full_c2 = cost_te; Q1_full_c2   = Q1_te;
        Q2_full_c2   = Q2_te;   t_full_c2    = t_te;
    else
        seg_switch_t_c2(end+1) = t_offset_c2;        %#ok — tempo di switch [s]
        T1_full_c2   = [T1_full_c2;   T1_te(2:end)];
        T2_full_c2   = [T2_full_c2;   T2_te(2:end)];
        ref_full_c2  = [ref_full_c2;  ref_te(2:end)];
        err_full_c2  = [err_full_c2;  err_te(2:end)];
        cost_full_c2 = [cost_full_c2; cost_te(2:end)];
        Q1_full_c2   = [Q1_full_c2;   Q1_te(2:end)];
        Q2_full_c2   = [Q2_full_c2;   Q2_te(2:end)];
        t_full_c2    = [t_full_c2;    t_te(2:end)];
    end
    t_offset_c2 = t_offset_c2 + (n_te - 1) * dt;
end

Q2_min_c2 = 0;  Q2_max_c2 = 0;

draw_case2(t_full_c2, T1_full_c2, T2_full_c2, ref_full_c2, ...
           Q1_full_c2, Q2_full_c2, cost_full_c2, err_full_c2, ...
           dt, Tamb_eval, Tset_seg_c2, seg_switch_t_c2, Q2_min_c2, Q2_max_c2);

% Salva Figure
fig_names = {11, 'case2_training'; 12, 'case2_evaluation'};

for fi = 1:size(fig_names, 1)
    fnum  = fig_names{fi, 1};
    fname = fig_names{fi, 2};
    if ishandle(fnum)
        p = fullfile(fig_dir, [fname '.png']);
        print(figure(fnum), p, '-dpng', '-r150');
        fprintf('  Figura %d salvata: %s\n', fnum, p);
    else
        fprintf('  Figura %d non trovata (non generata).\n', fnum);
    end
end

fprintf('\n=== Valutazione Case 2 completata! ===\n');
fprintf('Figure salvate in: %s\n', fig_dir);