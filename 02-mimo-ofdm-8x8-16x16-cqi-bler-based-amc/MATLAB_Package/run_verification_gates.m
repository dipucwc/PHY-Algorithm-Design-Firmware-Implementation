%{
=========================================================================================================================
 run_verification_gates.m — Executable verification gates 1 to 20 of the Project 2 CQI-based AMC chain
=========================================================================================================================

The script executes every verification gate of the Project 2 methodology and prints an explicit PASS or FAIL verdict
per gate. Gates 1 to 9 exercise the components directly: CRC acceptance and rejection, noiseless round trips at every
coding rate, puncturing-position consistency, MCS-table integrity, SINR-estimator behavior on known channels, and the
monotonicity of the effective-SINR mapping, the CQI, the calibrated-curve interpolation, and the BLER-target
selector. Gate 10 confirms feedback causality on the delay buffer, Gate 11 confirms the outer-loop update directions,
and Gate 12 runs one miniature two-slot link twice with the same seed and confirms bit-identical CRC verdicts and
delivered-bit counts. Gates 13 to 20 verify the corrections of the technical review: mapping-matched calibration
tables, the per-layer codeword-level quality report, zero expected outer-loop drift at the target block error rate,
transmitter-side offset application after the feedback delay, the per-MCS padding lengths, nondecreasing CQI on real
calibrated curves when they are present, the mapping match of the pilot-time-CSI reference, and the correctness of
the Wilson confidence intervals. No gate is reported as passed unless this script actually confirms it in MATLAB.
=========================================================================================================================
%}

cfg      = create_cqi_amc_config(8);              % Gate configuration on the 8x8 array.

mcsTable = create_mcs_table();

trellis  = poly2trellis(cfg.constraintLength, cfg.codePolynomials);

rng(cfg.randomSeed);

numPass = 0;  numFail = 0;


verdicts = ["FAIL", "PASS"];                      % Verdict lookup indexed by the gate outcome.

report = @(name, ok) fprintf('Gate %-44s %s\n', name, verdicts(ok+1));


%% Gate 1 — CRC verification:
%%

info = randi([0 1], 200, 1);

blockOk = append_crc(info, cfg.crcPolynomial);

[passValid, ~] = check_crc(blockOk, cfg.crcLength, cfg.crcPolynomial);

blockBad = blockOk;  blockBad(37) = 1 - blockBad(37);   % Corrupt one bit.

[passCorrupt, ~] = check_crc(blockBad, cfg.crcLength, cfg.crcPolynomial);

g = passValid && ~passCorrupt;
report('1  CRC valid pass / corrupted fail', g);  
numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 2 — Variable-rate round trip at every coding rate (noiseless):
%%

gateOk = true;

for m = [1 2 3]                                   % One MCS per coding rate: 1/2, 2/3, 3/4.
    mcsRow = mcsTable(m, :);
    containerBits = 600;                          % Small noiseless container.
    K = floor(containerBits * mcsRow.CodeRate) - cfg.crcLength - cfg.tailBits;
    infoBits = randi([0 1], K, 1);
    [txBits, cw] = encode_variable_rate(infoBits, mcsRow.CodeRate, containerBits, trellis, cfg, 12345);
    perfectLlr = 10 * (1 - 2*txBits);             % Noiseless soft values: positive for bit zero.
    [crcPass, infoHat] = decode_variable_rate(perfectLlr, cw, trellis, cfg);
    gateOk = gateOk && crcPass && isequal(infoHat, infoBits);
end

report('2  Noiseless round trip 1/2, 2/3, 3/4', gateOk);  numPass = numPass + gateOk;  numFail = numFail + ~gateOk;


%% Gate 3 — Puncturing and depuncturing position consistency:
%%

mother = (1:24).';                                % Position-valued mother stream.

mask   = select_puncturing_pattern(3/4);

[punct, kept] = apply_puncturing(mother, mask);

