function draw_case3_results(latent, realCost, ...
                            latent_single, realCost_single, ...
                            stair_latent, stair_realCost, stair_actions, ...
                            plant, cost, J, N, ...
                            Tset_train, Tset_stair_eval, H_step_eval, Q2_eval)
% draw_case3_results  Visualizza i risultati del Caso 3.
%
% Figure 13 — Training overview (stile Caso 2):
%   [1,2] Traiettorie T1 (grigio=casuali, colori=PILCO per Tset)
%   [3]   Progressione PILCO per il primo Tset
%   [4]   Costo per trial (colori per Tset)
%   [5,6] Costo medio per iterazione PILCO
%
% Figure 14 — Scalinata di valutazione (layout 2×3):
%   RIGA 1:
%   [1,2] T1(t) vs Tset(t) — traiettoria completa con sfondo colorato per gradino
%   [3]   Errore e(t) = T1 - Tset con banda ±2°C
%   RIGA 2:
%   [4,5] Q1(t) — azione di controllo [%] — NUOVO
%   [6]   Errore finale per gradino (barre colorate)
%
% Input
%   stair_actions  {1×nSteps}  Q1 [%] per ogni gradino (da rollout xx(:,end)+50)
%   Q2_eval        valore disturbo per la valutazione

nT      = length(Tset_train);
nS      = length(Tset_stair_eval);
n_train = length(latent);

colors_tset  = lines(nT);
colors_stair = cool(nS);

% Costo scalare per ogni trial
all_costs = zeros(1, n_train);
for k = 1:n_train
    if ~isempty(realCost{k}), all_costs(k) = sum(realCost{k}); end
end
y_top = max([all_costs, 0.01]) * 1.05;

% Mappa trial → indice Tset
tamb_of_trial = zeros(1, n_train);
for k = 1:J
    tamb_of_trial(k) = mod(k-1, nT) + 1;
end
for j = 1:N
    for tt = 1:nT
        idx = J + (j-1)*nT + tt;
        if idx <= n_train, tamb_of_trial(idx) = tt; end
    end
end


%% ================================================================
%% Figure 13 — Training overview
%% ================================================================
figure(13); clf;
set(gcf, 'Position', [50, 50, 1300, 820], 'Name', 'Case 3 — Training');

% --- [1,2] Tutte le traiettorie T1 ---
subplot(2,3,[1 2]); hold on;

for jj = 1:min(J, n_train)
    if isempty(latent{jj}), continue; end
    T1 = latent{jj}(:,1) + latent{jj}(:,3);
    t  = (0:length(T1)-1) * plant.dt / 60;
    hv = 'off'; if jj==1, hv='on'; end
    plot(t, T1, '--', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8, ...
         'DisplayName', 'Rollout casuali', 'HandleVisibility', hv);
end

for j = 1:N
    for tt = 1:nT
        idx = J + (j-1)*nT + tt;
        if idx > n_train || isempty(latent{idx}), continue; end
        T1 = latent{idx}(:,1) + latent{idx}(:,3);
        t  = (0:length(T1)-1) * plant.dt / 60;
        af = 0.25 + 0.75*(j/N);
        c  = af*colors_tset(tt,:) + (1-af)*[1 1 1];
        lw = 0.8 + 1.8*(j/N);
        if j == N
            plot(t, T1, '-', 'Color', colors_tset(tt,:), 'LineWidth', 2.5, ...
                 'DisplayName', sprintf('Tset=%2.0f°C (finale)', Tset_train(tt)));
            yline(Tset_train(tt), '--', 'Color', colors_tset(tt,:)*0.7, ...
                  'LineWidth', 1.0, 'HandleVisibility','off', 'Alpha', 0.5);
        else
            plot(t, T1, '-', 'Color', c, 'LineWidth', lw, 'HandleVisibility','off');
        end
    end
end

% Linea T1_init per vedere i casi e>0
yline(25, ':k', 'LineWidth', 1.0, 'DisplayName', 'T1_{init}=25°C (sopra→e>0)');

xlabel('Tempo [min]'); ylabel('T1 [°C]');
title({'Overview Training: traiettorie T1 per Tset vari', ...
       '(Tset<25°C → e_{init}>0: training sul raffreddamento)'});
legend('Location','eastoutside','FontSize',8); grid on;
ylim([10 65]);

