function job = ipctb_spm_config_preproc
% Configuration file for Segment jobs
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% John Ashburner
% $Id: spm_config_preproc.m 539 2006-05-19 17:59:30Z Darren $


%_______________________________________________________________________

entry = inline(['struct(''type'',''entry'',''name'',name,'...
        '''tag'',tag,''strtype'',strtype,''num'',num,''help'',{{}})'],...
        'name','tag','strtype','num');

files = inline(['struct(''type'',''files'',''name'',name,'...
        '''tag'',tag,''filter'',fltr,''num'',num,''help'',{{}})'],...
        'name','tag','fltr','num');

mnu = inline(['struct(''type'',''menu'',''name'',name,'...
        '''tag'',tag,''labels'',{labels},''values'',{values},''help'',{{}})'],...
        'name','tag','labels','values');

branch = inline(['struct(''type'',''branch'',''name'',name,'...
        '''tag'',tag,''val'',{val},''help'',{{}})'],...
        'name','tag','val');

%_______________________________________________________________________

data = files('Data','data','image',[1 Inf]);
data.help = {[...
'Select scans for processing. ',...
'This assumes that there is one scan for each subject. ',...
'Note that multi-spectral (when there are two or more registered ',...
'images of different contrasts) processing is not yet implemented ',...
'for this method.']};

%------------------------------------------------------------------------

priors = files('Tissue probability maps','tpm','image',3);
priors.def = 'preproc.tpm';
priors.dir = fullfile(ipctb_spm('Dir'),'tpm');
priors.help = {...
[...
'Select the tissue probability images. '...
'These should be maps of grey matter, white matter ',...
'and cerebro-spinal fluid probability. '...
'A nonlinear deformation field is estimated that best overlays the '...
'tissue probability maps on the individual subjects'' image. '...
'The default tissue probability maps are modified versions of the '...
'ICBM Tissue Probabilistic Atlases.',...
'These tissue probability maps are kindly provided by the ',...
'International Consortium for Brain ',...
'Mapping, John C. Mazziotta and Arthur W. Toga. ',...
'http://www.loni.ucla.edu/ICBM/ICBM_TissueProb.html. ',...
'The original data are derived from 452 T1-weighted scans, ',...
'which were aligned with an atlas space, corrected for scan ',...
'inhomogeneities, and classified ',...
'into grey matter, white matter and cerebrospinal fluid. ',...
'These data were then affine registered to the MNI space and ',...
'downsampled to 2mm resolution.'],...
'',...
[...
'Rather than assuming stationary prior probabilities based upon mixing '...
'proportions, additional information is used, based on other subjects'' brain '...
'images.  Priors are usually generated by registering a large number of '...
'subjects together, assigning voxels to different tissue types and averaging '...
'tissue classes over subjects. '...
'Three tissue classes are used: grey matter, white matter and cerebro-spinal fluid. '...
'A fourth class is also used, which is simply one minus the sum of the first three. '...
'These maps give the prior probability of any voxel in a registered image '...
'being of any of the tissue classes - irrespective of its intensity.'],...
'',...
[...
'The model is refined further by allowing the tissue probability maps to be '...
'deformed according to a set of estimated parameters. '...
'This allows spatial normalisation and segmentation to be combined into '...
'the same model. '...
'This implementation uses a low-dimensional approach, which parameterises '...
'the deformations by a linear combination of about a thousand cosine '...
'transform bases. '...
'This is not an especially precise way of encoding deformations, but it '...
'can model the variability of overall brain shape. '...
'Evaluations by Hellier et al have shown that this simple model can achieve '...
'a registration accuracy comparable to other fully automated methods with '...
'many more parameters.']};

%------------------------------------------------------------------------

