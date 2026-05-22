import { exec } from "child_process";
import { promises as fs } from "fs";
import path from "path";
import { promisify } from "util";
import { getCached, setCached } from "./cache";

const execAsync = promisify(exec);

const TEMP_DIR = process.env.TEMP_DIR || "/tmp/sandbox";
const TIMEOUT_MS = 10000;

interface ExecutionResult {
  language: string;
  stdout: string;
  stderr: string;
  exitCode: number;
  cached: boolean;
  executionTime: number;
}

function getImageName(language: string): string {
  const images: Record<string, string> = {
    python: "sandbox-python",
    nodejs: "sandbox-nodejs",
  };
  return images[language];
}

function getFileExtension(language: string): string {
  const extensions: Record<string, string> = {
    python: "py",
    nodejs: "js",
  };
  return extensions[language];
}

export async function executeCode(
  language: string,
  code: string
): Promise<ExecutionResult> {
  // Check Redis cache first
  const cacheKey = `exec:${language}:${Buffer.from(code).toString("base64")}`;
  const cached = await getCached(cacheKey);
  if (cached) {
    return { ...cached, cached: true };
  }

  // Ensure temp directory exists
  await fs.mkdir(TEMP_DIR, { recursive: true });

  // Write code to temp file
  const filename = `exec_${Date.now()}_${Math.random().toString(36).slice(2)}.${getFileExtension(language)}`;
  const filepath = path.join(TEMP_DIR, filename);

  await fs.writeFile(filepath, code, "utf8");

  const image = getImageName(language);
  const startTime = Date.now();

  // Docker run command with security constraints
  const dockerCmd = [
    "docker run",
    "--rm",
    "--network none",
    "--memory=256m",
    "--cpus=0.5",
    "--read-only",
    "--tmpfs /tmp:size=10m",
    `-v ${filepath}:/sandbox/code.${getFileExtension(language)}:ro`,
    image,
  ].join(" ");

  let result: ExecutionResult;

  try {
    const { stdout, stderr } = await Promise.race([
      execAsync(dockerCmd),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("Execution timed out after 10s")), TIMEOUT_MS)
      ),
    ]);

    result = {
      language,
      stdout: stdout.trim(),
      stderr: stderr.trim(),
      exitCode: 0,
      cached: false,
      executionTime: Date.now() - startTime,
    };
  } catch (err: any) {
    result = {
      language,
      stdout: err.stdout?.trim() || "",
      stderr: err.stderr?.trim() || err.message,
      exitCode: err.code || 1,
      cached: false,
      executionTime: Date.now() - startTime,
    };
  } finally {
    // Clean up temp file
    await fs.unlink(filepath).catch(() => {});
  }

  // Cache successful results
  if (result.exitCode === 0) {
    await setCached(cacheKey, result);
  }

  return result;
}
