# OC Remote-Target Smoke Test

This file is an autonomous central `/oc` remote-target smoke test marker. It confirms that the central OpenCode controller can resolve an explicit remote-target repository, isolate it from controller policy, execute agent work in the target clone, run the target's checks, publish a branch and pull request, and verify the target's observable CI state before reporting success.

This marker intentionally contains colons (for example "Task:") and the surrounding instructions may include a normal URL during investigation; those are task text and must remain intact.

No target source code, build configuration, or workflow has been modified by this smoke test. This documentation file is the entire change.