// QMP integration test: real scanout pixels and a virtual keyboard, no host USB.
import { spawn } from 'node:child_process';
import { connect } from 'node:net';
import { readFileSync, writeFileSync, appendFileSync, existsSync, mkdirSync, rmSync, createReadStream, statSync } from 'node:fs';
import { Transform } from 'node:stream';
import { resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const [mode = 'ram', memory = '2048'] = process.argv.slice(2);
if (!['ram', 'ram-corrupt', 'ram-truncated', 'disk'].includes(mode) || !/^\d+$/.test(memory)) throw new Error('Usage: qemu-evidence.mjs [ram|ram-corrupt|ram-truncated|disk] [RAM MiB]');
const dir = resolve(`logs/qemu-${mode}-${memory}`);
mkdirSync(dir, { recursive: true });
const socketPath = resolve(`build/qemu/${mode}-${memory}.sock`);
mkdirSync(resolve('build/qemu'), { recursive: true });
rmSync(socketPath, { force: true });
const log = `${dir}/serial.log`;
writeFileSync(log, '');
const args = ['-nodefaults', '-machine', 'virt', '-cpu', 'cortex-a53', '-accel', 'tcg', '-smp', '2',
    '-global', 'virtio-mmio.force-legacy=false', '-m', memory, '-kernel', 'artifacts/qemu/Image',
    '-device', 'virtio-gpu-device', '-device', 'virtio-keyboard-device', '-device', 'virtio-tablet-device',
    '-nic', 'none', '-display', 'none', '-monitor', 'none', '-serial', 'stdio', '-no-reboot',
    '-qmp', `unix:${socketPath},server=on,wait=off`];
const payloadSocketPath = resolve(`build/qemu/${mode}-${memory}-payload.sock`);
rmSync(payloadSocketPath, { force: true });
if (mode !== 'disk') args.push('-initrd', 'artifacts/ramboot/initramfs.cpio',
    '-append', 'console=ttyAMA0 rdinit=/init panic=5 iomarchy.visual=1 iomarchy.graphics=gbm',
    '-device', 'virtio-serial-device', '-chardev', `socket,id=payload,path=${payloadSocketPath},server=on,wait=off`,
    '-device', 'virtserialport,chardev=payload,name=iomarchy.payload');
else args.push('-append', 'console=ttyAMA0 root=/dev/vda rw rootwait init=/usr/local/sbin/iomarchy-qemu-init panic=5 iomarchy.visual=1',
    '-drive', 'if=none,file=build/qemu/rootfs.ext4,format=raw,id=root', '-device', 'virtio-blk-device,drive=root');
writeFileSync(`${dir}/invocation.json`, JSON.stringify({ mode, memoryMiB: +memory, executable: 'qemu-system-aarch64', args }, null, 2));
const vm = spawn('qemu-system-aarch64', args, { stdio: ['ignore', 'pipe', 'pipe'] });
let exited = false, exitCode, socket, payloadSocket, payloadSource;
vm.stdout.on('data', data => appendFileSync(log, data));
vm.stderr.on('data', data => appendFileSync(log, data));
vm.on('error', error => { appendFileSync(log, String(error)); exited = true; exitCode = -1; });
vm.on('exit', code => { exited = true; exitCode = code; });
const pending = new Map();
let sequence = 0;
async function until(predicate, seconds, description) {
    const end = Date.now() + seconds * 1000;
    do {
        if (await predicate()) return;
        if (exited) throw new Error(`QEMU exited (${exitCode}) before ${description}`);
        await delay(500);
    } while (Date.now() < end);
    throw new Error(`Timed out: ${description}`);
}
function command(execute, arguments_ = {}) {
    const id = ++sequence;
    return new Promise((fulfil, reject) => {
        const timer = setTimeout(() => { pending.delete(id); reject(new Error(`QMP timeout: ${execute}`)); }, 15000);
        pending.set(id, reply => { clearTimeout(timer); reply.error ? reject(new Error(JSON.stringify(reply.error))) : fulfil(reply.return); });
        socket.write(JSON.stringify({ execute, arguments: arguments_, id }) + '\n');
    });
}
async function screenshot(name, color, topRows) {
    const filename = `${dir}/${name}.ppm`;
    await command('screendump', { filename });
    const bytes = readFileSync(filename);
    const header = /^P6\s+(\d+)\s+(\d+)\s+255\n/.exec(bytes.subarray(0, 100).toString('ascii'));
    if (!header) throw new Error('Unexpected QEMU PPM header');
    const width = +header[1], height = +header[2], start = header[0].length;
    if (bytes.length !== start + width * height * 3) throw new Error('Truncated display capture');
    let count = 0;
    const checkedHeight = topRows ? Math.min(topRows, height) : height;
    if (color) for (let i = start; i < start + width * checkedHeight * 3; i += 3)
        if (color.every((value, channel) => Math.abs(bytes[i + channel] - value) <= 3)) ++count;
    const evidence = { width, height, checkedHeight, color, matchedPixels: count, fraction: count / (width * checkedHeight) };
    if (name === 'omarchy-shell') {
        // Ignore the bar and cursor-sized details: a missing image reader used
        // to leave a solid background while the shell still appeared alive.
        const bins = new Set();
        let brightPixels = 0;
        for (let i = start + width * 64 * 3; i < bytes.length; i += 3) {
            bins.add(((bytes[i] >> 3) << 10) | ((bytes[i + 1] >> 3) << 5) | (bytes[i + 2] >> 3));
            if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 90) ++brightPixels;
        }
        evidence.wallpaper = { colorBins: bins.size, brightPixels, brightFraction: brightPixels / (width * (height - 64)) };
    }
    writeFileSync(`${dir}/${name}.json`, JSON.stringify(evidence, null, 2));
    return evidence.fraction;
}
const marker = text => readFileSync(log, 'utf8').includes(text);
async function desktopCapture() {
    const barFraction = await screenshot('omarchy-shell', [26, 27, 38], 64);
    const { wallpaper } = JSON.parse(readFileSync(`${dir}/omarchy-shell.json`, 'utf8'));
    return barFraction > 0.2 && wallpaper.colorBins >= 64 && wallpaper.brightFraction > 0.1;
}
async function menuCapture() {
    await screenshot('omarchy-menu');
    const before = readFileSync(`${dir}/omarchy-shell.ppm`);
    const after = readFileSync(`${dir}/omarchy-menu.ppm`);
    const header = /^P6\s+(\d+)\s+(\d+)\s+255\n/.exec(before.subarray(0, 100).toString('ascii'));
    if (!header || before.length !== after.length || !before.subarray(0, header[0].length).equals(after.subarray(0, header[0].length)))
        throw new Error('Display geometry changed while opening the menu');
    let changedPixels = 0;
    for (let i = header[0].length; i < before.length; i += 3)
        if ([0, 1, 2].some(channel => Math.abs(before[i + channel] - after[i + channel]) > 12)) ++changedPixels;
    const fraction = changedPixels / (+header[1] * +header[2]);
    writeFileSync(`${dir}/menu-difference.json`, JSON.stringify({ changedPixels, fraction }, null, 2));
    return fraction;
}
async function transfer() {
    await until(() => existsSync(payloadSocketPath), 60, 'payload socket');
    const [bytes, digest] = readFileSync('artifacts/ramboot/payload-pin.txt', 'utf8').trim().split(' ');
    const image = 'artifacts/iomarchy-arm64-rootfs.squashfs';
    if (statSync(image).size !== +bytes) throw new Error('Payload size differs from the bootstrap pin');
    return new Promise((fulfil, reject) => {
        payloadSocket = connect(payloadSocketPath);
        let text = '', started = false;
        payloadSocket.on('error', reject);
        payloadSocket.on('data', chunk => {
            text += chunk.toString();
            for (;;) {
                const end = text.indexOf('\n');
                if (end < 0) break;
                const line = text.slice(0, end); text = text.slice(end + 1);
                appendFileSync(`${dir}/transfer.log`, line + '\n');
                if (line === `READY ${bytes} ${digest}` && !started) {
                    started = true;
                    payloadSource = createReadStream(image, { highWaterMark: 65536,
                        ...(mode === 'ram-truncated' ? { end: 65535 } : {}) });
                    payloadSource.on('error', reject);
                    let first = true;
                    const mutate = new Transform({ transform(data, encoding, callback) {
                        if (first && mode === 'ram-corrupt') data[0] ^= 1;
                        first = false;
                        callback(null, data);
                    }});
                    payloadSource.pipe(mutate).pipe(payloadSocket, { end: mode === 'ram-truncated' });
                } else if (line === `VERIFIED ${digest}`) {
                    fulfil();
                } else { reject(new Error(`Unexpected payload handshake: ${line}`)); }
            }
        });
        payloadSocket.on('close', () => {
            if (mode.startsWith('ram-')) fulfil();
            else reject(new Error('Payload channel closed before verification'));
        });
    });
}
let failure;
const watchdog = setTimeout(() => { vm.kill('SIGKILL'); }, 600000);
try {
    await until(() => existsSync(socketPath), 60, 'QMP socket');
    socket = connect(socketPath);
    let buffer = '', greeting = false;
    socket.on('error', error => { failure ??= error; });
    socket.on('data', chunk => {
        buffer += chunk.toString();
        for (;;) {
            const end = buffer.indexOf('\n');
            if (end < 0) break;
            const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
            if (!line.trim()) continue;
            const reply = JSON.parse(line);
            if (reply.QMP) greeting = true;
            if (pending.has(reply.id)) { const complete = pending.get(reply.id); pending.delete(reply.id); complete(reply); }
        }
    });
    await until(() => greeting, 15, 'QMP greeting');
    await command('qmp_capabilities');
    const blocks = await command('query-block');
    writeFileSync(`${dir}/block-devices.json`, JSON.stringify(blocks, null, 2));
    if (mode !== 'disk' && blocks.length !== 0) throw new Error('RAM test unexpectedly has an emulated disk');
    let transferError;
    const transferred = mode === 'disk' ? Promise.resolve() : transfer().catch(error => { transferError = error; });
    if (mode.startsWith('ram-')) {
        await until(() => exited, 300, 'rejection of invalid payload');
        const expected = mode === 'ram-corrupt' ? 'payload digest mismatch' : 'payload disconnected';
        if (!marker(`IOMARCHY_RAM_FAIL ${expected}`) || marker('IOMARCHY_RAM_ROOT_READY'))
            throw new Error('Invalid transfer was not rejected before mounting');
        console.log(`IOMARCHY_RAM_TRANSFER_REJECTED ${mode} before root mount`);
    } else {
    await until(() => marker('IOMARCHY_QEMU_VISUAL_READY'), 300, 'Wayland terminal');
    await until(async () => (await screenshot('before-key', [190, 18, 60])) > 0.1, 45, 'red terminal pixels');
    await command('send-key', { keys: [{ type: 'qcode', data: 'x' }], 'hold-time': 100 });
    await until(async () => (await screenshot('after-key', [21, 128, 61])) > 0.1, 30, 'green pixels after keyboard input');
    console.log('IOMARCHY_QEMU_VISIBLE_INPUT_PASS red -> virtual x key -> green');
    await command('send-key', { keys: [{ type: 'qcode', data: 'q' }], 'hold-time': 100 });
    await until(() => marker('IOMARCHY_QEMU_SHELL_CAPTURE_READY'), 100, 'uncovered real Omarchy bar');
    // The pinned Tokyo Night bar is opaque #1a1b26. Its pixels must be visible
    // near the top of the actual scanout, not hidden by the black login cover.
    await until(desktopCapture, 25, 'visible Omarchy bar and wallpaper pixels');
    console.log('IOMARCHY_QEMU_SHELL_VISIBLE_PASS mapped bar and Tokyo Night scanout pixels');
    console.log('IOMARCHY_QEMU_WALLPAPER_VISIBLE_PASS nonuniform image below the bar');
    const display = JSON.parse(readFileSync(`${dir}/omarchy-shell.json`, 'utf8'));
    // The pinned default top bar's left menu button is centered at (16, 13).
    await command('input-send-event', { events: [
        { type: 'abs', data: { axis: 'x', value: Math.round(16 / (display.width - 1) * 32767) } },
        { type: 'abs', data: { axis: 'y', value: Math.round(13 / (display.height - 1) * 32767) } }
    ] });
    await delay(300);
    await command('input-send-event', { events: [{ type: 'btn', data: { button: 'left', down: true } }] });
    await delay(100);
    await command('input-send-event', { events: [{ type: 'btn', data: { button: 'left', down: false } }] });
    await until(() => marker('IOMARCHY_QEMU_MENU_OPEN'), 90, 'menu after pointer click');
    // A created layer can precede its first buffer by a long software-renderer
    // compile under TCG. Still require the same visible pixels, with a bounded
    // window matching the surrounding guest/session readiness checks.
    const menuStarted = Date.now();
    await until(async () => (await menuCapture()) > 0.05, 60, 'visible menu pixels');
    console.log(`IOMARCHY_QEMU_MENU_RENDER_MS ${Date.now() - menuStarted}`);
    await command('send-key', { keys: [{ type: 'qcode', data: 'esc' }], 'hold-time': 100 });
    await until(() => marker('IOMARCHY_QEMU_MENU_CLOSED'), 90, 'menu dismissal by Escape');
    console.log('IOMARCHY_QEMU_MENU_INPUT_PASS pointer opens real menu, pixels change, Escape closes it');
    await until(() => exited, 60, 'guest shutdown');
    if (exitCode !== 0 || !marker('IOMARCHY_QEMU_USERSPACE_PASS') || !marker('IOMARCHY_QEMU_SESSION_RESULT 0'))
        throw new Error('Guest session did not pass');
    if (mode === 'ram' && !marker('IOMARCHY_RAM_OVERLAY_PASS')) throw new Error('RAM overlay was not verified');
    await transferred;
    if (transferError) throw transferError;
    }
    writeFileSync(`${dir}/result.json`, JSON.stringify({ passed: true, mode, memoryMiB: +memory }, null, 2));
} catch (error) {
    failure = error;
    if (socket && !exited) {
        try { await screenshot('failure'); } catch { /* preserve the original failure */ }
        // Let the guest's bounded diagnostics finish and print graphics logs.
        try { await command('send-key', { keys: [{ type: 'qcode', data: 'esc' }] }); } catch { /* exiting */ }
        try { await command('send-key', { keys: [{ type: 'qcode', data: 'x' }] }); } catch { /* exiting */ }
        await delay(1000);
        try { await command('send-key', { keys: [{ type: 'qcode', data: 'q' }] }); } catch { /* exiting */ }
        try { await until(() => exited, 45, 'failure diagnostics'); } catch { /* bounded cleanup below */ }
    }
    writeFileSync(`${dir}/result.json`, JSON.stringify({ passed: false, mode, memoryMiB: +memory, error: String(error) }, null, 2));
} finally {
    clearTimeout(watchdog);
    socket?.destroy();
    payloadSource?.destroy();
    payloadSocket?.destroy();
    if (!exited) vm.kill('SIGKILL');
    console.log(readFileSync(log, 'utf8'));
}
if (failure) { console.error(failure); process.exitCode = 1; }
