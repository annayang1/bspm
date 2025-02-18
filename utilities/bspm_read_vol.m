function [data, hdr, info] = bspm_read_vol(in, varargin)
% BSPM_READ_VOL  Wrapper for spm_vol/spm_read_vols + added options
%
% USAGE: [data hdr info] = bspm_read_vols(in, varargin)
%
%   ARGUMENTS
%       in: filename(s) of image volumes
%
%   OPTIONAL ARGUMENTS
%       'reshape' - reshapes to 2D, rows = voxels, cols = images
%       'zscore'  - zscores the image data
%       'zscoretime'  - zscores the image data by time
%       'implicit'- NaNs voxels less than 10% of the mean
%       'mask' - (must pair with filename)
%       'maskthresh' - (default is any non-zero value, must be paied with
%       value)
%       'reslice' - (must pair with reference filename)
%       'resliceinterp', interpolation, 0=Nearest Neighbor, 1=Trilinear(default)
%       

% ------------------------ Copyright (C) 2014 ------------------------
%	Author: Bob Spunt
%	Affilitation: Caltech
%	Email: spunt@caltech.edu
%
%	$Revision Date: Aug_20_2014

if nargin < 1, mfile_showhelp; return; end
if nargin > 1, optional = 1; else optional = 0; end
if any(cellfun(@iscell, varargin))
    varargin{cellfun(@iscell, varargin)} = char(varargin{cellfun(@iscell, varargin)}); 
end
if ischar(in), in = cellstr(in); end
hdr     = spm_vol(char(in));
data    = spm_read_vols(hdr);
nvol    = length(hdr);
if optional
    
    if ~ismember('maskthresh', cellnum2str(varargin))
        maskthresh = 0; 
    else
        argidx = find(ismember(cellnum2str(varargin), 'maskthresh'));
        maskthresh = varargin{argidx + 1};
        varargin(argidx:argidx+1) = []; 
    end
    if ~ismember('resliceinterp', cellnum2str(varargin))
        interp = 1; 
    end
    varargin = lower(varargin);
    if ismember('reslice', varargin) 
        ref = varargin{find(ismember(varargin, 'reslice'))+1};
        if iscell(ref), ref = char(ref); end
        refhdr = spm_vol(ref); 
        
        refmat = refhdr.mat; 
        refdim = refhdr.dim; 
        [x1,x2,x3]  = ndgrid(1:refdim(1),1:refdim(2),1:refdim(3));
        d           = [interp*[1 1 1]' [1 1 0]'];
        data        = repmat(zeros(refdim), 1, 1, 1, nvol); 
        for i = 1:nvol
            C           = spm_bsplinc(hdr(i), d);
            M           = inv(hdr(i).mat)*refmat; 
            y1          = M(1,1)*x1+M(1,2)*x2+(M(1,3)*x3+M(1,4));
            y2          = M(2,1)*x1+M(2,2)*x2+(M(2,3)*x3+M(2,4));
            y3          = M(3,1)*x1+M(3,2)*x2+(M(3,3)*x3+M(3,4));
            data(:,:,:,i) = spm_bsplins(C, y1,y2,y3, d);
        end
    else
        data = spm_read_vols(hdr);
    end
    datadim = size(data); 
    if ismember('implicit', varargin);
        for i = 1:nvol
            tmp = data(:,:,:,i);
            tmp(tmp < nanmean(tmp(:))/10) = NaN;
            data(:,:,:,i) = tmp;
        end
    end
    if ismember('mask', varargin)
        
        maskfile = varargin{find(ismember(varargin, 'mask'))+1};
        if iscell(maskfile), maskfile = char(maskfile); end
        if ismember('reslice', varargin) 
            mask = bspm_reslice(maskfile, ref, 1, 1);
        else
            mask = bspm_reslice(maskfile, hdr(1).fname, 1, 1);
        end
        if length(datadim)==3 datadim(4) = 1; end
        tmp          = data;
        tmp          = reshape(tmp, prod(datadim(1:3)), datadim(4));
        tmp(mask(:)<=maskthresh,:) = NaN;
        data         = reshape(tmp, datadim);
    end
    if ismember('reshape', varargin);
        if length(datadim)==3 datadim(4) = 1; end
        data = reshape(data, prod(datadim(1:3)), datadim(4));
        if ismember('zscoretime', varargin);
            d       = bsxfun(@minus, data', nanmean(data'));
            d       = bsxfun(@rdivide, d, nanstd(d));
            data    = d';
        end
        if ismember('zscore', varargin);
            for i = 1:size(data,2), data(~isnan(data(:,i)),i) = zscore(data(~isnan(data(:,i)),i)); end
        end
        return
    end
    if ismember('zscoretime', varargin);
        if nvol>1
            data = reshape(data, prod(datadim(1:3)), datadim(4));
            d    = bsxfun(@minus, data', nanmean(data'));
            d    = bsxfun(@rdivide, d, nanstd(d));
            data = d';
            data = reshape(data, datadim);
        end  
    end
end
if nargout==3
    info.dim    = size(data);
    info.n_nan  = sum(isnan(data(:)));
    info.n_zero = sum(data(:)==0);
    info.mean   = nanmean(data(:));
    info.median = nanmedian(data(:));
    info.std    = nanstd(data(:));
    info.max    = nanmax(data(:));
    info.min    = nanmin(data(:));
end
end
function out = cellnum2str(in, ndec, leftzeropad)
    % CELLNUM2STR 
    %
    %  USAGE: out = cellnum2str(in, ndec, leftzeropad)
    % __________________________________________________________________________
    %  INPUTS
    %   in:     numeric cell array
    %   ndec:   number of decimal points to display
    %

    % ---------------------- Copyright (C) 2015 Bob Spunt ----------------------
    %   Created:  2015-01-13
    %   Email:    spunt@caltech.edu
    % __________________________________________________________________________
    if nargin < 1, mfile_showhelp; return; end
    if nargin < 2, ndec = 3; end
    if nargin < 3, leftzeropad = 1; end
    if ~iscell(in), error('Input array must be cell!'); end
    numidx                  = cell2mat(cellfun(@isnumeric, in, 'Unif', false))==1;
    out                     = in;
    innum                   = in(numidx);
    decidx                  = mod(cell2mat(innum), 1) > 0;
    outnum                  = innum;
    outnum(~decidx)         = cellfun(@num2str, innum(~decidx), 'Unif', false);
    outnum(decidx)          = cellfun(@num2str, innum(decidx), repmat({['%2.' num2str(ndec) 'f']}, size(innum(decidx))), 'Unif', false);
    if ~leftzeropad, outnum = regexprep(outnum, '0\.', '\.'); end
    out(numidx)             = outnum;
end