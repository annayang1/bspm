function [Y,XYZ] = lui_spm_read_vols(V,mask)
% Read in entire image volumes
% FORMAT [Y,XYZ] = lui_spm_read_vols(V,mask)
% V    - vector of mapped image volumes to read in (from lui_spm_vol)
% mask - implicit zero mask?
% Y    - 4D matrix of image data, fourth dimension indexes images
% XYZ  - 3xn matrix of XYZ locations returned
%_______________________________________________________________________
%
% For image data types without a representation of NaN (see lui_spm_type),
% implicit zero masking can be used. If mask is set, then zeros are
% treated as masked, and returned as NaN.
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Andrew Holmes
% $Id: lui_spm_read_vols.m 401 2006-01-12 12:10:17Z john $



%-Argument checks
%-----------------------------------------------------------------------
if nargin<2, mask = 0; end
if nargin<1, error('insufficient arguments'), end

%-Image dimension, orientation and voxel size checks
%-----------------------------------------------------------------------
if length(V)>1 & any(any(diff(cat(1,V.dim),1,1),1))
	error('images don''t all have the same dimensions'), end
if any(any(any(diff(cat(3,V.mat),1,3),3)))
	error('images don''t all have same orientation & voxel size'), end

%-Read in image data
%-----------------------------------------------------------------------
n  = prod(size(V));			%-#images
Y = zeros([V(1).dim(1:3),n]);		%-image data matrix

for i=1:n, for p=1:V(1).dim(3)
	Y(:,:,p,i) = lui_spm_slice_vol(V(i),lui_spm_matrix([0 0 p]),V(i).dim(1:2),0);
end, end

%-Apply implicit zero mask for image datatypes without a NaNrep
%-----------------------------------------------------------------------
if mask
	%-Work out images without NaNrep
	im = logical(zeros(n,1));
	for i=1:n, im(i)=~lui_spm_type(V(i).dt(1),'NaNrep'); end
	%-Mask
	Y(Y(:,:,:,im)==0)=NaN;
end

%-Return as 3D matrix if single image
%-----------------------------------------------------------------------
if n==1; Y=Y(:,:,:,1); end

%-Compute XYZ co-ordinates (if required)
%-----------------------------------------------------------------------
if nargout>1
	[R,C,P]=ndgrid(1:V(1).dim(1),1:V(1).dim(2),1:V(1).dim(3));
	RCP = [R(:)';C(:)';P(:)'];
	clear R C P
	RCP(4,:)=1;
	XYZ = V(1).mat(1:3,:)*RCP;
end
