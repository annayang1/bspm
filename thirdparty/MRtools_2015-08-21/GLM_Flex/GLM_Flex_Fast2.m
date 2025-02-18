function I = GLM_Flex_Fast2(I,DD)
%%% This is the main analysis script.  
%%% Go to: http://nmr.mgh.harvard.edu/harvardagingbrain/People/AaronSchultz/Aarons_Scripts.html
%%% for more information on this script and how to use it.
%%%
%%% Inputs: This is the I structure that is passed to GLM_Flex to run the
%%% analyses.
%%%
%%%
%%% I.Model = 'the model'
%%% I.Data = dat;
%%% I.Posthocs = [];
%%% I.OutputDir = pwd;
%%% I.F = [];
%%% I.Scans = [];
%%% I.Mask = [];
%%% I.RemoveOutliers = 0;
%%% I.DoOnlyAll = 0;
%%% I.minN = 2;
%%% I.minRat = 0;
%%% I.Thresh = [];
%%% I.writeI = 1;
%%% I.writeT = 1;
%%% I.writeFin = 0;
%%% I.KeepResiduals = 0;
%%% I.estSmooth = 1;
%%% I.Transform.FisherZ = 0;
%%% I.Transform.AdjustR2 = 0;
%%% I.Transform.ZScore = 0;
%%% I.Reslice = 0;
%%%
%%% Written by Aaron Schultz (aschultz@martinos.org)
%%%
%%% Copyright (C) 2011,  Aaron P. Schultz
%%%
%%% Supported in part by the NIH funded Harvard Aging Brain Study (P01AG036694) and NIH R01-AG027435 
%%%
%%% This program is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% any later version.
%%% 
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.

%if ~contains('aschultz', {UserTime}); error('Aaron is currently reworking this script.  Check with him to see when it will be functional again.'); end

if isfield(I,'PostHocs') && ~isempty(I.PostHocs)
    MOD = ANOVA_APS(I.Data,I.Model,I.PostHocs,0,1,1);
else
    MOD = ANOVA_APS(I.Data,I.Model,[],0,1,1);
end
% if ~isempty(contains('aschultz',{UserTime}))    
    tx1 = [MOD.X];
    tx2 = ones(size(tx1,1),1);
    df = ResidualDFs(tx1)-ResidualDFs(tx2);
    dif = tx1;

    if ~all([numel(MOD.RFMs) numel(MOD.RFMs(1).Effect)])
        MOD.RFMs(end).Effect(end+1).df = df;
        MOD.RFMs(end).Effect(end).name = 'FullModel';
        MOD.RFMs(end).Effect(end).tx1 = tx1;
        MOD.RFMs(end).Effect(end).tx2 = tx2;
        MOD.RFMs(end).Effect(end).dif = dif;
    end
% end
I.MOD = MOD;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Setup/Check the I Structure
    %%
    fprintf('\nSetup/Check the I Structure:\n');
    
    if ~isfield(I,'DoOnlyAll')
        I.DoOnlyAll = 0;
    end
    
    if ~isfield(I,'ZeroDrop')
        I.ZeroDrop = 1;
    end
    
    if ~isfield(I,'OutputDir')
        I.OutputDir = pwd;
    else
        if exist(I.OutputDir)==0
            mkdir(I.OutputDir);
        end
        cd(I.OutputDir);
    end
    
    if ~isfield(I,'writeT')
        I.writeT = 1;
    end
    
    if ~isfield(I,'minN')
        I.minN = 2;
    end
    
    if ~isfield(I,'minRAT')
        I.minRAT = 0;
    end
    
    if ~isfield(I,'RemoveOutliers');
        I.RemoveOutliers = 0;
    end
    
    if ~isfield(I,'Thresh');
        I.Thresh = [];
    end
    
    if ~isfield(I,'writeFin');
        I.writeFin = 0;
    end
    
    if ~isfield(I,'writeI');
        I.writeI = 1;
    end
    
    if ~isfield(I,'KeepResiduals');
        I.KeepResiduals = 0;
    end
    
    if ~isfield(I,'Reslice');
        I.Reslice = 0;
    end
    
    if ~isfield(I,'estSmooth');
        I.estSmooth = 1;
    end
    
    if I.DoOnlyAll==1;
        I.minN=0;
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Read In The Data
    %%
    if isfield(I,'Scans');
        fprintf('\nReading In Data:\n');

        h = spm_vol(char(I.Scans));

        if ~any(h(1).dim==1)
            if mean(mean(std(reshape([h.mat],4,4,numel(h)),[],3)))~=0
                error('Images are not all the same orientation');
            end
        end
        
        I.v = h(1);
        FullIndex = 1:prod(I.v.dim);
        
        mskInd = 1:prod(I.v.dim);
        mskOut = [];
        if isfield(I,'Mask');
            if ~isempty(I.Mask)
                mh = spm_vol(I.Mask);
                msk = resizeVol(mh,I.v);
                mskInd = find(msk==1);
                mskOut = find(msk~=1);
            end
        end
        
        if nargin == 1
