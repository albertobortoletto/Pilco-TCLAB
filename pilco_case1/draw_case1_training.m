function draw_case1_training(latent, realCost, actions, J, N, dt, cost_target, Tset)
% draw_case1_training  Visualizzazione storico training — Caso 1.
%
% Signature:
%   draw_case1_training(latent, realCost, actions, J, N, dt, cost_target, Tset)
%
% Input:
%   latent{k}    → (H+1) × 2  matrice [T1, T2] per il k-esimo rollout
%   realCost{k}  → H × 1      costo lossSat per step
%   actions{k}   → già in [0,100]% (convertito in case1_learn_eval.m)
%   J            → numero rollout casuali  (latent{1..J})
%   N            → numero rollout PILCO    (latent{J+1..J+N})
%   dt           → intervallo di campionamento [s]
%   cost_target  → target T1 [°C]
%   Tset         → setpoint T1 [°C] (uguale a cost_target per Caso 1)
%
% Subplot (2 righe):
%   SP1: Traiettorie T1 di training [°C] nel tempo
%   SP2: Costo totale per rollout (bar chart)

% =========================================================================
% G2: Colori come variabili locali
% =========================================================================
c_random = [0.55 0.55 0.55];   % grigio medio per rollout casuali
c_ref    = [0.85 0.13 0.13];   % rosso per Tset
c_band   = [0.80 0.90 0.80];   % verde chiaro per banda ±2°C

% Colormap PILCO: gradazione da arancione (iter 1) a rosso scuro (iter N)
% per massimo contrasto con il grigio dei casuali
if N > 1
    c_start = [1.00 0.55 0.00];   % arancione
    c_end   = [0.60 0.00 0.10];   % rosso scuro
    cmap_pilco = zeros(N, 3);
    for ii = 1:N
        frac = (ii - 1) / max(N - 1, 1);
        cmap_pilco(ii,:) = (1 - frac) * c_start + frac * c_end;
    end
else
    cmap_pilco = [0.85 0.33 0.10];  % arancione singolo
end

K_tot = J + N;    % rollout totali

% =========================================================================
% G7: Figura
% =========================================================================
fig = figure('NumberTitle', 'off', ...
             'Name', 'Caso 1 — Training', ...
             'Color', 'w');                        % G1
clf(fig);
set(fig, 'Position', [80, 50, 1100, 700]);
set(fig, 'InvertHardcopy', 'off');

% =========================================================================
% SP1: Traiettorie T1 di training [°C] nel tempo
% =========================================================================
ax1 = subplot(2, 1, 1); hold on;
set(ax1, 'Color', 'w');                            % G1

% Determina H dal primo rollout disponibile
H_ref = size(latent{1}, 1) - 1;
t_min = (0:H_ref)' * dt / 60;                     % tempo [min]

% Banda ±2°C attorno a Tset (patch semitrasparente verde)
t_patch = [t_min; flipud(t_min)];
band_patch = [(Tset - 2) * ones(size(t_min)); (Tset + 2) * ones(size(t_min))];
patch(ax1, t_patch, band_patch, c_band, ...
      'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
      'DisplayName', '±2°C');

% Yline per Tset
yline(ax1, Tset, '--', 'Color', c_ref, 'LineWidth', 1.5, ...
      'DisplayName', sprintf('T_{set}=%.0f°C', Tset));

% --- Rollout casuali (k=1..J): grigio tratteggiato, linea sottile ---
for k = 1:J
    lt = latent{k};
    H_k = size(lt, 1) - 1;
    t_k = (0:H_k)' * dt / 60;
    hh = plot(ax1, t_k, lt(:,1), ':', 'Color', [c_random, 0.55], ...
              'LineWidth', 1.0, 'HandleVisibility', 'off');
    if k == 1
        set(hh, 'HandleVisibility', 'on', 'DisplayName', ...
            sprintf('Casuali (J=%d)', J));
    end
end

% --- Rollout PILCO (k=J+1..J+N): colorati, linea spessa con marker ---
marker_every = max(1, round(H_ref / 6));   % marker ogni ~6 punti
for j = 1:N
    k = J + j;
    if k > length(latent), break; end
    lt = latent{k};
    H_k = size(lt, 1) - 1;
    t_k = (0:H_k)' * dt / 60;
    % Linea piena spessa
    plot(ax1, t_k, lt(:,1), '-', 'Color', cmap_pilco(j,:), ...
         'LineWidth', 2.5, 'HandleVisibility', 'off');
    % Marker sovrapposti (solo ogni marker_every step) per distinguere le iter
    idx_mk = 1:marker_every:length(t_k);
    plot(ax1, t_k(idx_mk), lt(idx_mk,1), 'o', ...
         'Color', cmap_pilco(j,:), 'MarkerFaceColor', cmap_pilco(j,:), ...
         'MarkerSize', 5, 'LineWidth', 1.0, ...
         'DisplayName', sprintf('PILCO iter %d', j));
