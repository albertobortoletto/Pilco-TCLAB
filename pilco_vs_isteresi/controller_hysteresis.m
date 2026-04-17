function Q1 = controller_hysteresis(T_target, T_current, h)
    % Calcolo errore
    e = T_target - T_current;
    
    % Logica isteresi (tua funzione)
    u = isteresi_errore(e, h); 
    
    % Mapping: u=1 -> 100% (caldo), u=-1 -> 0% (freddo)
    if u == 1
        Q1 = 100;
    else
        Q1 = 0;
    end
end