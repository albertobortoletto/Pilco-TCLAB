function draw_case1(t, T1_traj, T2_traj, ref, u_traj, Q2_traj, ...
                    cost_traj, err_traj, dt, Tamb, Tset, Q2_min, Q2_max)
% draw_case1  Visualizzazione Caso 1: Tset FISSO, Tamb FISSA.
%
% Signature:
%   draw_case1(t, T1_traj, T2_traj, ref, u_traj, Q2_traj,Tset, Tamb, dt), ...
%
% Subplot (3 righe):
%   SP1 (40%): T1 misurata vs riferimento r(t) [°C]
% SP2 (30%): Q1 [%] — azione di controllo heater 1
%   SP3 (30%): Errore e(t) = T1 - r [°C] con area colorata
%
% Caso 1: Tset e Tamb fissi → nessuna linea verticale di cambio.

% =========================================================================
% R7: Colori definiti come variabili locali
% =========================================================================
c_T1   = [0.00, 0.45, 0.74];   % blu
c_ref  = [0.85, 0.13, 0.13];   % rosso
c_Q1   = [0.00, 0.45, 0.74];   % blu (stairs)
% c_Q2 rimosso: Q2 non mostrato nel Caso 1
c_err  = [0.85, 0.33, 0.10];   % arancione
c_cost = [0.47, 0.67, 0.19];   % verde
c_band = [0.80, 0.90, 0.80];   % verde chiaro semitrasparente
c_Tamb = [0.50, 0.50, 0.50];   % grigio

% =========================================================================
% Preparazione dati
% =========================================================================
N_pts = length(t);            % [punti]
t_min = t / 60;               % [min] tempo in minuti per leggibilità

% Q1 in percentuale [%]
Q1_perc = u_traj(:);          % [%] — già in [0,100] dalla chiamata esterna

% =========================================================================
% Figura
% =========================================================================
% R8: NumberTitle off, Name descrittivo
fig = figure('NumberTitle', 'off', 'Name', 'Caso 1 — Tset fisso, Tamb fissa', ...
             'Color', 'w');
clf(fig);
% R10: Position [80, 50, 1100, 850]
set(fig, 'Position', [80, 50, 1100, 850]);
set(fig, 'InvertHardcopy', 'off');  % non invertire: i colori sono già espliciti

% =========================================================================
% SP1 (40%): T1 vs riferimento [°C]
% =========================================================================
ax1 = subplot(3, 1, 1); hold on;

% Banda ±2°C attorno al riferimento (patch semitrasparente)
ref_vec = ref(:);
t_patch = [t_min(:); flipud(t_min(:))];
band_patch = [ref_vec - 2; flipud(ref_vec + 2)];
patch(ax1, t_patch, band_patch, c_band, ...
      'EdgeColor', 'none', 'FaceAlpha', 0.45, ...
      'DisplayName', '±2°C');

% Riferimento tratteggiato rosso
plot(ax1, t_min, ref_vec, '--', 'Color', c_ref, 'LineWidth', 1.8, ...
     'DisplayName', sprintf('Rif. T_{set} = %.0f°C', Tset));

% T1 misurata
plot(ax1, t_min, T1_traj, '-', 'Color', c_T1, 'LineWidth', 2.5, ...
     'DisplayName', 'T1 misurata');

% yline Tamb con label
yline(ax1, Tamb, ':', 'Color', c_Tamb, 'LineWidth', 1.2, ...
      'Label', sprintf('T_{amb} = %.0f°C', Tamb), ...
      'LabelHorizontalAlignment', 'left', 'FontSize', 8);

ylabel(ax1, 'Temperatura [°C]');
legend(ax1, 'Location', 'best', 'FontSize', 8);
grid(ax1, 'on');
title(ax1, 'T1 misurata vs riferimento');
xlabel(ax1, 'Tempo [min]');

% =========================================================================
% SP2 (30%): Q1 [%] sinistro
% =========================================================================
ax2 = subplot(3, 1, 2); hold on;

