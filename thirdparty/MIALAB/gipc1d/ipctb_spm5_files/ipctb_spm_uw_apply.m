function varargout = ipctb_spm_uw_apply(ds,flags)
% Reslices images volume by volume
% FORMAT spm_uw_apply(ds,[flags])
% or
% FORMAT P = spm_uw_apply(ds,[flags])
%
%               
% ds       - a structure created by spm_uw_estimate.m containing the fields:
%            ds can also be an array of structures, each struct corresponding
%            to one sesssion (it hardly makes sense to try and pool fields across
%            sessions since there will have been a reshimming). In that case each
%            session is unwarped separately, unwarped into the distortion space of
%            the average (default) position of that series, and with the first
%            scan on the series defining the pahse encode direction. After that each
%            scan is transformed into the space of the first scan of the first series.
%            Naturally, there is still only one actual resampling (interpolation).
%            It will be assumed that the same unwarping parameters have been used
%            for all sessions (anything else would be truly daft).
% 
% .P              - Images used when estimating deformation field and/or
%                   its derivative w.r.t. modelled factors. Note that this
%                   struct-array may contain .mat fields that differ from
%                   those you would observe with spm_vol(P(1).fname). This
%                   is because spm_uw_estimate has an option to re-estimate
%                   the movement parameters. The re-estimated parameters are
%                   not written to disc (in the form of .mat files), but rather
%                   stored in the P array in the ds struct.
%
% .order       - Number of basis functions to use for each dimension.
%                If the third dimension is left out, the order for 
%                that dimension is calculated to yield a roughly
%                equal spatial cut-off in all directions.
%                Default: [8 8 *]
% .sfP         - Static field supplied by the user. It should be a 
%                filename or handle to a voxel-displacement map in
%                the same space as the first EPI image of the time-
%                series. If using the FieldMap toolbox, realignment
%                should (if necessary) have been performed as part of
%                the process of creating the VDM. Note also that the
%                VDM mut be in undistorted space, i.e. if it is
%                calculated from an EPI based field-map sequence
%                it should have been inverted before passing it to
%                spm_uw_estimate. Again, the FieldMap toolbox will
%                do this for you.
% .regorder    - Regularisation of derivative fields is based on the
%                regorder'th (spatial) derivative of the field.
%                Default: 1
% .lambda      - Fudge factor used to decide relative weights of
%                data and regularisation.
%                Default: 1e5
% .jm          - Jacobian Modulation. If set, intensity (Jacobian)
%                deformations are included in the model. If zero,
%                intensity deformations are not considered. 
% .fot         - List of indexes for first order terms to model
%                derivatives for. Order of parameters as defined
%                by spm_imatrix. 
%                Default: [4 5]
% .sot         - List of second order terms to model second 
%                derivatives of. Should be an nx2 matrix where
%                e.g. [4 4; 4 5; 5 5] means that second partial
%                derivatives of rotation around x- and y-axis
%                should be modelled.
%                Default: []
% .fwhm        - FWHM (mm) of smoothing filter applied to images prior
%                to estimation of deformation fields.
%                Default: 6
% .rem         - Re-Estimation of Movement parameters. Set to unity means
%                that movement-parameters should be re-estimated at each
%                iteration.
%                Default: 0
% .noi         - Maximum number of Iterations.
%                Default: 5
% .exp_round   - Point in position space to do Taylor expansion around.
%                'First', 'Last' or 'Average'.
% .p0          - Average position vector (three translations in mm
%                and three rotations in degrees) of scans in P.
% .q           - Deviations from mean position vector of modelled
%                effects. Corresponds to deviations (and deviations
%                squared) of a Taylor expansion of deformation fields.
% .beta        - Coeffeicents of DCT basis functions for partial
%                derivatives of deformation fields w.r.t. modelled
%                effects. Scaled such that resulting deformation 
%                fields have units mm^-1 or deg^-1 (and squares 
%                thereof).
% .SS          - Sum of squared errors for each iteration.
%
% flags    - a structure containing various options.  The fields are:
%
%         mask - mask output images (1 for yes, 0 for no)
%                To avoid artifactual movement-related variance the realigned
%                set of images can be internally masked, within the set (i.e.
%                if any image has a zero value at a voxel than all images have
%                zero values at that voxel).  Zero values occur when regions
%                'outside' the image are moved 'inside' the image during
%                realignment.
%
%         mean - write mean image
%                The average of all the realigned scans is written to
%                mean*.img.
%
%         interp - the interpolation method (see e.g. spm_bsplins.m).
%
%         which - Values of 0 or 1 are allowed.
%                 0   - don't create any resliced images.
%                       Useful if you only want a mean resliced image.
%                 1   - reslice all the images.
%
%         udc - Values 1 or 2 are allowed
%               1   - Do only unwarping (not correcting 
%                     for changing sampling density).
%               2   - Do both unwarping and Jacobian correction.
%
%
%             The spatially realigned images are written to the orginal
%             subdirectory with the same filename but prefixed with an 'u'.
%             They are all aligned with the first.
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Jesper Andersson
% $Id: spm_uw_apply.m 403 2006-01-13 18:17:18Z john $