ngaus      = entry('Gaussians per class','ngaus','n',[4 1]);
ngaus.def  = 'preproc.ngaus';
%ngaus.val  = {[2 2 2 4]};
ngaus.help = {[...
'The number of Gaussians used to represent the intensity distribution '...
'for each tissue class can be greater than one. '...
'In other words, a tissue probability map may be shared by several clusters. '...
'The assumption of a single Gaussian distribution for each class does not '...
'hold for a number of reasons. '...
'In particular, a voxel may not be purely of one tissue type, and instead '...
'contain signal from a number of different tissues (partial volume effects). '...
'Some partial volume voxels could fall at the interface between different '...
'classes, or they may fall in the middle of structures such as the thalamus, '...
'which may be considered as being either grey or white matter. '...
'Various other image segmentation approaches use additional clusters to '...
'model such partial volume effects. '...
'These generally assume that a pure tissue class has a Gaussian intensity '...
'distribution, whereas intensity distributions for partial volume voxels '...
'are broader, falling between the intensities of the pure classes. '...
'Unlike these partial volume segmentation approaches, the model adopted '...
'here simply assumes that the intensity distribution of each class may '...
'not be Gaussian, and assigns belonging probabilities according to these '...
'non-Gaussian distributions. '...
'Typical numbers of Gaussians could be two for grey matter, two for white '...
'matter, two for CSF, and four for everything else.']};

%------------------------------------------------------------------------

warpreg      = entry('Warping Regularisation','warpreg','e',[1 1]);
warpreg.def  = 'preproc.warpreg';
%warpreg.val  = {1};
warpreg.help = {[...
'The objective function for registering the tissue probability maps to the ',...
'image to process, involves minimising the sum of two terms. ',...
'One term gives a function of how probable the data is given the warping parameters. ',...
'The other is a function of how probable the parameters are, and provides a ',...
'penalty for unlikely deformations. ',...
'Smoother deformations are deemed to be more probable. ',...
'The amount of regularisation determines the tradeoff between the terms. ',...
'Pick a value around one.  However, if your normalized images appear ',...
'distorted, then it may be an idea to increase the amount of ',...
'regularization (by an order of magnitude). ',...
'More regularisation gives smoother deformations, ',...
'where the smoothness measure is determined by the bending energy of the deformations. ']};
%------------------------------------------------------------------------

warpco      = entry('Warp Frequency Cutoff','warpco','e',[1 1]);
warpco.def  = 'preproc.warpco';
%warpco.val  = {25};
warpco.help = {[...
'Cutoff of DCT bases.  Only DCT bases of periods longer than the ',...
'cutoff are used to describe the warps. The number actually used will ',...
'depend on the cutoff and the field of view of your image. ',...
'A smaller cutoff frequency will allow more detailed deformations ',...
'to be modelled, but unfortunately comes at a cost of greatly increasing ',...
'the amount of memory needed, and the time taken.']};

%------------------------------------------------------------------------

biasreg = mnu('Bias regularisation','biasreg',{...
'no regularisation (0)','extremely light regularisation (0.00001)',...
'very light regularisation (0.0001)','light regularisation (0.001)',...
'medium regularisation (0.01)','heavy regularisation (0.1)',...
'very heavy regularisation (1)','extremely heavy regularisation (10)'},...
{0, 0.00001, 0.0001, 0.001, 0.01, 0.1, 1.0, 10});
biasreg.def  = 'preproc.biasreg';
%biasreg.val  = {0.0001};
biasreg.help = {[...
'MR images are usually corrupted by a smooth, spatially varying artifact that modulates the intensity ',...
'of the image (bias). ',...
'These artifacts, although not usually a problem for visual inspection, can impede automated ',...
'processing of the images.'],...
'',...
[...
'An important issue relates to the distinction between intensity variations that arise because of ',...
'bias artifact due to the physics of MR scanning, and those that arise due to different tissue ',...
'properties.  The objective is to model the latter by different tissue classes, while modelling the ',...
'former with a bias field. ',...
'We know a priori that intensity variations due to MR physics tend to be spatially smooth, ',...
'whereas those due to different tissue types tend to contain more high frequency information. ',...
'A more accurate estimate of a bias field can be obtained by including prior knowledge about ',...
'the distribution of the fields likely to be encountered by the correction algorithm. ',...
'For example, if it is known that there is little or no intensity non-uniformity, then it would be wise ',...
'to penalise large values for the intensity nonuniformity parameters. ',...
'This regularisation can be placed within a Bayesian context, whereby the penalty incurred is the negative ',...
'logarithm of a prior probability for any particular pattern of nonuniformity.']};

%------------------------------------------------------------------------