% --- Asse sinistro: Q1 ---
% asse singolo: solo Q1, nessun yyaxis
stairs(ax2, t_min(1:length(Q1_perc)), Q1_perc, '-', ...
       'Color', c_Q1, 'LineWidth', 2.0, 'DisplayName', 'Q1 [%]');
yline(ax2, 0,   ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');
yline(ax2, 100, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');
ylabel(ax2, 'Q1 [%]');
ylim(ax2, [-5, 110]);
ax2.YColor = c_Q1;   % asse unico, nessun yyaxis



legend(ax2, 'Location', 'best', 'FontSize', 8);
grid(ax2, 'on');
title(ax2, 'Segnali di controllo: Q1');
xlabel(ax2, 'Tempo [min]');

% =========================================================================
% SP3 (30%): Errore e(t) = T1 - r [°C] con area colorata
% =========================================================================
ax3 = subplot(3, 1, 3); hold on;

err_vec = err_traj(:);

% Area colorata dell'errore
area(ax3, t_min(1:length(err_vec)), err_vec, ...
     'FaceColor', c_err, 'FaceAlpha', 0.35, 'EdgeColor', c_err, ...
     'LineWidth', 1.5, 'DisplayName', 'e(t) = T1 − r');

% yline a 0
yline(ax3, 0, '-k', 'LineWidth', 1.0, 'HandleVisibility', 'off');

% yline ±2°C tratteggiata
yline(ax3, 2,  '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.2, ...
      'DisplayName', '±2°C');
yline(ax3, -2, '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.2, ...
      'HandleVisibility', 'off');

xlabel(ax3, 'Tempo [min]');   % R2: xlabel solo sull'ultimo
ylabel(ax3, 'Errore [°C]');
legend(ax3, 'Location', 'best', 'FontSize', 8);
grid(ax3, 'on');
title(ax3, 'Errore di inseguimento e(t) = T1 − r');

% =========================================================================
% R1: linkaxes su asse X — usato con cautela per evitare conflitti con yyaxis
% =========================================================================
% NOTA: linkaxes può causare hang con yyaxis. Per sicurezza, facciamo link
% manuale tramite listener-free xlim sync.
try
    linkaxes([ax1, ax2, ax3], 'x');
catch
    % Fallback: imposta xlim identici manualmente
    xl = [min(t_min), max(t_min)];
    xlim(ax1, xl); xlim(ax2, xl); xlim(ax3, xl);
end

% xlabel presente su tutti i subplot per export singoli

% =========================================================================
% Stile leggibile: sfondo bianco, contorno nero, titoli marcati
% =========================================================================
for aa = [ax1, ax2, ax3]
    set(aa, 'Color', 'w');                          % sfondo bianco nell'area dati
    set(aa, 'XColor', 'k');                          % asse X nero (bordo+tick+label)
    set(aa, 'GridColor', [0.15 0.15 0.15]);          % griglia scura
    set(aa, 'GridAlpha', 0.3);
    set(get(aa, 'Title'), 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12);
    set(get(aa, 'XLabel'), 'Color', 'k', 'FontSize', 10);
    set(get(aa, 'YLabel'), 'Color', 'k', 'FontSize', 10);
end
% YColor nero per axes senza yyaxis
set(ax1, 'YColor', 'k');
set(ax3, 'YColor', 'k');
% ax2: asse unico Q1, YColor gia' impostato sopra

% Legende con sfondo bianco
for aa = [ax1, ax2, ax3]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% R3: sgtitle con info essenziali
sgtitle(sprintf('Caso 1 — T_{set} = %.0f°C | T_{amb} = %.0f°C | dt = %ds', ...
        Tset, Tamb, dt), ...
        'FontWeight', 'bold', 'FontSize', 14, 'Color', 'k');

% R9: drawnow — force rendering
drawnow;
pause(0.1);   % permette al rendering engine di completare

end