function [u] = ipctb_spm_uc_Bonf(a,df,STAT,S,n)
% corrected critical height threshold at a specified significance level
% FORMAT [u] = spm_uc_Bonf(a,df,STAT,S,n)
% a     - critical probability - {alpha}
% df    - [df{interest} df{residuals}]
% STAT  - Statisical feild
%		'Z' - Gaussian feild
%		'T' - T - feild
%		'X' - Chi squared feild
%		'F' - F - feild
% S     - Voxel count
% n     - number of conjoint SPMs
%
% u     - critical height {corrected}
%
%___________________________________________________________________________
%
% spm_uc returns the corrected critical threshold at a specified significance
% level (a). If n > 1 a conjunction the probability over the n values of the 
% statistic is returned.
%___________________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Thomas Nichols
% $Id: spm_uc_Bonf.m 112 2005-05-04 18:20:52Z john $


u   = ipctb_spm_u((a/S).^(1/n),df,STAT);
