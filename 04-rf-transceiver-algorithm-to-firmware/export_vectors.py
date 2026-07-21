#!/usr/bin/env python3
"""Export golden reference vectors for the Project 1 firmware kernels.
Run from repo root: python3 scripts/export_vectors.py
The Python here mirrors the MATLAB reference (.m files in reference/) exactly, so
the C kernels are checked against the same algorithm they were ported from."""
import numpy as np, csv, os
os.makedirs("vectors", exist_ok=True)
rng = np.random.default_rng(7)

# ---------- Schmidl-Cox + coarse CFO ----------
def schmidl_cox(rx, L, preamble_len, cp_len, frame_len):
    search_len = min(preamble_len + cp_len + 1, frame_len - 2*L)
    M = np.zeros(search_len, complex); P = np.zeros(search_len)
    for d in range(search_len):
        r1 = rx[d:d+L]; r2 = rx[d+L:d+2*L]
        M[d] = np.sum(np.conj(r1)*r2); P[d] = np.sum(np.abs(r2)**2)
    lam = np.abs(M)**2 / np.maximum(P**2, 1e-12)
    return lam, M, search_len

# build a preamble with two identical halves + a CFO, detect it
Nfft=64; L=Nfft//2; cp=16; preamble_len=Nfft; 
half = rng.standard_normal(L)+1j*rng.standard_normal(L)
preamble = np.concatenate([half, half])
frame = np.concatenate([np.zeros(cp,complex), preamble, rng.standard_normal(200)*0.01+1j*rng.standard_normal(200)*0.01])
true_eps = 0.25
n = np.arange(len(frame))
frame_cfo = frame * np.exp(1j*2*np.pi*true_eps*n/Nfft)
lam, M, slen = schmidl_cox(frame_cfo, L, preamble_len, cp, len(frame_cfo))
d_hat = int(np.argmax(lam))
eps_coarse = np.angle(M[d_hat])/np.pi
with open('vectors/sync_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Nfft','L','cp','preamble_len','frame_len','true_eps','d_hat_ref','eps_coarse_ref'])
    w.writerow([Nfft,L,cp,preamble_len,len(frame_cfo),true_eps,d_hat,'%.8f'%eps_coarse])
    # also dump the frame so C reads identical input
