%% case3_eval.m
% *Sommario:* Valutazione e plot — Caso 3: Scalinata MAI VISTA.
%
% Prerequisito: eseguire prima case3_learn.m
%
% Fase 1  → Carica policy da results/policy/
% Fase 2a → Verifica su ogni Tset di training (singolo episodio)
% Fase 2b → Scalinata Tset_stair_eval mai vista, con raccolta Q1
% Fase 3  → Figure 13 e 14, salva in results/figures/

%% =========================================================================
%% FASE 1: Carica policy
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

policy_dir = fullfile(script_dir, 'results', 'policy');
fig_dir    = fullfile(script_dir, 'results', 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

load_path = fullfile(policy_dir, 'case3_policy_trained.mat');
if ~exist(load_path, 'file')
    error('File non trovato: %s\nEsegui prima case3_learn.m', load_path);
end

fprintf('=== Caricamento policy: %s ===\n', load_path);
load(load_path);

% Aggiorna i path con quelli locali (utile se si sposta la cartella)
policy_dir = fullfile(script_dir, 'results', 'policy');
fig_dir    = fullfile(script_dir, 'results', 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

try
    rd = '../../';
    addpath([rd 'base'],[rd 'util'],[rd 'gp'],[rd 'control'],[rd 'loss']);
catch
end

fprintf('Policy caricata.\n');
fprintf('  Tset_train    : %s °C\n', mat2str(Tset_train));
fprintf('  Scalinata eval: %s °C\n', mat2str(Tset_stair_eval));
fprintf('  Rollout totali: %d\n', length(latent));


%% =========================================================================
%% FASE 2a: Verifica su singoli Tset di training
%% =========================================================================
% Controlla che la policy raggiunga ogni setpoint di training.
% Usa Q2_eval (non Q2 di training) per testare anche robustezza al disturbo.

fprintf('\n=== FASE 2a: Verifica su Tset training ===\n');
fprintf('%s\n', repmat('-',1,65));
 
latent_single   = cell(1, nT_train);
realCost_single = cell(1, nT_train);

for tt = 1:nT_train
    Tset_tt = Tset_train(tt);
    e_init  = T1_init - Tset_tt;

    mu0_tt = [e_init; T2_init; Tset_tt; Q2_eval];
    S0_tt  = diag([0.1, 0.1, 0.001, 0.001]);

    [~, ~, rc, lt] = rollout(gaussian(mu0_tt, S0_tt), policy, H, plant, cost);

    latent_single{tt}   = lt;
    realCost_single{tt} = rc;

    e_fin  = lt(end,1);
    T1_fin = e_fin + lt(end,3);
    in_r   = ''; if Tset_tt < T1_init, in_r = ' [e>0: test cooling]'; end
    fprintf('  Tset=%2.0f°C%s | e_0=%+.1f°C | e_fin=%+.2f°C | T1_fin=%.1f°C | Costo=%.4f\n', ...
            Tset_tt, in_r, e_init, e_fin, T1_fin, sum(rc));
end
fprintf('%s\n', repmat('-',1,65));


%% =========================================================================
%% FASE 2b: Valutazione scalinata mai vista (con raccolta Q1)
%% =========================================================================
% Scalinata: H_step_eval passi per gradino, stato fisico propagato tra gradini.
%
% Come funziona il passaggio di stato:
%   Fine gradino s: T1_fin = e_fin + Tset_s,  T2_fin = T2 dal latent
%   Inizio gradino s+1: e_new = T1_fin - Tset_{s+1}  ← errore ri-calcolato
%
% Q1 viene estratto da rollout: xx(:,end) = output policy ∈ [-50,+50]
%   Q1_fisico [%] = xx(:,end) + 50  ∈ [0,100]

fprintf('\n=== FASE 2b: Scalinata mai vista ===\n');
fprintf('Scalinata: %s °C  |  Q2=%.1f%%  |  %d step/gradino (%ds)\n', ...
        mat2str(Tset_stair_eval), Q2_eval, H_step_eval, H_step_eval*dt);
fprintf('%s\n', repmat('-',1,65));

nSteps       = length(Tset_stair_eval);
stair_latent   = cell(1, nSteps);
stair_realCost = cell(1, nSteps);
stair_actions  = cell(1, nSteps);   % Q1 [%] per ogni gradino

T1_cur = T1_init;
T2_cur = T2_init;

for s = 1:nSteps
    Tset_s = Tset_stair_eval(s);
    e_s    = T1_cur - Tset_s;

    mu0_s = [e_s; T2_cur; Tset_s; Q2_eval];
    S0_s  = diag([0.05, 0.05, 0.001, 0.001]);

    % rollout restituisce xx = [H × (nState + nAction)]
    % ultima colonna = output policy ∈ [-50,+50]
    [xx, ~, rc, lt] = rollout(gaussian(mu0_s, S0_s), policy, H_step_eval, plant, cost);

    stair_latent{s}   = lt;
    stair_realCost{s} = rc;
    stair_actions{s}  = xx(:, end) + 50;   % converti in potenza [0,100]%

    e_fin  = lt(end,1);
    T2_fin = lt(end,2);
    T1_fin = e_fin + Tset_s;

    in_range = (Tset_s >= min(Tset_train)) && (Tset_s <= max(Tset_train));
    tag = ''; if ~in_range, tag = ' [extrap]'; end

    fprintf('  Gradino %d: Tset=%2.0f°C%s | e_0=%+.1f → e_fin=%+.2f°C | T1_fin=%.1f°C | Q1_medio=%.1f%% | Costo=%.4f\n', ...
            s, Tset_s, tag, e_s, e_fin, T1_fin, mean(stair_actions{s}), sum(rc));

    T1_cur = T1_fin;
    T2_cur = T2_fin;
end
fprintf('%s\n', repmat('-',1,65));

e_finals = cellfun(@(lt) lt(end,1), stair_latent);
fprintf('  Errore finale medio  |e|: %.2f°C\n', mean(abs(e_finals)));
fprintf('  Errore finale massimo|e|: %.2f°C\n', max(abs(e_finals)));


%% =========================================================================
%% FASE 3: Grafici e salvataggio
%% =========================================================================

fprintf('\n=== FASE 3: Grafici ===\n');

draw_case3_results(latent, realCost, ...
                   latent_single, realCost_single, ...
                   stair_latent, stair_realCost, stair_actions, ...
                   plant, cost, J, N, ...
                   Tset_train, Tset_stair_eval, H_step_eval, Q2_eval);

% Salva figure con findobj (robusto, non dipende dall'handle numerico grezzo)
fig_save = {13, 'case3_training'; 14, 'case3_staircase_eval'};

for fi = 1:size(fig_save,1)
    fnum  = fig_save{fi,1};
    fname = fig_save{fi,2};
    fh    = findobj('Type','figure','Number', fnum);   % ← cerca per numero, non ishandle
    if ~isempty(fh)
        out_png = fullfile(fig_dir, [fname '.png']);
        print(fh, out_png, '-dpng', '-r150');
        fprintf('  Figura %d salvata: %s\n', fnum, out_png);
    else
        fprintf('  Figura %d non trovata (non generata).\n', fnum);
    end
end

fprintf('\n=== Valutazione Case 3 completata! ===\n');
fprintf('Figure salvate in: %s\n', fig_dir);


