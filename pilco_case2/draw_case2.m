function draw_case2(t, T1_traj, T2_traj, ref, u_traj, Q2_traj, ...
                    cost_traj, err_traj, dt, Tamb_segments, ...
                    Tset_segments, seg_switch_t, Q2_min, Q2_max)
% draw_case2  Visualizzazione Caso 2: Tset FISSO, Tamb VARIABILE tra segmenti.
%
% Signature:
%   draw_case2(t, T1_traj, T2_traj, ref, u_traj, Q2_traj,
%              cost_traj, err_traj, dt, Tamb_segments,
%              Tset_segments, seg_switch_t, Q2_min, Q2_max)
%
% Subplot (4 righe):
%   SP1 (35%): T1 vs riferimento, con bande colorate per segmento Tamb
%   SP2 (25%): Q1 [%] (sinistro) + Q2 [%] (destro) con xline segmenti
%   SP3 (20%): Errore e(t) = T1 - r [°C] con yline ±2°C
%   SP4 (20%): Costo lossSat [0,1] + movmean(8)
%
% Caso 2: Tset fisso, Tamb variabile → xline ai cambi di segmento.

% =========================================================================
% R7: Colori definiti come variabili locali
% =========================================================================
c_T1   = [0.00, 0.45, 0.74];   % blu
c_ref  = [0.85, 0.13, 0.13];   % rosso
c_Q1   = [0.00, 0.45, 0.74];   % blu
c_Q2   = [0.55, 0.00, 0.75];   % viola
c_err  = [0.85, 0.33, 0.10];   % arancione
c_cost = [0.47, 0.67, 0.19];   % verde
c_band = [0.80, 0.90, 0.80];   % banda ±2°C
c_xline = [0.50, 0.50, 0.50];  % grigio per xline

% Colori segmenti (pastello per bande di sfondo)
seg_colors = [0.85, 0.92, 1.00;    % azzurro chiaro
              1.00, 0.92, 0.85;    % arancione chiaro
              0.85, 1.00, 0.85;    % verde chiaro
              1.00, 0.85, 1.00;    % rosa chiaro
              1.00, 1.00, 0.85;    % giallo chiaro
              0.90, 0.85, 1.00];   % lavanda

% =========================================================================
% Preparazione dati
% =========================================================================
t_min = t(:) / 60;                      % [min]
N_pts = length(t_min);
nSeg  = length(Tamb_segments);

% Tempi di switch in minuti [min]
seg_switch_min = seg_switch_t(:) / 60;   % [min]

% Assicura che i vettori siano colonna
Q1_perc  = u_traj(:);                    % [%]
Q2_vec   = Q2_traj(:);
err_vec  = err_traj(:);
cost_vec = cost_traj(:);
ref_vec  = ref(:);
T1_vec   = T1_traj(:);

% =========================================================================
% Figura
% =========================================================================
% R8: NumberTitle off, Name descrittivo
fig = figure('NumberTitle', 'off', 'Name', 'Caso 2 — Tset fisso, Tamb variabile', ...
             'Color', 'w');
clf(fig);
% R10: Position [80, 50, 1100, 850]
set(fig, 'Position', [80, 50, 1100, 850]);
set(fig, 'InvertHardcopy', 'off');  % non invertire: i colori sono già espliciti

