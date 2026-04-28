function draw_case2(t, T1_traj, T2_traj, ref, u_traj, Q2_traj, ...
                    cost_traj, err_traj, dt, Tamb_segments, ...
                    Tset_segments, seg_switch_t, Q2_min, Q2_max, ...
                    latent_eval, actions_eval)
% draw_case2  Visualizzazione Caso 2: Tset FISSO, Tamb VARIABILE.
%
% LAYOUT:
%   Riga TOP  : un subplot per ogni Tamb (T1 vs riferimento, metriche inline)
%   Riga BOT1 : Q1 [%] (sinistro) + Q2 [%] (destro) — segnale cucito
%   Riga BOT2 : Errore e(t) = T1 - r [°C]
%   Riga BOT3 : Costo lossSat [0,1] + movmean(8)
%
% Argomenti opzionali (15-16):
%   latent_eval   cell(1,nSeg): latent{te} = (H+1)×3  [T1, T2, Tamb]
%   actions_eval  cell(1,nSeg): Q1 già in [0,100]%,   lunghezza H o H+1
%   Se assenti, la riga TOP non viene disegnata.

% -------------------------------------------------------------------------
% Argomenti opzionali
% -------------------------------------------------------------------------
has_individual = nargin >= 16 && ~isempty(latent_eval) && ~isempty(actions_eval);

% -------------------------------------------------------------------------
% Colori
% -------------------------------------------------------------------------
c_T1    = [0.00, 0.45, 0.74];
c_ref   = [0.85, 0.13, 0.13];
c_Q1    = [0.00, 0.45, 0.74];
c_Q2    = [0.55, 0.00, 0.75];
c_err   = [0.85, 0.33, 0.10];
c_cost  = [0.47, 0.67, 0.19];
c_band  = [0.80, 0.90, 0.80];
c_xline = [0.50, 0.50, 0.50];

seg_colors = [0.85, 0.92, 1.00;
              1.00, 0.92, 0.85;
              0.85, 1.00, 0.85;
              1.00, 0.85, 1.00;
              1.00, 1.00, 0.85;
              0.90, 0.85, 1.00];

% -------------------------------------------------------------------------
% Dati cuciti
% -------------------------------------------------------------------------
t_min          = t(:) / 60;
nSeg           = length(Tamb_segments);
seg_switch_min = seg_switch_t(:) / 60;
Q1_perc  = u_traj(:);
Q2_vec   = Q2_traj(:);
err_vec  = err_traj(:);
cost_vec = cost_traj(:);
ref_vec  = ref(:);
T1_vec   = T1_traj(:);
Tset_val = Tset_segments(1);

% -------------------------------------------------------------------------
% Figura
% -------------------------------------------------------------------------
fig = figure('NumberTitle', 'off', ...
             'Name',        'Caso 2 — Tset fisso, Tamb variabile', ...
             'Color',       'w', ...
             'Position',    [40, 10, 1250, 1100]);
set(fig, 'InvertHardcopy', 'off');

% -------------------------------------------------------------------------
% Posizioni normalizzate — layout con gap per titoli e xlabel
%
%   sgtitle : ~0.96
%   top     : y=0.72  h=0.21  → [0.72, 0.93]   T1 per Tamb
%   (gap 0.06 per xlabel top + titolo bot1)
%   bot1    : y=0.47  h=0.14  → [0.47, 0.61]   Q1/Q2
%   (gap 0.05 per titolo bot2)
%   bot2    : y=0.26  h=0.14  → [0.26, 0.40]   errore
%   (gap 0.05 per titolo bot3)
%   bot3    : y=0.05  h=0.14  → [0.05, 0.19]   costo
% -------------------------------------------------------------------------
left_m = 0.07;
righ_m = 0.96;
full_w = righ_m - left_m;

if has_individual
    bot_y    = [0.47, 0.26, 0.05];
    bot_h    = [0.14, 0.14, 0.14];
    top_y    = 0.72;
    top_h    = 0.21;
