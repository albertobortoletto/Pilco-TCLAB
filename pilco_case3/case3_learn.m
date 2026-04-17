%% case3_learn.m
% *Sommario:* Training PILCO — Caso 3: Setpoint VARIABILE + Q2 disturbo.
%
% Struttura identica al Caso 2: episodi singoli con Tset fisso per episodio,
% ciclati su Tset_train. La copertura e>0 (raffreddamento) è garantita dal
% fatto che Tset_train=[20,28,35,43,50] include 20°C < T1_init=25°C:
%   → Tset=20°C: e_init=+5°C → GP impara raffreddamento passivo (Q1=0)
%   → nessuna complessità aggiuntiva rispetto al Caso 2
%
% Fasi:
%   1 → Rollout casuali su tutte le Tset_train (J rollout, 3 per Tset)
%   2 → Loop PILCO: GP + policy + rollout su tutte le Tset
%   3 → Salva in results/policy/

%% 0. Inizializzazione
case3_settings;

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
fprintf('Working dir: %s\n\n', script_dir);

%% =========================================================================
%% Cartelle output
%% =========================================================================

res_dir    = fullfile(script_dir, 'results');
policy_dir = fullfile(res_dir,    'policy');
fig_dir    = fullfile(res_dir,    'figures');

if ~exist(res_dir,    'dir'), mkdir(res_dir);    end
if ~exist(policy_dir, 'dir'), mkdir(policy_dir); end
if ~exist(fig_dir,    'dir'), mkdir(fig_dir);    end

fprintf('Policy → %s\n',   policy_dir);
fprintf('Figure → %s\n\n', fig_dir);


%% =========================================================================
%% FASE 1: Rollout casuali iniziali
%% =========================================================================
% J=15 rollout ciclati su Tset_train → 3 per ogni Tset.
% Con Tset=20°C: e_init=+5°C → rollout casuali coprono già e>0 fin dall'inizio.

fprintf('=== FASE 1: Rollout casuali (%d rollout) ===\n', J);
fprintf('    Tset_train = %s °C\n', mat2str(Tset_train));
fprintf('    e_init range: [%+.0f, %+.0f]°C  (Tset=%.0f copre e>0)\n', ...
        T1_init-max(Tset_train), T1_init-min(Tset_train), min(Tset_train));
fprintf('%s\n', repmat('-',1,65));

for jj = 1:J
    Tset_jj = Tset_train(mod(jj-1, nT_train) + 1);
    Q2_jj   = Q2_levels(mod(jj-1, nQ2) + 1);
    e_jj    = T1_init - Tset_jj;

    mu0_jj = [e_jj; T2_init; Tset_jj; Q2_jj];
    S0_jj  = diag([0.5, 0.5, 0.001, 0.001]);

    [xx, yy, rc, lt] = rollout(gaussian(mu0_jj, S0_jj), ...
                                struct('maxU', policy.maxU), H, plant, cost);
    x = [x; xx];
    y = [y; yy];
    realCost{end+1} = rc;
    latent{end+1}   = lt;

    T1_fin = lt(end,1) + lt(end,3);
    e_fin  = lt(end,1);
    fprintf('  Rollout %2d/%d | Tset=%2.0f°C, Q2=%.1f%% | e_0=%+.1f°C | e_fin=%+.1f°C | T1_fin=%.1f°C | Costo=%.4f\n', ...
            jj, J, Tset_jj, Q2_jj, e_jj, e_fin, T1_fin, sum(rc));
end
fprintf('Dataset iniziale: %d transizioni\n', size(x,1));


%% =========================================================================
%% Aggiornamento mu0Sim / S0Sim dopo raccolta dati
%% =========================================================================
% Cov(e,Tset) = -Var(Tset): alto Tset → basso e iniziale (correlazione neg.)

e_mean_data = T1_init - Tset_mean;
e_var_data  = Tset_var + 0.5;

mu0Sim = [e_mean_data; T2_init; Tset_mean; Q2_mean];

S0Sim = zeros(4,4);
S0Sim(1,1) = e_var_data;
S0Sim(2,2) = 1.0;
S0Sim(3,3) = Tset_var;
S0Sim(4,4) = Q2_var + 0.1;
S0Sim(1,3) = -Tset_var;
S0Sim(3,1) = -Tset_var;

