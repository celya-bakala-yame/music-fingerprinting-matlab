function [kq1, kq2, dm] = decode_key(keys)
%DECODE_KEY Inverse de l'encodage de generate_hashes.
%
%   [kq1, kq2, dm] = decode_key(keys)
%
% key = kq1*2^15 + kq2*2^5 + dm  (uint32)
%   dm  = bits 0-4   (5 bits)
%   kq2 = bits 5-14  (10 bits)
%   kq1 = bits 15-24 (10 bits)

keys = uint32(keys);
dm  = bitand(keys, uint32(31));
kq2 = bitand(bitshift(keys, -5), uint32(1023));
kq1 = bitshift(keys, -15);
end
