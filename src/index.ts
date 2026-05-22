import express, { Request, Response } from "express";
import { executeCode } from "./runner";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.post("/execute", async (req: Request, res: Response) => {
  const { language, code } = req.body;

  if (!language || !code) {
    return res.status(400).json({ error: "Missing required fields: language, code" });
  }

  if (!["python", "nodejs"].includes(language)) {
    return res.status(400).json({ error: "Unsupported language. Use: python, nodejs" });
  }

  try {
    const result = await executeCode(language, code);
    return res.json(result);
  } catch (err: any) {
    console.error("Execution error:", err.message);
    return res.status(500).json({ error: "Execution failed", details: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Polyglot Sandbox API running on port ${PORT}`);
});