tiny = 5e-2;

global defaults

def_flags = struct('mask',       1,...
                   'mean',       1,...
                   'interp',     4,...
                   'wrap',       [0 1 0],...
                   'which',      1,...
                   'udc',        1);

defnames = fieldnames(def_flags);

%
% Replace hardcoded defaults with spm_defaults
% when exist and defined.
%
if exist('defaults','var') && isfield(defaults,'realign') && isfield(defaults.realign,'write')
   wd = defaults.realign.write;
   if isfield(wd,'interp'),    def_flags.interp = wd.interp; end
   if isfield(wd,'wrap'),      def_flags.wrap = wd.wrap; end
   if isfield(wd,'mask'),      def_flags.mask = wd.mask; end
end

if nargin < 1 || isempty(ds)
    ds = load(ipctb_spm_select(1,'.*uw\.mat$','Select Unwarp result file'),'ds');
    ds = ds.ds;
end

%
% Default to using Jacobian modulation for the reslicing if it was
% used during the estimation phase.
%
if ds(1).jm ~= 0
   def_flags.udc = 2;
end

%
% Replace defaults with user supplied values for all fields
% defined by user. Also, warn user of any invalid fields,
% probably reflecting misspellings.
%
if nargin < 2 || isempty(flags)
   flags = def_flags;
end
for i=1:length(defnames)
   if ~isfield(flags,defnames{i})
      %flags = setfield(flags,defnames{i},getfield(def_flags,defnames{i}));
      flags.(defnames{i}) = def_flags.(defnames{i});
   end
end
flagnames = fieldnames(flags);
for i=1:length(flagnames)
   if ~isfield(def_flags,flagnames{i})
      warning('Warning, unknown flag field %s',flagnames{i});
   end
end

ntot = 0;
for i=1:length(ds)
   ntot = ntot + length(ds(i).P);
end

hold = [repmat(flags.interp,1,3) flags.wrap];

linfun = inline('fprintf(''%-60s%s'', x,repmat(sprintf(''\b''),1,60))');

%
% Create empty sfield for all structs.
%
[ds.sfield] = deal([]);

%
% Make space for output P-structs if required
%
if nargout > 0
   oP = cell(length(ds),1);
end

%
% First, create mask if so required.
%

