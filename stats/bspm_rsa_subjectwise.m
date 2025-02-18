function [rho, fishz] = bspm_rsa_subjectwise(maps, mask, eigenplot, rdmflag)
% [rho, fishz] = bspm_rsa_subjectwise(maps, mask, eigenplot, rdmflag)
%

% ----------------------------- Copyright (C) 2014 -----------------------------
%	Author: Bob Spunt
%	Affilitation: Caltech
%	Email: spunt@caltech.edu
%
%	$Revision Date: Aug_20_2014

if nargin < 4, rdmflag = 0; end
if nargin < 3, eigenplot = 1; end
if nargin < 2, []; end
if nargin < 1, mfile_showhelp; return; end

% %% MASK
if iscell(mask), mask = char(mask); end
% mask = bspm_reslice(mask,maps{1},1,1);

%% MAPS
if ischar(maps), maps = cellstr(maps); end
% all = bspm_read_vol(char(maps), 'reshape', 'implicitmask', 'mask', mask);
all = bspm_read_vol(char(maps), 'reshape');
if and(~isempty(mask), exist(mask, 'file'))
    m = bspm_reslice(mask, maps(1), 0, 1); 
    all(~m, :) = []; 
end
nmaps = length(maps);
% nvox = sum(mask(:) > 0);
% all = zeros(nvox, nmaps);
% for i = 1:nmaps
%     d = bspm_read_vol(maps{i});
%     d = d(:);
%     all(:,i) = d(mask(:) > 0);
% end
all(nanmean(all')==0,:) = 0;
all(find(sum(all'==0)),:) = [];
all(nanmean(isnan(all),2)>0,:) = [];

%% MDS
rho = corr(all, 'rows', 'pairwise');
D = 1 - rho;

[Y,eigvals] = cmdscale(D);
if eigenplot
    figure('color','white');
    plot(1:length(eigvals),eigvals,'bo-');
%     if feature('HGUsingMATLABClasses')
%         cl = specgraphhelper('createConstantLineUsingMATLABClasses','LineStyle',...
%             ':','Color',[.7 .7 .7],'Parent',gca);
%         cl.Value = 0;
%     else
%         graph2d.constantline(0,'LineStyle',':','Color',[.7 .7 .7]);
%     end
    axis([1,length(eigvals),min(eigvals),max(eigvals)*1.1]);
    xlabel('Eigenvalue number');
    ylabel('Eigenvalue');
    setfigpapersize(gcf); 
end

%% REPRESENTATIONAL DISSIMILARITY MATRIX OR CORR MAP
figure('color','white');
if rdmflag
    imagesc(D);
else
    imagesc(rho);
end
colormap(jet);
colorbar('SouthOutside');
axis('square');
box off;
setfigpapersize(gcf); 

%% CLEANUP DIAGONAL
fishz = rho;
fishz(:) = fisherz(rho);
fishz(isinf(fishz)) = NaN;
end
function setfigpapersize(figh)
set(figh, 'units', 'points', 'paperunits', 'points');
figpos = get(figh, 'pos');
set(figh, 'papersize', figpos(3:4), 'paperposition', [0 0 figpos(3:4)]);
end




 
 
 
 
 
 
 
 
