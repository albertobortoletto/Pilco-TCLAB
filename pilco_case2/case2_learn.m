%% case2_learn.m
% *Sommario:* Training PILCO — Caso 2: Tamb VARIABILE, setpoint fisso (T1=50°C).
%
% Cosa fa questo script:
%   Fase 1 → Rollout casuali su tutte le Tamb di training
%   Fase 2 → Loop PILCO: addestra GP + ottimizza policy + rollout su tutte le Tamb
%   Fase 3 → Salva policy + dati in results/policy/
%
% Dopo aver eseguito questo script, eseguire case2_eval.m per la
% valutazione su Tamb mai viste e la generazione dei grafici.
%
% -------------------------------------------------------------------------
% SCELTA DELLO STATO INIZIALE (mu0_tt) per ogni Tamb di training:
%
%   Nella realtà, se il sistema è spento in un ambiente a Tamb=12°C,
%   anche T1 e T2 si trovano a ~12°C prima di accendere il controllo.
%   → mu0_tt = [Tamb_tt; Tamb_tt; Tamb_tt]  (equilibrio termico con ambiente)
%
%   Questo è fisicamente diverso da usare sempre T_init=25°C:
%   - A Tamb=12°C il riscaldamento parte da più in basso → traiettoria più lunga
%   - A Tamb=40°C il sistema è già vicino al target → traiettoria più corta
%   - Il GP vede questa varietà di condizioni iniziali → modello più ricco
%   - La policy deve imparare a gestire entrambe le situazioni
%
% -------------------------------------------------------------------------
% AGGIORNAMENTO DI mu0Sim / S0Sim DOPO LA RACCOLTA DATI:
%
%   Con stati iniziali T1_0 = Tamb (correlati), la distribuzione iniziale vera è:
%       T1 ~ Tamb,  Tamb ~ N(Tamb_mean, Tamb_var)
%   → Cov(T1, Tamb) = Tamb_var  (correlazione perfetta all'equilibrio)
%

%% 0. Inizializzazione
case2_settings;
fprintf('\n');

%% =========================================================================
%% Cartelle output
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

res_dir    = fullfile(script_dir, 'results');
policy_dir = fullfile(res_dir,    'policy');
fig_dir    = fullfile(res_dir,    'figures');

if ~exist(res_dir,    'dir'), mkdir(res_dir);    end
if ~exist(policy_dir, 'dir'), mkdir(policy_dir); end
if ~exist(fig_dir,    'dir'), mkdir(fig_dir);    end


%% =========================================================================
%% FASE 1: Rollout casuali iniziali
%% =========================================================================
% J=12 rollout ciclati su Tamb_train=[25,35,40,30] -> 3 per ogni Tamb.
% Stato iniziale: equilibrio termico [Tamb_tt; Tamb_tt; Tamb_tt].
% Azioni casuali -> esplorazione ampia dello spazio degli stati.

fprintf('=== FASE 1: Rollout casuali iniziali (%d rollout) ===\n', J);

for jj = 1:J
    Tamb_jj = Tamb_train(mod(jj-1, nT_train) + 1);

    % Equilibrio termico con l'ambiente: T1=T2=Tamb_jj
    mu0_jj = [Tamb_jj; Tamb_jj; Tamb_jj];
    S0_jj  = diag([0.5, 0.5, 0.001]);

    [xx, yy, rc, lt] = rollout(gaussian(mu0_jj, S0_jj), ...
                                struct('maxU', policy.maxU), H, plant, cost);

    x = [x; xx];
    y = [y; yy];
    realCost{end+1} = rc;
    latent{end+1}   = lt;

    fprintf('  Rollout %2d/%d | Tamb=%2.0f°C | T1_0=%.1f°C | Costo=%.4f | T1_fin=%.1f°C\n', ...
            jj, J, Tamb_jj, mu0_jj(1), sum(rc), lt(end,1));
end
fprintf('Dataset iniziale: %d transizioni, %d colonne\n', size(x,1), size(x,2));


%% =========================================================================
%% Costruzione mu0Sim / S0Sim coerente con stati iniziali correlati a Tamb
%% =========================================================================
% Poiche' T1_0 = T2_0 = Tamb (equilibrio), la distribuzione degli stati
% iniziali e' completamente determinata da Tamb ~ N(Tamb_mean, Tamb_var):
%
%   Cov(T1, Tamb) = Cov(Tamb, Tamb) = Tamb_var    (correlazione piena)
%   Cov(T2, Tamb) = Tamb_var                       (stessa logica)
%   Cov(T1, T2)   = Tamb_var                       (entrambi = Tamb)
%
% Aggiunta di una piccola varianza di misura su T1, T2 (incertezza del
% sensore all'accensione, stimata ~0.5 grados).

mu0Sim_full = zeros(max(odei), 1);
S0Sim_full  = zeros(max(odei), max(odei));

mu0Sim_full(odei) = [Tamb_mean; Tamb_mean; Tamb_mean];

% Matrice di covarianza 3x3: tutti correlati via Tamb_var
S0Sim_base = Tamb_var * ones(3,3);          % covarianza da Tamb
S0Sim_meas = diag([1.0, 1.0, 0.001]);       % varianza di misura
S0Sim_full(odei, odei) = S0Sim_base + S0Sim_meas;

% Seleziona componenti dyno (richiesto da PILCO interno)
mu0Sim = mu0Sim_full(dyno);
S0Sim  = S0Sim_full(dyno, dyno);

fprintf('\nmu0Sim/S0Sim aggiornati (stati iniziali correlati a Tamb):\n');
fprintf('  mu0Sim     = [%.1f, %.1f, %.1f] gradi C\n', mu0Sim(1), mu0Sim(2), mu0Sim(3));
fprintf('  S0Sim diag = [%.2f, %.2f, %.2f]\n', S0Sim(1,1), S0Sim(2,2), S0Sim(3,3));
fprintf('  Cov(T1,Tamb)=%.2f  corr(T1,Tamb)=%.3f\n', ...
        S0Sim(1,3), S0Sim(1,3)/sqrt(S0Sim(1,1)*S0Sim(3,3)));


%% =========================================================================
%% FASE 2: Loop principale PILCO
%% =========================================================================

fprintf('\n=== FASE 2: Loop PILCO (%d iter x %d Tamb = %d rollout) ===\n', ...
        N, nT_train, N*nT_train);

% Se invertissi i 2 for ossia per ogni segmento faccio N passi, avrei un
% fenomeno di CATASTROPHIC FORGETTING:
% Se addestrassi la policy prima solo a Tamb = 25 e poi solo a Tamb = 40
% accadrebbe che
% Spostamento dei pesi: Durante la seconda fase (40), l'ottimizzatore 
% minimize calcola il gradiente della funzione di costo basandosi 
% solo sui dati e sulle simulazioni a 40.
%
% Sovrascrittura: Per minimizzare il costo attuale, l'algoritmo modifica i 
% pesi alpha_i della  RBF. 
% Poiché non ha "memoria" del fatto che quegli stessi pesi servivano a 
% gestire i 25, li sposta verso valori ottimali per i 40, 
% cancellando di fatto la configurazione precedente.
for j = 1:N
    fprintf('\n--- Iterazione PILCO %d/%d ---\n', j, N);

    % --- 2a. Addestramento GP ---------------------------------------------
    fprintf('  [2a] Addestramento GP (%d transizioni)...\n', size(x,1));
    trainDynModel;

    % --- 2b. Ottimizzazione policy ----------------------------------------
    fprintf('  [2b] Ottimizzazione policy\n');
    fprintf('       T1_0 ~ N(%.1f, s=%.1f),  Tamb ~ N(%.1f, s=%.1f),  corr=%.3f\n', ...
            mu0Sim(1), sqrt(S0Sim(1,1)), mu0Sim(3), sqrt(S0Sim(3,3)), ...
            S0Sim(1,3)/sqrt(S0Sim(1,1)*S0Sim(3,3)));
    learnPolicy;

    % --- 2c. Rollout reali su tutte le Tamb -------------------------------
    fprintf('  [2c] Rollout policy:\n');
    costi_iter = zeros(1, nT_train);

    for tt = 1:nT_train
        Tamb_tt = Tamb_train(tt);

        % Stato iniziale in equilibrio con Tamb_tt
        mu0_tt = [Tamb_tt; Tamb_tt; Tamb_tt];
        S0_tt  = diag([0.5, 0.5, 0.001]);

        [xx, yy, rc, lt] = rollout(gaussian(mu0_tt, S0_tt), policy, H, plant, cost);

        x = [x; xx];
        y = [y; yy];
        realCost{end+1} = rc;
        latent{end+1}   = lt;
        costi_iter(tt)  = sum(rc);

        fprintf('       Tamb=%2.0f°C | T1_0=%.1f°C | Costo=%.4f | T1_fin=%.1f°C\n', ...
                Tamb_tt, mu0_tt(1), sum(rc), lt(end,1));
    end
    fprintf('  Costo medio iter %d: %.4f\n', j, mean(costi_iter));
end


%% =========================================================================
%% FASE 3: Salvataggio
%% =========================================================================

fprintf('\n=== FASE 3: Salvataggio policy ===\n');

save_path = fullfile(policy_dir, 'case2_policy_trained.mat');
save(save_path, ...
     'policy', 'dynmodel', 'x', 'y', ...
     'latent', 'realCost', ...
     'cost', 'plant', 'H', 'dt', 'J', 'N', ...
     'Tamb_train', 'Tamb_eval', 'nT_train', 'nT_eval', 'T_init', ...
     'Tamb_mean', 'Tamb_var', ...
     'opt', 'trainOpt', 'plotting', ...
     'odei', 'dyno', 'poli', 'difi', 'mu0Sim', 'S0Sim');

fprintf('Policy salvata in: %s\n', save_path);
fprintf('\n=== Training completato! ===\n');
fprintf('Rollout totali: %d (J=%d casuali + %d PILCO)\n', ...
        J + N*nT_train, J, N*nT_train);
fprintf('Ora esegui case2_eval.m per la valutazione e i grafici.\n');