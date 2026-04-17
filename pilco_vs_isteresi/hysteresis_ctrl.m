function [T1_traj, T2_traj, u_traj, Q2_traj, cost_traj, err_traj] = ...
    hysteresis_ctrl(steps, dt, Tamb, Q2_min, Q2_max, ...
                    Q1_on, Q1_off, hyst_band, plant, cost)
% hysteresis_ctrl  Controllore a isteresi per TCLab (standalone).
%
% Simula un controllore on/off a isteresi su una sequenza di gradini,
% compatibile con il formato di case3_eval.m per confronto diretto con PILCO.
%
% Sintassi:
%   [T1_traj, T2_traj, u_traj, Q2_traj, cost_traj, err_traj] = ...
%       hysteresis_ctrl(steps, dt, Tamb, Q2_min, Q2_max, ...
%                       Q1_on, Q1_off, hyst_band, plant, cost)
%
% Input:
%   steps      [n×2] matrice [Tset_°C, durata_s] — sequenza gradini
%   dt         [s]   passo di campionamento
%   Tamb       [°C]  temperatura ambiente
%   Q2_min     [%]   limite inferiore disturbo Q2
%   Q2_max     [%]   limite superiore disturbo Q2
%   Q1_on      [%]   potenza heater quando T1 < Tset - hyst_band/2
%   Q1_off     [%]   potenza heater quando T1 > Tset + hyst_band/2
%   hyst_band  [°C]  ampiezza TOTALE della banda di isteresi
%   plant      struct PILCO (usa plant.noise, plant.dynamics)
%   cost       struct PILCO (per calcolare lossSat comparabile)
%
% Output:
%   T1_traj    [(H_eval+1)×1]  temperatura heater 1 [°C]
%   T2_traj    [(H_eval+1)×1]  temperatura heater 2 [°C]
%   u_traj     [H_eval×1]      azione Q1 in [0,100] [%]
%   Q2_traj    [H_eval×1]      disturbo Q2 [%]
%   cost_traj  [H_eval×1]      costo lossSat [0,1]
%   err_traj   [(H_eval+1)×1]  errore e(t)=T1-r(t) [°C]
%
% V6: L'azione u passata alla dynamics è convertita nel formato
%     [-maxU, +maxU] così che dentro dynamics_tclab_step la riga
%     Q1 = action(1) + 50 produca la percentuale corretta.

