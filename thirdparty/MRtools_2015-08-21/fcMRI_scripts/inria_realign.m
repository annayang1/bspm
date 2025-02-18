function inria_realign(P,flags)
% Robust rigid motion compensation in time series.
% FORMAT inria_realign(P,flags)
%
% Similar to spm_realign.m. 
%
% P     - matrix of filenames {one string per row}
%         All operations are performed relative to the first image.
%         ie. Coregistration is to the first image, and resampling
%         of images is into the space of the first image.
%         For multiple sessions, P should be a cell array, where each
%         cell should be a matrix of filenames.
%
% flags - a structure containing various options.  The fields are:
%
%         rho_func - A string indicating the cost function that
%                    will be used to caracterize intensity errors. 
%                    Possible choices are :
%
%                      'quadratic' -  fast, but not robust...
%                      'absolute'  -  quite slow, not very robust
%                        'huber'   -  Huber function 
%                        'cauchy'  -  Cauchy function 
%                        'geman'   -  Geman-McClure function
%                       'leclerc'  -  Leclerc-Welsch function
%                        'tukey'   -  Tukey's biweight function
%
%                    DEFAULT: 'geman', usually a good trade-off
%                    between robustness and speed.
%
%          cutoff  - Most of the rho functions listed above require
%                    an extra-parameter called the cut-off distance
%                    (exceptions are 'quadratic' and 'absolute'). The
%                    cut-off value is set proportionally to the
%                    standard deviation of the noise (which is
%                    estimated in course of registration using the
%                    median of absolute deviations). The
%                    proportionality factor, however, may be set by the
%                    user according to the considered rho-function.
%                    
%                    DEFAULT: 2.5.
%
%   The remaining flags are the same as in spm_realign:
%
%         quality - Quality versus speed trade-off.  Highest quality
%                   (1) gives most precise results, whereas lower
%                   qualities gives faster realignment.
%                   The idea is that some voxels contribute little to
%                   the estimation of the realignment parameters.
%                   This parameter is involved in selecting the number
%                   of voxels that are used.
%
%         fwhm    - The FWHM of the Gaussian smoothing kernel (mm)
%                   applied to the images before estimating the
%                   realignment parameters.
%
%         sep     - the default separation (mm) to sample the images.
%
%         rtm     - Register to mean.  If field exists then a two pass
%                   procedure is to be used in order to register the
%                   images to the mean of the images after the first
%                   realignment.
%
%         PW      - a filename of a weighting image (reciprocal of
%                   standard deviation).  If field does not exist, then
%                   no weighting is done.
%
%         hold    - hold for interpolation (see spm_slice_vol and
%                   spm_sample_vol).
%
%__________________________________________________________________________
%
% Inputs
% A series of *.img conforming to SPM data format (see 'Data Format').
%
% Outputs
% The parameter estimation part writes out ".mat" files for each of the
% input images.  The details of the transformation are displayed in the
% results window as plots of translation and rotation.
% A set of realignment parameters are saved for each session, named:
% realignment_params_*.txt.
%__________________________________________________________________________
%
% The `.mat' files.
%
% This simply contains a 4x4 affine transformation matrix in a variable `M'.
% These files are normally generated by the `realignment' and
% `coregistration' modules.  What these matrixes contain is a mapping from
% the voxel coordinates (x0,y0,z0) (where the first voxel is at coordinate
% (1,1,1)), to coordinates in millimeters (x1,y1,z1).  By default, the
% the new coordinate system is derived from the `origin' and `vox' fields
% of the image header.
%  
% x1 = M(1,1)*x0 + M(1,2)*y0 + M(1,3)*z0 + M(1,4)
% y1 = M(2,1)*x0 + M(2,2)*y0 + M(2,3)*z0 + M(2,4)
% z1 = M(3,1)*x0 + M(3,2)*y0 + M(3,3)*z0 + M(3,4)
%
% Assuming that image1 has a transformation matrix M1, and image2 has a
% transformation matrix M2, the mapping from image1 to image2 is: M2\M1
% (ie. from the coordinate system of image1 into millimeters, followed
% by a mapping from millimeters into the space of image2).
%
% These `.mat' files allow several realignment or coregistration steps to be
% combined into a single operation (without the necessity of resampling the
% images several times).  The `.mat' files are also used by the spatial
% normalisation module.
%__________________________________________________________________________
% @(#)inria_realign.m  1.01 Alexis Roche 01/03/08
% based on spm_realign.m  2.27 John Ashburner 99/10/26


if nargin==0, inria_realign_ui; return; end;

def_flags = struct('quality',1,'fwhm',6,'sep',4.5,'hold',-8,...
		   'rho_func','geman','cutoff',2.5);

if nargin < 2,
	flags = def_flags;
else,
	fnms = fieldnames(def_flags);
	for i=1:length(fnms),
		if ~isfield(flags,fnms{i}),
			flags = setfield(flags,fnms{i},getfield(def_flags,fnms{i}));
		end;
	end;
end;


linfun = inline('fprintf(''  %-60s%s'', x,sprintf(''\b'')*ones(1,60))');

% if ~isstruct(P) 
    if isempty(P), warning('Nothing to do'); return; end;
    if ~iscell(P), tmp = cell(1); tmp{1} = P; P = tmp; end;
    P = spm_vol(P);
    if isfield(flags,'PW'), flags.PW = spm_vol(flags.PW); end;
% end

if length(P)==1,
	linfun('Registering images..');
	P{1} = realign_series(P{1},flags);
	save_parameters(P{1}); 
else,
	linfun('Registering together the first image of each session..');
    %%% I might be able to tweak something here.
	Ptmp = P{1}(1);
	for s=2:prod(size(P)),
		Ptmp = [Ptmp ; P{s}(1)];
	end;

	Ptmp = realign_series(Ptmp,flags);

	for s=1:prod(size(P)),
		M  = Ptmp(s).mat*inv(P{s}(1).mat);
		for i=1:prod(size(P{s})),
			P{s}(i).mat = M*P{s}(i).mat;
		end;
	end;

	for s=1:prod(size(P)),
		linfun(['Registering together images from session ' num2str(s) '..']);
		P{s} = realign_series(P{s},flags);
		save_parameters(P{s});
	end;
end;

% Save Realignment Parameters
%---------------------------------------------------------------------------
linfun('Saving parameters..');
for s=1:prod(size(P)),
	for i=1:prod(size(P{s})),
        if strmatch(P{s}(i).fname(end-2:end), 'nii')
            %%% Alright, so this is all it took to get it straightend out.
            spm_get_space([P{s}(i).fname ',' num2str(i)], P{s}(i).mat);
        else
            spm_get_space(P{s}(i).fname, P{s}(i).mat);
        end
	end;
end;
plot_parameters(P,flags);

return;


%_______________________________________________________________________

%_______________________________________________________________________
function P = realign_series(P,flags)
% Realign a time series of 3D images to the first of the series.
% FORMAT P = realign_series(P,flags)
% P  - a vector of volumes (see spm_vol)
%-----------------------------------------------------------------------
% P(i).mat is modified to reflect the modified position of the image i.
% The scaling (and offset) parameters are also set to contain the
% optimum scaling required to match the images.
%_______________________________________________________________________

if prod(size(P))<2, return; end;

lkp = [1 2 3 4 5 6];
if P(1).dim(3) < 3, lkp = [1 2 6]; end;



% Robust estimation flags
%-----------------------------------------------------------------------
flagSSD = (flags.cutoff == Inf | strcmp(lower(flags.rho_func), 'quadratic'));
flagSAD = strcmp(lower(flags.rho_func), 'absolute');

% Points to sample in reference image
%-----------------------------------------------------------------------
skip = sqrt(sum(P(1).mat(1:3,1:3).^2)).^(-1)*flags.sep;
d    = P(1).dim(1:3);
[x1,x2,x3]=ndgrid(1:skip(1):d(1),1:skip(2):d(2),1:skip(3):d(3));
x1   = x1(:);
x2   = x2(:);
x3   = x3(:);


% Possibly mask an area of the sample volume.
%-----------------------------------------------------------------------
if isfield(flags,'PW'),
	[y1,y2,y3]=coords([0 0 0  0 0 0],P(1).mat,flags.PW.mat,x1,x2,x3);
	wt  = spm_sample_vol(flags.PW,y1,y2,y3,1);
	msk = find(wt>0.01);
	x1  = x1(msk);
	x2  = x2(msk);
	x3  = x3(msk);
	wt  = wt(msk);
else,
	wt = [];
end;
n = prod(size(x1));


% Compute rate of change of (robust) chi2  w.r.t changes in parameters (matrix A)
%--------------------------------------------------------------------------------
V = smooth_vol(P(1),flags.fwhm);
[G,dG1,dG2,dG3] = spm_sample_vol(V,x1,x2,x3,flags.hold);
clear V
A0 = make_A(P(1).mat,x1,x2,x3,dG1,dG2,dG3,lkp);

%----------------------------------------------------------------------
% Depending on flags.quality, remove a certain percentage of voxels 
% that contribute little to the final estimate. It basically
% involves removing the voxels that contribute least to the
% determinant of the inverse covariance matrix. 

if flags.quality < 1,

%   spm_chi2_plot('Init','Eliminating Unimportant Voxels',...
% 		'Fractional loss of quality','Iteration');
  spm_plot_convergence('Init','Eliminating Unimportant Voxels','Fractional loss of quality','Iteration');
  
  if isempty(wt),
    %det0 = det(spm_atranspa([A0 -G]));
    det0 = det([A0 -G]'*[A0 -G]); %APS_Edit
  else,
    det0 = det(spm_atranspa(diagW_A(sqrt(wt),[A0 -G])));
    det0 = (det0^2)/det(spm_atranspa(diagW_A(wt,[A0 -G])));
  end,
    

  % We will reject the voxels having the least gradient norm. Although
  % essentially heuristic, this choice allows to speed up the
  % selection while achieving compression rates that are not worse
  % than in the original SPM implementation.
  normG = dG1.^2 + dG2.^2 + dG3.^2; 
  Nvox = length(normG);

  if ~isempty(wt), 
    normG = (wt.^2).*normG;
  end,

  % Initial fraction of points. 
  prop = 0.5*flags.quality;
  [junk,mmsk] = sort(normG);   % junk == normG(msk)

  step = 0.1;
  det1=det0;
  stop = 0;
  isdet_large = 1;

  while stop == 0 & prop > 1e-2,

    msk = mmsk( round((1-prop)*Nvox):Nvox );
    Adim = [A0(msk,:), -G(msk,:)];
    
    if isempty(wt),
%       det1 = det(spm_atranspa(Adim));
      det1 = det(Adim'*Adim); %% aps edit
    else,
      det1 = det(spm_atranspa(diagW_A(sqrt(wt(msk)),Adim)));
      det1 = (det1^2)/det(spm_atranspa(diagW_A(wt(msk),Adim)));
    end,

    stop = ( abs(det1/det0 - flags.quality) < 1e-2 );
    
    aux = (det1/det0 > flags.quality);
    if aux ~= isdet_large,
      isdet_large = aux;
      step = step/2;
    end,
    
    if isdet_large,
      prop = prop - step;
    else,
      prop = prop + step;
    end,
    
    spm_plot_convergence('Set',det1/det0);

  end,
  clear Adim,
  clear normG,
  msk = mmsk(1:ceil((1-prop)*Nvox));
  A0(msk,:) = []; G(msk,:) = [];
  x1(msk,:) = [];  x2(msk,:) = [];  x3(msk,:) = [];
  dG1(msk,:) = []; dG2(msk,:) = []; dG3(msk,:) = [];
  if ~isempty(wt),  wt(msk,:) = []; end;

  spm_plot_convergence('Clear');
end,
  

%-----------------------------------------------------------------------
if isfield(flags,'rtm'),
        count = ones(size(G));
	ave   = G;
	grad1 = dG1;
	grad2 = dG2;
	grad3 = dG3;
end;

spm_progress_bar('Init',length(P)-1,'Registering Images');

% Loop over images
%-----------------------------------------------------------------------
for i=2:length(P),
  
  V=smooth_vol(P(i),flags.fwhm);
  countdown = -1;
  Hold = 1;  % Begin with tri-linear interpolation.
  
  
  for iter=1:64,
    
    % Initial multiplicative factor to be applied to image P(i)
    slope = 1.0; 
    
    % Voxel coordinates in the P(i) coordinate system of the
    % points yi that match the points xi
    [y1,y2,y3] = coords([0 0 0  0 0 0],P(1).mat,P(i).mat,x1,x2,x3);
    
    % Test partial overlap
    msk = find((y1>=1 & y1<=d(1) & y2>=1 & y2<=d(2) & y3>=1 & y3<=d(3)));
    msk = msk(find(msk<numel(G)));
    if length(msk)<32, error_message(P(i)); end;
    
    % Interpolates image P(i)
    F = spm_sample_vol(V, y1(msk),y2(msk),y3(msk),Hold);
        
    % Matrix A (7xn) and vector b (nx1)
    A = [A0(msk,:), -F];

    try
        b = slope*F - G(msk);
    catch
        keyboard;  
    end
    
    if flagSSD & isempty(wt),
      Alpha = spm_atranspa(A);
      Beta = A'*b;
    else,
                
      % Computes adaptive weights 
      if flagSSD,
	cutoff = Inf;
      elseif flagSAD,
	cutoff = 0;
      else,
	cutoff = flags.cutoff * 1.4826 * median(abs(b)); % Adaptive cut-off distance
      end,
      ad_wt = Mweight(b, cutoff, flags.rho_func);
                  
      % Possibly takes into account prior weights
      if ~isempty(wt), ad_wt = ad_wt.*wt(msk); end,
    
      % Computes A'*diag(ad_wt)
      AtW = diagW_A(ad_wt,A)';
      
      % Computes Alpha (Hessian) and Beta (-0.5* gradient) 
      Alpha = AtW*A;
      Beta  = AtW*b;
      
    end,
    
    % Update parameters
    soln = Alpha\Beta;
    slope = slope + soln(end); 
    p = [0 0 0  0 0 0  1 1 1  0 0 0];
    p(lkp) = soln(1:(end-1));
    
    % Update P(i).mat
    dP =  spm_matrix(p);
    P(i).mat = dP*P(i).mat;
    
    
    % Stopping criterion
    % Test the variation of parameters rather than the variation of 
    % the criterion 
    [epst,epsr] = rigid_errors(eye(4),dP);
    
    if epst < 1e-2 & epsr < 1e-4 & countdown == -1, % Stopped converging.
						    % Switch to a better (slower) interpolation
						    % and do two final iterations
						    Hold = flags.hold;
						    countdown = 2;
    end;
    if countdown ~= -1,
      if countdown==0, break; end;
      countdown = countdown -1;
    end;
  end;
  
  if isfield(flags,'rtm'),
    % Generate mean and derivatives of mean
    tiny = 5e-2; % From spm_vol_utils.c
    msk        = find((y1>=(1-tiny) & y1<=(d(1)+tiny) &...
		       y2>=(1-tiny) & y2<=(d(2)+tiny) &...
		       y3>=(1-tiny) & y3<=(d(3)+tiny)));
    count(msk) = count(msk) + 1;
    [G,dG1,dG2,dG3] = spm_sample_vol(V,y1(msk),y2(msk),y3(msk),flags.hold);
    ave(msk)   = ave(msk)   +   G.*soln(end);
    grad1(msk) = grad1(msk) + dG1.*soln(end);
    grad2(msk) = grad2(msk) + dG2.*soln(end);
    grad3(msk) = grad3(msk) + dG3.*soln(end);
  end;
  spm_progress_bar('Set',i-1);
end;
spm_progress_bar('Clear');


for i=1:prod(size(P)), 
  aux = spm_imatrix(P(i).mat/P(1).mat);
  Params(i,:) = aux(1:6);
end

%%% Bidouille
save SPMtmp Params flags,


if ~isfield(flags,'rtm'), return; end;
%_______________________________________________________________________
M=P(1).mat;
A0 = make_A(M,x1,x2,x3,grad1./count,grad2./count,grad3./count,lkp);
G = ave;

clear ave grad1 grad2 grad3,
  
% Loop over images
%-----------------------------------------------------------------------
spm_progress_bar('Init',length(P),'Registering Images to Mean');

for i=1:length(P),

  V=smooth_vol(P(i),flags.fwhm);

  for iter=1:64,
    
    slope = 1.0; 
    
    [y1,y2,y3] = coords([0 0 0  0 0 0],M,P(i).mat,x1,x2,x3);
    msk        = find((y1>=1 & y1<=d(1) & y2>=1 & y2<=d(2) & y3>=1 & y3<=d(3)));
    if length(msk)<32, error_message(P(i)); end;

    F = spm_sample_vol(V, y1(msk),y2(msk),y3(msk),flags.hold);
    
    A = [A0(msk,:), -F];
    b = slope*F - G(msk);
    
    if flagSSD & isempty(wt),
      Alpha = spm_atranspa(A);
      Beta = A'*b;
    else,
      
      if flagSSD,
	cutoff = Inf;
      elseif flagSAD,
	cutoff = 0;
      else,
	cutoff = flags.cutoff * 1.4826 * median(abs(b)); % Adaptive cut-off distance
      end,
      ad_wt = Mweight(b, cutoff, flags.rho_func);
                  
      if ~isempty(wt), ad_wt = ad_wt.*wt(msk); end,
    
      AtW = diagW_A(ad_wt,A)';
      Alpha = AtW*A;
      Beta  = AtW*b;
      
    end,
    
    % Update parameters
    soln = Alpha\Beta;
    slope = slope + soln(end); 
    p = [0 0 0  0 0 0  1 1 1  0 0 0];
    p(lkp) = soln(1:(end-1));
    
    % Update P(i).mat
    dP =  spm_matrix(p);
    P(i).mat = dP*P(i).mat;
        
    % Stopping criterion
    [epst,epsr] = rigid_errors(eye(4),dP);
    
    if epst < 1e-2 & epsr < 1e-4, % Stopped converging
      break; 
    end,
  end;
  spm_progress_bar('Set',i);
end;
spm_progress_bar('Clear');


% Since we are supposed to be aligning everything to the first
% image, then we had better do so
%-----------------------------------------------------------------------
M = M/P(1).mat;
for i=1:length(P)
	P(i).mat = M*P(i).mat;
end

return;
%_______________________________________________________________________

%_______________________________________________________________________
function [y1,y2,y3]=coords(p,M1,M2,x1,x2,x3)
% Rigid body transformation of a set of coordinates.
M  = (inv(M2)*spm_matrix(p(1:6))*M1);
y1 = M(1,1)*x1 + M(1,2)*x2 + M(1,3)*x3 + M(1,4);
y2 = M(2,1)*x1 + M(2,2)*x2 + M(2,3)*x3 + M(2,4);
y3 = M(3,1)*x1 + M(3,2)*x2 + M(3,3)*x3 + M(3,4);
return;
%_______________________________________________________________________

%_______________________________________________________________________
function V = smooth_vol(P,fwhm)

% Test wehter smoothing should really be applied...
if fwhm == 0, V = spm_read_vols(P); return; end,

% Convolve the volume in memory.
s  = sqrt(sum(P.mat(1:3,1:3).^2)).^(-1)*(fwhm/sqrt(8*log(2)));
x  = round(6*s(1)); x = [-x:x];
y  = round(6*s(2)); y = [-y:y];
z  = round(6*s(3)); z = [-z:z];
x  = exp(-(x).^2/(2*(s(1)).^2));
y  = exp(-(y).^2/(2*(s(2)).^2));
z  = exp(-(z).^2/(2*(s(3)).^2));
x  = x/sum(x);
y  = y/sum(y);
z  = z/sum(z);

i  = (length(x) - 1)/2;
j  = (length(y) - 1)/2;
k  = (length(z) - 1)/2;

V  = zeros(P.dim(1:3));
spm_conv_vol(P,V,x,y,z,-[i j k]);
return;
%_______________________________________________________________________
function A = make_A(M,x1,x2,x3,dG1,dG2,dG3,lkp)
% Matrix of rate of change of weighted difference w.r.t. parameter changes
p0 = [0 0 0  0 0 0  1 1 1  0 0 0];
A  = zeros(prod(size(x1)),length(lkp));
for i=1:length(lkp)
	pt         = p0;
	pt(lkp(i)) = pt(lkp(i))+1e-6;
	[y1,y2,y3] = coords(pt,M,M,x1,x2,x3);
	A(:,i) = sum([y1-x1 y2-x2 y3-x3].*[dG1 dG2 dG3],2)*(1e+6);
end
return;

%_______________________________________________________________________

%_______________________________________________________________________
function error_message(P)

str = {	'There is not enough overlap in the images',...
	'to obtain a solution.',...
	' ',...
	'Offending image:',...
	 P.fname,...
	' ',...
	'Please check that your header information is OK.'};
spm('alert*',str,mfilename,sqrt(-1));
error('insufficient image overlap')

return
%_______________________________________________________________________

%_______________________________________________________________________
function plot_parameters(P,flags)
fg=spm_figure('FindWin','Graphics');
if ~isempty(fg),
	P = cat(1,P{:});
	if length(P)<2, return; end;
	Params = zeros(prod(size(P)),12);
	for i=1:prod(size(P)),
	  Params(i,:) = spm_imatrix(P(i).mat/P(1).mat);
	end

	% display results
	% translation and rotation over time series
	%-------------------------------------------------------------------
	spm_figure('Clear','Graphics');
	ax=axes('Position',[0.1 0.65 0.8 0.2],'Parent',fg,'Visible','off');
	set(get(ax,'Title'),'String','Image realignment (INRIAlign toolbox)','FontSize',16,'FontWeight','Bold','Visible','on');
	x     =  0.1;
	y     =  0.9;
	for i = 1:min([prod(size(P)) 9])
		text(x,y,[sprintf('%-4.0f',i) P(i).fname],'FontSize',10,'Interpreter','none','Parent',ax);
		y = y - 0.08;
	end
	if prod(size(P)) > 9
		text(x,y,'................ etc','FontSize',10,'Parent',ax); end

	
	% Print important parameters
	y=y-0.08; text(x,y,'Parameters','Parent',ax,'FontSize',11,'FontWeight','Bold');	
	tmp  = str2mat('Quadratic','Absolute value','Huber','Cauchy','Geman-McClure','Leclerc-Welsch','Tukey');
	tmp2 = str2mat('quadratic','absolute','huber','cauchy','geman','leclerc','tukey');
	msg = ['   Cost function: ',deblank(tmp(strmatch(flags.rho_func,tmp2),:))];
	if ~strcmp(lower(flags.rho_func),'quadratic') & ~strcmp(lower(flags.rho_func),'absolute'),
	  msg = [msg, ', cut-off distance: ', ...
		 num2str(flags.cutoff),'\times\sigma'];
	end,
	y=y-0.08; text(x,y,msg,'Parent',ax,'Interpreter','tex');
	msg = ['   Quality: ',num2str(flags.quality)];
	msg = [msg,' - Subsampling: ',num2str(flags.sep), ' mm'];
	msg = [msg,' - Smoothing: ',num2str(flags.fwhm),' mm'];
	y=y-0.08; text(x,y,msg,'Parent',ax,'Interpreter','tex');
		
	ax=axes('Position',[0.1 0.35 0.8 0.2],'Parent',fg,'XGrid','on','YGrid','on');
	plot(Params(:,1:3),'Parent',ax)
	% s = ['x translation';'y translation';'z translation'];
	% text([2 2 2], Params(2, 1:3), s, 'Fontsize',10,'Parent',ax)
	legend(ax,'x translation','y translation','z translation');
	set(get(ax,'Title'),'String','translation','FontSize',16,'FontWeight','Bold');
	set(get(ax,'Xlabel'),'String','image');
	set(get(ax,'Ylabel'),'String','mm');


	ax=axes('Position',[0.1 0.05 0.8 0.2],'Parent',fg,'XGrid','on','YGrid','on');
	plot(Params(:,4:6)*180/pi,'Parent',ax)
	% s = ['pitch';'roll ';'yaw  '];
	% text([2 2 2], Params(2, 4:6)*180/pi, s, 'Fontsize',10,'Parent',ax)
	legend(ax,'pitch','roll','yaw');
	set(get(ax,'Title'),'String','rotation','FontSize',16,'FontWeight','Bold');
	set(get(ax,'Xlabel'),'String','image');
	set(get(ax,'Ylabel'),'String','degrees');

	% print realigment parameters
	spm_print
end
return;
%_______________________________________________________________________

%_______________________________________________________________________
function save_parameters(V)
fname = [spm_str_manip(prepend(V(1).fname,'realignment_params_'),'s') '.txt'];
n = length(V);
Q = zeros(n,6);
for j=1:n,
  qq     = spm_imatrix(V(j).mat/V(1).mat);
  Q(j,:) = qq(1:6);
end;
save(fname,'Q','-ascii');
return;
%_______________________________________________________________________

%_______________________________________________________________________
function PO = prepend(PI,pre)
[pth,nm,xt] = fileparts(deblank(PI));
PO             = fullfile(pth,[pre nm xt]);
return;
%_______________________________________________________________________
function y = Mweight(x, c, flag)


if c == Inf, flag = 'quadratic'; end,

% To avoid numerical instabilities
cc = max(c, 1e-1);

switch lower(flag)

 case 'quadratic'
  y = ones(size(x));

 case 'absolute'
  % To avoid numerical instabilities, the theoretical weighting
  % function given by 1/|x| is replaced with a bounded function. This 
  % corresponds to approximating |x| by sqrt(x^2 + tiny).
  ic = 10;
  y = 1./sqrt(1 + (ic*x).^2);  

 case 'huber'
  y = ones(size(x));
  [aux, msk] = find(abs(x)>cc);
  y(msk) = cc./abs(x(msk));
  
 case 'cauchy'
  ic = 1/cc;
  y = (1 + (x*ic).^2).^(-1);

 case 'geman'
  ic = 1/cc;
  y = (1 + (x*ic).^2).^(-2);
  
 case 'leclerc'
  ic = 1/cc;
  y = exp( - (x*ic).^2 );
  
 case 'tukey'
  ic = 1/cc;
  y = ( abs(x)<cc ) .* (1 - (x*ic).^2).^(2);
  
 otherwise
  error('no M-estimator specified'),
  
end,
  
return; 
%_______________________________________________________________________
function B = diagW_A(w,A);

% Computes diag(w)*A without computing w;
% Assumes wt is a column vector.

for i=1:size(A,2),
  B(:,i) = w.*A(:,i);
end,

return;

%_______________________________________________________________________
function [dt,dr] = rigid_errors ( T_gt, T );

% Translation error 
  dt = norm ( T_gt(1:3,4) - T(1:3,4) );

% Rotation error (in degrees)
  rad2deg = 57.2958;
  dR = inv(T_gt(1:3,1:3))*T(1:3,1:3);

  [V,D]=eig(dR);
  % Find the indice corresponding to eigenvalue 1
  [tmp,in]=min( (diag(D)-1).*conj(diag(D)-1) );
  % Rotation axis
  n=V(1:3,in);
  n=n/norm(n);
  % Construct an orthonormal basis (n,v,w)
  [tmp,in2]=min(abs(n));
  aux=[0 0 0]';
  aux(in2)=1;
  v=cross(n,aux);
  v=v/norm(v);
  w=cross(n,v);
  w=w/norm(w);
  % Rotation angle
  drv=dR*v;
  dr=atan2(w'*drv,v'*drv);
  % Error in degrees
  dr = rad2deg * abs(dr);

return;
