function [p_exact, p_tol] = rx_survival(Pc, Pd)
%RX_SURVIVAL Proportion des pics propres Pc retrouvés dans Pd :
%   p_exact : même position (m, k) ; p_tol : à ±1 trame et ±1 canal.
if isempty(Pc)
    p_exact = NaN; p_tol = NaN; return;
end
if isempty(Pd)
    p_exact = 0; p_tol = 0; return;
end
p_exact = mean(ismember(Pc, Pd, 'rows'));
hit = false(size(Pc, 1), 1);
for dm = -1:1
    for dk = -1:1
        hit = hit | ismember(Pc + [dm dk], Pd, 'rows');
    end
end
p_tol = mean(hit);
end
