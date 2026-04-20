function draw_case3_step(t_eval, T1_traj, ref, u_traj, Q2_traj, ...
                         cost_traj, err_traj, dt, step_times, ...
                         Tset_seq, Tamb, Q2_min, Q2_max, maxU)
% draw_case3_step  Visualizzazione Caso 3: Tset VARIABILE (gradini), Tamb fissa.
%
% Firma INVARIATA:
%   draw_case3_step(t_eval, T1_traj, ref, u_traj, Q2_traj,
%                   cost_traj, err_traj, dt, step_times,
%                   Tset_seq, Tamb, Q2_min, Q2_max, maxU)
%
% Subplot (3 righe):
%   SP1 (40%): T1 vs riferimento r(t) [°C] con banda ±2°C e sfondo gradini
%   SP2 (30%): Q1 [%] (sinistro) + Q2 [%] (destro)
%   SP3 (30%): Errore e(t) = T1 - r [°C] con area colorata
%
% Caso 3: Tset variabile (scalinata), Tamb fissa → xline ai cambi di setpoint.

% =========================================================================
% R7: Colori definiti come variabili locali (BUG4 corretto)
% =========================================================================
c_T1    = [0.00, 0.45, 0.74];   % blu — T1 misurata
c_ref   = [0.85, 0.13, 0.13];   % rosso — riferimento
c_Q1    = [0.00, 0.45, 0.74];   % blu — Q1 stairs
c_Q2    = [0.55, 0.00, 0.75];   % viola — Q2 disturbo
c_err   = [0.85, 0.33, 0.10];   % arancione — errore
c_cost  = [0.47, 0.67, 0.19];   % verde — costo
c_band  = [0.80, 0.90, 0.80];   % verde chiaro — banda ±2°C
c_xline = [0.50, 0.50, 0.50];   % grigio — xline ai cambi
c_Tamb  = [0.50, 0.50, 0.50];   % grigio — yline Tamb

% Colori per sfondo gradini (colori distinti pastello)
step_colors = [0.85, 0.92, 1.00;    % azzurro chiaro
               1.00, 0.92, 0.85;    % arancione chiaro
               0.85, 1.00, 0.85;    % verde chiaro
               1.00, 0.85, 1.00;    % rosa chiaro
               1.00, 1.00, 0.85;    % giallo chiaro
               0.90, 0.85, 1.00];   % lavanda

% =========================================================================
% Preparazione dati
% =========================================================================
t_min    = t_eval(:) / 60;              % [min]
nSteps   = length(Tset_seq);

% BUG1 corretto: conversione Q1 usa maxU (non hardcoded +50)
Q1_perc  = u_traj(:) + maxU;            % [%] policy output → potenza [0, 2*maxU]%
Q2_vec   = Q2_traj(:);
err_vec  = err_traj(:);
cost_vec = cost_traj(:);
ref_vec  = ref(:);
T1_vec   = T1_traj(:);

% Tempi di switch in minuti [min]
step_times_min = step_times(:) / 60;    % [min]

% =========================================================================
% Figura
% =========================================================================
% R8: NumberTitle off, Name descrittivo
fig = figure('NumberTitle', 'off', 'Name', 'Caso 3 — Tset variabile (gradini)', ...
             'Color', 'w');
clf(fig);
% R10/BUG5: Position [80, 50, 1100, 850]
set(fig, 'Position', [80, 50, 1100, 850]);
set(fig, 'InvertHardcopy', 'off');  % non invertire: i colori sono già espliciti

% =========================================================================
% Helper: sfondo colorato per gradini
% =========================================================================
    function draw_step_bg(ax, y_lo, y_hi)
        for ss = 1:nSteps
            if ss == 1
                t_s = t_min(1);
            else
                t_s = step_times_min(ss);
            end
            if ss < nSteps
                t_e = step_times_min(ss + 1);
            else
                t_e = t_min(end);
            end
            ci = mod(ss - 1, size(step_colors, 1)) + 1;
            patch(ax, [t_s, t_e, t_e, t_s], ...
                  [y_lo, y_lo, y_hi, y_hi], step_colors(ci, :), ...
                  'FaceAlpha', 0.20, 'EdgeColor', 'none', ...
                  'HandleVisibility', 'off');
        end
    end