else
    bot_y    = [0.74, 0.50, 0.26];
    bot_h    = [0.20, 0.20, 0.20];
    top_y    = [];
    top_h    = [];
end

% =========================================================================
% RIGA SUPERIORE — subplot individuali per Tamb
% =========================================================================
if has_individual
    gap_sp = 0.018;    % gap aumentato tra pannelli
    w_sp   = (full_w - gap_sp*(nSeg-1)) / nSeg;

    % Calcola limiti Y globali per rendere i pannelli confrontabili
    all_T1 = [];
    for ss = 1:nSeg
        all_T1 = [all_T1; latent_eval{ss}(:,1)];
    end
    y_lo_g = min(all_T1) - 3;
    y_hi_g = max(all_T1) + 4;

    for ss = 1:nSeg
        Tamb_ss = Tamb_segments(ss);
        lt_ss   = latent_eval{ss};
        T1_ss   = lt_ss(:, 1);
        n_ss    = size(lt_ss, 1);
        t_ss    = (0:n_ss-1)' * dt / 60;
        ref_ss  = Tset_val * ones(n_ss, 1);
        err_ss  = T1_ss - ref_ss;

        % Q1: allinea a n_ss punti
        Q1_ss = actions_eval{ss}(:);
        if length(Q1_ss) < n_ss
            Q1_ss = [Q1_ss(1); Q1_ss];
        end
        Q1_ss = Q1_ss(1:n_ss);

        x_pos  = left_m + (ss-1)*(w_sp + gap_sp);
        ax_top = axes('Position', [x_pos, top_y, w_sp, top_h], ...
                      'Parent', fig);
        hold(ax_top, 'on');

        % Sfondo tenue con il colore del segmento
        ci = mod(ss-1, size(seg_colors,1)) + 1;
        set(ax_top, 'Color', seg_colors(ci,:)*0.18 + 0.82);

        % Banda ±2°C
        t_p = [t_ss; flipud(t_ss)];
        r_p = [ref_ss-2; flipud(ref_ss+2)];
        patch(ax_top, t_p, r_p, c_band, 'EdgeColor','none', ...
              'FaceAlpha', 0.50, 'HandleVisibility','off');

        % Riferimento
        plot(ax_top, t_ss, ref_ss, '--', 'Color', c_ref, 'LineWidth', 1.6, ...
             'DisplayName', sprintf('T_{set}=%g', Tset_val));

        % T1
        plot(ax_top, t_ss, T1_ss, '-', 'Color', c_T1, 'LineWidth', 2.2, ...
             'DisplayName', 'T_1');

        % Metriche compatte — text box in alto a destra dentro il grafico
        rmse_ss = sqrt(mean(err_ss.^2));
        pct_ss  = 100 * mean(abs(err_ss) < 2);
        text(ax_top, t_ss(end)*0.97, y_hi_g - 1.0, ...
             sprintf('RMSE=%.1f°C | %d%%', rmse_ss, round(pct_ss)), ...
             'HorizontalAlignment', 'right', 'FontSize', 6.5, ...
             'Color', [0.15 0.15 0.15], ...
             'BackgroundColor', 'w', 'EdgeColor', [0.75 0.75 0.75], ...
             'Margin', 2);

        ylim(ax_top, [y_lo_g, y_hi_g]);

        % xlabel su TUTTI i pannelli con Tamb + tempo
        xlabel(ax_top, sprintf('T_{amb}=%g°C — Tempo [min]', Tamb_ss), ...
               'FontSize', 7.5, 'FontWeight', 'bold', 'Color', 'k');

        % ylabel solo sul primo pannello
        if ss == 1
            ylabel(ax_top, 'T_1 [°C]', 'FontSize', 8, 'Color', 'k');
            legend(ax_top, 'Location', 'southeast', 'FontSize', 6.5);
        else
            set(ax_top, 'YTickLabel', []);
        end

        grid(ax_top, 'on');
        set(ax_top, 'XColor', 'k', 'YColor', 'k', ...
                    'GridColor', [0.15 0.15 0.15], 'GridAlpha', 0.25, ...
                    'FontSize', 7);
        box(ax_top, 'on');
    end
