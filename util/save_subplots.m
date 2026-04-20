function save_subplots(fig_handle, fig_dir, prefix, dpi)
% save_subplots  Salva ogni subplot di una figura come immagine individuale.
%
%   save_subplots(fig_handle, fig_dir, prefix)
%   save_subplots(fig_handle, fig_dir, prefix, dpi)
%
%   Per ogni asse (subplot) nella figura, lo esporta come PNG singolo
%   usando exportgraphics (R2020a+) oppure un metodo hide/show di fallback.
%
%   Questa versione NON usa copyobj, quindi funziona anche con
%   axes che usano yyaxis (doppio asse Y) o linkaxes.
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

    % --- Rimuovi axes duplicati (yyaxis crea 2 axes sullo stesso pannello) ---
    % Raggruppa per OuterPosition: axes con la stessa OuterPosition sono
    % lo stesso subplot (asse sinistro + asse destro).
    positions = zeros(length(all_ax), 4);
    for k = 1:length(all_ax)
        positions(k,:) = get(all_ax(k), 'OuterPosition');
    end
    % Arrotonda per evitare differenze float
    positions = round(positions, 4);
    [~, unique_idx] = unique(positions, 'rows', 'stable');
    all_ax = all_ax(unique_idx);

    if isempty(all_ax)
        fprintf('  save_subplots: nessun subplot trovato nella figura.\n');
        return;
    end

    % Ordina gli axes per posizione verticale (dall'alto verso il basso)
    % Position(2) = posizione Y bottom → più alto = valore più grande
    positions_sorted = cell2mat(get(all_ax, 'Position'));
    if size(positions_sorted,1) == 1
        positions_sorted = positions_sorted(:)';  % garantisci riga
    end
    [~, sort_idx] = sort(positions_sorted(:, 2), 'descend');
    all_ax = all_ax(sort_idx);

    n_sp = length(all_ax);
    fprintf('  save_subplots: %d subplot trovati, salvataggio in %s\n', n_sp, fig_dir);

    % Controlla se exportgraphics è disponibile (R2020a+)
    has_exportgraphics = exist('exportgraphics', 'file') == 2;

    for sp = 1:n_sp
        ax_target = all_ax(sp);
        fname = sprintf('%s_sp%d.png', prefix, sp);
        fpath = fullfile(fig_dir, fname);

        if has_exportgraphics
            % ---- Metodo 1: exportgraphics (preferito, robusto con yyaxis) ----
            try
                exportgraphics(ax_target, fpath, 'Resolution', dpi);
                fprintf('    [%d/%d] %s (exportgraphics)\n', sp, n_sp, fname);
                continue;
            catch
                % fallback al metodo 2
            end
        end

        % ---- Metodo 2: hide/show fallback ----
        % Nasconde tutti gli oggetti tranne l'axes target e la sua legenda,
        % salva la figura, poi ripristina la visibilità.
        all_children = get(fig_handle, 'Children');
        orig_vis = cell(size(all_children));
        for k = 1:length(all_children)
            orig_vis{k} = get(all_children(k), 'Visible');
        end

        % Nascondi tutto
        for k = 1:length(all_children)
            try set(all_children(k), 'Visible', 'off'); catch, end
        end

        % Mostra solo l'axes target (e il suo yyaxis companion se presente)
        try set(ax_target, 'Visible', 'on'); catch, end

        % Trova e mostra anche la legenda associata
        try
            leg = get(ax_target, 'Legend');
            if ~isempty(leg) && isvalid(leg)
                set(leg, 'Visible', 'on');
            end
        catch
        end

        % Salva la posizione originale e temporaneamente espandi l'axes
        orig_pos = get(ax_target, 'Position');
        orig_outer = get(ax_target, 'OuterPosition');
        set(ax_target, 'OuterPosition', [0 0 1 1]);

        % Ripristina XTickLabel (potrebbe essere stato rimosso da linkaxes)
        set(ax_target, 'XTickLabelMode', 'auto');

        % Aggiungi xlabel 'Tempo [min]' se mancante
        xl = get(ax_target, 'XLabel');
        had_xlabel = ~isempty(get(xl, 'String'));
        if ~had_xlabel
            xlabel(ax_target, 'Tempo [min]');
        end

        % Salva
        print(fig_handle, fpath, '-dpng', sprintf('-r%d', dpi));
        fprintf('    [%d/%d] %s (hide/show)\n', sp, n_sp, fname);

        % Rimuovi xlabel temporaneo
        if ~had_xlabel
            xlabel(ax_target, '');
        end

        % Ripristina posizione originale
        set(ax_target, 'OuterPosition', orig_outer);
        set(ax_target, 'Position', orig_pos);

        % Ripristina visibilità originale
        for k = 1:length(all_children)
            try set(all_children(k), 'Visible', orig_vis{k}); catch, end
        end
    end
end
