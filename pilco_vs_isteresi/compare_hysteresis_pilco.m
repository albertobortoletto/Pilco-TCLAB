%% compare_hysteresis_pilco.m
% *Sommario:* Confronto PILCO vs controllore a isteresi — Caso 3 (scalinata Tset).
%
% Questo script:
%   0. Carica la policy addestrata da results/policy/case3_policy_trained.mat
%   1. Definisce la sequenza di gradini (identica a case3_eval.m)
%   2. Costruisce ref, t_eval, H_eval, step_times
%   3. Esegue la simulazione PILCO step-by-step (rng(42) per Q2)
%   4. Esegue la simulazione isteresi con hysteresis_ctrl.m (rng(42) per Q2)
%   5. Crea la figura di confronto a 4 subplot
%   6. Stampa la tabella di confronto nel terminale
%   7. Salva figura e dati in results/
%
% Prerequisito: eseguire prima case3_learn.m

%% =========================================================================
%% 0. Caricamento policy addestrata
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

% Il .mat si trova nella cartella case3
case3_dir  = fullfile(script_dir, '..', 'pilco_case3');
policy_dir = fullfile(case3_dir, 'results', 'policy');
load_path  = fullfile(policy_dir, 'case3_policy_trained.mat');

if ~exist(load_path, 'file')
    error('File non trovato: %s\nEsegui prima case3_learn.m', load_path);
end

fprintf('=== Caricamento policy: %s ===\n', load_path);
load(load_path);

% Aggiungi i path della repository PILCO
try
    rd = fullfile(script_dir, '..', '..', '');
    addpath(fullfile(rd, 'base'), fullfile(rd, 'util'), ...
            fullfile(rd, 'gp'),   fullfile(rd, 'control'), ...
            fullfile(rd, 'loss'));
catch
end

% Aggiungi il path di case3 (per dynamics_tclab_case3)
addpath(case3_dir);
% Aggiungi il path corrente (per hysteresis_ctrl)
addpath(script_dir);