% =========================================================================
% Helper: xline ai cambi di setpoint (R4: xline grigio ':')
% =========================================================================
    function draw_step_xlines(ax)
        for ss = 2:length(step_times_min)
            xline(ax, step_times_min(ss), ':', 'Color', c_xline, ...
                  'LineWidth', 1.3, 'HandleVisibility', 'off');
        end
    end

% =========================================================================
% SP1 (40%): T1 vs riferimento [°C] con banda ±2°C e sfondo gradini
% =========================================================================
ax1 = subplot(3, 1, 1); hold on;

T1_lo = min([T1_vec; ref_vec]) - 8;
T1_hi = max([T1_vec; ref_vec]) + 12;

draw_step_bg(ax1, T1_lo, T1_hi);
draw_step_xlines(ax1);

% Banda ±2°C per ogni segmento con check lunghezza (BUG3 corretto)
for ss = 1:nSteps
    if ss == 1
        t_s = t_min(1);
    else
        t_s = step_times_min(ss);
    end
    if ss < nSteps
        t_e = step_times_min(ss + 1);
    else
        t_e = t_min(end);
    end
    
    % Filtra i punti temporali in questo segmento
    idx_band = (t_min >= t_s - 1e-9) & (t_min <= t_e + 1e-9);
    t_band = t_min(idx_band);
    r_band = ref_vec(idx_band);
    
    % BUG3: check length(t_band) >= 2 per evitare patch vuote
    if length(t_band) >= 2
        t_p = [t_band; flipud(t_band)];
        r_p = [r_band - 2; flipud(r_band + 2)];
        hv = 'off';
        if ss == 1, hv = 'on'; end
        patch(ax1, t_p, r_p, c_band, ...
              'EdgeColor', 'none', 'FaceAlpha', 0.45, ...
              'DisplayName', '±2°C', 'HandleVisibility', hv);
    end
end

% Riferimento tratteggiato rosso
plot(ax1, t_min, ref_vec, '--', 'Color', c_ref, 'LineWidth', 1.8, ...
     'DisplayName', 'Rif. r(t)');

% T1 misurata
plot(ax1, t_min, T1_vec, '-', 'Color', c_T1, 'LineWidth', 2.5, ...
     'DisplayName', 'T1 misurata');

% yline Tamb
yline(ax1, Tamb, ':', 'Color', c_Tamb, 'LineWidth', 1.0, ...
      'Label', sprintf('T_{amb}=%.0f°C', Tamb), ...
      'LabelHorizontalAlignment', 'left', 'FontSize', 7, ...
      'HandleVisibility', 'off');

