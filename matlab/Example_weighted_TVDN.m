%% Exampled_weighted_TVDN
% Example to demonstrate use of TVDN solver when incorporating weights
% (performs one re-weighting of previous solution).


%% Clear workspace
clc;
clear;

%% Define paths
addpath misc/
addpath prox_operators/

%% Parameters
N = 64;
input_snr = 30; % Noise level (on the measurements)
randn('seed', 1); rand('seed', 1);

%% Load image
im = phantom(N);
%
figure(1); clf;
subplot(141), imagesc(im); axis image; axis off;
colormap gray; title('Original image'); drawnow;

%% Create a mask
% Mask
mask = rand(size(im)) < 0.33; ind = find(mask==1);
% Masking matrix (sparse matrix in matlab)
Ma = sparse(1:numel(ind), ind, ones(numel(ind), 1), numel(ind), numel(im));

%% Measure a few Fourier measurements

% Composition (Masking o Fourier)
A = @(x) Ma*reshape(fft2(x)/sqrt(numel(im)), numel(x), 1);
At = @(x) ifft2(reshape(Ma'*x(:), size(im))*sqrt(numel(im)));

% TV sparsity operator
Psit = @(x) x; Psi = Psit;

% Select 33% of Fourier coefficients
y = A(im);

% Add Gaussian i.i.d. noise
sigma_noise = 10^(-input_snr/20)*std(im(:));
y = y + (randn(size(y)) + 1i*randn(size(y)))*sigma_noise/sqrt(2);

% Display the downsampled image
figure(1);
subplot(142); imagesc(real(At(y))); axis image; axis off;
colormap gray; title('Measured image'); drawnow;

%% Reconstruct with TV 

% Tolerance on noise
epsilon = sqrt(chi2inv(0.99, 2*numel(ind))/2)*sigma_noise;

% Parameters for TVDN
param.verbose = 1; % Print log or not
param.rel_obj = 1e-4; % Stopping criterion for the TVDN problem
param.max_iter = 200; % Max. nb. of iterations for the TVDN problem
param.gamma = 1e-1; % Converge parameter
param.nu_B2 = 1; % Bound on the norm of the operator A
param.tol_B2 = 1e-4; % Tolerance for the projection onto the L2-ball
param.tight_B2 = 1; % Indicate if A is a tight frame (1) or not (0)
param.max_iter_TV = 500; % 
param.zero_weights_flag_TV = 0; %
param.identical_weights_flag_TV = 1; %

% Solve TVDN problem (without weights)
sol_1 = sopt_mltb_solve_TVDNoA(y, epsilon, A, At, Psi, Psit, param);

% Show first reconstructed image
figure(1);
subplot(143); imagesc(real(sol_1)); axis image; axis off;
colormap gray; 
title(['First estimate: ', ...
    num2str(sopt_mltb_SNR(im, real(sol_1))), 'dB']);
drawnow;
clc;

%% Re-fine the estimate with weighted TV
% Weights
[param.weights_dx_TV param.weights_dy_TV] = sopt_mltb_gradient_op(real(sol_1));
param.weights_dx_TV = 1./(abs(param.weights_dx_TV)+1e-3);
param.weights_dy_TV = 1./(abs(param.weights_dy_TV)+1e-3);
param.identical_weights_flag_TV = 0;
param.gamma = 1e-3;

% First reconstruction with weights in the gradient
param.zero_weights_flag_TV = 1;
sol_2 = sopt_mltb_solve_TVDNoA(y, epsilon, A, At, Psi, Psit, param);
% Show second reconstructed image
figure(1);
subplot(144); imagesc(real(sol_2)); axis image; axis off;
colormap gray; 
title(['Second estimate: ', ...
    num2str(sopt_mltb_SNR(im, real(sol_2))), 'dB']); 
drawnow;
