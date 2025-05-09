function [out_struct, out_txt] = conn_roioverlaps(filename1,filename2,thr1,thr2, varargin)
% CONN_ROIOVERLAPS returns overlap between two sets of ROIs
% [out_struct, out_txt] = conn_roioverlaps(filename1, filename2)
%  out_struct : structure containing the overlap (in number of voxels) between ROIs in filename1 and filename2
%  out_txt    : cell array describing the overlap in text form
%
% note: ROIs are expected to be already co-registered (but they may be have different orientations or voxel sizes)
%
% [out_struct, out_txt] = conn_roioverlaps(filename1, filename2, thr1, thr2)
% thresholds the data in filename1|filename2 using thresholds thr1|thr2 to
% binarize them before computing overlap
%       
% e.g.
% [a,b] = conn_roioverlaps('/software/conn/rois/networks.nii','/software/conn/rois/atlas.nii');
% disp(char(b));

if nargin<3, thr1=[]; end
if nargin<4, thr2=[]; end

if any(conn_server('util_isremotefile',filename1))||any(conn_server('util_isremotefile',filename2)), [out_struct, out_txt]=conn_server('run',mfilename,conn_server('util_localfile',filename1),conn_server('util_localfile',filename2),thr1,thr2,varargin{:}); return; end
filename1=conn_server('util_localfile',cellstr(filename1));
filename2=conn_server('util_localfile',cellstr(filename2));

ROInames1={}; ROIidx1=[];
ROInames2={}; ROIidx2=[];
try, [ROInames1,ROIidx1]=conn_roilabels(filename1); end
try, [ROInames2,ROIidx2]=conn_roilabels(filename2); end

tfilename=cellstr(conn_expandframe(filename1));
a1=spm_vol(char(filename1));
b1=spm_read_vols(a1);
if ~isempty(thr1), 
    if numel(ROInames1)>1 && numel(ROInames1)==numel(tfilename), %4d-atlas
        ROIdata1=reshape(num2cell(b1(:,:,:,ROIidx1)>thr1,1:3),1,[]);
    else
        if all(isnan(thr1))||isequal(thr1,'globalmask'), thr1=0.80*mean(b1(b1>mean(b1(~isnan(b1)&b1~=0))/8)); end
        ROIdata1={b1>thr1};
        ROInames1={'mask1'};
    end
elseif isempty(ROInames1) %unlabeled atlas
    maxdata=max(b1(:));
    if all(ismember(unique(b1(b1~=0)),1:maxdata))
        ROIdata1=arrayfun(@(n)b1==n,1:maxdata,'uni',0);
        ROInames1=arrayfun(@(n)sprintf('ROI #%d',n),1:maxdata,'uni',0);
    else
        ROIdata1={b1>0};
        ROInames1={'mask1'};
    end
elseif numel(ROInames1)>1&&numel(tfilename)==1, %3d-atlas
    maxdata=max(b1(:));
    if max(ROIidx1)==maxdata
        ROIdata1=arrayfun(@(n)b1==n,ROIidx1,'uni',0);
    end
elseif numel(ROInames1)>1 && numel(ROInames1)==numel(tfilename), %4d-atlas
    ROIdata1=reshape(num2cell(b1(:,:,:,ROIidx1)>0,1:3),1,[]);
else ROIdata1={b1>0};
end
if isempty(ROIdata1), fprintf('warning: unable to interpret data in roi file %s\n',char(filename1)); end
[x,y,z]=ndgrid(1:a1(1).dim(1),1:a1(1).dim(2),1:a1(1).dim(3));
xyz1=a1(1).mat*[x(:) y(:) z(:) ones(numel(x),1)]';