with open('vectors/sync_frame.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['re','im'])
    for z in frame_cfo: w.writerow(['%.10f'%z.real,'%.10f'%z.imag])

# ---------- MIMO equalizers (ZF, MMSE) ----------
def gen_case(Nr,Nt,snr_db,seed):
    r=np.random.default_rng(seed)
    H=(r.standard_normal((Nr,Nt))+1j*r.standard_normal((Nr,Nt)))/np.sqrt(2)
    x=(r.integers(0,2,Nt)*2-1 + 1j*(r.integers(0,2,Nt)*2-1))/np.sqrt(2)
    nvar=10**(-snr_db/10)
    noise=(r.standard_normal(Nr)+1j*r.standard_normal(Nr))*np.sqrt(nvar/2)
    y=H@x+noise
    zf=np.linalg.pinv(H)@y
    A=H.conj().T@H+nvar*np.eye(Nt)
    mmse=np.linalg.solve(A, H.conj().T@y)
    Ainv=np.linalg.inv(A)
    g=np.maximum(1.0-nvar*np.real(np.diag(Ainv)),1e-6)
    soft=mmse/g
    nv=np.maximum((1.0-g)/g,1e-6)
    return H,y,x,nvar,zf,mmse,soft,nv

rows=[]
cases=[]
cid=0
for (Nr,Nt) in [(4,4),(8,8),(2,2)]:
    for snr in [5,15,25]:
        H,y,x,nvar,zf,mmse,soft,nv=gen_case(Nr,Nt,snr,100+cid)
        cases.append((cid,Nr,Nt,snr,nvar,H,y,zf,mmse,soft,nv)); cid+=1
with open('vectors/equalize_vectors.csv','w',newline='') as f:
    w=csv.writer(f)
    w.writerow(['case','Nr','Nt','snr_db','nvar','H_re_im','y_re_im','zf_re_im','mmse_re_im','soft_re_im','nvar_eff'])
    for (cid,Nr,Nt,snr,nvar,H,y,zf,mmse,soft,nv) in cases:
        def flat(a): return ';'.join('%.10f'%v for z in a.reshape(-1) for v in (z.real,z.imag))
        w.writerow([cid,Nr,Nt,snr,'%.10f'%nvar,flat(H),flat(y),flat(zf),flat(mmse),flat(soft),
                    ';'.join('%.10f'%v for v in nv)])

# ---------- metrics (SINR, EVM, threshold AMC) ----------
def sinr_db(tx,rx):
    sig=np.mean(np.abs(tx)**2); err=np.mean(np.abs(tx-rx)**2)
    return 10*np.log10(sig/max(err,1e-12))
def evm_pct(tx,rx):
    err=np.mean(np.abs(tx-rx)**2); ref=np.mean(np.abs(tx)**2)
    return np.sqrt(err/max(ref,1e-12))*100
with open('vectors/metrics_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['n','tx_re_im','rx_re_im','sinr_ref','evm_ref'])
    for tcase in range(6):
        r=np.random.default_rng(200+tcase); N=32
        tx=(r.integers(0,2,N)*2-1+1j*(r.integers(0,2,N)*2-1))/np.sqrt(2)
        rx=tx+(r.standard_normal(N)+1j*r.standard_normal(N))*0.1
        flat=lambda a:';'.join('%.10f'%v for z in a for v in (z.real,z.imag))
        w.writerow([N,flat(tx),flat(rx),'%.8f'%sinr_db(tx,rx),'%.8f'%evm_pct(tx,rx)])
with open('vectors/amc_vectors.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['snr_db','M_ref','bps_ref'])
    for s in [-2,0,7.99,8,12,17.99,18,25,40]:
        if s<8: M,b=4,2
        elif s<18: M,b=16,4
        else: M,b=64,6
        w.writerow([s,M,b])

# ---------- channel estimation (LS pilots, fine CFO, Wiener application) ----------
r=np.random.default_rng(300)
Np=8; Nfft_c=32
tx_p=(r.integers(0,2,Np)*2-1+1j*(r.integers(0,2,Np)*2-1))/np.sqrt(2)
h_true=(r.standard_normal(Np)+1j*r.standard_normal(Np))/np.sqrt(2)
rx_p=h_true*tx_p+(r.standard_normal(Np)+1j*r.standard_normal(Np))*0.05
h_ls=rx_p/tx_p
# fine CFO: pilots of two symbols with a known rotation
symbol_len=40; eps_true=0.02
dphi=2*np.pi*eps_true*symbol_len/Nfft_c
p1=(r.standard_normal(Np)+1j*r.standard_normal(Np))
p2=p1*np.exp(1j*dphi)
eps_fine=np.angle(np.sum(p2*np.conj(p1)))*Nfft_c/(2*np.pi*symbol_len)
# Wiener application: random filter times pilot vector
W=(r.standard_normal((Nfft_c,Np))+1j*r.standard_normal((Nfft_c,Np)))/np.sqrt(Np)
h_all=W@h_ls
flatc=lambda a:';'.join('%.10f'%v for z in np.asarray(a).reshape(-1) for v in (z.real,z.imag))
with open('vectors/chanest_vectors.csv','w',newline='') as f:
    w=csv.writer(f)
    w.writerow(['Np','Nfft','symbol_len','rx_p','tx_p','h_ls_ref','p1','p2','eps_fine_ref','W','h_all_ref'])
    w.writerow([Np,Nfft_c,symbol_len,flatc(rx_p),flatc(tx_p),flatc(h_ls),flatc(p1),flatc(p2),
                '%.10f'%eps_fine,flatc(W),flatc(h_all)])
print("Project 1 vectors exported:", os.listdir("vectors"))
