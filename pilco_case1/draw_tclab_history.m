function draw_tclab_history(latent, realCost, plant, cost, J, N, actions)
% draw_tclab_history  Storico training Case 1: T1, Q1 (opt), costo per trial.
%
% LAYOUT con Q1 (3 pannelli verticali, stesso asse x):
%   Pannello 1 (alto)  : T1(t) — tutti i trial, grigio=casuali, colori=PILCO
%   Pannello 2 (medio) : Q1(t) [%] — azione di controllo  ← NUOVO
%   Pannello 3 (basso) : Costo totale per trial (barre)
%   linkaxes([ax_T1, ax_Q1], 'x') → x allineato
%
% LAYOUT senza Q1 (2 pannelli, comportamento originale):
%   Pannello 1 : T1(t)
%   Pannello 2 : Costo per trial
%
% Input:
%   latent    {1×n_trial}  ogni cella (H+1)×nState — traiettorie di stato
%   realCost  {1×n_trial}  ogni cella 1×H — costo per step
%   plant     struct PILCO (plant.dt, plant.dyno)
%   cost      struct PILCO (cost.target)
%   J         rollout casuali iniziali
%   N         iterazioni PILCO
%   actions   {1×n_trial}  Q1 [%] per ogni trial  (opzionale)
%             Se non fornito (nargin<7), il pannello Q1 non viene disegnato.
%             Q1 si ottiene da rollout come: xx(:,end)+50 ∈ [0,100]%
%
% Per raccogliere actions in case1_learn.m, aggiungere nella fase rollout:
%   [xx,yy,rc,lt] = rollout(...)
%   actions{end+1} = xx(:,end)+50;   % policy output→Q1 fisico
% e passare actions come 7° argomento a draw_tclab_history.

if nargin < 7 || isempty(actions)
    has_Q1  = false;
    n_rows  = 2;
    fig_h   = 650;
else
    has_Q1  = true;
    n_rows  = 3;
    fig_h   = 900;
end

n_trial = length(latent);
colors_pilco = lines(N);

figure(10); clf;
set(gcf, 'Position', [50, 50, 950, fig_h], 'Name', 'Case 1 — Training');

% ================================================================
% Pannello 1: T1(t)
% ================================================================
ax_T1 = subplot(n_rows, 1, 1);
hold(ax_T1, 'on');

% Rollout casuali (grigio tratteggiato)
for jj = 1:J
    if jj > n_trial || isempty(latent{jj}), continue; end
    T1 = latent{jj}(:, plant.dyno(1));
    t  = (0:length(T1)-1) * plant.dt / 60;
    hv = 'off'; if jj==1, hv='on'; end
    plot(ax_T1, t, T1, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.0, ...
         'DisplayName', 'Rollout casuali', 'HandleVisibility', hv);
end

% Iterazioni PILCO (colori distinti, crescente luminosità = iter avanzate)
for jj = 1:N
    idx = J + jj;
    if idx > n_trial || isempty(latent{idx})
        idx = jj;   % fallback se mancano trial
    end
    if idx > n_trial || isempty(latent{idx}), continue; end
    T1 = latent{idx}(:, plant.dyno(1));
    t  = (0:length(T1)-1) * plant.dt / 60;
    plot(ax_T1, t, T1, '-o', 'Color', colors_pilco(jj,:), 'LineWidth', 2.0, ...
         'MarkerSize', 4, 'DisplayName', sprintf('PILCO iter %d', jj));
end

yline(cost.target(1), '-.r', 'LineWidth', 2.5, ...
      'DisplayName', sprintf('Target %.0f°C', cost.target(1)), 'Parent', ax_T1);

ylabel(ax_T1, 'T1 [°C]');
title(ax_T1, 'Storico T1 — tutti i trial (grigio=casuali, colori=PILCO)');
legend(ax_T1, 'Location', 'eastoutside', 'FontSize', 9);
grid(ax_T1, 'on');
ylim(ax_T1, [min(cost.target(1))-15, max(cost.target(1))+20]);