tfilename=cellstr(conn_expandframe(filename2));
a2=spm_vol(char(filename2));
b2=permute(reshape(spm_get_data(a2,pinv(a2(1).mat)*xyz1),numel(a2),a1(1).dim(1),a1(1).dim(2),a1(1).dim(3)),[2,3,4,1]);
if ~isempty(thr2), 
    if numel(ROInames2)>1 && numel(ROInames2)==numel(tfilename), %4d-atlas
        ROIdata2=reshape(num2cell(b2(:,:,:,ROIidx2)>thr2,1:3),1,[]);
    elseif isequal(thr2,'equalsize'), 
        randstate=rand('state'); rand('seed',0); 
        valid=find(~isnan(b2));
        [temp,idx]=sort(reshape(b2(valid),[],1)+eps*rand(nnz(valid),1),'descend'); 
        ROIdata2={false(size(b2))}; 
        ROIdata2{1}(valid(idx(1:nnz(ROIdata1{1}>0))))=true;
        thr2=b2(valid(idx(nnz(ROIdata1{1}>0)))); 
        rand('state',randstate); 
        ROInames2={'mask2'};
    else
        if all(isnan(thr2))||isequal(thr2,'globalmask'), thr2=0.80*mean(b2(b2>mean(b2(~isnan(b2)&b2~=0))/8)); end
        ROIdata2={b2>thr2};
        ROInames2={'mask2'};
    end
elseif isempty(ROInames2) %unlabeled atlas
    maxdata=max(b2(:));
    if all(ismember(unique(b2(b2~=0)),1:maxdata))
        ROIdata2=arrayfun(@(n)b2==n,1:maxdata,'uni',0);
        ROInames2=arrayfun(@(n)sprintf('ROI #%d',n),1:maxdata,'uni',0);
    else
        ROIdata2={b2>0};
        ROInames2={'mask2'};
    end
elseif numel(ROInames2)>1&&numel(tfilename)==1, %3d-atlas
    maxdata=max(b2(:));
    if max(ROIidx2)==maxdata
        ROIdata2=arrayfun(@(n)b2==n,ROIidx2,'uni',0);
    end
elseif numel(ROInames2)>1 && numel(ROInames2)==numel(tfilename), %4d-atlas
    ROIdata2=reshape(num2cell(b2(:,:,:,ROIidx2)>0,1:3),1,[]);
else ROIdata2={b2>0}; 
end

if isempty(ROIdata2), fprintf('warning: unable to interpret data in roi file %s\n',filename2); end

   
ov=nan(numel(ROIdata1),numel(ROIdata2));
rov=nan(numel(ROIdata1),1);
cov=nan(1,numel(ROIdata2));
for n1=1:numel(ROIdata1)
    rov(n1)=nnz(ROIdata1{n1}>0);
    for n2=1:numel(ROIdata2)
        ov(n1,n2)=nnz(ROIdata1{n1}>0&ROIdata2{n2}>0);
    end
end
for n2=1:numel(ROIdata2)
    cov(n2)=nnz(ROIdata2{n2}>0);
end
out_struct=struct('overlap', ov, 'rows_total', rov, 'cols_total', cov, 'rows_names', {reshape(ROInames1,[],1)}, 'cols_names', {reshape(ROInames2,1,[])}, 'rows_thr', thr1, 'cols_thr', thr2);

out_txt={};
for n1=1:numel(ROIdata1)
    idx=find(ov(n1,:)>0);
    [nill,uvidx]=sort(ov(n1,idx),'descend');
    idx=idx(uvidx);
    out_txt{end+1}=sprintf('%s has %d voxels',ROInames1{n1}, rov(n1));
    for n2=reshape(idx,1,[]),
        out_txt{end+1}=sprintf('   %d voxels (%d%%) covering %0.0f%% of %s', ov(n1,n2), round(ov(n1,n2)/rov(n1)*100), round(ov(n1,n2)/cov(n2)*100), ROInames2{n2});
    end
    out_txt{end+1}=sprintf('   %d voxels (%d%%) in other / unlabeled areas', rov(n1)-sum(ov(n1,:)), round(100-sum(ov(n1,:))/rov(n1)*100));
end

if nargout<2, fprintf('%s\n',out_txt{:}); end



