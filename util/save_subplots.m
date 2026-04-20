function save_subplots(fig_handle, fig_dir, prefix, dpi)
% save_subplots  Salva ogni subplot di una figura come immagine individuale.
%
%   save_subplots(fig_handle, fig_dir, prefix)
%   save_subplots(fig_handle, fig_dir, prefix, dpi)
%
%   Per ogni asse (subplot) nella figura, lo esporta come PNG singolo.
%
%   Metodo primario: exportgraphics (MATLAB R2020a+) — gestisce
%   correttamente axes con yyaxis (doppio asse Y).
%
%   Fallback: copyobj in una figura temporanea (solo per axes senza yyaxis).
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
    % 2. Deduplicazione axes da yyaxis
    %    yyaxis crea internamente due ruler sullo stesso axes, ma findall
    %    può restituire axes nascosti sovrapposti. Raggruppiamo per
    %    OuterPosition arrotondata per rimuovere duplicati.
    % =====================================================================
    if length(all_ax) > 1
        opos = zeros(length(all_ax), 4);
        for k = 1:length(all_ax)
            opos(k,:) = get(all_ax(k), 'OuterPosition');
        end
        opos = round(opos, 3);
        [~, uidx] = unique(opos, 'rows', 'stable');
        all_ax = all_ax(uidx);
    end

    if isempty(all_ax)
        fprintf('  save_subplots: nessun subplot trovato nella figura.\n');
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

    % Controlla se exportgraphics è disponibile (R2020a+)
    use_export = (exist('exportgraphics', 'file') == 2);

    % =====================================================================
    % 4. Salvataggio di ogni subplot
    % =====================================================================
    for sp = 1:n_sp
        ax_target = all_ax(sp);
        fname = sprintf('%s_sp%d.png', prefix, sp);
        fpath = fullfile(fig_dir, fname);

        saved = false;

        % --- Metodo 1: exportgraphics (gestisce yyaxis correttamente) ---
        if use_export
            try
                exportgraphics(ax_target, fpath, ...
                    'Resolution', dpi, 'BackgroundColor', 'white');
                saved = true;
            catch ME
                fprintf('    [%d/%d] exportgraphics fallito: %s\n', sp, n_sp, ME.message);
            end
        end

        % --- Metodo 2: copyobj in figura temporanea (fallback) ---
        if ~saved
            tmp_fig = [];
            try
                orig_pos = get(fig_handle, 'Position');
                fig_w = orig_pos(3);
                fig_h = max(350, orig_pos(4) / n_sp * 1.4);

                tmp_fig = figure('Visible', 'off', ...
                    'Position', [100, 100, fig_w, fig_h], 'Color', 'w');

                ax_new = copyobj(ax_target, tmp_fig);
                set(ax_new, 'Position', [0.12, 0.15, 0.78, 0.72]);
                set(ax_new, 'XTickLabelMode', 'auto');

                % Aggiungi xlabel se mancante
                xl = get(ax_new, 'XLabel');
                if isempty(get(xl, 'String'))
                    xlabel(ax_new, 'Tempo [min]');
                end

                % Titolo
                ttl = get(ax_new, 'Title');
                ttl_str = get(ttl, 'String');
                if ~isempty(ttl_str)
                    title(ax_new, ttl_str, 'FontWeight', 'bold', 'FontSize', 12);
                end

                print(tmp_fig, fpath, '-dpng', sprintf('-r%d', dpi));
                close(tmp_fig);
                saved = true;
            catch ME
                fprintf('    [%d/%d] copyobj fallito: %s\n', sp, n_sp, ME.message);
                if ~isempty(tmp_fig) && isvalid(tmp_fig)
                    close(tmp_fig);
                end
            end
        end

        if saved
            fprintf('    [%d/%d] %s\n', sp, n_sp, fname);
        else
            fprintf('    [%d/%d] %s — SALTATO (errore)\n', sp, n_sp, fname);
        end
    end
end
