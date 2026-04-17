function draw_case2_results(latent, realCost, latent_eval, realCost_eval, ...
                             plant, cost, J, N, Tamb_train, Tamb_eval, ...
                             actions_eval)
% draw_case2_results  Case 2 — Training overview + Valutazione generalizzazione.
%
% Figure 11 — Training (2×3):
%   [1,2] Tutte le traiettorie T1  [3] Progressione PILCO Tamb(1)
%   [4]   Costo per trial          [5,6] Costo medio per iterazione
%
% Figure 12 — Valutazione su Tamb mai viste (2×3, asse x condiviso T1↔Q1):
%
%   ┌────────────────────────┬──────────────────────┐
%   │  T1(t) per Tamb_eval   │  T1 finale vs target │  ← riga 1
%   ├────────────────────────┼──────────────────────┤
%   │  Q1(t) per Tamb_eval   │  Q1 regime vs Tamb   │  ← riga 2 (linkaxes con T1)
%   │  (linkaxes con T1)     │  INSIGHT FISICO       │
%   └────────────────────────┴──────────────────────┘
%
% Insight fisico [6]: Q1 a regime vs Tamb_eval
%   → Tamb↓ richiede Q1↑ per compensare le maggiori perdite termiche
%   → Questo prova che la policy ha IMPARATO la fisica del sistema
%   → Trend atteso: monotono decrescente (Tamb alto = meno potenza richiesta)
%
% Input opzionale:
%   actions_eval  {1×nT_eval}  Q1 [0,100]% per ogni eval trial
%                (da rollout: xx(:,end)+50)

has_Q1 = nargin >= 11 && ~isempty(actions_eval) && ~isempty(actions_eval{1});

nT      = length(Tamb_train);
nT_e    = length(Tamb_eval);
n_train = length(latent);

T_target    = cost.target(1);
colors_tamb = lines(nT);
colors_eval = cool(nT_e);   % blu→ciano→verde→giallo (freddo→caldo)
dt          = plant.dt;

% Costo per trial di training
all_costs = zeros(1, n_train);
for k = 1:n_train
    if ~isempty(realCost{k}), all_costs(k) = sum(realCost{k}); end
end
y_top = max([all_costs, 0.01]) * 1.08;

% Mappa trial → indice Tamb
tamb_of_trial = zeros(1, n_train);
for k = 1:J,  tamb_of_trial(k) = mod(k-1,nT)+1; end
for j = 1:N
    for tt = 1:nT
        idx = J+(j-1)*nT+tt;
        if idx <= n_train, tamb_of_trial(idx) = tt; end
    end
end


%% ================================================================
%% Figure 11 — Training overview
%% ================================================================
figure(11); clf;
set(gcf,'Position',[50,50,1300,820],'Name','Case 2 — Training');

% [1,2] Overview T1
subplot(2,3,[1 2]); hold on;
for jj = 1:J
    if jj>n_train||isempty(latent{jj}), continue; end
    T1=latent{jj}(:,1); t=(0:length(T1)-1)*dt/60;
    hv='off'; if jj==1, hv='on'; end
    plot(t,T1,'--','Color',[0.75 0.75 0.75],'LineWidth',0.8, ...
         'DisplayName','Rollout casuali','HandleVisibility',hv);
end
for j=1:N
    for tt=1:nT
        idx=J+(j-1)*nT+tt;
        if idx>n_train||isempty(latent{idx}), continue; end
        T1=latent{idx}(:,1); t=(0:length(T1)-1)*dt/60;
        af=0.25+0.75*(j/N); c=af*colors_tamb(tt,:)+(1-af)*[1 1 1];
        if j==N
            plot(t,T1,'-','Color',colors_tamb(tt,:),'LineWidth',2.5, ...
                 'DisplayName',sprintf('Tamb=%2.0f°C (finale)',Tamb_train(tt)));
        else
            plot(t,T1,'-','Color',c,'LineWidth',0.8+1.8*(j/N),'HandleVisibility','off');
        end
    end
end
yline(T_target,'-.r','LineWidth',2.5,'DisplayName',sprintf('Target %.0f°C',T_target));
xlabel('Tempo [min]'); ylabel('T1 [°C]');
title('Overview Training: traiettorie T1 per Tamb di training');
legend('Location','eastoutside','FontSize',8); grid on; ylim([15 75]);

% [3] Progressione PILCO
subplot(2,3,3); hold on;
for j=1:N
    idx=J+(j-1)*nT+1;
    if idx>n_train||isempty(latent{idx}), continue; end
    T1=latent{idx}(:,1); t=(0:length(T1)-1)*dt/60;
    c_j=[0.1,0.3+0.5*(j/N),0.8*(1-j/N)+0.2];
    plot(t,T1,'-o','Color',c_j,'LineWidth',1.5,'MarkerSize',3,'DisplayName',sprintf('Iter %d',j));
