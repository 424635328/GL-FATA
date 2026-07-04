
function [ result ] = func_levy( x,bestX )
% Levy flights 
beta = 1.5 ;
[N,D] = size(x) ;
sigma_u = (gamma(1+beta)*sin(pi*beta/2)/(beta*gamma((1+beta)/2)*2^((beta-1)/2)))^(1/beta) ;
sigma_v = 1 ;
u = normrnd(0,sigma_u,N,D) ;
v = normrnd(0,sigma_v,N,D) ;
step = u./(abs(v).^(1/beta)) ;
l = 0.01 * ( x  - bestX); 
result = x + l .* step ;
end