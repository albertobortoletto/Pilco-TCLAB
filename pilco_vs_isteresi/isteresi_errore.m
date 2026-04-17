function u = isteresi_errore(e, h)
% ISTERESI_ERRORE
% e = errore
% h = semi-ampiezza della banda di isteresi
%
% Uscita:
%   u =  1  se e >  h
%   u = -1  se e < -h
%   u mantiene il valore precedente se -h <= e <= h

    persistent u_old

    if isempty(u_old)
        u_old = 0;   % valore iniziale
    end

    if e > h
        u_old = 1;
    elseif e < -h
        u_old = -1;
    end

    u = u_old;
end