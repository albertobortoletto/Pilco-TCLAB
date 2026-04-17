function dz = dynamics_tclab_case3(t, z, u)
% dynamics_tclab_case3 — ODE per il Caso 3: inseguimento setpoint variabile.
%
% STATO: z = [e; T2; Tset; Q2]
%   e    = T1 - Tset   errore di inseguimento [°C]  ← variabile controllata
%   T2   = temperatura heater 2 [°C]                ← non controllata
%   Tset = setpoint corrente [°C]  dTset/dt = 0     ← costante nell'episodio
%   Q2   = potenza disturbo heater 2 [%]  dQ2/dt = 0 ← costante nell'episodio
%
% Perché usare e = T1 - Tset invece di T1?
%   → La funzione di costo diventa INVARIANTE al setpoint:
%     cost.target = [0; 0; 0; 0],  W = diag([1, 0, 0, 0])
%     indipendentemente da quale Tset stiamo inseguendo.
%   → Il GP impara Delta_e = f(e, T2, Tset, Q2, u) → dipendenza da Tset
%     catturata esplicitamente nello stato.
%   → La policy mappa (e, Tset) → Q1: sa "quanto siamo lontani" e
%     "quale setpoint" → può adattare la potenza alle perdite fisiche.
%
% Tamb = 25°C fisso (Caso 3 si concentra su Tset variabile).
%
% Input:
%   t → tempo corrente [s] (richiesto da ODE45)
%   z → [e; T2; Tset; Q2]
%   u → funzione handle zero-order-hold della policy
%
% Output:
%   dz → [de/dt; dT2/dt; 0; 0]

    % --- 1. Estrai stato ---
    e    = z(1);   % errore di inseguimento
    T2   = z(2);
    Tset = z(3);   % setpoint corrente
    Q2   = z(4);   % disturbo heater 2 [%]

    % Ricostruisci T1 dall'errore e dal setpoint
    T1 = e + Tset;

    % --- 2. Azione della policy ---
    action = u(t);
    Q1 = action(1) + 50;   % output policy ∈ [-50,+50] → potenza [0,100]%
    % Q2 viene dallo stato (disturbo costante nell'episodio)

    % --- 3. Parametri fisici ---
    Tamb   = 25.0;            % temperatura ambiente fissa [°C] (Caso 3)
    Ta     = Tamb + 273.15;
    U      = 10.0;
    m      = 4.0e-3;
    Cp     = 500.0;
    A      = 10.0e-4;
    As     = 2.0e-4;
    alpha1 = 0.0100;
    alpha2 = 0.0075;
    eps_r  = 0.9;
    sigma  = 5.67e-8;

    % --- 4. Conversione °C → K ---
    T1_K = T1 + 273.15;
    T2_K = T2 + 273.15;

    % --- 5. Scambio termico heater1 ↔ heater2 ---
    conv12 = sign(T2_K - T1_K) * U * As * abs(T2_K - T1_K);
    rad12  = eps_r * sigma * As * (T2_K^4 - T1_K^4);

    % --- 6. Bilancio energetico ---
    mCp = m * Cp;

    dT1dt = (1.0/mCp) * ( ...
        U*A*(Ta - T1_K) + ...
        eps_r*sigma*A*(Ta^4 - T1_K^4) + ...
        conv12 + rad12 + ...
        alpha1*Q1 );

    dT2dt = (1.0/mCp) * ( ...
        U*A*(Ta - T2_K) + ...
        eps_r*sigma*A*(Ta^4 - T2_K^4) + ...
        -conv12 - rad12 + ...
        alpha2*Q2 );   % ← Q2 viene dallo stato

    % --- 7. Output ---
    % de/dt = dT1/dt  (poiché dTset/dt = 0 nell'episodio)
    % dTset/dt = 0   (Tset costante per episodio, cambia TRA episodi)
    % dQ2/dt   = 0   (Q2 costante per episodio, cambia TRA episodi)
    dz = [dT1dt; dT2dt; 0.0; 0.0];
end