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

draw_case2_results(latent, realCost, latent_eval, realCost_eval, ...
                   plant, cost, J, N, Tamb_train, Tamb_eval);

% Salva Figure 11 (training) e Figure 12 (valutazione)
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