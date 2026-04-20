%% case1_learn_eval.m
% *Sommario:* Training + salvataggio — Caso 1: Tamb fissa, setpoint fisso T1=50°C.
%
% Loop PILCO standard:
%   Fase 1 → J rollout casuali (raccoglie dati iniziali + Q1)
%   Fase 2 → N iterazioni: trainDynModel + learnPolicy + applyController (+ raccolta Q1)
%   Fase 3 → Salva risultati e grafici in results/

%% 0. Inizializzazione
case1_settings;


%% =========================================================================
%% Cartelle output (percorso assoluto basato su script_dir)
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

res_dir = fullfile(script_dir, 'results');
fig_dir = fullfile(res_dir,    'figures');
if ~exist(res_dir, 'dir'), mkdir(res_dir); end
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

fprintf('Output → %s\n\n', res_dir);


%% =========================================================================
%% FASE 1: Rollout casuali iniziali
%% =========================================================================
% Raccoglie i primi dati per il GP con azioni CASUALI (struct senza policy).
% Parallelamente salva Q1 in actions{} per il plot Q1 in draw_tclab_history.

fprintf('=== FASE 1: Rollout casuali (%d rollout) ===\n', J);

for jj = 1:J
    [xx, yy, realCost{jj}, latent{jj}] = ...
        rollout(gaussian(mu0, S0), struct('maxU', policy.maxU), H, plant, cost);

    x = [x; xx];
    y = [y; yy];

    % Raccoglie Q1: xx(:,end) = output policy ∈ [-50,+50] → Q1 fisico [0,100]%
    actions{jj} = xx(:, end) + 50;

    fprintf('  Rollout iniziale %2d/%d — Costo: %.4f\n', jj, J, sum(realCost{jj}));
end


%% =========================================================================
%% FASE 2: Loop principale PILCO
%% =========================================================================

fprintf('\n=== FASE 2: Loop PILCO (%d iterazioni) ===\n', N);

for j = 1:N
    fprintf('\n--- Iterazione PILCO %d/%d ---\n', j, N);

    % --- 2a. Addestramento GP ---
    % Usa tutti i dati x,y raccolti finora per fare fit del GP:
    % f(T1, T2, u) → (ΔT1, ΔT2).
    fprintf('  [2a] GP training (%d transizioni)...\n', size(x,1));
    trainDynModel;

    % --- 2b. Ottimizzazione policy ---
    % Minimizza il costo atteso J(π) simulando H step con il GP.
    % Nessuna interazione con il sistema fisico: solo gradiente sul GP.
    fprintf('  [2b] Policy optimization...\n');
    learnPolicy;

    % --- 2c. Applicazione policy sul sistema ---
    % Esegue UN episodio reale con la policy ottimizzata al passo precedente.
    % applyController è uno script PILCO che chiama rollout(mu0Sim,S0Sim,...)
    % e aggiorna x, y, realCost{j+J}, latent{j+J} nel workspace.
    applyController;

    % Raccoglie Q1 dal rollout appena eseguito.
    % Dopo applyController, xx è disponibile nel workspace come variabile locale.
    if exist('xx', 'var') && ~isempty(xx)
        actions{j+J} = xx(:, end) + 50;   % Q1 [%]
    end

    fprintf('  Costo reale: %.4f\n', sum(realCost{j+J}));
end


%% =========================================================================
%% FASE 3: Grafici e salvataggio
%% =========================================================================

fprintf('\n=== FASE 3: Grafici e salvataggio ===\n');

% --- Vecchio draw (storico training) ---
% draw_tclab_history(latent, realCost, plant, cost, J, N, actions);

% --- Nuovo draw_case1: mostra l'ultimo rollout PILCO ---
% NOTA: applyController.m usa indici diversi:
%   latent{j}      → j = 1..N  (sovrascrive i primi N random)
%   realCost{j+J}  → j+J = J+1..J+N
%   actions{j+J}   → j+J = J+1..J+N
lt_last  = latent{N};                                % (H+1) × nState — ultimo PILCO
T1_last  = lt_last(:, 1);                        % T1 [°C]
T2_last  = lt_last(:, 2);                        % T2 [°C]
N_pts    = size(lt_last, 1);                      % H+1 punti
t_vec    = (0:N_pts-1)' * dt;                     % tempo [s]
ref_last = cost.target(1) * ones(N_pts, 1);       % riferimento costante Tset [°C]

% Q1: azione dell'ultimo rollout [0,100]%
Q1_last  = actions{J + N};                        % H × 1
Q1_last  = [Q1_last(1); Q1_last];                 % allinea a (H+1) punti

% Q2: nel Caso 1 il disturbo è definito nella ODE (range fisso)
Q2_min_c1 = 0;   Q2_max_c1 = 0;                  % Caso 1: nessun disturbo Q2 esplicito
Q2_last   = zeros(N_pts, 1);                      % placeholder Q2 = 0

% Costo per step
rc_last   = realCost{J + N}(:);
cost_last = [rc_last(1); rc_last];                % allinea a (H+1)


% Errore di inseguimento
err_last  = T1_last - ref_last;

% Tamb e Tset (fissi nel Caso 1)
Tamb_c1 = 25;                                     % Tamb [°C] — fisso
Tset_c1 = cost.target(1);                          % Tset [°C]

draw_case1(t_vec, T1_last, T2_last, ref_last, Q1_last, Q2_last, ...
           cost_last, err_last, dt, Tamb_c1, Tset_c1, Q2_min_c1, Q2_max_c1);

% Salva workspace (solo l'ultima policy) in results/
save_path = fullfile(res_dir, 'case1_policy_trained.mat');
save(save_path, ...
     'policy', 'dynmodel', 'x', 'y', ...
     'latent', 'realCost', 'actions', ...
     'cost', 'plant', 'H', 'dt', 'J', 'N', ...
     'opt', 'trainOpt', 'plotting', ...
     'odei', 'dyno', 'poli', 'difi', 'mu0Sim', 'S0Sim');
fprintf('Policy salvata: %s\n', save_path);

% --- Pulizia file intermedi generati da applyController ---
% applyController.m salva un file per ogni iterazione PILCO:
%   basename + j + '_H' + H + '.mat'  (es. tclab_1_H30.mat, tclab_2_H30.mat, ...)
% Questi file sono ridondanti perché l'ultima policy è già in results/.
% Manteniamo solo l'ultimo e cancelliamo il resto.
for jj_clean = 1:N
    tmp_file = [basename num2str(jj_clean) '_H' num2str(H) '.mat'];
    if exist(tmp_file, 'file')
        delete(tmp_file);
        fprintf('  Rimosso file intermedio: %s\n', tmp_file);
    end
end
fprintf('File intermedi di applyController rimossi.\n');

% Salva figura 10 con findobj (robusto rispetto a ishandle/figure(10))
fh = findobj('Type','figure','Number',10);
if ~isempty(fh)
    fig_path = fullfile(fig_dir, 'case1_training_history.png');
    print(fh, fig_path, '-dpng', '-r150');
    fprintf('Figura salvata: %s\n', fig_path);
else
    fprintf('Figura 10 non trovata.\n');
end

fprintf('\n=== Training Caso 1 completato! ===\n');
fprintf('Rollout totali: %d (J=%d casuali + %d PILCO)\n', J+N, J, N);