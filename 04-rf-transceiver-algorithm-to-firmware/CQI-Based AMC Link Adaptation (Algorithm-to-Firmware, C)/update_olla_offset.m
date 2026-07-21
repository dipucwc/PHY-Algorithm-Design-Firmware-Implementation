%{
=========================================================================================================================
 update_olla_offset.m — Outer-loop link-adaptation offset update from all block verdicts of the slot
=========================================================================================================================

The function updates the outer-loop offset once per slot from the fraction of failed blocks among all spatial-layer
codewords of the slot. A positive offset makes the MCS selection more aggressive, so the failed fraction pulls the
offset down by the failure step and the successful fraction pushes it up by the smaller success step. The expected
drift, success fraction times the up step minus failure fraction times the down step, is zero exactly when the block
error rate equals the target, because the step ratio is set to target/(1-target); an update driven by an any-layer
slot verdict would instead steer the slot-failure rate toward the target and land the block error rate far below it.
The offset is clamped to the configured range.
=========================================================================================================================
%}

function ollaOffsetDb = update_olla_offset(ollaOffsetDb, failedBlocks, totalBlocks, cfg)

failureFraction = failedBlocks / max(totalBlocks, 1);     % Fraction of layer codewords that failed the CRC.

successFraction = 1 - failureFraction;                    % Fraction that passed.

ollaOffsetDb = ollaOffsetDb ...                           % Fraction-weighted asymmetric update.
    + successFraction * cfg.ollaStepUpDb ...
    - failureFraction * cfg.ollaStepDownDb;

ollaOffsetDb = min(max(ollaOffsetDb, cfg.ollaOffsetMin), cfg.ollaOffsetMax);  % Clamp to the configured range.

end
