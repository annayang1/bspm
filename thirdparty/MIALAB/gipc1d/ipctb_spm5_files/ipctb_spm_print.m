function ipctb_spm_print(fname)
% Print the graphics window
%____________________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% John Ashburner
% $Id: spm_print.m 267 2005-10-25 11:49:37Z john $


global defaults
try,

    if isfield(defaults,'ui') && isfield(defaults.ui,'print'),
        pd = defaults.ui.print;
    else
        pd = struct('opt',{{'-dpsc2'  '-append'}},'append',true,'ext','.ps');
    end;

    mon = {'Jan','Feb','Mar','Apr','May','Jun',...
            'Jul','Aug','Sep','Oct','Nov','Dec'};
    t   = clock;
    nam = ['spm_' num2str(t(1)) mon{t(2)} sprintf('%.2d',t(3))];

    if nargin<1,
        if pd.append,
            nam1 = fullfile(pwd,[nam pd.ext]);
        else
            nam1 = sprintf('%s_%3d',nam,1);
            for i=1:100000,
                nam1 = fullfile(pwd,sprintf('%s_%.3d%s',nam,i,pd.ext));
                if ~exist(nam1,'file'), break; end;
            end;
        end;
    else
        nam1 = fname;
    end;
    opts = {nam1,'-noui','-painters',pd.opt{:}};
    fg = ipctb_spm_figure('FindWin','Graphics');
    print(fg,opts{:});
catch,
    errstr = lasterr;
    tmp = [find(abs(errstr)==10),length(errstr)+1];
    str = {errstr(1:tmp(1)-1)};
    for i = 1:length(tmp)-1
        if tmp(i)+1 < tmp(i+1)
            str = [str, {errstr(tmp(i)+1:tmp(i+1)-1)}];
        end
    end
    str = {str{:},  '','- Print options are:', opts{:},...
                    '','- Current directory is:',['    ',pwd],...
                    '','            * nothing has been printed *'};
    ipctb_spm('alert!',str,'printing problem...',sqrt(-1));
end;
