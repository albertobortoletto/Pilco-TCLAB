function draw_case2_training(latent, realCost, J, N, dt, Tamb_train, cost_target)
% draw_case2_training  Visualizzazione storico training — Caso 2.
%
% Signature:
%   draw_case2_training(latent, realCost, J, N, dt, Tamb_train, cost_target)
%
% Input:
%   latent{k}    → (H+1) × 3  matrice [T1, T2, Tamb] per il k-esimo rollout
%   realCost{k}  → H × 1      costo lossSat per step
%   J            → numero rollout casuali (k=1..J)
%   N            → numero iterazioni PILCO
%   dt           → intervallo di campionamento [s]
%   Tamb_train   → vettore temperatura ambiente training [°C]
%   cost_target  → target T1 [°C]
%
% Struttura rollout:
%   k=1..J             → J casuali ciclati su Tamb_train
%   k=J+1..J+N*nT_train → N iterazioni × nT_train Tamb per iterazione
%
% Subplot (3 righe):
%   SP1: Traiettorie T1 [°C] per ogni Tamb di training
%   SP2: Costo per rollout raggruppato per Tamb
%   SP3: Costo medio per iterazione PILCO (curva di convergenza)

% =========================================================================
% G2: Colori come variabili locali
% =========================================================================
c_random_base = [0.7 0.7 0.7];    % grigio per rollout casuali (G9)
nT_train = length(Tamb_train);
c_tamb   = lines(nT_train);       % un colore per ogni Tamb

K_tot = length(latent);            % rollout totali disponibili

% =========================================================================
% G7: Figura
% =========================================================================
fig = figure('NumberTitle', 'off', ...
             'Name', 'Caso 2 — Training', ...
             'Color', 'w');                         % G1
clf(fig);
set(fig, 'Position', [80, 50, 1100, 950]);
set(fig, 'InvertHardcopy', 'off');

% =========================================================================
% SP1: Traiettorie T1 [°C] per ogni Tamb di training
% =========================================================================
ax1 = subplot(3, 1, 1); hold on;
set(ax1, 'Color', 'w');                             % G1

% Yline per Tset
yline(ax1, cost_target, '--', 'Color', [0.85 0.13 0.13], ...
      'LineWidth', 1.5, 'DisplayName', sprintf('T_{set}=%.0f°C', cost_target));

% Legenda tracker: una entry per Tamb
legend_entries_done = false(1, nT_train);

% --- Rollout casuali (k=1..J): tratteggiate per Tamb ---
for k = 1:J
    if k > K_tot, break; end
    lt = latent{k};
    Tamb_k = lt(1, 3);                             % Tamb del rollout
    tt_idx = find_tamb_idx(Tamb_k, Tamb_train);
    H_k = size(lt, 1) - 1;
    t_k = (0:H_k)' * dt / 60;

    hv = 'off';
    dn = '';
    if ~legend_entries_done(tt_idx)
        hv = 'on';
        dn = sprintf('Tamb=%.0f°C', Tamb_train(tt_idx));
        legend_entries_done(tt_idx) = true;
    end
    plot(ax1, t_k, lt(:,1), '--', 'Color', [c_tamb(tt_idx,:), 0.4], ...
         'LineWidth', 1, 'HandleVisibility', hv, 'DisplayName', dn);
end

% --- Rollout PILCO (k=J+1..K_tot): continue con LineWidth crescente ---
for j = 1:N
    for tt = 1:nT_train
        k = J + (j-1)*nT_train + tt;
        if k > K_tot, continue; end
        lt = latent{k};
        H_k = size(lt, 1) - 1;
        t_k = (0:H_k)' * dt / 60;
        lw = 1 + 0.3*(j-1);
        plot(ax1, t_k, lt(:,1), '-', 'Color', c_tamb(tt,:), ...
             'LineWidth', lw, 'HandleVisibility', 'off');
    end
end

ylabel(ax1, 'T1 [°C]', 'FontSize', 11);             % G4
legend(ax1, 'Location', 'best', 'FontSize', 9);      % G5
grid(ax1, 'on');                                      % G3
title(ax1, 'Traiettorie T1 per Tamb di training', 'FontSize', 12);

% =========================================================================
% SP2: Costo per rollout raggruppato per Tamb
% =========================================================================
ax2 = subplot(3, 1, 2); hold on;
set(ax2, 'Color', 'w');                              % G1

% Calcola costi totali
costs_tot = zeros(1, K_tot);
for k = 1:K_tot
    if ~isempty(realCost{k})
        costs_tot(k) = sum(realCost{k});
    else
        costs_tot(k) = NaN;
    end