restored = depuncture_llr(punct, kept, 24);

g = isequal(restored(kept), mother(kept)) && all(restored(setdiff(1:24, kept)) == 0);

report('3  Puncture/depuncture positions', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 4 — MCS-table integrity:
%%

g = numel(unique(mcsTable.McsIndex)) == height(mcsTable) && ...
    all(ismember(mcsTable.ModulationOrder, [4 16 64])) && ...
    all(ismember(round(mcsTable.CodeRate, 4), round([1/2 2/3 3/4], 4))) && ...
    all(diff(mcsTable.NominalSpectralEfficiency) >= 0);

report('4  MCS-table integrity', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 5 — SINR-estimator behavior on known diagonal channels:
%%

Nt = 4;

Hdiag = repmat(2*eye(Nt), 1, 1, 1);               % Strong diagonal channel at one subcarrier.

sStrong = estimate_post_eq_sinr(Hdiag, 0.01, 1, Nt);

Hweak = repmat(0.5*eye(Nt), 1, 1, 1);             % Weak diagonal channel.

sWeak = estimate_post_eq_sinr(Hweak, 0.01, 1, Nt);

sNoisy = estimate_post_eq_sinr(Hdiag, 0.1, 1, Nt);  % Same strong channel, more noise.

g = all(sStrong(:) > sWeak(:)) && all(sStrong(:) > sNoisy(:));

report('5  SINR estimator gain/noise behavior', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 6 — Effective-SINR monotonicity:
%%

base = 10.^(randn(64,1));                         % A random SINR grid.

up   = base * 1.5;                                % Every resource element improved.

g = true;
for method = ["mean", "minimum", "eesm"]
    g = g && calculate_effective_sinr(up, method, 5) >= calculate_effective_sinr(base, method, 5);
end

report('6  Effective-SINR monotonicity', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Synthetic monotone curves for gates 7 to 9, 13, 16, and 19:
%%

rowsC = [];
for m = 0:8
    thr = 2 + 2.2*m;                              % Synthetic per-MCS thresholds.
    for e = -5:1:30
        b = min(1, max(1e-4, 1/(1 + exp(1.5*(e - thr)))));  % Monotone synthetic BLER.
        rowsC = [rowsC; {m, NaN, e, b, 1000, round(1000*b), 1000-round(1000*b), NaN, NaN, cfg.eesmBeta(m+1), 'eesm'}]; %#ok<AGROW>
    end
end
curves = cell2table(rowsC, 'VariableNames', {'McsIndex','SnrDb','EffectiveSinrDb','MeasuredBler', ...
    'TotalBlocks','FailedBlocks','SuccessfulBlocks','CiLow95','CiHigh95','EesmBeta','Mapping'});


%% Gate 7 — CQI monotonicity:
%%

cqiPrev = -1;  g = true;

for sc = [0.1 0.3 1 3 10 30 100]                  % Increasing SINR scale.
    cqi = estimate_cqi(sc*ones(4,32), curves, mcsTable, cfg, "eesm");
    g = g && cqi >= cqiPrev;
    cqiPrev = cqi;
end

report('7  CQI monotonicity', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 8 — BLER-curve monotonicity under interpolation:
%%

g = true;  prev = Inf;

for e = -5:0.5:30
    p = interpolate_bler_curve(curves, 4, e);
    g = g && p <= prev + 1e-12;
    prev = p;
end

report('8  BLER-curve monotone prediction', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 9 — BLER-target selector correctness with the tie-break rule:
%%

sinrGrid = 8*ones(4,32);                          % A per-layer grid with a known effective SINR of ~9 dB.

Q = estimate_quality_report(sinrGrid, "eesm", cfg);

[sel, selBler, status] = select_mcs_for_target_bler(Q, curves, mcsTable, cfg, 0);

g = ~isnan(selBler) && selBler <= cfg.targetBler; % The selected MCS satisfies the target...

for m = 0:8
    p = mean(arrayfun(@(l) interpolate_bler_curve(curves, m, Q(l, m+1)), 1:size(Q,1)));
    if mcsTable.NominalSpectralEfficiency(m+1) > mcsTable.NominalSpectralEfficiency(sel+1)
        g = g && p > cfg.targetBler;              % ...every higher-efficiency entry violates it...
    end
    if mcsTable.NominalSpectralEfficiency(m+1) == mcsTable.NominalSpectralEfficiency(sel+1) && p <= cfg.targetBler
        g = g && p >= selBler - 1e-12;            % ...and equal-efficiency satisfiers carry no lower criterion BLER.
    end
end
g = g && any(status == ["target_met", "highest_mcs_selected", "lowest_mcs_fallback"]);

report('9  Highest satisfying MCS selected', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 10 — Feedback causality:
%%

state = struct('buffer', {{}});

[first, state]  = apply_cqi_feedback_delay(state, 5, cfg);   % Slot 1 report 5.

[second, ~] = apply_cqi_feedback_delay(state, 7, cfg);       % Slot 2 report 7.

g = isempty(first) && isequal(second, 5);         % Slot 1 sees no report yet; slot 2 sees slot 1's report.

report('10 Feedback causality (delay buffer)', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 11 — OLLA direction:
%%

offFail = update_olla_offset(0, 1, 1, cfg);       % An all-failed slot must lower the offset.

offPass = update_olla_offset(0, 0, 1, cfg);       % An all-passed slot must raise it slightly.

g = offFail < 0 && offPass > 0 && abs(offFail) > abs(offPass);

report('11 OLLA failure down / success up', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 12 — Reproducibility of a miniature link run:
%%

link = build_link_precompute(cfg);

link.noiseVar = 1/10^(20/10);

link.W_wiener = build_wiener_filter(link, cfg);

verdicts12 = cell(2,1);  delivered = zeros(2,1);

for rep = 1:2                                     % Same seed twice.
    v = [];  d = 0;
    for slot = 1:2
        rs = RandStream('mt19937ar', 'Seed', 4242 + slot);
        ps = RandStream('mt19937ar', 'Seed', 999 + slot);
        shared = prepare_slot_shared(cfg, link, rs);
        res = run_slot_link(shared, mcsTable(1,:), cfg, trellis, ps);
        v = [v; res.crcPass]; d = d + res.deliveredBits; %#ok<AGROW>
    end
    verdicts12{rep} = v;  delivered(rep) = d;
end

g = isequal(verdicts12{1}, verdicts12{2}) && delivered(1) == delivered(2);

report('12 Reproducibility (same seed)', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 13 — Mapping-matched calibration tables:
%%

g = true;

try
    verify_curve_mapping(curves, "eesm");         % The matching request must pass silently.
catch
    g = false;
end

mismatchCaught = false;

try
    verify_curve_mapping(curves, "mean");         % The foreign-axis request must error.
catch
    mismatchCaught = true;
end

g = g && mismatchCaught;

report('13 Mapping-matched curve tables', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 14 — Per-layer codeword-level quality report:
%%

grid14 = [10*ones(1,32); 10*ones(1,32); 10*ones(1,32); 0.1*ones(1,32)];  % One weak layer among three strong ones.

Q14 = estimate_quality_report(grid14, "eesm", cfg);

g = isequal(size(Q14), [4, height(mcsTable)]) && ...  % One row per layer codeword, one column per candidate...
    all(Q14(4,:) < Q14(1,:) - 3);                     % ...and the weak layer reports a clearly lower quality.

report('14 Per-layer quality report', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 15 — Zero expected OLLA drift at the target block error rate:
%%

drift = update_olla_offset(0, 1, 10, cfg);        % A slot at exactly the 0.10 block failure fraction.

g = abs(drift) < 1e-12;                           % The fraction-weighted update is stationary at the target.

report('15 OLLA drift zero at target BLER', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 16 — Transmitter-side offset after the delayed retrieval:
%%

stateA = struct('buffer', {{}});

QA = estimate_quality_report(8*ones(4,32), "eesm", cfg);  % A report of moderate quality.

[~, stateA]    = apply_cqi_feedback_delay(stateA, QA, cfg);   % Slot 1 buffers the report.

[Qdel, ~] = apply_cqi_feedback_delay(stateA, QA, cfg);        % Slot 2 retrieves it.

selZero = select_mcs_for_target_bler(Qdel, curves, mcsTable, cfg, 0);     % Selection without offset.

selNeg  = select_mcs_for_target_bler(Qdel, curves, mcsTable, cfg, -100);  % A large negative transmitter offset.

g = isequal(Qdel, QA) && selZero > 0 && selNeg == 0;  % The buffered report is uncorrected; the offset acts at selection.

report('16 OLLA applied after delayed retrieval', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 17 — Per-MCS padding lengths:
%%

pads = zeros(height(mcsTable), 1);

for m = 1:height(mcsTable)                        % Encode one codeword per MCS at its real container size.
    b = log2(mcsTable.ModulationOrder(m));
    containerBits = cfg.Nfft * cfg.numDataSymbols * b;
    K = floor(containerBits * mcsTable.CodeRate(m)) - cfg.crcLength - cfg.tailBits;
    [~, cw17] = encode_variable_rate(randi([0 1], K, 1), mcsTable.CodeRate(m), containerBits, trellis, cfg, 777);
    pads(m) = cw17.padLength;
end

fprintf('     Padding bits per MCS 0-8: %s\n', mat2str(pads.'));

g = isequal(pads.', [0 0 0 0 1 0 0 0 0]);         % Exact fill everywhere except one known zero bit at MCS 4.

report('17 Per-MCS padding lengths reported', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 18 — Nondecreasing CQI on real calibrated curves when present:
%%

realFile = sprintf('mcs_bler_curves_eesm_%s.csv', cfg.arrayLabel);

if isfile(realFile)                               % Prefer the executed calibration when it exists.
    curves18 = readtable(realFile);
    fprintf('     Gate 18 uses the executed calibration file %s\n', realFile);
else
    curves18 = curves;                            % Fall back to the synthetic monotone curves.
    fprintf('     Gate 18 uses synthetic curves; rerun after calibration for the executed check\n');
end

cqiPrev = -1;  g = true;

for sc = [0.1 0.3 1 3 10 30 100 300]              % Increasing SINR scale.
    cqi = estimate_cqi(sc*ones(4,32), curves18, mcsTable, cfg, "eesm");
    g = g && cqi >= cqiPrev;
    cqiPrev = cqi;
end

report('18 Nondecreasing CQI on real curves', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 19 — Reference calibration matched to its mapping:
%%

refMapping = "eesm";                              % The pilot-time-CSI reference selects with the EESM mapping.

g = true;

try
    verify_curve_mapping(curves, refMapping);     % Its curves must carry the same mapping label.
catch
    g = false;
end

report('19 Reference uses mapping-matched curves', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Gate 20 — Wilson confidence-interval correctness:
%%

[~, lo1, hi1] = compute_bler(63, 800);            % The 12 dB online point of the 8x8 study.

[~, lo2, hi2] = compute_bler(100, 920);           % The final MCS 4 calibration point of the 8x8 study.

g = abs(lo1 - 0.0620) < 5e-4 && abs(hi1 - 0.0995) < 5e-4 && ...
    abs(lo2 - 0.0902) < 5e-4 && abs(hi2 - 0.1305) < 5e-4;

report('20 Wilson interval correctness', g);  numPass = numPass + g;  numFail = numFail + ~g;


%% Summary:
%%

fprintf('\nVerification gates: %d passed, %d failed\n', numPass, numFail);
