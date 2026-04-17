function dz = dynamics_tclab_case1(t, z, u)
% dynamics_tclab - ODE che descrive la fisica del TCLab
%
% Questa funzione viene chiamata da ODE45 per simulare l'evoluzione
% delle temperature nel tempo. Dato lo stato attuale z e l'azione u,
% restituisce la derivata dello stato dz/dt.
%
% Input:
%   t  -> tempo corrente [s] (richiesto da ODE45)
%   z  -> stato corrente: z = [T1; T2] temperature in gradi Celsius
%   u  -> funzione handle dell'azione (zero-order-hold passata da PILCO)
%
% Output:
%   dz -> derivata dello stato: dz = [dT1/dt; dT2/dt] in gradi C/s

    % 1. Estrae le temperature correnti dallo stato
    T1 = z(1);   % temperatura heater/sensore 1 [gradi C]
    T2 = z(2);   % temperatura heater/sensore 2 [gradi C]

    % 2. Calcola l'azione da applicare al tempo t
    % u e' una funzione handle (zero-order-hold): restituisce l'azione
    % costante decisa dalla policy per questo intervallo dt
    action = u(t);
    Q1 = action(1) + 50;  % converte output policy [-50,+50] in potenza [0,100]%
    Q2 = 0;               % heater 2 non controllato (in futuro: Q2 = action(2))

    % 3. Parametri fisici del TCLab
    Tamb   = 25;            % temperatura ambiente [gradi C]
    Ta     = Tamb + 273.15; % temperatura ambiente [K]
    U      = 10.0;          % coefficiente di convezione [W/m^2 K]
    m      = 4.0/1000.0;    % massa dell'heater [kg]
    Cp     = 0.5 * 1000.0;  % calore specifico [J/kg K]
    A      = 10.0/100.0^2;  % area scambio heater-ambiente [m^2]
    As     = 2.0/100.0^2;   % area scambio tra heater 1 e 2 [m^2]
    alpha1 = 0.0100;        % efficienza heater 1 [W/%]
    alpha2 = 0.0075;        % efficienza heater 2 [W/%]
    eps    = 0.9;           % emissivita' superficiale
    sigma  = 5.67e-8;       % costante di Stefan-Boltzmann [W/m^2 K^4]

    % 4. Conversione temperature da Celsius a Kelvin
    % Necessario per il termine radiativo (Stefan-Boltzmann usa T^4 in Kelvin)
    T1_K = T1 + 273.15;
    T2_K = T2 + 273.15;

    % 5. Scambio termico tra heater 1 e heater 2
    % Convezione: proporzionale alla differenza di temperatura
    conv12 = sign(T2_K - T1_K) * U * As * abs(T2_K - T1_K);
    % Irraggiamento: legge di Stefan-Boltzmann (proporzionale a T^4)
    rad12  = eps * sigma * As * (T2_K^4 - T1_K^4);

    % 6. Bilancio energetico: dT/dt = (1/mCp) * somma(flussi di calore)
    dT1dt = (1.0/(m*Cp)) * ( ...
        U*A*(Ta - T1_K) + ...               % convezione con ambiente
        eps*sigma*A*(Ta^4 - T1_K^4) + ...   % irraggiamento con ambiente
        conv12 + rad12 + ...                % scambio con heater 2 !!!!!!!! DOVREI MOLTIPLICARLI PER 0, ma teniamo cosi
        alpha1*Q1 );                        % calore generato da heater 1

    dT2dt = (1.0/(m*Cp)) * ( ...
        U*A*(Ta - T2_K) + ...               % convezione con ambiente
        eps*sigma*A*(Ta^4 - T2_K^4) + ...   % irraggiamento con ambiente
        -conv12 - rad12 + ...               % scambio con heater 1 (segno opposto) !!!! DOVREI MOLTIPLICARLI PER 0, ma teniamo cosi per ora
        alpha2*Q2 );                        % calore generato da heater 2

    % Separo T1 e T2 e il sistema è costituito da 2 SISO e noi consideriamo
    % solo quello di T1 

    % 7. Restituisce la derivata come vettore COLONNA (formato richiesto da ODE45)
    dz = [dT1dt; dT2dt];
    % dal pendolo:
    % z1 = dT1dt
    % z2 = T1
end