end

% =========================================================================
% Helper: bande sfondo cucito
% =========================================================================
    function draw_seg_bands(ax, y_lo, y_hi)
        for ss = 1:nSeg
            if ss == 1, ts = t_min(1); else, ts = seg_switch_min(ss-1); end
            if ss < nSeg && ss <= length(seg_switch_min)
                te = seg_switch_min(ss);
            else
                te = t_min(end);
            end
            ci = mod(ss-1, size(seg_colors,1)) + 1;
            patch(ax, [ts,te,te,ts], [y_lo,y_lo,y_hi,y_hi], seg_colors(ci,:), ...
                  'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
        end
    end

% =========================================================================
% Helper: xline ai cambi di segmento
% =========================================================================
    function draw_seg_xlines(ax)
        for ss = 1:length(seg_switch_min)
            xline(ax, seg_switch_min(ss), ':', 'Color', c_xline, ...
                  'LineWidth', 1.3, 'HandleVisibility', 'off');
        end
    end

% =========================================================================
% BOT1 — Q1 + Q2 (cucito)
% =========================================================================
ax2 = axes('Position', [left_m, bot_y(1), full_w, bot_h(1)], ...
           'Color', 'w', 'Parent', fig);
hold(ax2, 'on');
draw_seg_xlines(ax2);

yyaxis(ax2, 'left');
stairs(ax2, t_min(1:length(Q1_perc)), Q1_perc, '-', 'Color', c_Q1, ...
       'LineWidth', 2.0, 'DisplayName', 'Q1 [%]');
yline(ax2, 0,   ':', 'Color',[0.5 0.5 0.5], 'LineWidth',0.8, 'HandleVisibility','off');
yline(ax2, 100, ':', 'Color',[0.5 0.5 0.5], 'LineWidth',0.8, 'HandleVisibility','off');
ylabel(ax2, 'Q1 [%]', 'FontSize',10, 'Color',c_Q1);
ylim(ax2, [-5, 110]);
ax2.YColor = c_Q1;

yyaxis(ax2, 'right');
scatter(ax2, t_min(1:length(Q2_vec)), Q2_vec, 10, c_Q2, 'filled', ...
        'DisplayName','Q2 campioni','MarkerFaceAlpha',0.45);
if length(Q2_vec) >= 5
    plot(ax2, t_min(1:length(Q2_vec)), movmean(Q2_vec,5), '-', ...
         'Color',c_Q2,'LineWidth',1.6,'DisplayName','Q2 media');
end
ylabel(ax2, 'Q2 [%]', 'FontSize',10, 'Color',c_Q2);
ylim(ax2, [max(0,Q2_min-2), Q2_max+3]);
ax2.YColor = c_Q2;

% Etichette Tamb sopra ogni segmento
yyaxis(ax2, 'left');
for ss = 1:nSeg
    if ss == 1, ts2 = t_min(1); else, ts2 = seg_switch_min(ss-1); end
    if ss < nSeg && ss <= length(seg_switch_min), te2 = seg_switch_min(ss);
    else, te2 = t_min(end); end
    text(ax2, (ts2+te2)/2, 104, sprintf('T_{amb}=%.0f°C', Tamb_segments(ss)), ...
         'HorizontalAlignment','center','FontSize',7.5, ...
         'Color',[0.25 0.25 0.25],'FontWeight','bold');
end

legend(ax2, 'Location','best','FontSize',8);
grid(ax2, 'on');
title(ax2, 'Q1 controllo + Q2 disturbo', 'FontSize',11,'FontWeight','bold','Color','k');
set(ax2, 'XTickLabel',[], 'XColor','k', 'GridColor',[0.15 0.15 0.15],'GridAlpha',0.3);

% =========================================================================
% BOT2 — Errore (cucito)
% =========================================================================
ax3 = axes('Position', [left_m, bot_y(2), full_w, bot_h(2)], ...
           'Color', 'w', 'Parent', fig);
hold(ax3, 'on');
e_lo = min(err_vec) - 1;  e_hi = max(err_vec) + 1;
draw_seg_bands(ax3, e_lo, e_hi);
draw_seg_xlines(ax3);

area(ax3, t_min(1:length(err_vec)), err_vec, ...
     'FaceColor',c_err,'FaceAlpha',0.28,'EdgeColor',c_err, ...
     'LineWidth',1.3,'DisplayName','e(t) = T1 − r');
yline(ax3,  0, '-k',  'LineWidth',1.0, 'HandleVisibility','off');
yline(ax3,  2, '--', 'Color',[0.0 0.6 0.1],'LineWidth',1.2,'DisplayName','±2°C');
yline(ax3, -2, '--', 'Color',[0.0 0.6 0.1],'LineWidth',1.2,'HandleVisibility','off');

ylabel(ax3, 'Errore [°C]','FontSize',10,'Color','k');
legend(ax3, 'Location','best','FontSize',8);
grid(ax3, 'on');
title(ax3, 'Errore di inseguimento e(t) = T1 − r','FontSize',11,'FontWeight','bold','Color','k');
set(ax3, 'XTickLabel',[],'XColor','k','YColor','k', ...
         'GridColor',[0.15 0.15 0.15],'GridAlpha',0.3);

% =========================================================================
% BOT3 — Costo lossSat (cucito)
% =========================================================================
ax4 = axes('Position', [left_m, bot_y(3), full_w, bot_h(3)], ...
           'Color', 'w', 'Parent', fig);
hold(ax4, 'on');
draw_seg_xlines(ax4);

plot(ax4, t_min(1:length(cost_vec)), cost_vec, '-', ...
     'Color',[c_cost, 0.30],'LineWidth',0.9,'DisplayName','c(t) istantaneo');
if length(cost_vec) >= 8
    plot(ax4, t_min(1:length(cost_vec)), movmean(cost_vec,8), '-', ...
         'Color',c_cost,'LineWidth',2.2,'DisplayName','movmean(8)');
end

% RMSE e % entro ±2°C sull'intero episodio
rmse_tot = sqrt(mean(err_vec.^2));
pct_tot  = 100 * mean(abs(err_vec) < 2);
text(ax4, t_min(end)*0.98, 0.90, ...
     sprintf('RMSE = %.2f°C  |  %d%% step entro ±2°C', rmse_tot, round(pct_tot)), ...
     'HorizontalAlignment','right','FontSize',8.5,'Color','k', ...
     'BackgroundColor','w','EdgeColor',[0.7 0.7 0.7]);

xlabel(ax4, 'Tempo [min]','FontSize',10,'Color','k');
ylabel(ax4, 'Costo lossSat','FontSize',10,'Color','k');
ylim(ax4, [0, 1.05]);
legend(ax4, 'Location','best','FontSize',8);
grid(ax4, 'on');
title(ax4, 'Costo lossSat — segnale cucito','FontSize',11,'FontWeight','bold','Color','k');
set(ax4, 'XColor','k','YColor','k', ...
         'GridColor',[0.15 0.15 0.15],'GridAlpha',0.3);

% -------------------------------------------------------------------------
% Legende bianche
% -------------------------------------------------------------------------
for aa = [ax2, ax3, ax4]
    lg = findobj(aa, 'Type','Legend');
    if ~isempty(lg)
        set(lg, 'TextColor','k','EdgeColor',[0.5 0.5 0.5],'Color','w');
    end
end

% -------------------------------------------------------------------------
% sgtitle globale
% -------------------------------------------------------------------------
Tamb_str = strjoin(arrayfun(@(x) sprintf('%.0f',x), Tamb_segments, ...
           'UniformOutput',false), ', ');
sgtitle(sprintf(['Caso 2 — T_{set} = %.0f°C  |  T_{amb} = [%s]°C  |  ' ...
                 'dt = %ds  |  Q2 \\in [%.0f, %.0f]%%'], ...
        Tset_val, Tamb_str, dt, Q2_min, Q2_max), ...
        'FontWeight','bold','FontSize',12,'Color','k');

drawnow;
end