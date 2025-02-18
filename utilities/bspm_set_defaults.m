function varargout = bspm_set_defaults(varargin)
    % BSPM_SET_DEFAULTS Set global SPM defaults
    % 
    %   USAGE: im = bspm_set_defaults(name, varargin);
    %
    %   AVAILABLE DEFAULTS (partial name matches OK)
    %       coreg.write.prefix          
    %       deformations.modulate.prefix
    %       normalise.write.prefix      
    %       realign.write.prefix        
    %       slicetiming.prefix          
    %       smooth.prefix               
    %       mask.thresh                 
    %       stats.maxmem                
    %       stats.maxres
    %       stats.resmem
    %       stats.fmri.ufp                
    %       stats.results.svc.distmin   
    %       stats.results.svc.nbmax     
    %       stats.results.volume.distmin
    %       stats.results.volume.nbmax  
    %       ui.colour
    %       cmdline                   
    %
    % =================================================================================
    if length(varargin)==1 & any([isempty(varargin{1}) varargin{1}==0]), varargin = {}; end     
    def = { ...
            'coreg_write_prefix',           'r', ...
            'deformations_modulate_prefix', 'm', ...
            'normalise_write_prefix',       'w', ...
            'realign_write_prefix',         'r', ...
            'slicetiming_prefix',           'a', ...
            'smooth_prefix',                's', ...
            'mask_thresh',                  -Inf, ...
            'stats_maxmem',                 2^33, ...
            'stats_maxres',                 128, ...
            'stats_resmem',                 0, ...
            'stats_fmri_ufp',               0.001, ...
            'stats_results_svc_distmin',    16, ...
            'stats_results_svc_nbmax',      6, ...
            'stats_results_volume_distmin', 8, ...
            'stats_results_volume_nbmax',   3, ...
            'ui_colour',                    [0.58 0.77 0.57], ...
            'cmdline',                      1, ...
          };
    vals = setargs(def, varargin);
    if nargin==0, mfile_showhelp; fprintf('\t| - VARARGIN DEFAULTS - |\n'); disp(vals); return; end
    def = reshape(def, 2, length(def)/2)';
    def(:,2)  = struct2cell(vals);
    def(:,1) = regexprep(def(:,1), '_', '.');
    for i = 1:size(def, 1), spm_get_defaults(def{i,1}, def{i,2}); end
end

