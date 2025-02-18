function icatb_utilities(selectedString)
% Utilities contain tools like removing artifacts from the data

if ~exist('selectedString', 'var')
    selectedString = 'remove component(s)';
end

switch lower(selectedString)
    case 'batch'
        % Batch analysis
        icatb_batch_file_run;
    case 'remove component(s)'
        % call the function to remove artifacts
        icatb_removeArtifact;
    case 'icasso'
        % Call ICASSO GUI
        icatb_icasso;
    case 'mancovan'
        % Mancovan toolbox
        giftPath = fileparts(which('gift.m'));
        addpath(genpath(fullfile(giftPath, 'icatb_mancovan_files')));
        mancovan_toolbox;
    case {'dfnc', 'temporal dfnc'}
        % Temporal dfnc
        dfnc_toolbox;
    case {'sdfnc', 'spatial dfnc'}
        % spatial dfnc using IVA
        sdfnc_toolbox;
    case 'component labeller'
        component_labeller;
    case 'ascii_to_spm.mat'
        % form design matrix
        icatb_formDesignMat;
    case 'event average'
        icatb_eventAverage;
    case 'calculate stats'
        icatb_calculate_stats;
    case 'spectral group compare'
        icatb_compare_frequency_bins;
    case 'stats on beta weights'
        icatb_statistical_testing_TC;
    case 'spm stats'
        icatb_spm_stats;
    case 'spatial-temporal regression'
        icatb_spatial_temp_regress;
    case 'write talairach table'
        giftPath = fileparts(which('gift.m'));
        addpath(genpath(fullfile(giftPath, 'icatb_talairach_scripts')));
        % Write talairach table
        icatb_talairach;
    case 'single trial amplitudes'
        % Compute single trial amplitudes
        icatb_single_trial_amplitude;
    case 'z-shift'
        % Z-shift
        icatb_convert_to_z_shift;
    case 'percent variance'
        % Percent Variance
        icatb_percent_variance;
    case 'sbm stats'
        % SBM Stats
        icatb_stats_loadings;
    case 'image viewer'
        % Image viewer (montage, ortho plots, render options)
        icatb_image_viewer;
    case 'component explorer'
        % Component explorer
        icatb_componentExplore;
    case 'composite viewer'
        % Composite viewer
        icatb_compositeViewer;
    case {'orthogonal explorer', 'orthogonal viewer'}
        % Orthogonal explorer
        icatb_orthoViewer;
    case 'component viewer'
        % Component viewer (ortho slices + spectra plots)
        icatb_component_viewer;
    case 'group networks'
        % Group networks
        icatb_groupNetworks;
end
% end for switch