% Rimuovi etichetta x se ci sono pannelli sotto
if has_Q1
    set(ax_T1, 'XTickLabel', []);
else
    xlabel(ax_T1, 'Tempo [min]');
end


% ================================================================
% Pannello 2: Q1(t)  — solo se actions disponibili
% ================================================================
if has_Q1
    ax_Q1 = subplot(n_rows, 1, 2);
    hold(ax_Q1, 'on');

    % Rollout casuali Q1
    for jj = 1:J
        if jj > n_trial || isempty(actions{jj}), continue; end
        q1  = actions{jj};
        t_q = (0:length(q1)-1) * plant.dt / 60;
        hv  = 'off'; if jj==1, hv='on'; end
        stairs(ax_Q1, t_q, q1, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.0, ...
               'DisplayName', 'Rollout casuali', 'HandleVisibility', hv);
    end

    % PILCO Q1
    for jj = 1:N
        idx = J + jj;
        if idx > n_trial || isempty(actions{idx})
            idx = jj;
        end
        if idx > n_trial || isempty(actions{idx}), continue; end
        q1  = actions{idx};
        t_q = (0:length(q1)-1) * plant.dt / 60;
        stairs(ax_Q1, t_q, q1, '-', 'Color', colors_pilco(jj,:), 'LineWidth', 2.0, ...
               'DisplayName', sprintf('PILCO iter %d', jj));
    end

    yline(0,   ':k', 'LineWidth', 0.8, 'HandleVisibility','off', 'Parent', ax_Q1);
    yline(100, ':k', 'LineWidth', 0.8, 'HandleVisibility','off', 'Parent', ax_Q1);

    ylabel(ax_Q1, 'Q1 [%]');
    title(ax_Q1, 'Azione di controllo Q1(t) — potenza heater 1');
    legend(ax_Q1, 'Location', 'eastoutside', 'FontSize', 9);
    grid(ax_Q1, 'on');
    ylim(ax_Q1, [-5, 110]);
    set(ax_Q1, 'XTickLabel', []);   % etichetta x gestita dal pannello sotto

    % ← ALLINEAMENTO: T1 e Q1 condividono esattamente lo stesso asse x
    linkaxes([ax_T1, ax_Q1], 'x');
end


% ================================================================
% Pannello ultimo: Costo totale per trial
% ================================================================
ax_cost = subplot(n_rows, 1, n_rows);
hold(ax_cost, 'on');

tutti_costi = zeros(1, n_trial);
for jj = 1:n_trial
    if ~isempty(realCost{jj}), tutti_costi(jj) = sum(realCost{jj}); end
end
y_top_c = max(tutti_costi) * 1.05;

for jj = 1:n_trial
    if jj <= J
        bar(ax_cost, jj, tutti_costi(jj), 'FaceColor', [0.6 0.6 0.6], 'EdgeColor','none');
    else
        pilco_idx = jj - J;
        if pilco_idx > N, pilco_idx = N; end
        bar(ax_cost, jj, tutti_costi(jj), 'FaceColor', colors_pilco(pilco_idx,:), 'EdgeColor','none');
    end
end

xline(J+0.5, 'r-.', 'LineWidth', 2, 'Parent', ax_cost);
if y_top_c > 0
    text(ax_cost, J/2+0.5,     y_top_c*0.92, 'Rollout casuali', ...
         'HorizontalAlignment','center','Color',[0.5 0.5 0.5],'FontWeight','bold');
    if J+N/2+0.5 <= n_trial
        text(ax_cost, J+N/2+0.5, y_top_c*0.92, 'PILCO', ...
             'HorizontalAlignment','center','Color','r','FontWeight','bold');
    end
end

xlabel(ax_cost, 'Trial #');
ylabel(ax_cost, 'Costo totale');
title(ax_cost, 'Costo reale per trial — deve scendere con PILCO');
grid(ax_cost, 'on');

sgtitle(sprintf('Case 1 — TCLab PILCO  |  Target=%.0f°C  |  J=%d, N=%d', ...
                cost.target(1), J, N), 'FontWeight','bold', 'FontSize',13);
drawnow;