% --- [3] Progressione PILCO per Tset_train(1) ---
subplot(2,3,3); hold on;
tt_show = 1;
for j = 1:N
    idx = J + (j-1)*nT + tt_show;
    if idx > n_train || isempty(latent{idx}), continue; end
    T1 = latent{idx}(:,1) + latent{idx}(:,3);
    t  = (0:length(T1)-1) * plant.dt / 60;
    c_j = [0.1, 0.3+0.5*(j/N), 0.8*(1-j/N)+0.2];
    plot(t, T1, '-o', 'Color', c_j, 'LineWidth', 1.5, 'MarkerSize', 3, ...
         'DisplayName', sprintf('Iter %d', j));
end
yline(Tset_train(tt_show), '-.r', 'LineWidth', 2, ...
      'DisplayName', sprintf('Target %.0f°C', Tset_train(tt_show)));
xlabel('Tempo [min]'); ylabel('T1 [°C]');
title(sprintf('Progressione PILCO — Tset=%.0f°C', Tset_train(tt_show)));
legend('Location','southeast','FontSize',7); grid on; ylim([10 65]);

% --- [4] Costo per trial ---
subplot(2,3,4); hold on;
for k = 1:n_train
    tt = tamb_of_trial(k);
    if k <= J
        bar(k, all_costs(k), 'FaceColor', [0.75 0.75 0.75], 'EdgeColor','none');
    elseif tt > 0
        bar(k, all_costs(k), 'FaceColor', colors_tset(tt,:), 'EdgeColor','none');
    end
end
xline(J+0.5, 'r-.', 'LineWidth', 2);
text(J/2+0.5, y_top*0.93, 'Casuali', 'HorizontalAlignment','center', ...
     'Color',[0.5 0.5 0.5], 'FontWeight','bold', 'FontSize', 8);
if J + N*nT/2 <= n_train
    text(J + N*nT/2, y_top*0.93, 'PILCO', 'HorizontalAlignment','center', ...
         'Color','r', 'FontWeight','bold', 'FontSize', 8);
end
for tt = 1:nT
    patch(NaN, NaN, colors_tset(tt,:), 'DisplayName', sprintf('Tset=%.0f°C',Tset_train(tt)));
end
xlabel('Trial #'); ylabel('Costo totale');
title('Costo per trial (colore = Tset)');
legend('Location','northeast','FontSize',7); grid on;

% --- [5,6] Costo medio per iterazione ---
subplot(2,3,[5 6]); hold on;
if J > 0
    bar(0, mean(all_costs(1:J)), 'FaceColor', [0.75 0.75 0.75], 'EdgeColor','k');