end

% Barre per tutti i rollout
for k = 1:K_tot
    if k <= J
        % Casuale: colore per Tamb
        lt = latent{k};
        tt_idx = find_tamb_idx(lt(1,3), Tamb_train);
        bar(ax2, k, costs_tot(k), 'FaceColor', c_tamb(tt_idx,:), ...
            'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    else
        % PILCO: colore per Tamb
        j_iter = floor((k - J - 1) / nT_train) + 1;
        tt = mod(k - J - 1, nT_train) + 1;
        bar(ax2, k, costs_tot(k), 'FaceColor', c_tamb(tt,:), ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

% xline tra casuali e PILCO
if J > 0 && N > 0
    xline(ax2, J + 0.5, '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.5, ...
          'HandleVisibility', 'off');
end

% xline tra iterazioni PILCO
for j = 1:N-1
    xpos = J + j * nT_train + 0.5;
    xline(ax2, xpos, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, ...
          'HandleVisibility', 'off');
end

% Etichette iterazione sopra ogni gruppo
y_top = max(costs_tot(~isnan(costs_tot))) * 1.02;
if isempty(y_top) || isnan(y_top), y_top = 1; end
for j = 1:N
    x_center = J + (j-0.5)*nT_train + 0.5;
    text(ax2, x_center, y_top, sprintf('Iter %d', j), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, ...
         'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
end

ylabel(ax2, 'Costo totale episodio', 'FontSize', 11);
grid(ax2, 'on');                                      % G3
title(ax2, 'Costo per rollout', 'FontSize', 12);

% =========================================================================
% SP3: Costo medio per iterazione PILCO (curva di convergenza)
% =========================================================================
ax3 = subplot(3, 1, 3); hold on;
set(ax3, 'Color', 'w');                              % G1

% Costo medio per iterazione
cost_mean_iter = zeros(1, N);
for j = 1:N
    costi_j = [];
    for tt = 1:nT_train
        k = J + (j-1)*nT_train + tt;
        if k <= K_tot && ~isempty(realCost{k})
            costi_j(end+1) = sum(realCost{k});       %#ok
        end
    end
    if ~isempty(costi_j)
        cost_mean_iter(j) = mean(costi_j);
    else
        cost_mean_iter(j) = NaN;
    end
end

% Baseline: media costo rollout casuali
costi_rand = [];
for k = 1:J
    if k <= K_tot && ~isempty(realCost{k})
        costi_rand(end+1) = sum(realCost{k});        %#ok
    end
end
if ~isempty(costi_rand)
    baseline = mean(costi_rand);
    yline(ax3, baseline, '--', 'Color', c_random_base, 'LineWidth', 1.5, ...
          'DisplayName', sprintf('Media casuali (%.2f)', baseline));
end

plot(ax3, 1:N, cost_mean_iter, '-o', 'Color', [0.00 0.45 0.74], ...
     'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', [0.00 0.45 0.74], ...
     'DisplayName', 'Costo medio PILCO');

xlabel(ax3, 'Iterazione PILCO', 'FontSize', 11);     % G4
ylabel(ax3, 'Costo medio su tutte le Tamb', 'FontSize', 11);
legend(ax3, 'Location', 'best', 'FontSize', 9);
grid(ax3, 'on');                                      % G3
title(ax3, 'Convergenza: costo medio per iterazione', 'FontSize', 12);

% =========================================================================
% Stile comune
% =========================================================================
for aa = [ax1, ax2, ax3]
    set(aa, 'XColor', 'k', 'YColor', 'k');
    set(aa, 'GridColor', [0.15 0.15 0.15], 'GridAlpha', 0.3);
    set(get(aa, 'Title'), 'Color', 'k', 'FontWeight', 'bold');
    set(get(aa, 'XLabel'), 'Color', 'k');
    set(get(aa, 'YLabel'), 'Color', 'k');
end

% Legende con sfondo bianco
for aa = [ax1, ax2, ax3]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% G8: sgtitle
Tamb_str = mat2str(Tamb_train);
sgtitle(sprintf('Caso 2 — Training: T_{set}=%.0f°C | Tamb training=%s°C', ...
        cost_target, Tamb_str), ...
        'FontWeight', 'bold', 'FontSize', 13, 'Color', 'k');

% G6: drawnow
drawnow;

end

% =========================================================================
% Helper locale: trova l'indice della Tamb più vicina nel vettore training
% =========================================================================
function idx = find_tamb_idx(Tamb_val, Tamb_vec)
    [~, idx] = min(abs(Tamb_vec - Tamb_val));
end
