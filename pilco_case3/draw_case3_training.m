function draw_case3_training(latent, realCost, J, N, dt, ...
                              Tset_train, nT_train, T1_init)
% draw_case3_training  Visualizzazione storico training — Caso 3.
%
% Signature:
%   draw_case3_training(latent, realCost, J, N, dt,
%                       Tset_train, nT_train, T1_init)
%
% Input:
%   latent{k}    → (H+1) × 4  matrice [e, T2, Tset, Q2] per il k-esimo rollout
%                  NOTA: T1 = e + Tset → da ricostruire come lt(:,1) + lt(:,3)
%   realCost{k}  → H × 1      costo lossSat per step
%   J            → numero rollout casuali (k=1..J)
%   N            → numero iterazioni PILCO
%   dt           → intervallo di campionamento [s]
%   Tset_train   → vettore setpoint di training [°C]
%   nT_train     → length(Tset_train)
%   T1_init      → temperatura iniziale T1 [°C]
%
% Struttura rollout:
%   k=1..J               → J casuali ciclati su Tset_train
%   k=J+1..J+N*nT_train  → N iterazioni × nT_train Tset per iterazione
%
% Subplot (3 righe):
%   SP1: Traiettorie T1 RICOSTRUITE [°C] per ogni Tset di training
%   SP2: Errore finale |e_fin| per rollout
%   SP3: Costo medio per iterazione PILCO (curva di convergenza)

% =========================================================================
% G2: Colori come variabili locali
% =========================================================================
c_random_base = [0.7 0.7 0.7];    % grigio per rollout casuali (G9)
c_tset   = lines(nT_train);       % un colore per ogni Tset

K_tot = length(latent);            % rollout totali disponibili

% =========================================================================
% G7: Figura
% =========================================================================
fig = figure('NumberTitle', 'off', ...
             'Name', 'Caso 3 — Training', ...
             'Color', 'w');                         % G1
clf(fig);
set(fig, 'Position', [80, 50, 1100, 950]);
set(fig, 'InvertHardcopy', 'off');

% =========================================================================
% SP1: Traiettorie T1 RICOSTRUITE [°C] per ogni Tset di training
% =========================================================================
ax1 = subplot(3, 1, 1); hold on;
set(ax1, 'Color', 'w');                             % G1

% Yline per ogni Tset
for tt = 1:nT_train
    yline(ax1, Tset_train(tt), '--', 'Color', c_tset(tt,:), ...
          'LineWidth', 1.2, ...
          'Label', sprintf('Tset=%.0f°C', Tset_train(tt)), ...
          'LabelHorizontalAlignment', 'right', 'FontSize', 7, ...
          'HandleVisibility', 'off');
end

% Legenda tracker
legend_entries_done = false(1, nT_train);

% --- Rollout casuali (k=1..J): tratteggiate, alpha bassa ---
for k = 1:J
    if k > K_tot, break; end
    lt = latent{k};
    T1_k = lt(:,1) + lt(:,3);                      % T1 = e + Tset
    Tset_k = lt(1, 3);
    tt_idx = find_tset_idx(Tset_k, Tset_train);
    H_k = size(lt, 1) - 1;
    t_k = (0:H_k)' * dt / 60;

    hv = 'off';
    dn = '';
    if ~legend_entries_done(tt_idx)
        hv = 'on';
        dn = sprintf('Tset=%.0f°C', Tset_train(tt_idx));
        legend_entries_done(tt_idx) = true;
    end
    plot(ax1, t_k, T1_k, '--', 'Color', [c_tset(tt_idx,:), 0.4], ...
         'LineWidth', 1, 'HandleVisibility', hv, 'DisplayName', dn);
end

% --- Rollout PILCO (k=J+1..K_tot): continue con LineWidth crescente ---
for j = 1:N
    for tt = 1:nT_train
        k = J + (j-1)*nT_train + tt;
        if k > K_tot, continue; end
        lt = latent{k};
        T1_k = lt(:,1) + lt(:,3);                  % T1 = e + Tset
        H_k = size(lt, 1) - 1;
        t_k = (0:H_k)' * dt / 60;
        lw = 1 + 0.3*(j-1);
        plot(ax1, t_k, T1_k, '-', 'Color', c_tset(tt,:), ...
             'LineWidth', lw, 'HandleVisibility', 'off');
    end
end

ylabel(ax1, 'T1 [°C]', 'FontSize', 11);             % G4
legend(ax1, 'Location', 'best', 'FontSize', 9);      % G5
grid(ax1, 'on');                                      % G3
title(ax1, 'Traiettorie T1 ricostruite (=e+Tset) per Tset di training', 'FontSize', 12);

% =========================================================================
% SP2: Errore finale |e_fin| per rollout
% =========================================================================
ax2 = subplot(3, 1, 2); hold on;
set(ax2, 'Color', 'w');                              % G1

% Barre |e_fin| per ogni rollout
for k = 1:K_tot
    lt = latent{k};
    e_fin = abs(lt(end, 1));
    Tset_k = lt(1, 3);
    tt_idx = find_tset_idx(Tset_k, Tset_train);

    if k <= J
        bar(ax2, k, e_fin, 'FaceColor', c_tset(tt_idx,:), ...
            'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    else
        bar(ax2, k, e_fin, 'FaceColor', c_tset(tt_idx,:), ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

% yline soglia accettabilità 2°C
yline(ax2, 2, '--', 'Color', [0.85 0.13 0.13], 'LineWidth', 1.2, ...
      'DisplayName', 'Soglia 2°C');

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

% Etichette iterazione
y_top = max(cellfun(@(lt) abs(lt(end,1)), latent)) * 1.05;
if isnan(y_top) || y_top == 0, y_top = 5; end
for j = 1:N
    x_center = J + (j-0.5)*nT_train + 0.5;
    text(ax2, x_center, y_top, sprintf('Iter %d', j), ...
         'HorizontalAlignment', 'center', 'FontSize', 8, ...
         'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
end

ylabel(ax2, '|e finale| [°C]', 'FontSize', 11);
legend(ax2, 'Location', 'best', 'FontSize', 9);
grid(ax2, 'on');                                      % G3
title(ax2, 'Errore finale |e_{fin}| per rollout', 'FontSize', 12);

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
ylabel(ax3, 'Costo medio su tutti i Tset', 'FontSize', 11);
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
Tset_str = mat2str(Tset_train);
sgtitle(sprintf('Caso 3 — Training: Tset=%s°C | e=T1-Tset | J=%d + N=%d iter', ...
        Tset_str, J, N), ...
        'FontWeight', 'bold', 'FontSize', 13, 'Color', 'k');

% G6: drawnow
drawnow;

end

% =========================================================================
% Helper locale: trova l'indice del Tset più vicino nel vettore training
% =========================================================================
function idx = find_tset_idx(Tset_val, Tset_vec)
    [~, idx] = min(abs(Tset_vec - Tset_val));
end
