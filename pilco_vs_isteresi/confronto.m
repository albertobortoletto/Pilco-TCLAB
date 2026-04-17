%% Script di confronto PILCO vs Isteresi
load('pilco_case2/results/policy/case2_policy_trained.mat'); % Carica PILCO

% Parametri di test
Tamb_test = 20; 
T_target  = 50;
h_band    = 1.5; % Semi-ampiezza banda isteresi
H_steps   = H;   % Stesso orizzonte di PILCO

% --- 1. Rollout con PILCO ---
mu0_test = [Tamb_test; Tamb_test; Tamb_test];
S0_test  = diag([0.1, 0.1, 0.001]);
[~, ~, ~, lt_pilco] = rollout(gaussian(mu0_test, S0_test), policy, H_steps, plant, cost);

% --- 2. Rollout con ISTERESI ---
T_hist = zeros(H_steps+1, 1);
T_hist(1) = Tamb_test;
clear isteresi_errore; % Resetta la variabile persistent u_old

for t = 1:H_steps
    % Calcola azione
    Q1 = controller_hysteresis(T_target, T_hist(t), h_band);
    
    % Simula un passo con l'ODE del plant
    % Usiamo l'integrità del plant definito nei settings
    z_in = [T_hist(t); Tamb_test; Tamb_test]; % Semplificato
    u_fun = @(t_ode) Q1 - 50; % PILCO usa u in [-50, 50]
    
    [~, z_out] = ode45(@(t,z) dynamics_tclab_param(t, z, u_fun), [0 dt], z_in);
    T_hist(t+1) = z_out(end, 1);
end

% --- 3. Plot di confronto ---
figure; hold on;
time = (0:H_steps) * dt / 60;
plot(time, lt_pilco(:,1), 'b-', 'LineWidth', 2, 'DisplayName', 'PILCO (RBF)');
plot(time, T_hist, 'r--', 'LineWidth', 2, 'DisplayName', 'Isteresi (Bang-Bang)');
yline(T_target, 'k:', 'Target 50°C');
xlabel('Tempo [min]'); ylabel('Temperatura [°C]');
legend; title('Confronto: Intelligenza Artificiale vs Logica a Isteresi');
grid on;