end
yline(T_target,'-.r','LineWidth',2,'DisplayName','Target');
xlabel('Tempo [min]'); ylabel('T1 [°C]');
title(sprintf('Progressione PILCO — Tamb=%.0f°C',Tamb_train(1)));
legend('Location','southeast','FontSize',7); grid on; ylim([15 75]);

% [4] Costo per trial
subplot(2,3,4); hold on;
for k=1:n_train
    tt=tamb_of_trial(k);
    if k<=J
        bar(k,all_costs(k),'FaceColor',[0.75 0.75 0.75],'EdgeColor','none');
    elseif tt>0
        bar(k,all_costs(k),'FaceColor',colors_tamb(tt,:),'EdgeColor','none');
    end
end
xline(J+0.5,'r-.','LineWidth',2);
if max(all_costs)>0
    text(J/2+0.5,y_top*0.9,'Casuali','HorizontalAlignment','center', ...
         'Color',[0.5 0.5 0.5],'FontWeight','bold','FontSize',8);
end
for tt=1:nT
    patch(NaN,NaN,colors_tamb(tt,:),'DisplayName',sprintf('Tamb=%.0f°C',Tamb_train(tt)));
end
xlabel('Trial #'); ylabel('Costo totale');
title('Costo per trial (colore = Tamb)');
legend('Location','northeast','FontSize',7); grid on;

% [5,6] Costo medio per iterazione
subplot(2,3,[5 6]); hold on;
if J>0, bar(0,mean(all_costs(1:J)),'FaceColor',[0.75 0.75 0.75],'EdgeColor','k'); end
for j=1:N
    idx_s=J+(j-1)*nT+1; idx_e=min(J+j*nT,n_train);
    if idx_s>n_train, continue; end
    cm=mean(all_costs(idx_s:idx_e));
    bar(j,cm,'FaceColor',[0.2 0.4 0.8],'EdgeColor','k');
    text(j,cm+0.01*y_top,sprintf('%.3f',cm),'HorizontalAlignment','center','FontSize',7);
end
xlabel('Iterazione (0=casuali)'); ylabel('Costo medio');
title('Apprendimento PILCO — deve decrescere');
xticks(0:N);
xticklabels(['Casuali',arrayfun(@(j)sprintf('Iter %d',j),1:N,'UniformOutput',false)]);
xtickangle(30); grid on;

sgtitle(sprintf('Case 2 — Training  |  Tamb_{train}=%s°C',mat2str(Tamb_train)), ...
        'FontWeight','bold','FontSize',13);
drawnow;


%% ================================================================
%% Figure 12 — Valutazione generalizzazione (2×3 con Q1 allineato)
%% ================================================================
figure(12); clf;
set(gcf,'Position',[50,50,1380,720],'Name','Case 2 — Valutazione Generalizzazione');

% Colonne Q1 per insight: calcola Q1 a regime (ultimi 5 step per eval)
if has_Q1
    n_ss   = 5;
    Q1_ss  = zeros(1, nT_e);
    for te = 1:nT_e
        if ~isempty(actions_eval{te})
            q1     = actions_eval{te}(:);
            n_back = min(n_ss, numel(q1));
            Q1_ss(te) = mean(q1(end-n_back+1:end));
        end
    end
end

% Larghezze subplot: colonne 1-2 (stime) più larghe di col 3 (summary)
% Usiamo posizioni manuali per migliore controllo
left1=0.06; w12=0.50; gap=0.04; left3=left1+w12+gap; w3=0.20;
h_row=0.38; bot1=0.55; bot2=0.10;

% ---- RIGA 1 ----

% [1,2] T1(t) per Tamb_eval
ax_T1 = axes('Position',[left1, bot1, w12, h_row]); %#ok
hold on;
for te=1:nT_e
    if isempty(latent_eval{te}), continue; end
    T1=latent_eval{te}(:,1);
    t=(0:length(T1)-1)*dt/60;
    plot(t,T1,'-','Color',colors_eval(te,:),'LineWidth',2.2, ...
         'DisplayName',sprintf('Tamb=%.0f°C',Tamb_eval(te)));
end
yline(T_target,'-.r','LineWidth',2.2, ...
      'DisplayName',sprintf('Target %.0f°C',T_target));
ylabel('T1 [°C]');
title({'T1(t) per Tamb mai viste in training', ...
       sprintf('Tamb_{train}=%s°C',mat2str(Tamb_train))});
legend('Location','eastoutside','FontSize',9); grid on;
ylim([0 85]);
set(gca,'XTickLabel',[]);
ax_T1 = gca;