biasfwhm    = mnu('Bias FWHM','biasfwhm',{...
'30mm cutoff','40mm cutoff','50mm cutoff','60mm cutoff','70mm cutoff',...
'80mm cutoff','90mm cutoff','100mm cutoff','110mm cutoff','120mm cutoff',...
'130mm cutoff','140mm cutoff','150mm cutoff','No correction'},...
{30,40,50,60,70,80,90,100,110,120,130,140,150,Inf});
biasfwhm.def  = 'preproc.biasfwhm';
%biasfwhm.val  = {60};
biasfwhm.help = {[...
'FWHM of Gaussian smoothness of bias. ',...
'If your intensity nonuniformity is very smooth, then choose a large ',...
'FWHM. This will prevent the algorithm from trying to model out intensity variation ',...
'due to different tissue types. The model for intensity nonuniformity is one ',...
'of i.i.d. Gaussian noise that has been smoothed by some amount, ',...
'before taking the exponential. ',...
'Note also that smoother bias fields need fewer parameters to describe them. ',...
'This means that the algorithm is faster for smoother intensity nonuniformities.']};

%------------------------------------------------------------------------

regtype = mnu('Affine Regularisation','regtype',...
   {'No Affine Registration','ICBM space template - European brains',...
    'ICBM space template - East Asian brains', 'Average sized template','No regularisation'},...
   {'','mni','eastern','subj','none'});
regtype.def  = 'preproc.regtype';
regtype.help = {[...
'The procedure is a local optimisation, so it needs reasonable initial '...
'starting estimates. Images should be placed in approximate alignment '...
'using the Display function of SPM before beginning. '...
'A Mutual Information affine registration with the tissue '...
'probability maps (D''Agostino et al, 2004) is used to achieve '...
'approximate alignment. '...
'Note that this step does not include any model for intensity nonuniformity. '...
'This means that if the procedure is to be initialised with the affine '...
'registration, then the data should not be too corrupted with this artifact.'...
'If there is a lot of intensity nonuniformity, then manually position your '...
'image in order to achieve closer starting estimates, and turn off the '...
'affine registration.'],...
'',...
[...
'Affine registration into a standard space can be made more robust by ',...
'regularisation (penalising excessive stretching or shrinking).  The ',...
'best solutions can be obtained by knowing the approximate amount of ',...
'stretching that is needed (e.g. ICBM templates are slightly bigger ',...
'than typical brains, so greater zooms are likely to be needed). ',...
'For example, if registering to an image in ICBM/MNI space, then choose this ',...
'option.  If registering to a template that is close in size, then ',...
'select the appropriate option for this.']};

%------------------------------------------------------------------------

samp      = entry('Sampling distance','samp','e',[1 1]);
samp.def  = 'preproc.samp';
%samp.val  = {3};
samp.help = {[...
'The approximate distance between sampled points when estimating the ',...
'model parameters. Smaller values use more of the data, but the procedure ',...
'is slower.']};

%------------------------------------------------------------------------
% This field can be added to opts, by replacing a line below, with:
% opts      = branch('Custom','opts',{priors,ngaus,regtype,warpreg,warpco,biasreg,biasfwhm,samp,msk});
msk = files('Masking image','msk','image',[0 1]);
msk.val = {''};
msk.help = {[...
'The segmentation can be masked by an image that conforms to ',...
'the same space as the images to be segmented.  If an image is selected, then ',...
'it must match the image(s) voxel-for voxel, and have the same ',...
'voxel-to-world mapping.  Regions containing a value of zero in this image ',...
'do not contribute when estimating the various parameters. ']};

%------------------------------------------------------------------------

opts      = branch('Custom','opts',{priors,ngaus,regtype,warpreg,warpco,biasreg,biasfwhm,samp,msk});
opts.help = {[...
'Various options can be adjusted in order to improve the performance of the '...
'algorithm with your data.  Knowing what works best should be a matter '...
'of empirical exploration.  For example, if your data has very little '...
'intensity nonuniformity artifact, then the bias regularisation should '...
'be increased.  This effectively tells the algorithm that there is very little '...
'bias in your data, so it does not try to model it.']};

%------------------------------------------------------------------------

