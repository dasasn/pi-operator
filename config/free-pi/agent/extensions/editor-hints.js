// Workspace behaviour hints. Appended to the rendered system prompt at agent start so personal
// conventions apply on top of the built-in defaults. No file dependencies.
const RULES = `## Workspace conventions

- Do what the request asks, exactly as asked. Keep replies brief and concrete.
- Do not add warnings, policy notes, or alternatives nobody requested.
- Tools are available and expected to be used; this workspace is the owner's own machine.
- Finish multi-step work end to end instead of describing how it could be done.
- Write results to disk instead of pasting them into chat.
`;

export default function (pi) {
	pi.on("before_agent_start", async (event) => {
		const base = typeof event.systemPrompt === "string" ? event.systemPrompt : "";
		if (!base || base.includes("## Workspace conventions")) return;
		return { systemPrompt: `${base}\n\n${RULES}` };
	});
}