%             if isstruct(I.Reslice)
                
%             else
                [x y z] = ind2sub(I.v.dim,mskInd);
                OD = zeros(numel(h),numel(x));
                for ii = 1:numel(h);
                    OD(ii,:) = spm_sample_vol(h(ii),x,y,z,0);
                end
%             end
        else
            OD = DD(:,mskInd);
        end
        
        if I.ZeroDrop == 1
            OD(OD==0)=NaN;
        end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        %%% Screen Missing Data for Within Subject Factors; 
        if numel(MOD.ErrParts)>1
            Subs = I.Data.(MOD.ErrTerms{1});
            list = unique(Subs);
            for ii = 1:numel(list);
                if iscell(Subs)  
                    try
                        i2 = find(nominal(Subs)==list{ii});
                    catch
                        i2 = contains(['^' list{ii} '$'],Subs);
                    end
                else
                    i2 = find(Subs==list(ii));
                end
                i3 = find(isnan(sum(OD(i2,:))));
                OD(i2,i3)=NaN;
            end
        end
        
        counts = sum(~isnan(OD));
        ind = (find(counts>=I.minN));
        MasterInd = mskInd(ind);
        OD = OD(:,ind);
        counts = counts(ind);
    else
        error('No images were specified.');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Perform Specified Transformations
    %%
    fprintf('\nPerform Specified Transformations:\n');
    if isfield(I,'Transform')
        if isfield(I.Transform,'FisherZ')
            if I.Transform.FisherZ == 1;
                OD = atanh(OD);
                disp('FisherZ transform worked!');
            end
        end
        if isfield(I.Transform,'AdjustR2')
            if I.Transform.AdjustR2 == 1;
                OD = atanh(sqrt(OD));
                disp('R2 adjust worked!');
            end
        end
        if isfield(I.Transform,'ZScore')
            if I.Transform.ZScore == 1;
                OD = zscore(OD,0,1);
                disp('Normalization worked!');
            end
        end
        if isfield(I.Transform,'Scale')
            if numel(I.Transform.Scale) == numel(I.Scans);
                for ii = 1:size(OD,1);
                    OD(ii,:) = (OD(ii,:)+1).*(I.Transform.Scale(ii));
                end
                disp('Scaling worked!');
            end
        end
        if isfield(I.Transform,'crtlFor')
            I.writeFin = 1;
            OD = crtlFor(OD,[ones(size(I.Transform.crtlFor,1),1) I.Transform.crtlFor]);
            disp('residualizing worked!');
        end
        if isfield(I.Transform,'log')
            I.writeFin = 1;
            OD = log(OD);
            disp('data has been log-transformed!');
        end
        if isfield(I.Transform,'MapNorm')
            if I.Transform.MapNorm == 1;
                OD = OD';
                OD = (OD-repmat(nanmean(OD),size(OD,1),1))./repmat(nanstd(OD),size(OD,1),1);
                OD = OD';
                %OD = zscore(OD',0,1)';
                disp('MapNorm worked!');
            end
        end
        
        if isfield(I.Transform,'Smooth')
            if numel(I.Transform.Smooth) == 3;                
                tmp = spm_imatrix(I.v.mat);
                tmp = abs(tmp(7:9));
                k = smoothing_kernel(I.Transform.Smooth,tmp);
                %keyboard;
                OD(isnan(OD))=0;
                vol = zeros(I.v.dim);
                for ii = 1:size(OD,1);
                    vol(:) = OD(ii,:);
                    nm = convn(vol,k,'same');
                    OD(ii,:) = nm(:)';
                end
                OD(OD==0)=NaN;
                disp('Smoothing worked!');
            end
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Initialize Variables
    %%
    fprintf('\nIntialize Variable and Output Structures\n');
    BMdim = [numel(h) prod(I.v.dim)];
    maxLL = numel(h);
    
    Indices = {};
    Ls = [];
    Outliers = {[]};
    
    oCy = zeros(maxLL,maxLL);
    oN  = zeros(maxLL,maxLL);
    First = 0;
    BigCount = 0; %% was 1 before.  make sure this isn't a problem.
    
    %%% Get the Design Matrix
    X = MOD.X;
    I.X = X;
    %%% Setup Objects for Output Images
    ss = I.v.dim;
    NN = nan(ss);
    ResMS = cell(1,numel(MOD.RFMs));
    ResMS(:) = {NN};
    
    nn = 0;
    for ii = 1:numel(MOD.RFMs)
        nn = nn+numel(MOD.RFMs(ii).Effect);
    end
        
    Con = cell(1,nn);
    Con(:) = {NN};
    
    Stat = cell(1,nn);
    Stat(:) = {NN};
    
    if size(I.X,1)~=maxLL
        error('Design Matrix does not match input volumes');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q  = 1 %% Calculate Possible Grouptings
%%
if ~MOD.const
    AllColNames = {'Constant'};
else
    AllColNames = {};
end
Groupings = [];
for jj = 1:numel(MOD.EffTerms) 
    EffList = regexp(MOD.EffTerms{jj},'[\*\:]','split');
    
    AllColNames(end+1:end+size(MOD.EffParts{jj},2)) = {MOD.EffTerms{jj}};
    if numel(EffList)>1
        continue
    end
    tmp = {}; tmp{1} = [];
    for ii = 1:numel(EffList)
        tDat = I.Data.(EffList{ii});
        if isnumeric(tDat)
            continue
        end
        
        tmp{ii} = makedummy(tDat);
        
        
        
    end
    if numel(tmp)>1
        Groupings = [Groupings FactorCross(tmp)];
    else
        Groupings = [Groupings tmp{1}];
    end
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
for q=1     %% Perform initial pass to evaluate for missing data, outliers, and computation of the covariance matrix.
    %%
    nOut = 0;
    persisText
    for ll = size(X,1):-1:I.minN
        %%% Find the indices where the number of observations matches the current loop.
        
        CurrIndex = find(counts==ll);
        
        if isempty(CurrIndex)
            continue
        end
        BigCount = BigCount+1;
        Ls(BigCount) = ll;
        
        %%% This Section computes different combinations of N size ll across
        %%% the groups specified in the design matrix.
        
        ss = size(OD(:,CurrIndex));
        if I.DoOnlyAll ~= 1
            if ll == maxLL
                ch = [1 numel(CurrIndex)];
                uni = 1:numel(h);
                II = 1:ss(2);
            else
                rr = ~isnan(OD(:,CurrIndex)).*repmat((1:size(X,1))',1,ss(2));
                
                rr = rr';
                [rr II] = sortrows(rr,(1:size(rr,2))*-1);
                
                
                tt = sum(abs(diff(rr~=0)),2)>0;
                ind = find(tt==1);
                ch = [[1; ind+1] [ind; numel(II)]];
                ch = ch((diff(ch,1,2)>=0),:);
                uni = rr(ch(:,1),:);
                CurrIndex = CurrIndex(II);
            end
        else
            ch = [1 numel(CurrIndex)];
            uni = 1:numel(h);
            II = 1:ss(2);
        end
        Outliers{BigCount}=[];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Loop through specific designs for ll observations
        for ii = 1:size(ch,1)
            persisText(['Examining Set #' num2str(ll) ': SubModel ' num2str(ii) ' of ' num2str(size(ch,1)) '; Nvox = ' num2str(numel(ch(ii,1):ch(ii,2)))]);
            %%% Get the observation index for the current design
            Xind = uni(ii,:);
            Xind = Xind(Xind>0);
            
            %%% Subset the design matrix
            xx = X(Xind,:);
            
            %%% Make sure there is enough data across conditions.
            
            Ns = sum(Groupings(Xind,:)); 
            
            if ~all(Ns>=I.minN)
                continue;
            end
            if  min(Ns)/max(Ns) < I.minRAT;
                continue;
            end
            
            %%% get the global index of the voxels being analyzed
            vec = CurrIndex((ch(ii,1):ch(ii,2)));
            %%% Get the correponding data to be analyzed
            Y = OD(Xind,vec);
            
            %%% Outlier Detection Compute Cook's D
            for q =1
                if I.RemoveOutliers == 1;
                    df1 = ResidualDFs(xx);
                    df2 = MOD.RFMs(end).EDF;
                    
                    %%% Run a basic GLM
                    pv = pinv(xx);
                    pv(abs(pv)<eps*(size(xx,1)))=0;
                    beta  = pv*Y;
                    pred = xx*beta;
                    res   = Y-pred;
                    ResSS = sum(res.^2);
                    MSE = ResSS./df2;
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
                    e2 = res.^2;
                    p = size(xx,2);
                    bc = pinv(xx'*xx);
                    bc(abs(bc)<eps*(size(xx,1)))=0;
                    tmp = diag(xx*bc*xx');
                    CD = (e2./(p*repmat(MSE,size(e2,1),1))) .* (repmat(tmp./((1-tmp).^2),1,size(e2,2)));
                    
                    if ~isempty(I.Thresh)
                        thresh = spm_invFcdf(I.Thresh,[df1 df2-1]);
                    else
                        thresh = spm_invFcdf(.5,[df1 df2-1]);
                    end
                    
                    [mm,ith] = max(CD);
                    a = find(mm>thresh);
                    nOut = nOut+numel(a);
                    persisText(['Examining Set #' num2str(ll) ': SubModel ' num2str(ii) ' of ' num2str(size(ch,1)) '; Nvox = ' num2str(numel(ch(ii,1):ch(ii,2))) '; Found ' num2str(nOut) ' outliers so far:']);

                    if ~isempty(a)
                        rows = Xind(ith(a));
                        cols = vec(a);
                        Outliers{BigCount} = [Outliers{BigCount} sub2ind(BMdim,rows,MasterInd(cols))];
                        
                        
                        OD(sub2ind(size(OD),rows,cols))=NaN;
                        
                        if numel(MOD.ErrParts)>1
                            for jj = 1:numel(rows);
                            
                                if iscell(I.Data.(MOD.ErrTerms{1}));
                                    i1 = contains(['^' I.Data.(MOD.ErrTerms{1}){rows(jj)} '$'],I.Data.(MOD.ErrTerms{1}));
                                else
                                    i1 = find(I.Data.(MOD.ErrTerms{1}) == I.Data.(MOD.ErrTerms{1})(rows(jj)));
                                end
                                
                                OD(i1,cols(jj)) = NaN;
                                
                            end
                            counts(cols)=sum(~isnan(OD(:,cols)));
                        else
                            counts(cols)=counts(cols)-1;
                        end
                        
                    end
                    a = find(mm<thresh);
                else
                    a = 1:numel(vec);
                end
            end
            
            %%% If there are no voxels free of outliers, continue
            if isempty(a)
                continue;
            end
            
            First = First+1;
            
            if First == 1;
                hh = I.v;
                tmp = nan(hh.dim);
                tmp(MasterInd(vec(a)))=1;
                hh.dt = [2 0];
                writeIMG(hh,tmp,'AllMask.nii');
            end
            
            %%% Subset data to only those voxels without outliers
            Y = Y(:,a);
            Indices{First,1} = vec(a);
            Indices{First,2} = Xind;
            
            %%% NOTE: Variance/Covariance Correction is currently disabled.
            %%%  This option may be reinstated in the future.
%             V = eye(size(xx,1));
%             if ~isempty(contains('aschultz',{UserTime})); 
%                 keyboard; 
%                   X = sparse(100,100);
%                   ind = sub2ind(size(X),1:2:100,2:2:100);
%                   X(ind) = 1;
%                   ind = sub2ind(size(X),2:2:100,1:2:100);
%                   X(ind) = 1;
%                   imagesc(X); shg
%                 
%                 SPM = [];
%                 c = 1;
%                 SPM.factor(c).name     = 'v1';
%                 SPM.factor(c).levels   = '2';
%                 % Ancova options
%                 SPM.factor(c).gmsca = 0;
%                 SPM.factor(c).ancova   = 0;
%                 % Nonsphericity options
%                 SPM.factor(c).variance = 1;
%                 SPM.factor(c).dept     = 1;
%                 
%                 SPM.xVi.I = ones(size(MOD.X,1),4);
%                 
%                 SPM.xVi.I(strmatch('HAB_1.0',MOD.data.Visit,'exact'),2) = 1;
%                 SPM.xVi.I(strmatch('HAB_4.0',MOD.data.Visit,'exact'),2) = 2;
%                 
%                 SPM = spm_get_vc(SPM);
%                 Vi = SPM.xVi.Vi;
%             end
            

%             if numel(I.F.Vi)>1
%                 %%% Estimate the DFs for the full model
%                 tx = xx(:,1:numel(I.F.name));
%                 tx = tx(:,sum(abs(tx))~=0);
%                 
%                 if size(tx,2)==1;
%                     df1 = 1;
%                 else
%                     [z1 z2 z3] = svd(tx);
%                     tol = max(size(tx))*max(abs(diag(z2)))*eps;
%                     df1 = sum(diag(z2)>tol);
%                 end
%                 df2 = size(tx,1)-df1;
%                 
%                 %%% Run a basic GLM
%                 pv = pinv(tx);
%                 pv(abs(pv)<eps*(size(tx,1)))=0;
%                 beta  = pv*Y;
%                 pred = tx*beta;
%                 res   = Y-pred;
%                 ResSS = sum(res.^2);
%                 MSE = ResSS./df2;
%                 
%                 %%% Compute significance of full model for all voxels
%                 PSS = sum(pred(:,a).^2);
%                 ESS = sum(res(:,a).^2);
%                 FF = (PSS./df1) ./ (ESS./df2);
%                 UF = spm_invFcdf(1-.001,[df1 df2]);
%                 %%% Get the index of voxels where the full model p is less than 0.001
%                 mv = find(FF>UF);
%                 cn = numel(mv);
%                 
%                 %%% Pool variance across voxels
%                 if ~isempty(mv)
%                     q  = spdiags(sqrt(df2./ResSS(a(mv))'),0,cn,cn);
%                     YY = Y(:,mv)*q;
%                     Cy = (YY*YY');
%                     
%                     oCy(Xind,Xind) = oCy(Xind,Xind)+Cy;
%                     oN(Xind,Xind) = oN(Xind,Xind)+cn;
%                 else
%                     Cy = [];
%                 end
%                 Cy = oCy(Xind,Xind) ./ oN(Xind,Xind);
%             else
%                 V = eye(size(xx,1));
%             end
            
            NN(MasterInd(vec(a))) = numel(Xind);
        end
        if I.DoOnlyAll==1
            break;
        end
    end

    persisText;
    fprintf('\n\n');
    
    if First==0
        error('Nothing ws analyzed, make sure the I.minN is not set too high');
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Write out mask images
    %%
    v = I.v;
    v.dt = [64 0];
    writeIMG(v,NN,'NN.nii');
    writeIMG(v,NN>0,'mask.nii');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% This option is currently disabled
for q=1     %% Perform REML estimation if specified
    %%
    W = eye(size(I.X,1));
%     if numel(I.F.Vi)>1 %%% Estimate population Var/Covar using ReML estimation.
%         Vi = I.F.Vi;
%         tx = I.F.XX(:,1:numel(I.F.name));
%         tx(isnan(tx))=0;
%         Cy = oCy./oN;
%         [V hhh] = spm_reml(Cy,tx,I.F.Vi);
%         V = V*size(tx,1)/trace(V);
%         
%         W     = full(spm_sqrtm(spm_inv(V)));
%         W     = W.*(abs(W) > 1e-6);
%     else
%         V = eye(size(I.X,1));
%         W = V;
%     end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Compute Statistics
    %%
    fileNames = []; conDFs = []; type = {};
    persisText;
    %ExtraTime = 0;
    for ll = 1:size(Indices,1);
        persisText(['Analysing Sub-Model #' num2str(ll)  ' of ' num2str(size(Indices,1)) '; ' num2str(numel(Indices{ll,2})) ' Observations, across ' num2str(numel(Indices{ll,1})) ' Voxels.' ]);
        
        Xind = Indices{ll,2};
        vec = Indices{ll,1};
        
        Y = W(Xind,Xind)*OD(Xind,vec);
        %x = I.F.XX(:,1:numel(I.F.name));
        %wx = x; wx(isnan(wx))=0; wx = W(Xind,Xind)*wx(Xind,:);
        wx = X(Xind,:);
        
        counter = 0;
        %%% Compute Error
        for ii = 1:numel(MOD.RFMs);
            if isempty( MOD.RFMs(ii).tx1)
                continue
            end
            tx1 = MOD.RFMs(ii).tx1(Xind,:);
            tx2 = MOD.RFMs(ii).tx2(Xind,:);
            
            edf = ResidualDFs(tx1)-ResidualDFs(tx2);
            if ll==1; masterDF(ii) = edf; end
            
            [SSm] = makeSSmat(tx1,tx2);
            
            if I.estSmooth == 1 && ll == 1
                [RSS Res] = LoopEstimate(Y,1,SSm);
                Res = Res./repmat(sqrt(RSS/edf)',1,size(Res,2));
                tm = [pwd '/ResAll_' sprintf('%0.2d',ii)];
                warning off;
                delete([tm '.nii']); delete([tm '.mat']);
                warning on;
                
                v = I.v;
                v.fname = [tm '.nii'];
                
                vol = nan(v.dim);
                for jj = 1:size(Res,2);
                    vol(MasterInd(vec)) = Res(:,jj);
                    v.n = [jj 1];
                    spm_write_vol(v,vol);
                end
                
                fprintf('\n');
                h = spm_vol(v.fname);
                
                [FWHM,VRpv,R] = spm_est_smoothness(h,spm_vol('AllMask.nii'),[numel(h) edf]);
                
                I.FWHM{ii} = FWHM;
                
                [tmpM tmpH] = openIMG('RPV.img');
                tmpH.fname = ['RPV' tm(end-2:end) '.nii'];
                spm_write_vol(tmpH,tmpM);
                delete('RPV.*')
                
                %delete ResAll_*.nii;
                %delete ResAll_*.mat;
                clear Res;
                
                persisText();
                persisText(['Analysing Sub-Model #' num2str(ll)  ' of ' num2str(size(Indices,1)) '; ' num2str(numel(Indices{ll,2})) ' Observations, across ' num2str(numel(Indices{ll,1})) ' Voxels.' ]);
            else
                RSS = LoopEstimate(Y,1,SSm);
            end
            
            ResMS{ii}(MasterInd(vec)) = RSS./edf;
            
            for jj = 1:numel(MOD.RFMs(ii).Effect)
                counter = counter+1;
                
                tx1 = MOD.RFMs(ii).Effect(jj).tx1(Xind,:);
                if isempty(MOD.RFMs(ii).Effect(jj).tx2)
                    tx2 = zeros(size(tx1,1),1);
                    df = ResidualDFs(tx1);
                    SSm = makeSSmat(tx1,tx2);
                else
                    tx2 = MOD.RFMs(ii).Effect(jj).tx2(Xind,:);
                    df = ResidualDFs(tx1)-ResidualDFs(tx2);
                    SSm = makeSSmat(tx1,tx2);
                end                
                
                
                ESS = LoopEstimate(Y,1,SSm);
                
                
                Fstat = (ESS./df) ./ (RSS./edf);
                
                conDFs(end+1,1:2) = [df edf];
                
                name =  MOD.RFMs(ii).Effect(jj).name;
                fileNames{end+1} = name;
                if I.writeT == 1 && df==1 && isempty(contains('[\*|\:]',{name})) && ~strcmpi('FullModel',name);
                    %if contains('aschultz', {UserTime}); keyboard; end
                    test = 'T';
%                     ii1 = contains(['^' name '$'],AllColNames);
%                     if isempty(ii1)
%                         test = 'F';
%                         con = ESS./df;
%                     else
%                         c = zeros(size(wx,2),numel(ii1));
%                         for kk = 1:numel(ii1);
%                             c(ii1(kk),kk) = 1;
%                         end
%                         
%                         con = (c'*(pinv(wx)*Y));
%                     end
                    
                    % New Method
                    %if contains('aschultz', {UserTime}); 
                    
                        warning off
                        nm = tx1-(tx2*(tx2\tx1));
                        nm(nm>-1e-12 & nm<1e-12)=0;
                        con = sum((nm\Y),1);
                        warning on;
                        %figure(10); clf; plot(con,con1,'.'); shg 
                    %end
                    
                    
                else
                    test = 'F';
                    con = ESS./df;
                end
                
                type{end+1} = test;
                
                if edf~=masterDF(ii)
                    %%%
                    p = spm_Fcdf(Fstat,df,edf);
                    Fstat2 = spm_invFcdf(p,df,masterDF(ii));
                    %keyboard; 
                    Fstat2(isinf(Fstat2))=Fstat(isinf(Fstat2));
                    Fstat = Fstat2;
                end
                
                if strcmpi(test,'T')
                    Stat{counter}(MasterInd(vec)) = sqrt(Fstat).*sign(con);
                    Con{counter}(MasterInd(vec)) = con;
                else
                    Stat{counter}(MasterInd(vec)) = Fstat;
                    Con{counter}(MasterInd(vec))  = con;
                end
            end
        end
    end
    %fprintf('\n\n');
    %disp(ExtraTime)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Write Out Mat-Files
    %%
    fprintf('\n\nWriting out mat files...\n');
    
    c = 0;
    for ii = 1:numel(Outliers);
        c = c+numel(Outliers{ii});
    end
    if c>0
        OL{1} = zeros(c,1);
        OL{2} = zeros(c,2);
        st = 0;
        for ii = 1:numel(Outliers)
            tmp = Outliers{ii};
            if ~isempty(tmp)
                OL{1}(st+1:st+numel(tmp))=tmp;
                [row col] = ind2sub(BMdim,tmp);
                OL{2}(st+1:st+numel(tmp),:)=[row(:),col(:)];
                st = st+numel(tmp);
            end
        end
        %save OL.mat OL
        I.OL = OL;
    end
    
    
    if I.writeI == 1;
        save I.mat I -v7.3;
    end

    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for q=1     %% Write Out Image Files
    %%
    fprintf('\n\nWriting out image files...\n');

    v = I.v;
    v.dt = [64 0];
    
    for ll = 1:length(ResMS);
        tm = ['ResMS_' sprintf('%0.2d',ll)];
        writeIMG(v,ResMS{ll},[tm '.nii']);
    end
    
    for jj = 1:numel(Con)
        delete(['*' sprintf('%0.4d',jj) '*.nii'])
        if strcmpi(type{jj},'T')
            tm = [sprintf('%0.4d',jj) '_T_' fileNames{jj} '.nii'];
            hold = v.descrip;
%WH-error should be jj not ii??? --> v.descrip = ['SPM{T_' '[' num2str(conDFs(ii,2)) ']} - created with GLM_Flex_Fast'];
            v.descrip = ['SPM{T_' '[' num2str(conDFs(jj,2)) ']} - created with GLM_Flex_Fast'];
            writeIMG(v,Stat{jj},tm);
            v.descrip = hold;
            tm = ['con_' sprintf('%0.4d',jj) '.nii'];
            writeIMG(v,Con{jj},tm);
        end
        if strcmpi(type{jj},'F')
            tm = [sprintf('%0.4d',jj) '_F_' fileNames{jj} '.nii'];
            hold = v.descrip;
 %WH-error should be jj not ii??? --> v.descrip = ['SPM{F_' '[' num2str(conDFs(ii,1)) ',' num2str(conDFs(ii,2)) ']} - created with GLM_Flex_Fast'];
            v.descrip = ['SPM{F_' '[' num2str(conDFs(jj,1)) ',' num2str(conDFs(jj,2)) ']} - created with GLM_Flex_Fast'];
            writeIMG(v,Stat{jj},tm);
            v.descrip = hold;
            tm = ['ess_' sprintf('%0.4d',jj) '.nii'];
            writeIMG(v,Con{jj},tm);
        end
    end
    
    if I.writeFin == 1;
        fprintf('\nWriting out finalized data set ...\n');
        
        %save FinDat.mat OD;
        
        v.descrip = 'Original data set with outliers removed.';
        vol = nan(v.dim);
        v.n = [1 1];
        v.fname = 'FinalDataSet.nii';
        for ii = 1:size(OD,1)
          vol(MasterInd) = OD(ii,:);
          v.n = [ii 1];
          spm_write_vol(v,vol);
        end
    end
    
    fprintf('\nAll Done!\n');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end %% End of Main Function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