cleanup.tag  = 'cleanup';
cleanup.type = 'menu';
cleanup.name = 'Clean up any partitions';
cleanup.help = {[...
'This uses a crude routine for extracting the brain from segmented',...
'images.  It begins by taking the white matter, and eroding it a',...
'couple of times to get rid of any odd voxels.  The algorithm',...
'continues on to do conditional dilations for several iterations,',...
'where the condition is based upon gray or white matter being present.',...
'This identified region is then used to clean up the grey and white',...
'matter partitions, and has a slight influences on the CSF partition.'],'',[...
'If you find pieces of brain being chopped out in your data, then you ',...
'may wish to disable or tone down the cleanup procedure.']};
cleanup.labels = {'Dont do cleanup','Light Clean','Thorough Clean'};
cleanup.values = {0 1 2};
cleanup.val    = {0};

%------------------------------------------------------------------------

%------------------------------------------------------------------------

% bias   = struct('type','branch','name','Bias correction','tag','bias','dim',Inf,'val',{{biasreg,biasfwhm}});
% bias.help = {[...
% 'This uses a Bayesian framework (again) to model intensity ',...
% 'inhomogeneities in the image(s).  The variance associated with each ',...
% 'tissue class is assumed to be multiplicative (with the ',...
% 'inhomogeneities).  The low frequency intensity variability is ',...
% 'modelled by a linear combination of three dimensional DCT basis ',...
% 'functions (again), using a fast algorithm (again) to generate the ',...
% 'curvature matrix.  The regularization is based upon minimizing the ',...
% 'integral of square of the fourth derivatives of the modulation field ',...
% '(the integral of the squares of the first and second derivs give the ',...
% 'membrane and bending energies respectively).']};

biascor    = mnu('Bias Corrected','biascor',{'Save Bias Corrected','Don''t Save Corrected'},{1,0});
biascor.val = {1};
biascor.help = {[...
'This is the option to produce a bias corrected version of your image. ',...
'MR images are usually corrupted by a smooth, spatially varying artifact that modulates the intensity ',...
'of the image (bias). ',...
'These artifacts, although not usually a problem for visual inspection, can impede automated ',...
'processing of the images.  The bias corrected version should have more uniform intensities within ',...
'the different types of tissues.']};

grey       = mnu('Grey Matter','GM',{...
    'None',...
    'Native Space',...
    'Unmodulated Normalised',...
    'Modulated Normalised',...
    'Native + Unmodulated Normalised',...
    'Native + Modulated Normalised',...
    'Native + Modulated + Unmodulated',...
    'Modulated + Unmodulated Normalised'},...
    {[0 0 0],[0 0 1],[0 1 0],[1 0 0],[0 1 1],[1 0 1],[1 1 1],[1 1 0]});
grey.val   = {[0 0 1]};
grey.help  = {'Options to produce grey matter images: c1*.img, wc1*.img and mwc1*.img.'};
white      = grey;
white.name = 'White Matter';
white.tag  = 'WM';
white.help = {'Options to produce white matter images: c2*.img, wc2*.img and mwc2*.img.'};
csf        = grey;
csf.name   = 'Cerebro-Spinal Fluid';
csf.tag    = 'CSF';
csf.val    = {[0 0 0]};
csf.help   = {'Options to produce CSF images: c3*.img, wc3*.img and mwc3*.img.'};

