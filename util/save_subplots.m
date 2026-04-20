function save_subplots(fig_handle, fig_dir, prefix, dpi)
% save_subplots  Salva ogni subplot di una figura come immagine individuale.
%
%   save_subplots(fig_handle, fig_dir, prefix)
%   save_subplots(fig_handle, fig_dir, prefix, dpi)
%
%   Tre metodi in cascata:
%     1. exportgraphics — funziona con yyaxis (MATLAB R2020a+)
%     2. copyobj        — funziona con axes semplici (pre-R2020a)
%     3. getframe       — ultima risorsa, cattura i pixel dallo schermo
%
%   La figura originale NON viene modificata né chiusa.
%
%   Input:
%     fig_handle  handle della figura con i subplot
%     fig_dir     cartella in cui salvare le immagini  [stringa]
%     prefix      prefisso dei file  [stringa]  (es. 'case1')
%                 → salva come prefix_sp1.png, prefix_sp2.png, ...
%     dpi         (opzionale) risoluzione PNG  [default: 150]

    if nargin < 4 || isempty(dpi), dpi = 150; end
    if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

    % Controlla che la figura sia ancora valida
    if ~isvalid(fig_handle)
        fprintf('  save_subplots: handle figura non valido (chiusa?), salto.\n');
        return;
    end

    % Forza sfondo bianco per output consistente
    set(fig_handle, 'Color', 'w');
    set(fig_handle, 'InvertHardcopy', 'on');

    % =====================================================================
    % 1. Trova tutti gli Axes reali (escludi legende, colorbar)
    % =====================================================================
    all_ax = findall(fig_handle, 'Type', 'axes');

    keep = true(size(all_ax));
    for k = 1:length(all_ax)
        tag = get(all_ax(k), 'Tag');
        if strcmpi(tag, 'legend') || strcmpi(tag, 'Colorbar')
            keep(k) = false;
        end
        try
            if isa(all_ax(k), 'matlab.graphics.illustration.Legend') || ...
               isa(all_ax(k), 'matlab.graphics.illustration.ColorBar')
                keep(k) = false;
            end
        catch
        end
    end
    all_ax = all_ax(keep);

    % =====================================================================
    % 2. Deduplicazione axes da yyaxis (stessa OuterPosition)
    % =====================================================================
    if length(all_ax) > 1
        opos = zeros(length(all_ax), 4);
        for k = 1:length(all_ax)
            opos(k,:) = get(all_ax(k), 'OuterPosition');
        end
        [~, uidx] = unique(round(opos, 3), 'rows', 'stable');
        all_ax = all_ax(uidx);
    end

    if isempty(all_ax)
        fprintf('  save_subplots: nessun subplot trovato.\n');
        return;
    end

    % =====================================================================
    % 3. Ordina dall'alto verso il basso (Position(2) descending)
    % =====================================================================
    if length(all_ax) > 1
        pos_mat = cell2mat(get(all_ax, 'Position'));
    else
        pos_mat = get(all_ax, 'Position');
    end
    [~, sort_idx] = sort(pos_mat(:, 2), 'descend');
    all_ax = all_ax(sort_idx);

    n_sp = length(all_ax);
    fprintf('  save_subplots: %d subplot trovati, salvataggio in %s\n', n_sp, fig_dir);

    % Check exportgraphics — usa which() che è più affidabile di exist()
    use_export = ~isempty(which('exportgraphics'));

    % =====================================================================
    % 4. Salvataggio di ogni subplot
    % =====================================================================
    for sp = 1:n_sp
        ax_target = all_ax(sp);
        fname = sprintf('%s_sp%d.png', prefix, sp);
        fpath = fullfile(fig_dir, fname);
        saved = false;
        method = '';

        % ----- Metodo 1: exportgraphics (gestisce yyaxis) -----
        if use_export
            try
                exportgraphics(ax_target, fpath, ...
                    'Resolution', dpi, 'BackgroundColor', 'white');
                saved = true;
                method = 'exportgraphics';
            catch
            end
        end

        % ----- Metodo 2: copyobj in figura temporanea -----
        if ~saved
            tmp_fig = [];
            try
                orig_pos = get(fig_handle, 'Position');
                fig_w = orig_pos(3);
                fig_h = max(350, orig_pos(4) / n_sp * 1.4);

                tmp_fig = figure('Visible', 'off', ...
                    'Position', [100, 100, fig_w, fig_h], ...
                    'Color', 'w', 'InvertHardcopy', 'on');

                ax_new = copyobj(ax_target, tmp_fig);
                set(ax_new, 'Position', [0.12, 0.15, 0.78, 0.72]);
                set(ax_new, 'XTickLabelMode', 'auto');

                xl = get(ax_new, 'XLabel');
                if isempty(get(xl, 'String'))
                    xlabel(ax_new, 'Tempo [min]');
                end

                ttl = get(ax_new, 'Title');
                ttl_str = get(ttl, 'String');
                if ~isempty(ttl_str)
                    title(ax_new, ttl_str, 'FontWeight', 'bold', 'FontSize', 12);
                end

                print(tmp_fig, fpath, '-dpng', sprintf('-r%d', dpi));
                close(tmp_fig);
                saved = true;
                method = 'copyobj';
            catch
                if ~isempty(tmp_fig) && isvalid(tmp_fig)
                    close(tmp_fig);
                end
            end
        end

        % ----- Metodo 3: getframe (ultima risorsa, cattura pixel) -----
        if ~saved
            try
                drawnow;

                % Posizione dell'axes in pixel
                orig_units = get(ax_target, 'Units');
                set(ax_target, 'Units', 'pixels');
                outer_px = get(ax_target, 'OuterPosition');
                set(ax_target, 'Units', orig_units);

                % Dimensione della figura in pixel
                fig_units = get(fig_handle, 'Units');
                set(fig_handle, 'Units', 'pixels');
                fig_px = get(fig_handle, 'Position');
                set(fig_handle, 'Units', fig_units);

                % Rettangolo di cattura [x, y, w, h] da lower-left
                x0 = max(1, floor(outer_px(1)));
                y0 = max(1, floor(outer_px(2)));
                w0 = min(ceil(outer_px(3)), ceil(fig_px(3)) - x0);
                h0 = min(ceil(outer_px(4)), ceil(fig_px(4)) - y0);
                rect = [x0, y0, w0, h0];

                frame = getframe(fig_handle, rect);
                imwrite(frame.cdata, fpath);
                saved = true;
                method = 'getframe';
            catch
            end
        end

        if saved
            fprintf('    [%d/%d] %s (%s)\n', sp, n_sp, fname, method);
        else
            fprintf('    [%d/%d] %s — SALTATO\n', sp, n_sp, fname);
        end
    end
end