% =========================================================================
% Costruzione automatica dei vettori temporali e riferimento
% (Identica a case3_eval.m)
% =========================================================================
nSteps   = size(steps, 1);                    % [#] numero di gradini
Tset_seq = steps(:, 1);                       % [°C] sequenza setpoint
dur_seq  = steps(:, 2);                       % [s]  durata per gradino

H_total  = sum(ceil(dur_seq / dt));           % [step] step totali
H_eval   = H_total;                           % [step]
t_eval   = (0:H_eval)' * dt;                  % [s] vettore tempo (H_eval+1 punti)

% Costruisci il vettore riferimento r(t) [°C]
ref      = zeros(H_eval + 1, 1);             % [°C]
step_idx = 1;                                 % indice gradino corrente
cum_step = 0;                                 % step cumulativi

for ss = 1:nSteps
    H_ss = ceil(dur_seq(ss) / dt);            % [step] per questo gradino
    idx_start = cum_step + 1;
    idx_end   = cum_step + H_ss;
    if ss == nSteps
        idx_end = H_eval + 1;                 % ultimo gradino copre fino alla fine
    end
    idx_end = min(idx_end, H_eval + 1);
    ref(idx_start:idx_end) = Tset_seq(ss);    % [°C]
    cum_step = cum_step + H_ss;
end

% =========================================================================
% Inizializzazione
% =========================================================================
T1_traj   = zeros(H_eval + 1, 1);            % [°C]
T2_traj   = zeros(H_eval + 1, 1);            % [°C]
u_traj    = zeros(H_eval, 1);                % [%] Q1 in [0,100]
Q2_traj   = zeros(H_eval, 1);                % [%]
cost_traj = zeros(H_eval, 1);                % [0,1]
err_traj  = zeros(H_eval + 1, 1);            % [°C]

% Condizioni iniziali
T1_traj(1) = Tamb;                            % [°C] sistema freddo
T2_traj(1) = Tamb;                            % [°C]
err_traj(1) = T1_traj(1) - ref(1);           % [°C]

% Stato interno isteresi: inizia spento
Q1_state = Q1_off;                            % [%]

% Rumore di misura dalla struct plant
noise_cov = plant.noise;                      % [°C²] matrice di covarianza

% Identifica maxU per la conversione azione → dynamics
% Di default assumiamo maxU = 50 (policy.maxU standard)
maxU = 50;                                    % [%] default

% Determina gli step per ogni gradino (per rigenerare Q2)
step_boundaries = zeros(nSteps + 1, 1);       % [step]
cum = 0;
for ss = 1:nSteps
    step_boundaries(ss) = cum;
    cum = cum + ceil(dur_seq(ss) / dt);
end
step_boundaries(nSteps + 1) = H_eval;

% Q2 rigenerato per ogni gradino (come in case3_eval.m)
Q2_per_step = Q2_min + (Q2_max - Q2_min) * rand(nSteps, 1);  % [%]

% =========================================================================
% Loop di simulazione
% =========================================================================
for k = 1:H_eval
    % Determina il gradino corrente
    current_step = nSteps;
    for ss = 1:nSteps
        if k - 1 < step_boundaries(ss + 1)
            current_step = ss;
            break;
        end
    end

    Tset_now = Tset_seq(current_step);        % [°C]
    Q2_now   = Q2_per_step(current_step);     % [%]
    Q2_traj(k) = Q2_now;

    % --- Logica isteresi ---
    T1_meas = T1_traj(k);                    % [°C]

    if T1_meas < Tset_now - hyst_band / 2
        Q1_state = Q1_on;                    % [%] accendi
    elseif T1_meas > Tset_now + hyst_band / 2
        Q1_state = Q1_off;                   % [%] spegni
    end
    % altrimenti mantieni lo stato precedente (isteresi)

    u_traj(k) = Q1_state;                    % [%] Q1 in [0,100]

    % --- Simulazione ODE (stessa struttura di case3_eval.m) ---
    % Lo stato per dynamics_tclab_case3 è [e; T2; Tset; Q2]
    e_now = T1_meas - Tset_now;              % [°C]
    z0 = [e_now; T2_traj(k); Tset_now; Q2_now];

    % V6: Converti Q1_state in formato [-maxU, +maxU] per la dynamics
    % Dentro dynamics_tclab_case3: Q1 = action(1) + 50
    % Quindi action = Q1_state - 50
    u_action = Q1_state - maxU;              % azione policy simulata
    u_fun = @(t_ode) u_action;               % function handle ZOH

    % Integrazione ODE
    [~, z_out] = ode45(@(t_ode, z) plant.dynamics(t_ode, z, u_fun), ...
                       [0, dt], z0);

    % Stato finale
    e_next  = z_out(end, 1);                  % [°C] errore
    T2_next = z_out(end, 2);                  % [°C]
    T1_next = e_next + Tset_now;              % [°C] ricostruisci T1

    % Aggiungi rumore di misura (come in case3_eval.m)
    if size(noise_cov, 1) >= 2
        noise_std = sqrt(diag(noise_cov));
        T1_next = T1_next + noise_std(1) * randn();   % [°C]
        T2_next = T2_next + noise_std(2) * randn();   % [°C]
    end

    % Aggiorna traiettorie
    T1_traj(k + 1)  = T1_next;               % [°C]
    T2_traj(k + 1)  = T2_next;               % [°C]
    err_traj(k + 1) = T1_next - ref(k + 1);  % [°C]

    % --- Costo lossSat (identico a case3_eval.m) ---
    % Stato per il costo: [e; T2; Tset; Q2] (4D come case3)
    x_cost = [T1_next - ref(k + 1); T2_next; Tset_now; Q2_now];
    S_cost = zeros(length(x_cost));           % nessuna incertezza
    cost_traj(k) = cost.fcn(cost, x_cost, S_cost);  % [0,1]
end

end
