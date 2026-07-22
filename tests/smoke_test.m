% Basic, toolbox-free verification for the two root-level optimizers.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
originalDirectory = pwd;
restoreDirectory = onCleanup(@() cd(originalDirectory)); %#ok<NASGU>

cd(projectRoot);
addpath(projectRoot);
clear FATA GL_FATA

objective = @(x) sum(x .^ 2);

rng(20260722, 'twister');
lowerBound = [-5, -3, -1];
upperBound = [2, 4, 7];
[bestPos, bestScore, curve] = GL_FATA(objective, lowerBound, upperBound, 3, 10, 100);

assert(isfinite(bestScore), 'GL_FATA did not return a finite score.');
assert(~isempty(curve), 'GL_FATA did not return a convergence curve.');
assert(all(bestPos >= lowerBound & bestPos <= upperBound), 'GL_FATA returned an infeasible point.');

rng(20260722, 'twister');
[bestPos, bestScore, curve] = FATA(objective, -5, 5, 3, 10, 100);

assert(isfinite(bestScore), 'FATA did not return a finite score.');
assert(~isempty(curve), 'FATA did not return a convergence curve.');
assert(all(bestPos >= -5 & bestPos <= 5), 'FATA returned an infeasible point.');
assert(isfile(fullfile(projectRoot, 'third_party', 'FATA', 'FATA.m')), ...
    'The upstream FATA submodule has not been initialized.');

fprintf('GL-FATA smoke test passed.\n');