% =========================================================================
% Helper: disegna bande colorate di sfondo per ogni segmento
% =========================================================================
    function draw_seg_bands(ax, y_lo, y_hi)
        for ss = 1:nSeg
            if ss == 1
                t_start = t_min(1);
            else
                t_start = seg_switch_min(ss - 1);
            end
            if ss < nSeg && ss <= length(seg_switch_min)
                t_end = seg_switch_min(ss);
            else
                t_end = t_min(end);
            end
            ci = mod(ss - 1, size(seg_colors, 1)) + 1;
            patch(ax, [t_start, t_end, t_end, t_start], ...
                  [y_lo, y_lo, y_hi, y_hi], seg_colors(ci, :), ...
                  'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                  'HandleVisibility', 'off');
        end
    end

% =========================================================================
% Helper: disegna xline ai cambi di segmento (R4: xline grigio ':')
% =========================================================================
    function draw_seg_xlines(ax)
        for ss = 1:length(seg_switch_min)
            xline(ax, seg_switch_min(ss), ':', 'Color', c_xline, ...
                  'LineWidth', 1.3, 'HandleVisibility', 'off');
        end
    end

% =========================================================================
% SP1 (35%): T1 vs riferimento con bande di sfondo per Tamb
% =========================================================================
ax1 = subplot(4, 1, 1); hold on;

T1_lo = min([T1_vec; ref_vec]) - 8;
T1_hi = max([T1_vec; ref_vec]) + 12;
draw_seg_bands(ax1, T1_lo, T1_hi);
draw_seg_xlines(ax1);

% Etichette "Tamb=X°C" centrate nella banda di ogni segmento
for ss = 1:nSeg
    if ss == 1
        t_s = t_min(1);
    else
        t_s = seg_switch_min(ss - 1);
    end
    if ss < nSeg && ss <= length(seg_switch_min)
        t_e = seg_switch_min(ss);
    else
        t_e = t_min(end);
    end
    t_mid = (t_s + t_e) / 2;
    text(ax1, t_mid, T1_hi - 3, sprintf('T_{amb}=%.0f°C', Tamb_segments(ss)), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, ...
         'Color', [0.3, 0.3, 0.3], 'FontWeight', 'bold');
end

% Riferimento tratteggiato rosso
plot(ax1, t_min, ref_vec, '--', 'Color', c_ref, 'LineWidth', 1.8, ...
     'DisplayName', sprintf('Rif. T_{set}'));

% T1 misurata
plot(ax1, t_min, T1_vec, '-', 'Color', c_T1, 'LineWidth', 2.5, ...
     'DisplayName', 'T1 misurata');

ylabel(ax1, 'Temperatura [°C]');
legend(ax1, 'Location', 'best', 'FontSize', 8);
grid(ax1, 'on');
ylim(ax1, [T1_lo, T1_hi]);
title(ax1, 'T1 misurata vs riferimento — bande colorate = segmento Tamb');
xlabel(ax1, 'Tempo [min]');

% =========================================================================
% SP2 (25%): Q1 [%] sinistro + Q2 [%] destro
% =========================================================================
ax2 = subplot(4, 1, 2); hold on;

draw_seg_xlines(ax2);

% --- Asse sinistro: Q1 ---
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

% --- Asse destro: Q2 (R5) ---
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

legend(ax2, 'Location', 'best', 'FontSize', 8);
grid(ax2, 'on');
title(ax2, 'Q1 + Q2 disturbo');
xlabel(ax2, 'Tempo [min]');

% =========================================================================
% SP3 (20%): Errore e(t) = T1 - r [°C]
% =========================================================================
ax3 = subplot(4, 1, 3); hold on;

draw_seg_xlines(ax3);

% Area errore
area(ax3, t_min(1:length(err_vec)), err_vec, ...
     'FaceColor', c_err, 'FaceAlpha', 0.35, 'EdgeColor', c_err, ...
     'LineWidth', 1.5, 'DisplayName', 'e(t) = T1 − r');

% yline a 0
yline(ax3, 0, '-k', 'LineWidth', 1.0, 'HandleVisibility', 'off');

% yline ±2°C
yline(ax3, 2,  '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.2, ...
      'DisplayName', '±2°C');
yline(ax3, -2, '--', 'Color', [0.0, 0.6, 0.1], 'LineWidth', 1.2, ...
      'HandleVisibility', 'off');

ylabel(ax3, 'Errore [°C]');
legend(ax3, 'Location', 'best', 'FontSize', 8);
grid(ax3, 'on');
title(ax3, 'Errore di inseguimento e(t) = T1 − r');
xlabel(ax3, 'Tempo [min]');

% =========================================================================
% SP4 (20%): Costo lossSat [0,1] + movmean(8)
% =========================================================================
ax4 = subplot(4, 1, 4); hold on;

draw_seg_xlines(ax4);

% Costo istantaneo
plot(ax4, t_min(1:length(cost_vec)), cost_vec, '-', ...
     'Color', [c_cost, 0.4], 'LineWidth', 1.0, ...
     'DisplayName', 'Costo lossSat');

% Media mobile costo
if length(cost_vec) >= 8
    cost_smooth = movmean(cost_vec, 8);
    plot(ax4, t_min(1:length(cost_vec)), cost_smooth, '-', ...
         'Color', c_cost, 'LineWidth', 2.2, ...
         'DisplayName', 'movmean(8)');
end

xlabel(ax4, 'Tempo [min]');
ylabel(ax4, 'Costo lossSat [0,1]');
ylim(ax4, [0, 1.05]);
legend(ax4, 'Location', 'best', 'FontSize', 8);
grid(ax4, 'on');
title(ax4, 'Costo lossSat');

% =========================================================================
% R1: linkaxes su asse X
% =========================================================================
linkaxes([ax1, ax2, ax3, ax4], 'x');

% R2: xlabel solo sull'ultimo → rimuovi dagli altri
set(ax1, 'XTickLabel', []);
set(ax2, 'XTickLabel', []);
set(ax3, 'XTickLabel', []);

% =========================================================================
% Stile leggibile: sfondo bianco, contorno nero, titoli marcati
% =========================================================================
for aa = [ax1, ax2, ax3, ax4]
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
set(ax4, 'YColor', 'k');
% ax2: i colori Y sinistro/destro sono già fissati per Q1/Q2

% Legende con sfondo bianco e testo nero
for aa = [ax1, ax2, ax3, ax4]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% R3: sgtitle con info essenziali
Tamb_str = strjoin(arrayfun(@(x) sprintf('%.0f', x), Tamb_segments, ...
           'UniformOutput', false), ', ');
sgtitle(sprintf('Caso 2 — Tamb variabile [%s]°C | dt = %ds | Q2 \\in [%.0f, %.0f]%%', ...
        Tamb_str, dt, Q2_min, Q2_max), ...
        'FontWeight', 'bold', 'FontSize', 14, 'Color', 'k');

% R9: drawnow
drawnow;

end
