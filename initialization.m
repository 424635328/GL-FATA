function Positions = initialization(SearchAgents_no, dim, ub, lb)
%INITIALIZATION Initialize FATA's first population.
%   This compatibility dependency follows the upstream FATA implementation
%   tracked in third_party/FATA/initialization.m.

if isscalar(ub)
    Positions = rand(SearchAgents_no, dim) .* (ub - lb) + lb;
    return;
end

Positions = zeros(SearchAgents_no, dim);
for i = 1:dim
    Positions(:, i) = rand(SearchAgents_no, 1) .* (ub(i) - lb(i)) + lb(i);
end
end