% Cartelle output
res_dir = fullfile(script_dir, '..', 'pilco_vs_isteresi', 'results');
fig_dir = fullfile(res_dir, 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

fprintf('Policy caricata.\n');
fprintf('  maxU = %.0f\n', policy.maxU);

%% =========================================================================
%% 1. Definizione sequenza di gradini
%% =========================================================================
% Formato: [Tset_°C, durata_s]   — identica a case3_eval.m
% L'utente può cambiarla qui esattamente come in case3_eval.m.

steps = [25, 400;    % [°C, s]  gradino 1
         45, 400;    % [°C, s]  gradino 2
         35, 400;    % [°C, s]  gradino 3
         55, 400];   % [°C, s]  gradino 4

Tamb     = 25.0;     % [°C] temperatura ambiente
Q2_min   = 5;        % [%]  limite inferiore Q2
Q2_max   = 8;        % [%]  limite superiore Q2
maxU     = policy.maxU(1);  % [%] dal .mat caricato

%% =========================================================================
%% 2. Costruzione automatica ref, t_eval, H_eval, step_times
%% =========================================================================
% (Stesso codice di case3_eval.m)

nSteps   = size(steps, 1);                     % [#]
Tset_seq = steps(:, 1);                        % [°C]
dur_seq  = steps(:, 2);                        % [s]

H_per_step = ceil(dur_seq / dt);               % [step] per gradino
H_eval     = sum(H_per_step);                  % [step] totali
t_eval     = (0:H_eval)' * dt;                 % [s] (H_eval+1 punti)

% Riferimento r(t) [°C]
ref = zeros(H_eval + 1, 1);                    % [°C]
step_times = zeros(nSteps, 1);                  % [s] inizio ogni gradino
cum = 0;
for ss = 1:nSteps
    step_times(ss) = cum * dt;                  % [s]
    idx_start = cum + 1;
    idx_end   = cum + H_per_step(ss);
    if ss == nSteps
        idx_end = H_eval + 1;
    end
    idx_end = min(idx_end, H_eval + 1);
    ref(idx_start:idx_end) = Tset_seq(ss);      % [°C]
    cum = cum + H_per_step(ss);
end

fprintf('\n=== Sequenza gradini ===\n');
for ss = 1:nSteps
    fprintf('  Gradino %d: Tset = %2.0f°C, durata = %ds (%d step)\n', ...
            ss, Tset_seq(ss), dur_seq(ss), H_per_step(ss));
end
fprintf('  Totale: %d step (%ds)\n', H_eval, H_eval * dt);

%% =========================================================================
%% 3. Simulazione PILCO step-by-step (rng(42) per Q2 — V4)
%% =========================================================================

fprintf('\n=== Simulazione PILCO ===\n');

rng(42, 'twister');  % V4: seed fisso per Q2

% Pre-generazione Q2 per ogni gradino (stessa logica di case3_eval.m)
Q2_per_step_pilco = Q2_min + (Q2_max - Q2_min) * rand(nSteps, 1);  % [%]

% Output PILCO
T1_pilco   = zeros(H_eval + 1, 1);    % [°C]
T2_pilco   = zeros(H_eval + 1, 1);    % [°C]
u_pilco    = zeros(H_eval, 1);        % azione policy raw ∈ [-maxU, +maxU]
Q2_pilco   = zeros(H_eval, 1);        % [%]
cost_pilco = zeros(H_eval, 1);        % [0,1]
err_pilco  = zeros(H_eval + 1, 1);    % [°C]

T1_pilco(1) = Tamb;                   % [°C] sistema freddo
T2_pilco(1) = Tamb;                   % [°C]
err_pilco(1) = T1_pilco(1) - ref(1);  % [°C]

noise_std = sqrt(diag(plant.noise));   % [°C]

cum_step = 0;
for ss = 1:nSteps
    Tset_s = Tset_seq(ss);            % [°C]
    Q2_s   = Q2_per_step_pilco(ss);   % [%]
    H_s    = H_per_step(ss);          % [step]

    for kk = 1:H_s
        k_global = cum_step + kk;     % indice globale
        if k_global > H_eval, break; end

        % Stato PILCO: [e, T2, Tset, Q2]
        e_now  = T1_pilco(k_global) - Tset_s;
        x_now  = [e_now; T2_pilco(k_global); Tset_s; Q2_s];

        % --- Calcola azione policy ---
        % La policy mappa [e, Tset] → u ∈ [-maxU, +maxU]
        m_now = x_now(plant.poli);     % [e; Tset]
        s_now = 0.01 * eye(length(m_now));
        [u_act, ~, ~] = policy.fcn(policy, m_now, s_now);
        u_act = max(-maxU, min(maxU, u_act));  % clip

        u_pilco(k_global) = u_act;     % azione raw
        Q2_pilco(k_global) = Q2_s;     % [%]

        % --- Integrazione ODE ---
        z0 = [e_now; T2_pilco(k_global); Tset_s; Q2_s];
        u_fun = @(t_ode) u_act;

        [~, z_out] = ode45(@(t_ode, z) plant.dynamics(t_ode, z, u_fun), ...
                           [0, dt], z0);

        e_next  = z_out(end, 1);       % [°C]
        T2_next = z_out(end, 2);       % [°C]
        T1_next = e_next + Tset_s;     % [°C]

        % Rumore di misura
        T1_next = T1_next + noise_std(1) * randn();  % [°C]
        T2_next = T2_next + noise_std(2) * randn();  % [°C]

        T1_pilco(k_global + 1) = T1_next;
        T2_pilco(k_global + 1) = T2_next;
        err_pilco(k_global + 1) = T1_next - ref(k_global + 1);

        % Costo lossSat
        x_cost = [T1_next - ref(k_global + 1); T2_next; Tset_s; Q2_s];
        S_cost = zeros(length(x_cost));
        cost_pilco(k_global) = cost.fcn(cost, x_cost, S_cost);
    end

    cum_step = cum_step + H_s;
    fprintf('  Gradino %d: Tset=%2.0f°C | T1_fin=%.1f°C | Q2=%.1f%%\n', ...
            ss, Tset_s, T1_pilco(min(cum_step + 1, H_eval + 1)), Q2_s);
end

% Converti Q1 PILCO in percentuale [%]
Q1_perc_pilco = u_pilco + maxU;                % [%]

%% =========================================================================
%% 4. Simulazione isteresi (rng(42) per Q2 — V4)
%% =========================================================================

fprintf('\n=== Simulazione Isteresi ===\n');

% Parametri isteresi
Q1_on      = 80;    % [%] potenza accensione
Q1_off     = 0;     % [%] potenza spegnimento
hyst_band  = 4;     % [°C] ampiezza totale banda (±2°C)

rng(42);  % V4: stesso seed per Q2 → confronto equo

[T1_hyst, T2_hyst, u_hyst, Q2_hyst, cost_hyst, err_hyst] = ...
    hysteresis_ctrl(steps, dt, Tamb, Q2_min, Q2_max, ...
                    Q1_on, Q1_off, hyst_band, plant, cost);

fprintf('  Q1_on = %d%%, Q1_off = %d%%, banda = ±%.0f°C\n', ...
        Q1_on, Q1_off, hyst_band / 2);

% Q1 isteresi è già in [0,100] [%]
Q1_perc_hyst = u_hyst;                         % [%]

%% =========================================================================
%% 5. Figura di confronto a 4 subplot
%% =========================================================================

fprintf('\n=== Generazione figura di confronto ===\n');

% R7: Colori definiti come variabili locali
c_pilco = [0.00, 0.45, 0.74];   % blu
c_hyst  = [0.85, 0.33, 0.10];   % arancione
c_ref   = [0.85, 0.13, 0.13];   % rosso
c_band  = [0.80, 0.80, 0.80];   % grigio chiaro
c_xline = [0.50, 0.50, 0.50];   % grigio

t_min = t_eval / 60;                           % [min]

% R8: NumberTitle off, Name descrittivo
fig = figure('NumberTitle', 'off', 'Name', 'Confronto PILCO vs Isteresi — Caso 3', ...
             'Color', 'w');
clf(fig);
% R10: Position
set(fig, 'Position', [80, 50, 1100, 850]);
set(fig, 'InvertHardcopy', 'off');  % non invertire: i colori sono già espliciti

% ---- SP1: Temperatura T1 [°C] ----
ax1 = subplot(4, 1, 1); hold on;

% Banda ±2°C attorno al riferimento
ref_vec = ref(:);
t_patch = [t_min; flipud(t_min)];
band_patch = [ref_vec - 2; flipud(ref_vec + 2)];
patch(ax1, t_patch, band_patch, c_band, ...
      'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
      'DisplayName', '±2°C');

% Riferimento
plot(ax1, t_min, ref_vec, '-', 'Color', c_ref, 'LineWidth', 1.2, ...
     'DisplayName', 'Riferimento');

% T1 PILCO
plot(ax1, t_min, T1_pilco, '-', 'Color', c_pilco, 'LineWidth', 2.5, ...
     'DisplayName', 'PILCO');

% T1 Isteresi
plot(ax1, t_min, T1_hyst, '--', 'Color', c_hyst, 'LineWidth', 2.0, ...
     'DisplayName', 'Isteresi');

% R4: xline ai cambi di setpoint
for ss = 2:nSteps
    xline(ax1, step_times(ss) / 60, ':', 'Color', c_xline, ...
          'LineWidth', 1.3, 'HandleVisibility', 'off');
end

ylabel(ax1, 'T1 [°C]');
legend(ax1, 'Location', 'best', 'FontSize', 8);
grid(ax1, 'on');
title(ax1, 'Temperatura T1 nel tempo');
xlabel(ax1, 'Tempo [min]');

% ---- SP2: Q1 controllo [%] ----
ax2 = subplot(4, 1, 2); hold on;

% Q1 PILCO
stairs(ax2, t_min(1:H_eval), Q1_perc_pilco, '-', 'Color', c_pilco, ...
       'LineWidth', 2.0, 'DisplayName', 'PILCO');

% Q1 Isteresi
stairs(ax2, t_min(1:H_eval), Q1_perc_hyst, '--', 'Color', c_hyst, ...
       'LineWidth', 1.8, 'DisplayName', 'Isteresi');

% yline 0% e 100%
yline(ax2, 0,   ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');
yline(ax2, 100, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');

% xline ai cambi di setpoint
for ss = 2:nSteps
    xline(ax2, step_times(ss) / 60, ':', 'Color', c_xline, ...
          'LineWidth', 1.3, 'HandleVisibility', 'off');
end

ylabel(ax2, 'Q1 [%]');
ylim(ax2, [-5, 110]);
legend(ax2, 'Location', 'best', 'FontSize', 8);
grid(ax2, 'on');
title(ax2, 'Azione di controllo Q1');
xlabel(ax2, 'Tempo [min]');

% ---- SP3: Errore di tracking e(t) [°C] ----
ax3 = subplot(4, 1, 3); hold on;

% e PILCO
plot(ax3, t_min, err_pilco, '-', 'Color', c_pilco, 'LineWidth', 2.0, ...
     'DisplayName', 'PILCO');

% e Isteresi
plot(ax3, t_min, err_hyst, '--', 'Color', c_hyst, 'LineWidth', 1.8, ...
     'DisplayName', 'Isteresi');

% yline 0, ±2°C
yline(ax3, 0,  '-k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
yline(ax3, 2,  '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.0, ...
      'DisplayName', '±2°C');
yline(ax3, -2, '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.0, ...
      'HandleVisibility', 'off');

% xline ai cambi di setpoint
for ss = 2:nSteps
    xline(ax3, step_times(ss) / 60, ':', 'Color', c_xline, ...
          'LineWidth', 1.3, 'HandleVisibility', 'off');
end

ylabel(ax3, 'Errore [°C]');
legend(ax3, 'Location', 'best', 'FontSize', 8);
grid(ax3, 'on');
title(ax3, 'Errore di tracking e(t) = T1 − r(t)');
xlabel(ax3, 'Tempo [min]');

% ---- SP4: Costo lossSat cumulativo normalizzato [0,1] ----
ax4 = subplot(4, 1, 4); hold on;

% Costo PILCO con movmean
plot(ax4, t_min(1:H_eval), cost_pilco, '-', ...
     'Color', [c_pilco, 0.3], 'LineWidth', 0.8, ...
     'HandleVisibility', 'off');
if H_eval >= 10
    plot(ax4, t_min(1:H_eval), movmean(cost_pilco, 10), '-', ...
         'Color', c_pilco, 'LineWidth', 2.2, ...
         'DisplayName', 'PILCO movmean(10)');
end

% Costo Isteresi con movmean
plot(ax4, t_min(1:H_eval), cost_hyst, '--', ...
     'Color', [c_hyst, 0.3], 'LineWidth', 0.8, ...
     'HandleVisibility', 'off');
if H_eval >= 10
    plot(ax4, t_min(1:H_eval), movmean(cost_hyst, 10), '--', ...
         'Color', c_hyst, 'LineWidth', 2.2, ...
         'DisplayName', 'Isteresi movmean(10)');
end

% xline ai cambi di setpoint
for ss = 2:nSteps
    xline(ax4, step_times(ss) / 60, ':', 'Color', c_xline, ...
          'LineWidth', 1.3, 'HandleVisibility', 'off');
end

xlabel(ax4, 'Tempo [min]');
ylabel(ax4, 'Costo lossSat [0,1]');
ylim(ax4, [0, 1.05]);
legend(ax4, 'Location', 'best', 'FontSize', 8);
grid(ax4, 'on');
title(ax4, 'Costo lossSat (movmean 10)');

% R1: linkaxes
linkaxes([ax1, ax2, ax3, ax4], 'x');

% R2: xlabel solo sull'ultimo
set(ax1, 'XTickLabel', []);
set(ax2, 'XTickLabel', []);
set(ax3, 'XTickLabel', []);

% R3: sgtitle
Tset_str = strjoin(arrayfun(@(x) sprintf('%.0f', x), Tset_seq, ...
           'UniformOutput', false), '→');
sgtitle(sprintf('Confronto PILCO vs Isteresi — T_{set} = [%s]°C | T_{amb} = %.0f°C | dt = %ds', ...
        Tset_str, Tamb, dt), ...
        'FontWeight', 'bold', 'FontSize', 13);

% =========================================================================
% Stile leggibile: sfondo bianco, contorno nero, titoli marcati
% =========================================================================
for aa = [ax1, ax2, ax3, ax4]
    set(aa, 'Color', 'w');                          % sfondo bianco
    set(aa, 'XColor', 'k');                          % asse X nero
    set(aa, 'YColor', 'k');                          % asse Y nero
    set(aa, 'GridColor', [0.15 0.15 0.15]);
    set(aa, 'GridAlpha', 0.3);
    set(get(aa, 'Title'), 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12);
    set(get(aa, 'XLabel'), 'Color', 'k', 'FontSize', 10);
    set(get(aa, 'YLabel'), 'Color', 'k', 'FontSize', 10);
end

% Legende con sfondo bianco e testo nero
for aa = [ax1, ax2, ax3, ax4]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% R9: drawnow
drawnow;

%% =========================================================================
%% 6. Tabella di confronto nel terminale
%% =========================================================================

% Metriche PILCO
e_pilco_vec  = err_pilco(2:end);               % [°C] salta IC
costo_medio_P = mean(cost_pilco);              % [0,1]
costo_tot_P   = sum(cost_pilco);               % [0,H_eval]
rmse_P        = sqrt(mean(e_pilco_vec.^2));    % [°C]
max_err_P     = max(abs(e_pilco_vec));         % [°C]
pct_in_band_P = 100 * sum(abs(e_pilco_vec) < 2) / length(e_pilco_vec);  % [%]

% Metriche Isteresi
e_hyst_vec   = err_hyst(2:end);                 % [°C]
costo_medio_H = mean(cost_hyst);               % [0,1]
costo_tot_H   = sum(cost_hyst);                % [0,H_eval]
rmse_H        = sqrt(mean(e_hyst_vec.^2));     % [°C]
max_err_H     = max(abs(e_hyst_vec));          % [°C]
pct_in_band_H = 100 * sum(abs(e_hyst_vec) < 2) / length(e_hyst_vec);  % [%]

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║         Confronto PILCO vs Isteresi — Caso 3             ║\n');
fprintf('╠═════════════════╦═══════════════╦════════════════════════╣\n');
fprintf('║ Metrica         ║     PILCO     ║      Isteresi          ║\n');
fprintf('╠═════════════════╬═══════════════╬════════════════════════╣\n');
fprintf('║ Costo medio     ║    %.4f     ║       %.4f           ║\n', costo_medio_P, costo_medio_H);
fprintf('║ Costo totale    ║    %.4f    ║       %.4f          ║\n', costo_tot_P, costo_tot_H);
fprintf('║ RMSE tracking   ║    %.2f °C    ║       %.2f °C          ║\n', rmse_P, rmse_H);
fprintf('║ Max |errore|    ║    %.2f °C   ║       %.2f °C         ║\n', max_err_P, max_err_H);
fprintf('║ %% entro ±2°C    ║    %.1f %%     ║       %.1f %%           ║\n', pct_in_band_P, pct_in_band_H);
fprintf('╚═════════════════╩═══════════════╩════════════════════════╝\n');
fprintf('\n');

%% =========================================================================
%% 7. Salvataggio figura e dati
%% =========================================================================

% Singoli subplot — VA CHIAMATO PRIMA DI print()
% (print() modifica lo stato interno della figura e invalida exportgraphics)
save_subplots(fig, fig_dir, 'comparison');

% Salva figura combinata (DOPO save_subplots)
drawnow;
fig_path = fullfile(fig_dir, 'comparison_combined.png');
print(fig, fig_path, '-dpng', '-r150');
fprintf('Figura combinata salvata: %s\n', fig_path);

% Salva dati
data_path = fullfile(res_dir, 'case3_comparison.mat');
save(data_path, ...
     'steps', 'Tset_seq', 'dur_seq', 'dt', 'Tamb', ...
     'Q2_min', 'Q2_max', 'maxU', ...
     'T1_pilco', 'T2_pilco', 'u_pilco', 'Q1_perc_pilco', ...
     'Q2_pilco', 'cost_pilco', 'err_pilco', ...
     'T1_hyst', 'T2_hyst', 'u_hyst', 'Q1_perc_hyst', ...
     'Q2_hyst', 'cost_hyst', 'err_hyst', ...
     'ref', 't_eval', 'step_times', 'H_eval', ...
     'Q1_on', 'Q1_off', 'hyst_band', ...
     'costo_medio_P', 'costo_tot_P', 'rmse_P', 'max_err_P', 'pct_in_band_P', ...
     'costo_medio_H', 'costo_tot_H', 'rmse_H', 'max_err_H', 'pct_in_band_H');
fprintf('Dati salvati: %s\n', data_path);

fprintf('\n=== Confronto PILCO vs Isteresi completato! ===\n');