% Etichette setpoint centrate
for ss = 1:nSteps
    if ss == 1
        t_s = t_min(1);
    else
        t_s = step_times_min(ss);
    end
    if ss < nSteps
        t_e = step_times_min(ss + 1);
    else
        t_e = t_min(end);
    end
    t_mid = (t_s + t_e) / 2;
    text(ax1, t_mid, T1_hi - 3, sprintf('T_{set}=%.0f°C', Tset_seq(ss)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, ...
         'Color', [0.3, 0.3, 0.3], 'FontWeight', 'bold');
end

ylabel(ax1, 'Temperatura [°C]');
legend(ax1, 'Location', 'best', 'FontSize', 8);
grid(ax1, 'on');
ylim(ax1, [T1_lo, T1_hi]);
title(ax1, 'T1 misurata vs riferimento — sfondo colorato = gradino Tset');

% =========================================================================
% SP2 (30%): Q1 [%] sinistro + Q2 [%] destro
% =========================================================================
ax2 = subplot(3, 1, 2); hold on;

draw_step_xlines(ax2);

% --- Asse sinistro: Q1 (R5 compatibile) ---
yyaxis(ax2, 'left');
stairs(ax2, t_min(1:length(Q1_perc)), Q1_perc, '-', ...
       'Color', c_Q1, 'LineWidth', 2.0, 'DisplayName', 'Q1 [%]');
yline(ax2, 0,   ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');
yline(ax2, 100, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, ...
      'HandleVisibility', 'off');
ylabel(ax2, 'Q1 [%]');
ylim(ax2, [-5, 110]);
ax2.YColor = c_Q1;

% --- Asse destro: Q2 (R5: Q2 su asse Y destro) ---
yyaxis(ax2, 'right');
scatter(ax2, t_min(1:length(Q2_vec)), Q2_vec, 12, c_Q2, 'filled', ...
        'DisplayName', 'Q2 campioni', 'MarkerFaceAlpha', 0.5);
if length(Q2_vec) >= 5
    Q2_smooth = movmean(Q2_vec, 5);
    plot(ax2, t_min(1:length(Q2_vec)), Q2_smooth, '-', 'Color', c_Q2, ...
         'LineWidth', 1.8, 'DisplayName', 'Q2 movmean(5)');
end
yline(ax2, Q2_min, '--', 'Color', c_Q2 * 0.7, 'LineWidth', 1.0, ...
      'HandleVisibility', 'off');
yline(ax2, Q2_max, '--', 'Color', c_Q2 * 0.7, 'LineWidth', 1.0, ...
      'HandleVisibility', 'off');
ylabel(ax2, 'Q2 [%]');
ylim(ax2, [max(0, Q2_min - 3), Q2_max + 3]);
ax2.YColor = c_Q2;

% BUG2 corretto: legenda senza stringhe vuote
legend(ax2, 'Location', 'best', 'FontSize', 8);
grid(ax2, 'on');
title(ax2, 'Q1 + Q2 disturbo');

% =========================================================================
% SP3 (30%): Errore e(t) = T1 - r [°C] con area colorata
% =========================================================================
ax3 = subplot(3, 1, 3); hold on;

draw_step_xlines(ax3);

% Area errore
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
% R1: linkaxes su asse X
% =========================================================================
linkaxes([ax1, ax2, ax3], 'x');

% R2: xlabel solo sull'ultimo → rimuovi dagli altri
set(ax1, 'XTickLabel', []);
set(ax2, 'XTickLabel', []);

% =========================================================================
% Stile leggibile: sfondo bianco, contorno nero, titoli marcati
% =========================================================================
for aa = [ax1, ax2, ax3]
    set(aa, 'Color', 'w');                          % sfondo bianco
    set(aa, 'XColor', 'k');                          % asse X nero
    set(aa, 'GridColor', [0.15 0.15 0.15]);
    set(aa, 'GridAlpha', 0.3);
    set(get(aa, 'Title'), 'Color', 'k', 'FontWeight', 'bold', 'FontSize', 12);
    set(get(aa, 'XLabel'), 'Color', 'k', 'FontSize', 10);
    set(get(aa, 'YLabel'), 'Color', 'k', 'FontSize', 10);
end
% YColor nero per axes senza yyaxis
set(ax1, 'YColor', 'k');
set(ax3, 'YColor', 'k');
% ax2: i colori Y sinistro/destro sono già fissati per Q1/Q2

% Legende con sfondo bianco e testo nero
for aa = [ax1, ax2, ax3]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% R3: sgtitle con info essenziali
Tset_str = strjoin(arrayfun(@(x) sprintf('%.0f', x), Tset_seq, ...
           'UniformOutput', false), '→');
sgtitle(sprintf('Caso 3 — T_{set} = [%s]°C | T_{amb} = %.0f°C | dt = %ds | Q2 \\in [%.0f, %.0f]%%', ...
        Tset_str, Tamb, dt, Q2_min, Q2_max), ...
        'FontWeight', 'bold', 'FontSize', 14, 'Color', 'k');

% R9: drawnow
drawnow;

end