if flags.mask || flags.mean,
   linfun('Computing mask..');
   ipctb_spm_progress_bar('Init',ntot,'Computing available voxels',...
                    'volumes completed');
   [x,y,z] = ndgrid(1:ds(1).P(1).dim(1),1:ds(1).P(1).dim(2),1:ds(1).P(1).dim(3));
   xyz = [x(:) y(:) z(:) ones(prod(ds(1).P(1).dim(1:3)),1)]; clear x y z;
   if flags.mean
      Count    = zeros(prod(ds(1).P(1).dim(1:3)),1);
      Integral = zeros(prod(ds(1).P(1).dim(1:3)),1);
   end

   % if flags.mask 
   msk = zeros(prod(ds(1).P(1).dim(1:3)),1);  
   % end

   tv = 1;
   for s=1:length(ds)
      def_array = zeros(prod(ds(s).P(1).dim(1:3)),size(ds(s).beta,2));
      Bx = ipctb_spm_dctmtx(ds(s).P(1).dim(1),ds(s).order(1));
      By = ipctb_spm_dctmtx(ds(s).P(1).dim(2),ds(s).order(2));
      Bz = ipctb_spm_dctmtx(ds(s).P(1).dim(3),ds(s).order(3));
      if isfield(ds(s),'sfP') && ~isempty(ds(s).sfP)
         T = ds(s).sfP.mat\ds(1).P(1).mat;
         txyz = xyz * T';
         c = ipctb_spm_bsplinc(ds(s).sfP,ds(s).hold);
         ds(s).sfield = ipctb_spm_bsplins(c,txyz(:,1),txyz(:,2),txyz(:,3),ds(s).hold);
         ds(s).sfield = ds(s).sfield(:);
         clear c txyz;
      end 
      for i=1:size(ds(s).beta,2)
         def_array(:,i) = ipctb_spm_get_def(Bx,By,Bz,ds(s).beta(:,i));
      end
      sess_msk = zeros(prod(ds(1).P(1).dim(1:3)),1);
      for i = 1:numel(ds(s).P)
         T = inv(ds(s).P(i).mat) * ds(1).P(1).mat;
         txyz = xyz * T';
         txyz(:,2) = txyz(:,2) + ipctb_spm_get_image_def(ds(s).P(i),ds(s),def_array);
         sess_msk = sess_msk + real(txyz(:,1) < (1-tiny) | txyz(:,1) > (ds(s).P(1).dim(1)+tiny) |...
                                    txyz(:,2) < (1-tiny) | txyz(:,2) > (ds(s).P(1).dim(2)+tiny) |...
                                    txyz(:,3) < (1-tiny) | txyz(:,3) > (ds(s).P(1).dim(3)+tiny));     % Changed 23/3-05   
         ipctb_spm_progress_bar('Set',tv);
         tv = tv+1;
      end
      msk = msk + sess_msk;
      if flags.mean, Count = Count + repmat(length(ds(s).P),prod(ds(s).P(1).dim(1:3)),1) - sess_msk; end   % Changed 23/3-05
  
      %
      % Include static field in estmation of mask.
      %
      if isfield(ds(s),'sfP') && ~isempty(ds(s).sfP)
         T = inv(ds(s).sfP.mat) * ds(1).P(1).mat;
         txyz = xyz * T';
         msk = msk + real(txyz(:,1) < (1-tiny) | txyz(:,1) > (ds(s).sfP.dim(1)+tiny) |...
                          txyz(:,2) < (1-tiny) | txyz(:,2) > (ds(s).sfP.dim(2)+tiny) |...
                          txyz(:,3) < (1-tiny) | txyz(:,3) > (ds(s).sfP.dim(3)+tiny)); 
      end
      if isfield(ds(s),'sfield') && ~isempty(ds(s).sfield)
         ds(s).sfield = [];
      end
   end
   if flags.mask, msk = find(msk ~= 0); end
end

linfun('Reslicing images..');
ipctb_spm_progress_bar('Init',ntot,'Reslicing','volumes completed');

