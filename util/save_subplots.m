function save_subplots(fig_handle, fig_dir, prefix, dpi)
% save_subplots  Salva ogni subplot di una figura come immagine individuale.
%
%   save_subplots(fig_handle, fig_dir, prefix)
%   save_subplots(fig_handle, fig_dir, prefix, dpi)
%
%   Per ogni asse (subplot) nella figura, crea una nuova figura temporanea,
%   copia l'asse al suo interno con tutte le proprietà (titolo, legende,
%   yaxis, ecc.), salva come PNG e chiude la figura temporanea.
%
%   La figura originale NON viene modificata né chiusa.
%
%   Input:
%     fig_handle  handle della figura con i subplot
%     fig_dir     cartella in cui salvare le immagini  [stringa]
%     prefix      prefisso dei file  [stringa]  (es. 'case1')
%                 → salva come prefix_sp1.png, prefix_sp2.png, ...
%     dpi         (opzionale) risoluzione PNG  [default: 150]
%
%   Esempio:
%     save_subplots(gcf, 'results/figures', 'case2', 200)
%     → salva results/figures/case2_sp1.png, case2_sp2.png, ...

    if nargin < 4 || isempty(dpi), dpi = 150; end
    if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

    % Trova tutti gli Axes nella figura (escludi legende, colorbar, ecc.)
    all_ax = findobj(fig_handle, 'Type', 'axes');

    % Filtra: teniamo solo gli axes "veri" (no legende, no colorbar)
    keep = true(size(all_ax));
    for k = 1:length(all_ax)
        tag = get(all_ax(k), 'Tag');
        % Le legende hanno Tag 'legend', le colorbar 'Colorbar'
        if strcmpi(tag, 'legend') || strcmpi(tag, 'Colorbar')
            keep(k) = false;
        end
        % Anche gli axes creati da yyaxis destro sono figli dello stesso Parent:
        % verifichiamo che non siano 'colorbar' o 'legend' tramite class
        try
            if isa(all_ax(k), 'matlab.graphics.illustration.Legend') || ...
               isa(all_ax(k), 'matlab.graphics.illustration.ColorBar')
                keep(k) = false;
            end
        catch
        end
    end
    all_ax = all_ax(keep);

    if isempty(all_ax)
        fprintf('  save_subplots: nessun subplot trovato nella figura.\n');
        return;
    end

    % Ordina gli axes per posizione verticale (dall'alto verso il basso)
    % Position(2) = posizione Y bottom → più alto = valore più grande
    positions = cell2mat(get(all_ax, 'Position'));
    [~, sort_idx] = sort(positions(:, 2), 'descend');
    all_ax = all_ax(sort_idx);

    n_sp = length(all_ax);
    fprintf('  save_subplots: %d subplot trovati, salvataggio in %s\n', n_sp, fig_dir);

    for sp = 1:n_sp
        ax_orig = all_ax(sp);

        % Dimensione della figura temporanea: larga come l'originale, alta proporzionata
        orig_pos = get(fig_handle, 'Position');  % [left, bottom, width, height]
        fig_w = orig_pos(3);
        fig_h = max(350, orig_pos(4) / n_sp * 1.4);  % altezza singola aumentata

        % Crea figura temporanea invisibile
        tmp_fig = figure('Visible', 'off', 'Position', [100, 100, fig_w, fig_h], ...
                         'Color', 'w');

        % Copia l'asse nella figura temporanea
        ax_new = copyobj(ax_orig, tmp_fig);

        % Riposiziona l'asse per occupare tutta la figura tmp
        set(ax_new, 'Position', [0.10, 0.15, 0.82, 0.72]);

        % Ripristina XTickLabel (potrebbe essere stato rimosso da linkaxes)
        set(ax_new, 'XTickLabelMode', 'auto');

        % Aggiungi xlabel 'Tempo [min]' se mancante
        xl = get(ax_new, 'XLabel');
        if isempty(get(xl, 'String'))
            xlabel(ax_new, 'Tempo [min]');
        end

        % Titolo del subplot come titolo della figura
        ttl = get(ax_new, 'Title');
        ttl_str = get(ttl, 'String');
        if ~isempty(ttl_str)
            title(ax_new, ttl_str, 'FontWeight', 'bold', 'FontSize', 12);
        end

        % Salva
        fname = sprintf('%s_sp%d.png', prefix, sp);
        fpath = fullfile(fig_dir, fname);
        print(tmp_fig, fpath, '-dpng', sprintf('-r%d', dpi));
        fprintf('    [%d/%d] %s\n', sp, n_sp, fname);

        close(tmp_fig);
    end
end