end
for j = 1:N
    idx_s = J + (j-1)*nT + 1;
    idx_e = min(J + j*nT, n_train);
    if idx_s > n_train, continue; end
    cm = mean(all_costs(idx_s:idx_e));
    bar(j, cm, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor','k');
    text(j, cm + 0.01*y_top, sprintf('%.3f',cm), ...
         'HorizontalAlignment','center', 'FontSize', 7);
end
xlabel('Iterazione (0=casuali)'); ylabel('Costo medio');
title('Apprendimento PILCO — deve decrescere');
xticks(0:N);
xticklabels(['Casuali', arrayfun(@(j) sprintf('Iter %d',j), 1:N, 'UniformOutput',false)]);
xtickangle(30); grid on;

sgtitle(sprintf('Case 3 — Training  |  Tset_{train} = %s °C', mat2str(Tset_train)), ...
        'FontWeight','bold', 'FontSize', 13);
drawnow;


%% ================================================================
%% Figure 14 — Valutazione scalinata (layout 2×3)
%% ================================================================
figure(14); clf;
set(gcf, 'Position', [50, 50, 1400, 780], 'Name', 'Case 3 — Scalinata Eval');

% --- Assembla traiettorie complete stitching gradini ---
T1_full   = [];
T2_full   = [];
e_full    = [];
Q1_full   = [];
Tref_full = [];
t_full    = [];
step_boundaries = [];
t_offset  = 0;

for s = 1:nS
    if s > length(stair_latent) || isempty(stair_latent{s}), continue; end
    lt     = stair_latent{s};
    e_seg  = lt(:,1);
    T2_seg = lt(:,2);
    Ts_s   = lt(1,3);
    T1_seg = e_seg + Ts_s;
    n_seg  = size(lt,1);        % H_step_eval+1 punti
    t_seg  = (0:n_seg-1) * plant.dt/60 + t_offset;

    % Q1: H_step_eval valori di azione; estendi a n_seg ripetendo il primo
    if s <= length(stair_actions) && ~isempty(stair_actions{s})
        q1_seg = [stair_actions{s}(1); stair_actions{s}];   % n_seg×1
    else
        q1_seg = NaN(n_seg, 1);
    end

    step_boundaries(end+1) = t_offset; %#ok
    if s == 1
        T1_full=T1_seg; T2_full=T2_seg; e_full=e_seg;
        Q1_full=q1_seg; Tref_full=Ts_s*ones(n_seg,1); t_full=t_seg';
    else
        % Salta primo punto (uguale all'ultimo del gradino precedente)
        T1_full   = [T1_full;   T1_seg(2:end)];
        T2_full   = [T2_full;   T2_seg(2:end)];
        e_full    = [e_full;    e_seg(2:end)];
        Q1_full   = [Q1_full;   q1_seg(2:end)];
        Tref_full = [Tref_full; Ts_s*ones(n_seg-1,1)];
        t_full    = [t_full;    t_seg(2:end)'];
    end
    t_offset = t_offset + (n_seg-1)*plant.dt/60;
end
step_boundaries(end+1) = t_offset;

% Helper: sfondo colorato + linee verticali di cambio setpoint
function plot_step_bg(step_boundaries, colors_stair, nS, y_lo, y_hi)
    for s = 1:nS
        fill([step_boundaries(s) step_boundaries(s+1) ...
              step_boundaries(s+1) step_boundaries(s)], ...
             [y_lo y_lo y_hi y_hi], colors_stair(s,:), ...
             'FaceAlpha',0.07,'EdgeColor','none','HandleVisibility','off');
    end
    for s = 2:length(step_boundaries)-1
        xline(step_boundaries(s),':k','LineWidth',1.5, ...
              'HandleVisibility','off','Alpha',0.6);
    end
end

T1_lo = min([T1_full; Tref_full])-8;
T1_hi = max([T1_full; Tref_full])+12;

% ====== RIGA 1 ======

% --- [1,2] T1(t) vs riferimento ---
subplot(2,3,[1 2]); hold on;
plot_step_bg(step_boundaries, colors_stair, nS, T1_lo, T1_hi);
plot(t_full, Tref_full, 'r--', 'LineWidth', 2.5, 'DisplayName', 'Rif. T_{set}(t)');
plot(t_full, T1_full,   'b-',  'LineWidth', 2.0, 'DisplayName', 'T1(t) — policy');

% Annotazioni errore finale per gradino
for s = 1:nS
    if s > length(stair_latent) || isempty(stair_latent{s}), continue; end
    e_fin_s = stair_latent{s}(end,1);
    t_mid   = (step_boundaries(s)+step_boundaries(s+1))/2;
    text(t_mid, T1_hi-2, sprintf('err=%+.1f°',e_fin_s), ...
         'HorizontalAlignment','center','FontSize',8, ...
         'Color', local_sign_color(e_fin_s), 'FontWeight','bold');
    % Etichetta cambio setpoint
    if s < nS
        text(step_boundaries(s+1)+0.1, T1_lo+3, ...
             sprintf('→%.0f°C',Tset_stair_eval(s+1)), ...
             'FontSize',7,'Color',[0.3 0.3 0.3],'Rotation',90);
    end
end

xlabel('Tempo [min]'); ylabel('T1 [°C]');
title({'Inseguimento scalinata — policy PILCO', ...
       '(nessun gradino visto durante il training)'});
legend('Location','eastoutside','FontSize',9); grid on;
ylim([T1_lo, T1_hi]);

% --- [3] Errore e(t) ---
subplot(2,3,3); hold on;
e_lo = -max(abs(e_full))*1.2-2;
e_hi =  max(abs(e_full))*1.2+2;
plot_step_bg(step_boundaries, colors_stair, nS, e_lo, e_hi);
fill([t_full(1) t_full(end) t_full(end) t_full(1)], [-2 -2 2 2], ...
     [0.8 1.0 0.8],'EdgeColor','none','FaceAlpha',0.5,'DisplayName','±2°C OK');
yline(0, '-r', 'LineWidth', 1.5, 'DisplayName', 'e = 0');
plot(t_full, e_full, 'b-', 'LineWidth', 1.8, 'DisplayName', 'e(t)=T1−T_{set}');
xlabel('Tempo [min]'); ylabel('Errore e [°C]');
title('Errore di inseguimento e(t) = T1 − T_{set}');
legend('Location','northeast','FontSize',8); grid on;
ylim([e_lo, e_hi]);


% ====== RIGA 2 ======

% --- [4,5] Q1(t) azione di controllo ---
subplot(2,3,[4 5]); hold on;
plot_step_bg(step_boundaries, colors_stair, nS, -5, 110);

yline(Q2_eval, '--', 'Color', [0.55 0.0 0.75], 'LineWidth', 1.8, ...
      'DisplayName', sprintf('Q2 disturbo = %.1f%%', Q2_eval));
yline(0,   ':k', 'LineWidth', 0.8, 'HandleVisibility','off');
yline(100, ':k', 'LineWidth', 0.8, 'HandleVisibility','off');

plot(t_full, Q1_full, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, ...
     'DisplayName', 'Q1(t) — potenza heater [%]');

% Media Q1 per gradino
for s = 1:nS
    if s > length(stair_actions) || isempty(stair_actions{s}), continue; end
    q1m   = mean(stair_actions{s});
    t_mid = (step_boundaries(s)+step_boundaries(s+1))/2;
    text(t_mid, 105, sprintf('%.0f%%',q1m), ...
         'HorizontalAlignment','center','FontSize',8,'Color',[0.6 0.2 0.0],'FontWeight','bold');
end

xlabel('Tempo [min]'); ylabel('Potenza Q1 [%]');
title({'Azione di controllo Q1(t)', '(0% = spento, 100% = piena potenza)'});
legend('Location','eastoutside','FontSize',9); grid on;
ylim([-5, 115]);

% --- [6] Errore finale per gradino (barre) ---
subplot(2,3,6); hold on;
e_finals  = zeros(1,nS);
for s = 1:nS
    if ~isempty(stair_latent{s})
        e_finals(s) = stair_latent{s}(end,1);
    end
end
b = bar(1:nS, e_finals, 'FaceColor','flat', 'EdgeColor','k', 'LineWidth', 1.2);
for s = 1:nS, b.CData(s,:) = local_sign_color(e_finals(s)); end
yline(0,  '-k',  'LineWidth', 2);
yline( 2, ':g',  'LineWidth', 1.5, 'DisplayName', '±2°C tolleranza');
yline(-2, ':g',  'LineWidth', 1.5, 'HandleVisibility','off');
for s = 1:nS
    yoff = sign(e_finals(s)+0.001) * 0.5;
    text(s, e_finals(s)+yoff, sprintf('%+.2f°',e_finals(s)), ...
         'HorizontalAlignment','center','FontSize',9,'FontWeight','bold', ...
         'Color', local_sign_color(e_finals(s)));
end
xticks(1:nS);
xticklabels(arrayfun(@(T) sprintf('Tset\n%.0f°C',T), Tset_stair_eval,'UniformOutput',false));
ylabel('Errore finale e_{fin} [°C]');
title({'Errore finale per gradino', '(verde<2°, arancione 2–5°, rosso>5°)'});
grid on; box on;
legend('Location','northeast','FontSize',8);

sgtitle(sprintf('Case 3 — Scalinata Eval  |  T_{set}=%s°C (mai vista)  |  Q2=%.1f%%', ...
                mat2str(Tset_stair_eval), Q2_eval), ...
        'FontWeight','bold','FontSize',12);
drawnow;

end   % fine draw_case3_results


%% ================================================================
%% Funzione locale: sfondo colorato per gradini
%% ================================================================
function plot_step_bg(step_boundaries, colors_stair, nS, y_lo, y_hi)
    for s = 1:nS
        if s+1 > length(step_boundaries), break; end
        fill([step_boundaries(s) step_boundaries(s+1) ...
              step_boundaries(s+1) step_boundaries(s)], ...
             [y_lo y_lo y_hi y_hi], colors_stair(s,:), ...
             'FaceAlpha',0.07,'EdgeColor','none','HandleVisibility','off');
    end
    for s = 2:length(step_boundaries)-1
        xline(step_boundaries(s),':k','LineWidth',1.5, ...
              'HandleVisibility','off','Alpha',0.6);
    end
end


%% ================================================================
%% Funzione locale: colore basato sull'errore
%% ================================================================
function c = local_sign_color(err)
    if abs(err) < 2
        c = [0.0, 0.6, 0.1];    % verde
    elseif abs(err) < 5
        c = [0.8, 0.5, 0.0];    % arancione
    else
        c = [0.8, 0.1, 0.1];    % rosso
    end
end