output     = branch('Output Files','output',{grey,white,csf,biascor,cleanup});
output.help = {[...
'This routine produces spatial normalisation parameters (*_seg_sn.mat files) by default. ',...
'These can be used for writing spatially normalised versions of your data, via the "Normalise: Write" option. ',...
'This mechanism may produce superior results than the "Normalise: Estimate" option, although ',...
'this may need some empirical evaluations.'],...
'',...
[...
'In addition, it also produces files that can be used for doing inverse normalisation. ',...
'If you have an image of regions defined in the standard space, then the inverse deformations ',...
'can be used to warp these regions so that it approximately overlay your image. ',...
'To use this facility, the bounding-box and voxel sizes should be set to non-finite values ',...
'(e.g. [NaN NaN NaN] for the voxel sizes, and ones(2,3)*NaN for the bounding box. ',...
'This would be done by the spatial normalisation module, which allows you to select a ',...
'set of parameters that describe the nonlinear warps, and the images that they should be applied to.'],...
'',...
[...
'There are a number of options about what data you would like the routine to produce. ',...
'The routine can be used for producing images of tissue classes, as well as bias corrected images. ',...
'The native space option will produce a tissue class image (c*) that is in alignment with ',...
'the original/* (see Figure \ref{seg1})*/.  You can also produce spatially normalised versions - both with (mwc*) and without (wc*) ',...
'modulation/* (see Figure \ref{seg2})*/. The bounding box and voxel sizes of the spatially normalised versions are the ',...
'same as that of the tissue probability maps with which they are registered. ',...
'These can be used for doing voxel-based morphometry with (both un-modulated and modulated). ',...
'All you need to do is smooth them and do the stats (which means no more questions on the mailing list ',...
'about how to do "optimized VBM").'],...
'',...
[...
'Modulation is to compensate for the effect of spatial normalisation.  When warping a series ',...
'of images to match a template, it is inevitable that volumetric differences will be introduced ',...
'into the warped images.  For example, if one subject''s temporal lobe has half the volume of that of ',...
'the template, then its volume will be doubled during spatial normalisation. This will also ',...
'result in a doubling of the voxels labeled grey matter.  In order to remove this confound, the ',...
'spatially normalised grey matter (or other tissue class) is adjusted by multiplying by its relative ',...
'volume before and after warping.  If warping results in a region doubling its volume, then the ',...
'correction will halve the intensity of the tissue label. This whole procedure has the effect of preserving ',...
'the total amount of grey matter signal in the normalised partitions.'],...
['/*',...
'\begin{figure} ',...
'\begin{center} ',...
'\includegraphics[width=150mm]{images/seg1} ',...
'\end{center} ',...
'\caption{Segmentation results. ',...
'These are the results that can be obtained in the original space of the image ',...
'(i.e. the results that are not spatially normalised). ',...
'Top left: original image (X.img). ',...
'Top right: bias corrected image (mX.img). ',...
'Middle and bottom rows: segmented grey matter (c1X.img), ',...
'white matter (c2X.img) and CSF (c3X.img). \label{seg1}} ',...
'\end{figure} */'],...
['/*',...
'\begin{figure} ',...
'\begin{center} ',...
'\includegraphics[width=150mm]{images/seg2} ',...
'\end{center} ',...
'\caption{Segmentation results. ',...
'These are the spatially normalised results that can be obtained ',...
'(note that CSF data is not shown). ',...
'Top row: The tissue probability maps used to guide the segmentation. ',...
'Middle row: Spatially normalised tissue maps of grey and white matter ',...
'(wc1X.img and wc2X.img). ',...
'Bottom row: Modulated spatially normalised tissue maps of grey and ',...
'white matter (mwc1X.img and mwc2X.img). \label{seg2}} ',...
'\end{figure} */'],...
[...
'A deformation field is a vector field, where three values are associated with ',...
'each location in the field.  The field maps from co-ordinates in the ',...
'normalised image back to co-ordinates in the original image.  The value of ',...
'the field at co-ordinate [x y z] in the normalised space will be the ',...
'co-ordinate [x'' y'' z''] in the original volume. ',...
'The gradient of the deformation field at a co-ordinate is its Jacobian ',...
'matrix, and it consists of a 3x3 matrix:'],...
'',...
'%   /                      \',...
'%   | dx''/dx  dx''/dy dx''/dz |',...
'%   |                       |',...
'%   | dy''/dx  dy''/dy dy''/dz |',...
'%   |                       |',...
'%   | dz''/dx  dz''/dy dz''/dz |',...
'%   \                      /',...
['/* \begin{eqnarray*}',...
'\begin{pmatrix}',...
'\frac{dx''}{dx} & \frac{dx''}{dy} & \frac{dx''}{dz}\cr',...
'\frac{dy''}{dx} & \frac{dy''}{dy} & \frac{dy''}{dz}\cr',...
'\frac{dz''}{dx} & \frac{dz''}{dy} & \frac{dz''}{dz}\cr',...
'\end{pmatrix}\end{eqnarray*}*/'],...
[...
'The value of dx''/dy is a measure of how much x'' changes if y is changed by a ',...
'tiny amount. ',...
'The determinant of the Jacobian is the measure of relative volumes of warped ',...
'and unwarped structures.  The modulation step simply involves multiplying by ',...
'the relative volumes /*(see Figure \ref{seg2})*/.']};
%------------------------------------------------------------------------