% [3] T1 finale vs target
axes('Position',[left3, bot1, w3, h_row]); %#ok
hold on;
T1_finali = cellfun(@(lt) lt(end,1), latent_eval);
b = bar(1:nT_e, T1_finali,'FaceColor','flat','EdgeColor','k','LineWidth',1.2);
for te=1:nT_e, b.CData(te,:)=colors_eval(te,:); end
yline(T_target,'-.r','LineWidth',2.2);
for te=1:nT_e
    err=T1_finali(te)-T_target;
    text(te, T1_finali(te)+1.8, sprintf('%+.1f°',err), ...
         'HorizontalAlignment','center','FontSize',9,'FontWeight','bold', ...
         'Color',local_sign_color(err));
end
xticks(1:nT_e);
xticklabels(arrayfun(@(T)sprintf('T_{amb}\n%.0f°C',T),Tamb_eval,'UniformOutput',false));
ylabel('T1 finale [°C]');
title({'T1 finale', 'vs target'});
ylim([0, max([T1_finali,T_target])*1.25+5]);
grid on; box on;

% ---- RIGA 2 ----

if has_Q1
    % [4,5] Q1(t) per Tamb_eval — linkaxes con T1
    axes('Position',[left1, bot2, w12, h_row]); %#ok
    hold on;
    for te=1:nT_e
        if isempty(actions_eval{te}), continue; end
        q1  = actions_eval{te}(:);
        t_q = (0:numel(q1)) * dt/60;
        stairs(t_q, [q1;q1(end)], '-', 'Color',colors_eval(te,:), ...
               'LineWidth',2.2, 'DisplayName',sprintf('Tamb=%.0f°C',Tamb_eval(te)));
    end
    yline(0,  ':k','LineWidth',0.8,'HandleVisibility','off');
    yline(100,':k','LineWidth',0.8,'HandleVisibility','off');
    xlabel('Tempo [min]'); ylabel('Q1 [%]');
    title({'Q1(t): potenza heater per ogni Tamb', ...
           'Tamb↓ → Q1↑ (maggiore potenza per compensare le perdite)'});
    legend('Location','eastoutside','FontSize',9);
    grid on; ylim([-5, 112]);
    ax_Q1 = gca;

    % ← ALLINEAMENTO: T1 e Q1 stesso asse temporale
    linkaxes([ax_T1, ax_Q1], 'x');

    % [6] Q1 a regime vs Tamb — INSIGHT FISICO CHIAVE
    axes('Position',[left3, bot2, w3, h_row]); %#ok
    hold on;

    % Ordina per Tamb crescente per la linea di trend
    [Tamb_s, sidx] = sort(Tamb_eval);
    Q1_s = Q1_ss(sidx); col_s = colors_eval(sidx,:);

    % Linea di trend tratteggiata
    plot(Tamb_s, Q1_s, '--k', 'LineWidth',1.5, 'HandleVisibility','off');

    % Punti colorati per Tamb
    for te=1:nT_e
        plot(Tamb_s(te), Q1_s(te), 'o', ...
             'MarkerSize',10, 'MarkerFaceColor',col_s(te,:), ...
             'MarkerEdgeColor','k', 'LineWidth',1.5, ...
             'DisplayName',sprintf('%.0f°C → %.0f%%',Tamb_s(te),Q1_s(te)));
    end

    % Freccia e testo insight
    x_mid = mean(Tamb_s);
    y_mid = mean(Q1_s);
    annotation_str = sprintf('Tamb↓  →  Q1↑\n(legge di raffreddamento\ndi Newton + Stefan-B.)');
    text(x_mid, y_mid + (max(Q1_s)-min(Q1_s))*0.25, annotation_str, ...
         'HorizontalAlignment','center','FontSize',7.5,'Color',[0.6 0.0 0.0], ...
         'FontWeight','bold','BackgroundColor','w','EdgeColor',[0.8 0.0 0.0]);

    xlabel('Tamb [°C]'); ylabel('Q1 a regime [%]');
    title({'Q1 regime vs Tamb', '(INSIGHT: fisica appresa)'});
    legend('Location','northeast','FontSize',7);
    grid on; box on;
    xlim([min(Tamb_s)-3, max(Tamb_s)+3]);
    ylim([max(0,min(Q1_s)-8), min(100,max(Q1_s)+12)]);

else
    % Fallback senza Q1: mostra nota
    axes('Position',[left1, bot2, w12+gap+w3, h_row]); %#ok
    text(0.5,0.5,'actions\_eval non fornito: nessun grafico Q1 disponibile', ...
         'HorizontalAlignment','center','FontSize',11,'Color',[0.5 0.5 0.5], ...
         'Units','normalized');
    axis off;
end

sgtitle(sprintf('Case 2 — Generalizzazione  |  Tamb_{eval}=%s°C (mai viste)', ...
                mat2str(Tamb_eval)),'FontWeight','bold','FontSize',12);
drawnow;

end  % fine draw_case2_results


%% --- funzione locale colore errore ---
function c = local_sign_color(err)
    if abs(err) < 2,    c = [0.0, 0.60, 0.1];
    elseif abs(err) < 5, c = [0.8, 0.50, 0.0];
    else,                c = [0.8, 0.10, 0.1]; end
end