fprintf('\nmu0Sim/S0Sim:\n');
fprintf('  mu0Sim  = [e=%.1f, T2=%.1f, Tset=%.1f, Q2=%.1f]\n', ...
        mu0Sim(1), mu0Sim(2), mu0Sim(3), mu0Sim(4));
fprintf('  diag    = [%.2f, %.2f, %.2f, %.2f]\n', ...
        S0Sim(1,1), S0Sim(2,2), S0Sim(3,3), S0Sim(4,4));
fprintf('  Cov(e,Tset)=%.2f  corr=%.3f\n', ...
        S0Sim(1,3), S0Sim(1,3)/sqrt(S0Sim(1,1)*S0Sim(3,3)));


%% =========================================================================
%% FASE 2: Loop principale PILCO
%% =========================================================================

fprintf('\n=== FASE 2: Loop PILCO (%d iter × %d Tset = %d rollout) ===\n', ...
        N, nT_train, N*nT_train);

for j = 1:N
    fprintf('\n--- Iterazione PILCO %d/%d ---\n', j, N);

    % --- 2a. GP training ---
    fprintf('  [2a] GP training (%d transizioni)...\n', size(x,1));
    trainDynModel;

    % --- 2b. Policy optimization ---
    fprintf('  [2b] Policy optimization\n');
    fprintf('       e ~ N(%.1f, s=%.1f), Tset ~ N(%.1f, s=%.1f), corr=%.3f\n', ...
            mu0Sim(1), sqrt(S0Sim(1,1)), mu0Sim(3), sqrt(S0Sim(3,3)), ...
            S0Sim(1,3)/sqrt(S0Sim(1,1)*S0Sim(3,3)));
    learnPolicy;

    % --- 2c. Rollout su tutte le Tset_train ---
    fprintf('  [2c] Rollout policy:\n');
    costi_iter = zeros(1, nT_train);

    for tt = 1:nT_train
        Tset_tt = Tset_train(tt);
        Q2_tt   = Q2_levels(mod(tt-1, nQ2) + 1);
        e_tt    = T1_init - Tset_tt;

        mu0_tt = [e_tt; T2_init; Tset_tt; Q2_tt];
        S0_tt  = diag([0.5, 0.5, 0.001, 0.001]);

        [xx, yy, rc, lt] = rollout(gaussian(mu0_tt, S0_tt), policy, H, plant, cost);
        x = [x; xx]; y = [y; yy];
        realCost{end+1} = rc;
        latent{end+1}   = lt;
        costi_iter(tt)  = sum(rc);

        T1_fin = lt(end,1)+lt(end,3);
        e_fin  = lt(end,1);
        fprintf('       Tset=%2.0f°C, Q2=%.1f%% | e_0=%+.0f → e_fin=%+.2f°C | T1_fin=%.1f°C | Costo=%.4f\n', ...
                Tset_tt, Q2_tt, e_tt, e_fin, T1_fin, sum(rc));
    end
    fprintf('  Costo medio iter %d: %.4f\n', j, mean(costi_iter));
end


%% =========================================================================
%% FASE 3: Salvataggio (percorso assoluto)
%% =========================================================================

fprintf('\n=== FASE 3: Salvataggio policy ===\n');

save_path = fullfile(policy_dir, 'case3_policy_trained.mat');
save(save_path, ...
     'policy', 'dynmodel', 'x', 'y', ...
     'latent', 'realCost', ...
     'cost', 'plant', 'H', 'dt', 'J', 'N', ...
     'Tset_train', 'Tset_stair_eval', 'nT_train', 'T1_init', 'T2_init', ...
     'Q2_levels', 'Q2_mean', 'Q2_var', 'Q2_eval', 'H_step_eval', ...
     'Tset_mean', 'Tset_var', ...
     'opt', 'trainOpt', 'plotting', ...
     'odei', 'dyno', 'poli', 'difi', 'mu0Sim', 'S0Sim');

fprintf('Policy salvata: %s\n', save_path);
fprintf('\n=== Training completato! ===\n');
fprintf('Rollout totali: %d (J=%d casuali + %d PILCO)\n', ...
        J + N*nT_train, J, N*nT_train);
fprintf('Ora esegui case3_eval.m\n');