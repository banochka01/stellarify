import net from "node:net";

const [, , targetHost, targetPortRaw] = process.argv;
const targetPort = Number(targetPortRaw);

if (!targetHost || !Number.isInteger(targetPort) || targetPort < 1 || targetPort > 65535) {
  process.stderr.write("Usage: node socks-proxy.mjs <host> <port>\n");
  process.exit(2);
}

const socket = net.connect({ host: "127.0.0.1", port: 7890 });
socket.setNoDelay(true);
socket.on("error", (error) => {
  process.stderr.write(`SOCKS proxy error: ${error.message}\n`);
  process.exit(1);
});

function readReply(expectedLength) {
  return new Promise((resolve, reject) => {
    let buffered = Buffer.alloc(0);
    const onData = (chunk) => {
      buffered = Buffer.concat([buffered, chunk]);
      const needed = expectedLength(buffered);
      if (needed === null || buffered.length < needed) return;
      socket.off("data", onData);
      socket.off("end", onEnd);
      resolve({ reply: buffered.subarray(0, needed), extra: buffered.subarray(needed) });
    };
    const onEnd = () => reject(new Error("SOCKS proxy closed during handshake"));
    socket.on("data", onData);
    socket.once("end", onEnd);
  });
}

await new Promise((resolve) => socket.once("connect", resolve));
socket.write(Buffer.from([0x05, 0x01, 0x00]));
const greeting = await readReply(() => 2);
if (greeting.reply[0] !== 0x05 || greeting.reply[1] !== 0x00) {
  throw new Error("SOCKS proxy does not accept unauthenticated connections");
}

const host = Buffer.from(targetHost, "utf8");
if (host.length > 255) throw new Error("Target host is too long");
socket.write(
  Buffer.from([
    0x05,
    0x01,
    0x00,
    0x03,
    host.length,
    ...host,
    (targetPort >> 8) & 0xff,
    targetPort & 0xff,
  ]),
);

const connection = await readReply((buffer) => {
  if (buffer.length < 5) return null;
  if (buffer[3] === 0x01) return 10;
  if (buffer[3] === 0x04) return 22;
  if (buffer[3] === 0x03) return 7 + buffer[4];
  throw new Error("SOCKS proxy returned an unknown address type");
});
if (connection.reply[0] !== 0x05 || connection.reply[1] !== 0x00) {
  throw new Error(`SOCKS proxy connection failed with code ${connection.reply[1]}`);
}

if (connection.extra.length) process.stdout.write(connection.extra);
process.stdin.pipe(socket);
socket.pipe(process.stdout);
process.stdin.resume();
