function dz = dynamics_tclab_case2(t, z, u)
% dynamics_tclab - ODE che descrive la fisica del TCLab
%
% CASO 1 (stato 2D): z = [T1; T2]         → dz ha dimensione 2
% CASO 2 (stato 3D): z = [T1; T2; Tamb]   → dz ha dimensione 3, dTamb/dt = 0
%
% La compatibilità backward è garantita: se z ha 2 elementi, Tamb = 25°C fisso.
% Se z ha 3 elementi, Tamb = z(3) → il modello GP vede Tamb come variabile di stato.
%
% Input:
%   t  → tempo corrente [s] (richiesto da ODE45, non usato esplicitamente)
%   z  → stato: [T1; T2] oppure [T1; T2; Tamb]  [°C]
%   u  → funzione handle zero-order-hold (action = u(t))
%
% Output:
%   dz → derivata stato: [dT1/dt; dT2/dt] oppure [dT1/dt; dT2/dt; 0]

    % --- 1. Estrai stato ---
    T1   = z(1);
    T2   = z(2);

    % Tamb: costante nell'episodio. dTamb/dt = 0 sempre.
    % Se Tamb è nel vettore di stato (Caso 2), viene letta da z(3).
    % Altrimenti rimane al valore fisso di default del Caso 1.
    if numel(z) >= 3
        Tamb = z(3);   % Caso 2: temperatura ambiente come stato (variabile tra episodi)
    else
        Tamb = 25.0;   % Caso 1: Tamb fissa a 25°C (valore hardcoded originale)
    end

    % --- 2. Azione della policy ---
    % u è una funzione handle zero-order-hold: restituisce l'azione
    % costante decisa dalla policy per l'intervallo corrente.
    action = u(t);
    Q1 = action(1) + 50;   % policy output ∈ [-50,+50] → potenza [0,100]%
    Q2 = 0;                % heater 2 non controllato

    % --- 3. Parametri fisici del TCLab ---
    Ta     = Tamb + 273.15;   % temperatura ambiente [K] ← ORA dipende da z(3)
    U      = 10.0;            % coefficiente convettivo [W/m²K]
    m      = 4.0e-3;          % massa heater [kg]
    Cp     = 500.0;           % calore specifico [J/kg·K]
    A      = 10.0e-4;         % area heater-ambiente [m²]
    As     = 2.0e-4;          % area heater1-heater2 [m²]
    alpha1 = 0.0100;          % efficienza heater 1 [W/%]
    alpha2 = 0.0075;          % efficienza heater 2 [W/%]
    eps_r  = 0.9;             % emissività superficiale
    sigma  = 5.67e-8;         % costante Stefan-Boltzmann [W/m²K⁴]

    % --- 4. Conversione °C → K (necessario per Stefan-Boltzmann) ---
    T1_K = T1 + 273.15;
    T2_K = T2 + 273.15;

    % --- 5. Scambio termico tra heater 1 e heater 2 ---
    conv12 = sign(T2_K - T1_K) * U * As * abs(T2_K - T1_K);   % convezione
    rad12  = eps_r * sigma * As * (T2_K^4 - T1_K^4);           % irraggiamento

    % --- 6. Bilancio energetico: dT/dt = (1/mCp) * Σ(flussi) ---
    mCp = m * Cp;

    dT1dt = (1.0/mCp) * ( ...
        U*A*(Ta - T1_K) + ...                   % convezione con ambiente
        eps_r*sigma*A*(Ta^4 - T1_K^4) + ...     % irraggiamento con ambiente
        conv12 + rad12 + ...                     % scambio con heater 2
        alpha1*Q1 );                             % calore da heater 1

    dT2dt = (1.0/mCp) * ( ...
        U*A*(Ta - T2_K) + ...                   % convezione con ambiente
        eps_r*sigma*A*(Ta^4 - T2_K^4) + ...     % irraggiamento con ambiente
        -conv12 - rad12 + ...                    % scambio con heater 1 (opposto)
        alpha2*Q2 );                             % calore da heater 2

    % --- 7. Output ---
    % dTamb/dt = 0: Tamb è COSTANTE nell'episodio (è un parametro, non una variabile dinamica).
    % Includerla in dz con derivata nulla è il modo corretto per PILCO:
    % il GP apprende ΔTamb ≈ 0 e lascia Tamb invariata durante la propagazione interna.
    if numel(z) >= 3
        dz = [dT1dt; dT2dt; 0.0];   % Caso 2: stato 3D
    else
        dz = [dT1dt; dT2dt];         % Caso 1: stato 2D (backward compatible)
    end
end