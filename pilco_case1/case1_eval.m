%% case1_eval.m
% *Sommario:* Solo valutazione + grafici — Caso 1: Tamb fissa, setpoint fisso.
%
% Prerequisito: eseguire prima case1_learn_eval.m che produce
%   results/case1_policy_trained.mat
%
% Cosa fa questo script:
%   Fase 1 → Carica policy addestrata da results/
%   Fase 2 → Esegue un rollout con la policy caricata
%   Fase 3 → Genera i grafici e li salva in results/figures/
%
% NESSUN RETRAINING: la policy è usata esattamente come prodotta.

%% =========================================================================
%% FASE 1: Carica policy addestrata
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

res_dir = fullfile(script_dir, 'results');
fig_dir = fullfile(res_dir,    'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

load_path = fullfile(res_dir, 'case1_policy_trained.mat');

if ~exist(load_path, 'file')
    error('File non trovato: %s\nEsegui prima case1_learn_eval.m', load_path);
end

fprintf('=== Caricamento policy da: %s ===\n', load_path);
load(load_path);

% Ricarica i path della repository
repo_root = fullfile(script_dir, '..');
addpath(fullfile(repo_root, 'base'), fullfile(repo_root, 'util'), ...
        fullfile(repo_root, 'gp'),   fullfile(repo_root, 'control'), ...
        fullfile(repo_root, 'loss'));

% Aggiungi anche la cartella corrente (per draw_case1, dynamics, ecc.)
addpath(script_dir);

fprintf('Policy caricata. Training summary:\n');
fprintf('  dt = %d s | H = %d | J = %d rollout random | N = %d PILCO\n', dt, H, J, N);
fprintf('  Tset = %.0f°C | Tamb = 25°C (fissa)\n', cost.target(1));

% Ricostruisci mu0 / S0 se non presenti nel .mat (backward compatibility)
if ~exist('mu0', 'var')
    if exist('mu0Sim', 'var')
        mu0 = mu0Sim(:);
    else
        mu0 = [25; 25];
    end
    fprintf('  [INFO] mu0 ricostruito: %s\n', mat2str(mu0'));
end
if ~exist('S0', 'var')
    if exist('S0Sim', 'var')
        S0 = S0Sim;
    else
        S0 = 0.5 * eye(length(mu0));
    end
end


%% =========================================================================
%% FASE 2: Rollout con la policy caricata
%% =========================================================================

fprintf('\n=== FASE 2: Rollout di valutazione ===\n');

% Esegui un singolo rollout con la policy
[xx_eval, ~, rc_eval, lt_eval] = rollout(gaussian(mu0, S0), policy, H, plant, cost);

T1_eval = lt_eval(:, 1);
T2_eval = lt_eval(:, 2);
N_pts   = size(lt_eval, 1);
t_vec   = (0:N_pts-1)' * dt;
ref_eval = cost.target(1) * ones(N_pts, 1);

% Q1: output della policy → [0,100]%
Q1_eval = xx_eval(:, end) + 50;          % H × 1
Q1_eval = [Q1_eval(1); Q1_eval];         % allinea a (H+1)

% Q2: Caso 1 → nessun disturbo
Q2_eval = zeros(N_pts, 1);
Q2_min_c1 = 0;  Q2_max_c1 = 0;

% Costo per step
rc_vec    = rc_eval(:);
cost_eval = [rc_vec(1); rc_vec];          % allinea a (H+1)

% Errore di inseguimento
err_eval = T1_eval - ref_eval;

% Tamb e Tset
Tamb_c1 = 25;
Tset_c1 = cost.target(1);

T1_fin = T1_eval(end);
err_fin = T1_fin - Tset_c1;
fprintf('  T1_finale = %.1f°C | Errore = %+.1f°C | Costo = %.4f\n', ...
        T1_fin, err_fin, sum(rc_eval));


%% =========================================================================
%% FASE 3: Grafici e salvataggio
%% =========================================================================

fprintf('\n=== FASE 3: Generazione grafici ===\n');

% Chiudi figure precedenti per evitare conflitti
close all;

draw_case1(t_vec, T1_eval, T2_eval, ref_eval, Q1_eval, Q2_eval, ...
           cost_eval, err_eval, dt, Tamb_c1, Tset_c1, Q2_min_c1, Q2_max_c1);

% Salva la figura
drawnow;  % assicura rendering completo
fh = findobj('Type', 'figure', 'Name', 'Caso 1 — Tset fisso, Tamb fissa');
if ~isempty(fh) && isvalid(fh(1))
    % Forza sfondo bianco per export
    set(fh(1), 'Color', 'w', 'InvertHardcopy', 'off');
    % Figura combinata
    fig_path = fullfile(fig_dir, 'case1_combined.png');
    print(fh(1), fig_path, '-dpng', '-r150');
    fprintf('Figura combinata salvata: %s\n', fig_path);
    % Singoli subplot
    save_subplots(fh(1), fig_dir, 'case1');
else
    fprintf('Figura Case 1 non trovata o handle non valido.\n');
end

fprintf('\n=== Valutazione Case 1 completata! ===\n');
fprintf('Figure salvate in: %s\n', fig_dir);
