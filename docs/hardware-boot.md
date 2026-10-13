# First J96 hardware boot record

**Status: not attempted.** Host verification is recorded separately.

Target: iPad mini 4 Wi-Fi, iPad5,1, J96, A1538, Apple A8/T7000,
128 GB, MK9N2LL/A; reported iPadOS 15.8.3.

After the first attempt, record:

- Date, host/kernel, cable and adapter arrangement.
- Artifact manifest and per-attempt combined image SHA-256.
- Whether product/board/ECID checks passed, without publishing the ECID.
- DFU, PongoOS, m1n1 and kernel handoff results.
- First visible kernel/userspace output and any panic or stall.
- USB controller binding, ACM enumeration and interactive shell result.
- CPU/memory observations and recovery to normal iPadOS.
- A specific next investigation supported by the captured logs.

Local boot logs are written under `logs/boot-*/`. Keep originals local and
add only reviewed, redacted evidence here. Successful output is described
in [first-boot.md](first-boot.md); it has not yet been observed on this iPad.
