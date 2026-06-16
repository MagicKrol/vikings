import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const viteBin = path.join(rootDir, "node_modules", ".bin", "vite");

const children = [
	spawn(process.execPath, ["server/index.js"], {
		cwd: rootDir,
		env: process.env,
		stdio: "inherit"
	}),
	spawn(viteBin, ["--host", "127.0.0.1"], {
		cwd: rootDir,
		env: process.env,
		stdio: "inherit"
	})
];

let shuttingDown = false;

function stopChildren() {
	shuttingDown = true;
	for (const child of children) {
		if (!child.killed) {
			child.kill("SIGTERM");
		}
	}
}

for (const child of children) {
	child.on("error", (error) => {
		console.error(error.message);
		stopChildren();
		process.exit(1);
	});

	child.on("exit", (code) => {
		if (shuttingDown) {
			return;
		}
		if (code !== 0 && code !== null) {
			stopChildren();
			process.exit(code);
		}
	});
}

process.on("SIGINT", () => {
	stopChildren();
	process.exit(0);
});

process.on("SIGTERM", () => {
	stopChildren();
	process.exit(0);
});