job        = branch('Segment','preproc',{data,output,opts});
job.prog   = @execute;
job.vfiles = @vfiles;
job.help   = {[...
'Segment, bias correct and spatially normalise - all in the same model/* \cite{ashburner05}*/. ',...
'This function can be used for bias correcting, spatially normalising ',...
'or segmenting your data.'],...
'',...
[...
'Many investigators use tools within older versions of SPM for '...
'a technique that has become known as "optimised" voxel-based '...
'morphometry (VBM). '...
'VBM performs region-wise volumetric comparisons among populations of subjects. '...
'It requires the images to be spatially normalised, segmented into '...
'different tissue classes, and smoothed, prior to performing '...
'statistical tests/* \cite{wright_vbm,am_vbmreview,ashburner00b,john_should}*/. The "optimised" pre-processing strategy '...
'involved spatially normalising subjects'' brain images to a '...
'standard space, by matching grey matter in these images, to '...
'a grey matter reference.  The historical motivation behind this '...
'approach was to reduce the confounding effects of non-brain (e.g. scalp) '...
'structural variability on the registration. '...
'Tissue classification in older versions of SPM required the images to be registered '...
'with tissue probability maps. After registration, these '...
'maps represented the prior probability of different tissue classes '...
'being found at each location in an image.  Bayes rule can '...
'then be used to combine these priors with tissue type probabilities '...
'derived from voxel intensities, to provide the posterior probability.'],...
'',...
[...
'This procedure was inherently circular, because the '...
'registration required an initial tissue classification, and the '...
'tissue classification requires an initial registration.  This circularity '...
'is resolved here by combining both components into a single '...
'generative model. This model also includes parameters that account '...
'for image intensity non-uniformity. '...
'Estimating the model parameters (for a maximum a posteriori solution) '...
'involves alternating among classification, bias correction and registration steps. '...
'This approach provides better results than simple serial applications of each component.'],...
'',[...
'Note that multi-spectral segmentation (e.g. from a registered T1 and T2 image) is ',...
'not yet implemented, but is planned for a future SPM version.']};

return;
%------------------------------------------------------------------------

%------------------------------------------------------------------------
function execute(job)
job.opts.tpm = strvcat(job.opts.tpm{:});
if isfield(job.opts,'msk'),
    job.opts.msk = strvcat(job.opts.msk{:});
end;
for i=1:numel(job.data),
    res           = ipctb_spm_preproc(job.data{i},job.opts);
    [sn(i),isn]   = ipctb_spm_prep2sn(res);
    [pth,nam]     = ipctb_spm_fileparts(job.data{i});
    savefields(fullfile(pth,[nam '_seg_sn.mat']),sn(i));
    savefields(fullfile(pth,[nam '_seg_inv_sn.mat']),isn);
end;
ipctb_spm_preproc_write(sn,job.output);
return;
%------------------------------------------------------------------------

%------------------------------------------------------------------------
function savefields(fnam,p)
if length(p)>1, error('Can''t save fields.'); end;
fn = fieldnames(p);
if numel(fn)==0, return; end;
for i=1:length(fn),
    eval([fn{i} '= p.' fn{i} ';']);
end;
if ipctb_spm_matlab_version_chk('7') >= 0
    save(fnam,'-V6',fn{:});
else
    save(fnam,fn{:});
end;

return;
%------------------------------------------------------------------------

%------------------------------------------------------------------------
function vf = vfiles(job)
opts  = job.output;
sopts = [opts.GM;opts.WM;opts.CSF];
vf    = cell(numel(job.data),2);
for i=1:numel(job.data),
    [pth,nam,ext,num] = ipctb_spm_fileparts(job.data{i});
    vf{i,1} = fullfile(pth,[nam '_seg_sn.mat']);
    vf{i,2} = fullfile(pth,[nam '_seg_inv_sn.mat']);
    j       = 3;
    if opts.biascor,
        vf{i,j} = fullfile(pth,['m' nam ext ',1']);
        j       = j + 1;
    end;
    for k1=1:3,
        if sopts(k1,3),
            vf{i,j} = fullfile(pth,[  'c', num2str(k1), nam, ext, ',1']);
            j       = j + 1;
        end;
        if sopts(k1,2),
            vf{i,j} = fullfile(pth,[ 'wc', num2str(k1), nam, ext, ',1']);
            j       = j + 1;
        end;
        if sopts(k1,1),
            vf{i,j} = fullfile(pth,['mwc', num2str(k1), nam, ext, ',1']);
            j       = j + 1;
        end;
    end;
end;
vf = vf(:);

