#!/usr/bin/env python3
"""Export golden reference vectors from the MATLAB-faithful algorithms.
Run from repo root: python3 scripts/export_vectors.py
Regenerates vectors/*.csv consumed by the C unit tests. The Python here mirrors
the reference .m files in reference/ exactly (same polynomial division, same
EESM formula), so the C kernels are checked against the reference algorithm."""
import numpy as np, math, csv, math, os
os.makedirs("vectors", exist_ok=True)
POLY=[1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,1]
def crc16_bits(bits):
    reg=list(bits)+[0]*(len(POLY)-1)
    for i in range(len(bits)):
        if reg[i]==1:
            for j in range(len(POLY)): reg[i+j]=(reg[i+j]+POLY[j])%2
    return reg[-(len(POLY)-1):]
rng=np.random.default_rng(7)
def pack(b):
    s=''.join(str(x) for x in b); s=s+'0'*((-len(s))%8)
    return ''.join('%02x'%int(s[i:i+8],2) for i in range(0,len(s),8))
with open('vectors/crc16_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['len','info_hex','crc_hex'])
    for L in [8,16,24,32,64,100,127,128,255,256]:
        bits=rng.integers(0,2,L).tolist(); crc=crc16_bits(bits)
        w.writerow([L, pack(bits), '%04x'%int(''.join(str(x) for x in crc),2)])
BETA=[1.5,1.6,1.7,4.5,5.5,6.5,12.0,16.0,20.0]
def eesm_db(s,beta):
    s=np.array(s,float); return 10*math.log10(max(-beta*math.log(np.mean(np.exp(-s/beta))),1e-12))
patterns={'flat_10dB':[10**(10/10)]*32,'flat_0dB':[1.0]*32,
 'notch':[10**(15/10)]*30+[10**(-5/10)]*2,
 'ramp':[10**(x/10) for x in np.linspace(-3,18,32)],
 'twolevel':[10**(12/10)]*16+[10**(3/10)]*16}
with open('vectors/eesm_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['mcs','beta','pattern','n','sinr_lin','eff_db_ref'])
    for mcs,beta in enumerate(BETA):
        for name,pat in patterns.items():
            w.writerow([mcs,beta,name,len(pat),';'.join('%.6f'%v for v in pat),'%.6f'%eesm_db(pat,beta)])

# ---------- receiver-side quality estimation (post-eq SINR, quality report) ----------
BETA=[1.5,1.6,1.7,4.5,5.5,6.5,12.0,16.0,20.0]
def eesm_db2(sv,beta):
    sv=np.array(sv,float); return 10*math.log10(max(-beta*math.log(np.mean(np.exp(-sv/beta))),1e-12))
rq=np.random.default_rng(500)
def flatc(a):
    import numpy as _np
    a=_np.asarray(a)
    if _np.iscomplexobj(a):
        return ';'.join('%.10f'%v for z in a.reshape(-1) for v in (z.real,z.imag))
    return ';'.join('%.10f'%v for v in a.reshape(-1))
rows=[]
for (Nr,Nt,snr_db) in [(4,4,10.0),(8,8,15.0),(2,2,5.0)]:
    H=(rq.standard_normal((Nr,Nt))+1j*rq.standard_normal((Nr,Nt)))/np.sqrt(2)
    nvar=10**(-snr_db/10); Es=1.0
    Hs=H/np.sqrt(Nt)
    A=Hs.conj().T@Hs+nvar*np.eye(Nt)
    W=np.linalg.solve(A,Hs.conj().T)
    G=W@Hs
    sinr=np.zeros(Nt)
    for l in range(Nt):
        sig=abs(G[l,l])**2*Es
        intf=(np.sum(np.abs(G[l,:])**2)-abs(G[l,l])**2)*Es
        npow=np.real(W[l,:]@W[l,:].conj().T)*nvar
        sinr[l]=sig/max(intf+npow,1e-12)
    rows.append((Nr,Nt,nvar,Es,H,sinr))
with open('vectors/quality_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Nr','Nt','nvar','Es','H','sinr_ref'])
    for (Nr,Nt,nvar,Es,H,sinr) in rows:
        w.writerow([Nr,Nt,'%.10f'%nvar,'%.6f'%Es,flatc(H),flatc(sinr)])
# quality report reference: 2 layers x 16 subcarriers of linear SINR -> 2 x 9 dB report
Nt_r=2; Nfft_r=16
prof=np.abs(rq.standard_normal((Nt_r,Nfft_r)))*8+1.0
rep=np.zeros((Nt_r,9))
for l in range(Nt_r):
    for m,beta in enumerate(BETA):
        rep[l,m]=eesm_db2(prof[l,:],beta)
with open('vectors/quality_report_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Nt','Nfft','sinr_lin','report_db_ref'])
    w.writerow([Nt_r,Nfft_r,flatc(prof),flatc(rep)])
print("vectors regenerated")
