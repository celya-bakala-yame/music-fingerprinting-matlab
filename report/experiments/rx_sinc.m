function y = rx_sinc(x)
%RX_SINC Sinus cardinal normalisé, sans toolbox.
y = ones(size(x));
nz = x ~= 0;
y(nz) = sin(pi * x(nz)) ./ (pi * x(nz));
end
