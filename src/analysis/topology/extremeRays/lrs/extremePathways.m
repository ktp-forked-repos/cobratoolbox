function [R, V] = extremePathways(model, positivity, inequality)
% Calculates the extreme pathways of a stoichiometric model using the vertex/facet enumeration package
%
% USAGE:
%
%    [R, V] = extremePathways(model, positivity, inequality)
%
% INPUTS:
%    model:         COBRA Toolbox model with fields:
%
%                     * .description - string used to name files
%                     * .lb - lower bounds and
%                     * .ub - upper bounds to derive directionality
%                     * .b - dxdt
% OPTIONAL INPUT:
%    positivity:    {0, (1)} if `positivity == 1`, then positive orthant base
%    inequality:    {(0), 1} if `inequality == 1`, then use two inequalities rather than a single equality
%
% OUTPUTS:
%    R:             `nDim` by `nRay` matrix of extreme rays
%    V:             `nDim` by `nVertex` matrix of vertices
%
% .. Author: - lrs by David Avis, McGill University

[nMet, nRxn] = size(model.S);

A = model.S;

if nnz(A - round(A))
    figure
    spy(A - round(A))
    title('S-round(S)')
    error('Stoichiometric coefficients must be all integers')
end

if isfield(model, 'lb') && isfield(model,'ub')
    directionality = zeros(nRxn,1);
    %forward irrev
    directionality(model.ub > 0 & model.lb >= 0) = 1;
    %backward irrev
    directionality(model.ub <= 0 & model.lb < 0) = -1;
    D = diag(directionality);
    d = zeros(nRxn, 1);
else
    D = [];
    d = [];
end

if isfield(model, 'description')
    filename = model.description;
else
    filename = 'model';
end

if ~exist('positivity', 'var')
    positivity = 1;
end
if ~exist('inequality', 'var')
    inequality = 0;
end

suffix = '';
if positivity
    suffix = [suffix 'pos_'];
else
    suffix = [suffix 'neg_'];
end
if inequality
    suffix = [suffix 'ineq'];
else
    suffix = [suffix 'eq'];
end

if isfield(model, 'b')
    a = model.b;
else
    a = zeros(nMet, 1);
end

% no linear objective
f = [];

sh = 0;

% INPUT
% A          matrix of linear equalities A*x=(a)
% D          matrix of linear inequalities D*x>=(d)
% filename   base name of output file
%
% OPTIONAL INPUT
% positivity {0,(1)} if positivity==1, then positive orthant base
% inequality {0,(1)} if inequality==1, then use two inequalities rather than a single equaltiy
% a          boundry values for matrix of linear equalities A*x=a
% d          boundry values for matrix of linear inequalities D*x>=d
% f          linear objective for a linear optimization problem in rational arithmetic
%            minimise     f'*x
%            subject to   A*x=(a)
%                         D*x>=(d)
lrsInputHalfspace(A, D, filename, positivity, inequality, a, d, f, sh);

% pause(eps)
[status, result] = system('which lrs');
if ~isempty(strfind(result, '/lrs')) %% no filesep here, as which always (even the git bash version on windows returns pathes with /)
    % call lrs and wait until extreme pathways have been calculated
    systemCallText = ['lrs ' pwd filesep filename '_' suffix '.ine > ' pwd filesep filename '_' suffix '.ext'];
    [status, result] = system(systemCallText);
    if status == 1
        error(['lsr failed on file ', pwd filesep filename '_' suffix '.ine']);
    end
else
    error('lrs is not installed on your machine or not in the path. Refer to http://cgm.cs.mcgill.ca/~avis/C/lrs.html to install lrs.');
end

[R, V] = lrsOutputReadRay([filename '_' suffix '.ext']);

if any((A * R) ~= 0)
    warning('pathway not in nullspace of stoichiometric matrix')
end
