### Simple differential expression tests

import sys, io, os, gzip, copy, re, time, pickle, argparse
import numpy as np
import pandas as pd
import scipy.stats
from scipy.sparse import *
from joblib.parallel import Parallel, delayed

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import utilt

parser = argparse.ArgumentParser()
parser.add_argument('--input', type=str, help='')
parser.add_argument('--output', type=str, help='')
parser.add_argument('--feature', type=str, default='', help='')
parser.add_argument('--feature_label', type=str, default = "gene", help='')
parser.add_argument('--min_ct_per_feature', default=50, type=int, help='')
parser.add_argument('--max_pval_output', default=1e-3, type=float, help='')
parser.add_argument('--min_fold_output', default=1.5, type=float, help='')
parser.add_argument('--min_output_per_factor', default=10, type=int, help='Even when there are no significant DE genes, output top genes for each factor')
parser.add_argument('--thread', default=1, type=int, help='')
args = parser.parse_args()

pcut=args.max_pval_output
fcut=args.min_fold_output
gene_kept = set()
if os.path.exists(args.feature):
    feature = pd.read_csv(args.feature, sep='\t', header=0)
    gene_kept = set(feature[args.feature_label].values )

# Read aggregated count table
info = pd.read_csv(args.input,sep='\t',header=0)
oheader = []
header = []
for x in info.columns:
    y = re.match('^[A-Za-z]*_*(\d+)$', x)
    if y:
        header.append(y.group(1))
        oheader.append(x)
K = len(header)
M = info.shape[0]
reheader = {oheader[k]:header[k] for k in range(K)}
reheader[args.feature_label] = "gene"
info.rename(columns = reheader, inplace=True)
print(f"Read posterior count over {M} genes and {K} factors")

if len(gene_kept) > 0:
    info = info.loc[info.gene.isin(gene_kept), :]
info["gene_tot"] = info.loc[:, header].sum(axis=1)
info = info[info["gene_tot"] > args.min_ct_per_feature]
info.index = info.gene.values
total_umi = info.gene_tot.sum()
total_k = np.array(info.loc[:, [str(k) for k in range(K)]].sum(axis = 0) )
M = info.shape[0]

print(f"Testing {M} genes over {K} factors")

def chisq(k,info,total_k,total_umi):
    res = []
    if total_k <= 0:
        return res
    for name, v in info.iterrows():
        if v[str(k)] <= 0:
            continue
        tab=np.zeros((2,2))
        tab[0,0]=v[str(k)]
        tab[0,1]=v["gene_tot"]-tab[0,0]
        tab[1,0]=total_k-tab[0,0]
        tab[1,1]=total_umi-total_k-v["gene_tot"]+tab[0,0]
        fd=tab[0,0]/total_k/tab[0,1]*(total_umi-total_k)
        if fd < 1:
            continue
        tab = np.around(tab, 0).astype(int) + 1
        chi2, p, dof, ex = scipy.stats.chi2_contingency(tab, correction=False)
        res.append([name,k,chi2,p,fd,v["gene_tot"]])
    return res

res = []
if args.thread > 1:
    for k in range(K):
        idx_slices = [idx for idx in utilt.gen_even_slices(M, args.thread)]
        with Parallel(n_jobs=args.thread, verbose=0) as parallel:
            result = parallel(delayed(chisq)(k, \
                        info.iloc[idx, :].loc[:, [str(k), 'gene_tot']],\
                        total_k[k], total_umi) for idx in idx_slices)
        res += [item for sublist in result for item in sublist]
else:
    for name, v in info.iterrows():
        for k in range(K):
            if total_k[k] <= 0 or v[str(k)] <= 0:
                continue
            tab=np.zeros((2,2))
            tab[0,0]=v[str(k)]
            tab[0,1]=v["gene_tot"]-tab[0,0]
            tab[1,0]=total_k[k]-tab[0,0]
            tab[1,1]=total_umi-total_k[k]-v["gene_tot"]+tab[0,0]
            fd=tab[0,0]/total_k[k]/tab[0,1]*(total_umi-total_k[k])
            if fd < 1:
                continue
            tab = np.around(tab, 0).astype(int) + 1
            chi2, p, dof, ex = scipy.stats.chi2_contingency(tab, correction=False)
            res.append([name,k,chi2,p,fd,v["gene_tot"]])

chidf=pd.DataFrame(res,columns=['gene','factor','Chi2','pval','FoldChange','gene_total'])
chidf.sort_values(by=['factor','Chi2'],ascending=[True,False],inplace=True)
chidf['Rank'] = 0
for k in range(K):
    chidf.loc[chidf.factor.eq(k), 'Rank'] = np.arange((chidf.factor==k).sum())
chidf = chidf.loc[((chidf.pval<pcut)&(chidf.FoldChange>fcut)) | (chidf.Rank < args.min_output_per_factor), :]
chidf.sort_values(by=['factor','Chi2'],ascending=[True,False])
chidf.drop(columns = 'Rank', inplace=True)

chidf.to_csv(args.output,sep='\t',float_format="%.2e",index=False)