end

xlabel(ax1, 'Tempo [min]', 'FontSize', 11);
ylabel(ax1, 'T1 [°C]', 'FontSize', 11);
legend(ax1, 'Location', 'best', 'FontSize', 9);
grid(ax1, 'on');                                    % G3
title(ax1, 'Traiettorie T1 di training', 'FontSize', 12);

% =========================================================================
% SP2: Costo totale per rollout (bar chart)
% =========================================================================
ax2 = subplot(2, 1, 2); hold on;
set(ax2, 'Color', 'w');                             % G1

% Calcola costi totali
costs_tot = zeros(1, K_tot);
for k = 1:K_tot
    if k <= length(realCost) && ~isempty(realCost{k})
        costs_tot(k) = sum(realCost{k});
    else
        costs_tot(k) = NaN;
    end
end

% Sfondo colorato per distinguere le due fasi
max_cost = max(costs_tot(~isnan(costs_tot)));
if isempty(max_cost), max_cost = 1; end
if J > 0
    patch(ax2, [0.5, J+0.5, J+0.5, 0.5], ...
          [0, 0, max_cost*1.15, max_cost*1.15], ...
          [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
          'HandleVisibility', 'off');
end
if N > 0
    patch(ax2, [J+0.5, K_tot+0.5, K_tot+0.5, J+0.5], ...
          [0, 0, max_cost*1.15, max_cost*1.15], ...
          [1.00 0.95 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
          'HandleVisibility', 'off');
end

% Barre grigie per casuali
for k = 1:J
    bar(ax2, k, costs_tot(k), 'FaceColor', c_random, ...
        'EdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5, ...
        'HandleVisibility', 'off');
end
% Prima barra casuale per legenda
if J > 0
    bar(ax2, NaN, NaN, 'FaceColor', c_random, 'EdgeColor', [0.4 0.4 0.4], ...
        'DisplayName', sprintf('Casuali (J=%d)', J));
end

% Barre colorate per PILCO
for j = 1:N
    k = J + j;
    if k > K_tot, break; end
    bar(ax2, k, costs_tot(k), 'FaceColor', cmap_pilco(j,:), ...
        'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 0.5, ...
        'DisplayName', sprintf('PILCO iter %d', j));
end

% Linea orizzontale a costo=0 (minimo teorico)
yline(ax2, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');

% xline tra casuali e PILCO + etichette
if J > 0 && N > 0
    xline(ax2, J + 0.5, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 2.0, ...
          'HandleVisibility', 'off');
    text(ax2, J/2, max_cost * 1.08, 'Fase 1: Casuali', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, ...
         'FontWeight', 'bold', 'Color', [0.4 0.4 0.4]);
    text(ax2, J + N/2 + 0.5, max_cost * 1.08, 'Fase 2: PILCO', ...
         'HorizontalAlignment', 'center', 'FontSize', 10, ...
         'FontWeight', 'bold', 'Color', [0.7 0.20 0.05]);
end
ylim(ax2, [0, max_cost * 1.18]);

xlabel(ax2, 'Rollout #', 'FontSize', 11);           % G4
ylabel(ax2, 'Costo totale episodio', 'FontSize', 11);
legend(ax2, 'Location', 'eastoutside', 'FontSize', 9); % G5
grid(ax2, 'on');                                     % G3
title(ax2, 'Costo totale per rollout', 'FontSize', 12);

% =========================================================================
% Stile comune
% =========================================================================
for aa = [ax1, ax2]
    set(aa, 'XColor', 'k', 'YColor', 'k');
    set(aa, 'GridColor', [0.15 0.15 0.15], 'GridAlpha', 0.3);
    set(get(aa, 'Title'), 'Color', 'k', 'FontWeight', 'bold');
end

% Legende con sfondo bianco
for aa = [ax1, ax2]
    lg = findobj(aa, 'Type', 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'EdgeColor', [0.5 0.5 0.5], 'Color', 'w');
    end
end

% G8: sgtitle
sgtitle(sprintf('Caso 1 — Training: T_{set}=%.0f°C | J=%d casuali + N=%d PILCO', ...
        Tset, J, N), ...
        'FontWeight', 'bold', 'FontSize', 13, 'Color', 'k');

% G6: drawnow
drawnow;

end