jP       = ds(1).P(1);
jP       = rmfield(jP,{'fname','descrip','n','private'});
jP.dim   = jP.dim(1:3);
jP.dt    = [ipctb_spm_type('float64'), ipctb_spm_platform('bigend')];
jP.pinfo = [1 0]';
tv       = 1;
for s=1:length(ds)
   def_array = zeros(prod(ds(s).P(1).dim(1:3)),size(ds(s).beta,2));
   Bx = ipctb_spm_dctmtx(ds(s).P(1).dim(1),ds(s).order(1));
   By = ipctb_spm_dctmtx(ds(s).P(1).dim(2),ds(s).order(2));
   Bz = ipctb_spm_dctmtx(ds(s).P(1).dim(3),ds(s).order(3));
   if isfield(ds(s),'sfP') && ~isempty(ds(s).sfP)
      T = ds(s).sfP.mat\ds(1).P(1).mat;
      txyz = xyz * T';
      c = ipctb_spm_bsplinc(ds(s).sfP,ds(s).hold);
      ds(s).sfield = ipctb_spm_bsplins(c,txyz(:,1),txyz(:,2),txyz(:,3),ds(s).hold);
      ds(s).sfield = ds(s).sfield(:);
      clear c txyz;
   end 
   for i=1:size(ds(s).beta,2)
      def_array(:,i) = ipctb_spm_get_def(Bx,By,Bz,ds(s).beta(:,i));
   end
   if flags.udc > 1
      ddef_array = zeros(prod(ds(s).P(1).dim(1:3)),size(ds(s).beta,2));
      dBy = ipctb_spm_dctmtx(ds(s).P(1).dim(2),ds(s).order(2),'diff');
      for i=1:size(ds(s).beta,2)
         ddef_array(:,i) = ipctb_spm_get_def(Bx,dBy,Bz,ds(s).beta(:,i));
      end
   end
   for i = 1:length(ds(s).P)
      linfun(['Reslicing volume ' num2str(tv) '..']);
      %
      % Read undeformed image.
      %
      T = inv(ds(s).P(i).mat) * ds(1).P(1).mat;
      txyz = xyz * T';
      if flags.udc > 1
         [def,jac] = ipctb_spm_get_image_def(ds(s).P(i),ds(s),def_array,ddef_array);
      else
         def = ipctb_spm_get_image_def(ds(s).P(i),ds(s),def_array);
      end
      txyz(:,2) = txyz(:,2) + def;
      if flags.udc > 1
         jP.dat = reshape(jac,ds(s).P(i).dim(1:3));
         jtxyz = xyz * T';
         c = ipctb_spm_bsplinc(jP.dat,hold);
         jac = ipctb_spm_bsplins(c,jtxyz(:,1),jtxyz(:,2),jtxyz(:,3),hold);
      end      
      c = ipctb_spm_bsplinc(ds(s).P(i),hold);
      ima = ipctb_spm_bsplins(c,txyz(:,1),txyz(:,2),txyz(:,3),hold);
      if flags.udc > 1
         ima = ima .* jac;
      end
      %
      % Write it if so required.
      %
      if flags.which
         PO         = ds(s).P(i);
         PO.fname   = prepend(PO.fname,'u');
         PO.mat     = ds(1).P(1).mat;
         PO.descrip = 'spm - undeformed';
	 ivol       = ima; 
         if flags.mask
	    ivol(msk) = NaN;
         end
         ivol = reshape(ivol,PO.dim(1:3));
         PO   = ipctb_spm_create_vol(PO);
         for ii=1:PO.dim(3),
             PO = ipctb_spm_write_plane(PO,ivol(:,:,ii),ii);
         end;
	 if nargout > 0
	    oP{s}(i) = PO;
	 end
      end
      %
      % Build up mean image if so required.
      %
      if flags.mean
         Integral = Integral + nan2zero(ima);
      end
      ipctb_spm_progress_bar('Set',tv);
      tv = tv+1;
   end
   if isfield(ds(s),'sfield') && ~isempty(ds(s).sfield)
      ds(s).sfield = [];
   end
end

if flags.mean
   % Write integral image (16 bit signed)
   %-----------------------------------------------------------
   warning('off'); % Shame on me!
   Integral   = Integral./Count;
   warning('on');
   PO         = ds(1).P(1);
   PO.fname   = prepend(ds(1).P(1).fname, 'meanu');
   PO.pinfo   = [max(max(max(Integral)))/32767 0 0]';
   PO.descrip = 'spm - mean undeformed image';
   PO.dt      = [4 ipctb_spm_platform('bigend')];
   ivol = reshape(Integral,PO.dim);
   ipctb_spm_write_vol(PO,ivol);
end

linfun(' ');
ipctb_spm_figure('Clear','Interactive');

if nargout > 0
   varargout{1} = oP;
end

return;


%_______________________________________________________________________
function PO = prepend(PI,pre)
[pth,nm,xt,vr] = fileparts(deblank(PI));
PO             = fullfile(pth,[pre nm xt vr]);
return;
%_______________________________________________________________________

%_______________________________________________________________________
function vo = nan2zero(vi)
vo = vi;
vo(~isfinite(vo)) = 0;
return;
%_______________________________________________________________________

