function q = rx_quantile(v, p)
%RX_QUANTILE Quantile empirique, sans Statistics Toolbox.
v = sort(v(~isnan(v(:))));
if isempty(v), q = NaN; return; end
q = v(max(1, ceil(p * numel(v))));
end
